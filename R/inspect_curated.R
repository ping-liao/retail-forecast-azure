# Quick look at the curated dataset, downloaded fresh from Blob.
suppressPackageStartupMessages({ library(arrow); library(dplyr) })

storage_acct <- Sys.getenv("AZURE_STORAGE_ACCOUNT")
container    <- Sys.getenv("AZURE_STORAGE_CONTAINER", "retail-data")
work <- tempfile(); dir.create(work)
local <- file.path(work, "curated.parquet")

system2("az", c("storage","blob","download",
  "--account-name", storage_acct, "--container-name", container,
  "--name","curated/daily_revenue_by_country.parquet",
  "--file", local, "--auth-mode","login","--only-show-errors"))

df <- read_parquet(local)
cat("Rows:", nrow(df), " | Countries:", n_distinct(df$country), "\n")
cat("Date range:", as.character(min(df$invoice_date)), "to",
    as.character(max(df$invoice_date)), "\n\n")
print(df |> count(country, name = "n_days"))
