# R/prep.R
# Reads raw UCI Online Retail II xlsx from Azure Blob, cleans it,
# aggregates to daily revenue by country (top 5 + ALL_COUNTRIES),
# writes curated parquet back to Blob.
#
# Run from the project root:  Rscript R/prep.R

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(arrow)
})

# ---- Config ----
storage_acct <- Sys.getenv("AZURE_STORAGE_ACCOUNT")
container    <- Sys.getenv("AZURE_STORAGE_CONTAINER", "retail-data")
stopifnot(nzchar(storage_acct))

work_dir <- tempfile("prep_")
dir.create(work_dir)
on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

# ---- 1. Download raw xlsx via az CLI ----
raw_blob  <- "raw/online_retail_II.xlsx"
raw_local <- file.path(work_dir, "online_retail_II.xlsx")
message("Downloading ", raw_blob, " ...")
res <- system2("az", c(
  "storage", "blob", "download",
  "--account-name", storage_acct,
  "--container-name", container,
  "--name", raw_blob,
  "--file", raw_local,
  "--auth-mode", "login",
  "--only-show-errors"
))
stopifnot(res == 0, file.exists(raw_local))

# ---- 2. Read both sheets and union ----
sheets <- excel_sheets(raw_local)
message("Sheets found: ", paste(sheets, collapse = " | "))
raw <- bind_rows(lapply(sheets, function(s) {
  read_excel(raw_local, sheet = s) |>
    mutate(source_sheet = s)
}))
message("Raw rows: ", format(nrow(raw), big.mark = ","))

# ---- 3. Clean ----
clean <- raw |>
  rename(
    invoice      = Invoice,
    stock_code   = StockCode,
    description  = Description,
    quantity     = Quantity,
    invoice_date = InvoiceDate,
    price        = Price,
    customer_id  = `Customer ID`,
    country      = Country
  ) |>
  filter(
    !is.na(invoice_date),
    !startsWith(as.character(invoice), "C"),  # drop cancellations
    quantity > 0,
    price > 0
  ) |>
  mutate(
    revenue      = quantity * price,
    invoice_date = as_date(invoice_date)
  )

message("Clean rows: ", format(nrow(clean), big.mark = ","))
message("Date range: ", min(clean$invoice_date), " to ", max(clean$invoice_date))

# ---- 4. Top 5 countries by total revenue ----
top5 <- clean |>
  group_by(country) |>
  summarise(total_rev = sum(revenue), .groups = "drop") |>
  arrange(desc(total_rev)) |>
  slice_head(n = 5) |>
  pull(country)
message("Top 5 countries: ", paste(top5, collapse = ", "))

# ---- 5. Daily revenue by country + an ALL_COUNTRIES rollup ----
daily_by_country <- clean |>
  filter(country %in% top5) |>
  group_by(country, invoice_date) |>
  summarise(
    revenue     = sum(revenue),
    n_invoices  = n_distinct(invoice),
    n_items     = sum(quantity),
    .groups     = "drop"
  )

daily_all <- clean |>
  group_by(invoice_date) |>
  summarise(
    revenue    = sum(revenue),
    n_invoices = n_distinct(invoice),
    n_items    = sum(quantity),
    .groups    = "drop"
  ) |>
  mutate(country = "ALL_COUNTRIES") |>
  select(country, invoice_date, revenue, n_invoices, n_items)

curated <- bind_rows(daily_by_country, daily_all) |>
  arrange(country, invoice_date)

message("Curated rows: ", format(nrow(curated), big.mark = ","))

# ---- 6. Write parquet locally ----
out_local <- file.path(work_dir, "daily_revenue_by_country.parquet")
write_parquet(curated, out_local)
message("Wrote local parquet: ", out_local, " (",
        format(file.info(out_local)$size, big.mark = ","), " bytes)")

# ---- 7. Upload curated parquet to Blob ----
out_blob <- "curated/daily_revenue_by_country.parquet"
message("Uploading to ", out_blob, " ...")
res <- system2("az", c(
  "storage", "blob", "upload",
  "--account-name", storage_acct,
  "--container-name", container,
  "--name", out_blob,
  "--file", out_local,
  "--auth-mode", "login",
  "--overwrite",
  "--only-show-errors"
))
stopifnot(res == 0)

message("\nDone. Sample of curated data:")
print(head(curated, 10))