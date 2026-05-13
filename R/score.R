# R/score.R
# Load saved models, pull latest curated data, generate H=42d forward forecasts.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(lubridate)
  library(parsnip); library(recipes); library(workflows)
  library(modeltime); library(timetk)
})

storage_acct <- Sys.getenv("AZURE_STORAGE_ACCOUNT")
container    <- Sys.getenv("AZURE_STORAGE_CONTAINER", "retail-data")
stopifnot(nzchar(storage_acct))

H             <- 42L
artifacts_dir <- "artifacts"
reports_dir   <- "reports"
dir.create(reports_dir, showWarnings = FALSE, recursive = TRUE)

# Load trained models
models_path <- file.path(artifacts_dir, "baseline_models.rds")
stopifnot(file.exists(models_path))
results <- readRDS(models_path)
message("Loaded models for: ", paste(names(results), collapse = ", "))

# Download latest curated data
work_dir <- tempfile("score_")
dir.create(work_dir)
on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

curated_blob  <- "curated/daily_revenue_by_country.parquet"
curated_local <- file.path(work_dir, "daily_revenue_by_country.parquet")

message("Downloading ", curated_blob, " ...")
res <- system2("az", c(
  "storage", "blob", "download",
  "--account-name", storage_acct,
  "--container-name", container,
  "--name", curated_blob,
  "--file", curated_local,
  "--auth-mode", "login",
  "--only-show-errors", "--output", "none"
))
stopifnot(res == 0, file.exists(curated_local))

curated <- read_parquet(curated_local) |>
  select(country, invoice_date, revenue) |>
  arrange(country, invoice_date)

# Score each country
fc_list <- lapply(names(results), function(cn) {
  message("\n== Scoring ", cn, " ==")

  df <- curated |>
    filter(country == cn) |>
    select(invoice_date, revenue) |>
    pad_by_time(invoice_date, .by = "day", .pad_value = 0)

  refit <- results[[cn]]$refit

  fc <- refit |>
    modeltime_forecast(h = H, actual_data = df, conf_interval = 0.80) |>
    mutate(country = cn)

  message("  Winner model: ", results[[cn]]$winner,
          "  Forecast horizon: ", H, " days from ", max(df$invoice_date))
  fc
})

fc_all <- bind_rows(fc_list)

# Save outputs
saveRDS(fc_all, file.path(artifacts_dir, "scored_forecast.rds"))
message("\nWrote ", file.path(artifacts_dir, "scored_forecast.rds"))

fc_all |>
  select(country, .key, .index, .value, .model_desc) |>
  write.csv(file.path(reports_dir, "scored_forecast.csv"), row.names = FALSE)
message("Wrote ", file.path(reports_dir, "scored_forecast.csv"))

message("\nDone. Scored ", length(fc_list), " countries, H=", H, " days.")
