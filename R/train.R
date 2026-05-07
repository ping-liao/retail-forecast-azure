# R/train.R
# NOTE: Prophet model temporarily excised on branch `step3-smoke-no-prophet`.
# Reason: rstan .onLoad failure in AML CI image (R 4.5.x). Restore in Step 4
# rocker container, which gives a fresh env. Tracking ticket: step-3-carryover.
# NOTE: Forecast plot uses base R (graphics::plot) instead of ggplot2 because
# this CI's ggplot2 4.x has an S7/S3 +.gg dispatch collision. Restore ggplot2
# version in Step 4 rocker container.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(lubridate)
  library(parsnip); library(recipes); library(workflows)
  library(rsample); library(yardstick); library(modeltime); library(timetk)
})

storage_acct <- Sys.getenv("AZURE_STORAGE_ACCOUNT")
container    <- Sys.getenv("AZURE_STORAGE_CONTAINER", "retail-data")
stopifnot(nzchar(storage_acct))

H              <- 42L
SEED           <- 1234L
COUNTRY_FILTER <- Sys.getenv("COUNTRIES_FILTER", "")

artifacts_dir <- "artifacts"
reports_dir   <- "reports"
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(reports_dir,   showWarnings = FALSE, recursive = TRUE)

work_dir <- tempfile("train_")
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

if (nzchar(COUNTRY_FILTER)) {
  keep <- strsplit(COUNTRY_FILTER, ",")[[1]] |> trimws()
  curated <- curated |> filter(country %in% keep)
  message("Filtering to: ", paste(keep, collapse = ", "))
}

message("Loaded ", format(nrow(curated), big.mark = ","),
        " rows across ", dplyr::n_distinct(curated$country), " series")

fit_one_country <- function(df_country, country_name) {
  message("\n== ", country_name, " (", nrow(df_country), " rows) ==")

  df <- df_country |>
    select(invoice_date, revenue) |>
    pad_by_time(invoice_date, .by = "day", .pad_value = 0)

  splits <- time_series_split(
    df, date_var = invoice_date,
    assess = H, cumulative = TRUE
  )

  date_only_rec <- recipe(revenue ~ invoice_date, data = training(splits))

  feat_rec <- recipe(revenue ~ invoice_date, data = training(splits)) |>
    step_timeseries_signature(invoice_date) |>
    step_rm(invoice_date) |>
    step_rm(matches("(iso|xts|hour|minute|second|am\\.pm)$")) |>
    step_dummy(all_nominal_predictors(), one_hot = TRUE) |>
    step_normalize(matches("(index\\.num)$"))

  arima_spec <- arima_reg() |> set_engine("auto_arima")

  xgb_spec <- boost_tree(
    trees = 500, learn_rate = 0.02, tree_depth = 6
  ) |> set_engine("xgboost") |> set_mode("regression")

  arima_fit <- workflow() |>
    add_model(arima_spec) |> add_recipe(date_only_rec) |>
    fit(training(splits))

  xgb_fit <- workflow() |>
    add_model(xgb_spec) |> add_recipe(feat_rec) |>
    fit(training(splits))

  models_tbl <- modeltime_table(arima_fit, xgb_fit)
  calib <- models_tbl |> modeltime_calibrate(testing(splits), quiet = TRUE)

  acc <- calib |> modeltime_accuracy() |>
    mutate(country = country_name, .before = 1)
  print(acc)

  winner_row  <- acc[which.min(acc$rmse), ]
  winner_id   <- winner_row$.model_id
  winner_name <- winner_row$.model_desc
  message("Winner: ", winner_name, " (model_id=", winner_id, ")")

  winner_only <- models_tbl[models_tbl$.model_id == winner_id, ]
  refit <- winner_only |> modeltime_refit(data = df)

  fc <- refit |>
    modeltime_forecast(h = H, actual_data = df) |>
    mutate(country = country_name)

  list(accuracy = acc, forecast = fc, refit = refit, winner = winner_name)
}

set.seed(SEED)
countries <- unique(curated$country)
results <- lapply(countries, function(c) {
  fit_one_country(filter(curated, country == c), c)
})
names(results) <- countries

acc_all <- bind_rows(lapply(results, `[[`, "accuracy"))
write.csv(acc_all, file.path(reports_dir, "baseline_accuracy.csv"), row.names = FALSE)
message("\nWrote ", file.path(reports_dir, "baseline_accuracy.csv"))
print(acc_all)

# Forecast plot — base R instead of ggplot2 (see header note)
fc_all <- bind_rows(lapply(results, `[[`, "forecast"))
n_countries <- length(unique(fc_all$country))
nrow_grid   <- ceiling(n_countries / 2)
ncol_grid   <- if (n_countries == 1) 1 else 2

png(file.path(reports_dir, "baseline_forecast.png"),
    width = 1200, height = 200 + 250 * nrow_grid, res = 100)
op <- par(mfrow = c(nrow_grid, ncol_grid), mar = c(3, 4, 2, 1), oma = c(0, 0, 3, 0))
for (cn in unique(fc_all$country)) {
  d <- fc_all[fc_all$country == cn, ]
  d_act  <- d[d$.key == "actual", ]
  d_pred <- d[d$.key == "prediction", ]
  rng    <- range(c(d_act$.value, d_pred$.value), na.rm = TRUE)
  plot(d_act$.index, d_act$.value, type = "l", col = "grey40",
       main = cn, xlab = "", ylab = "Revenue", ylim = rng)
  lines(d_pred$.index, d_pred$.value, col = "firebrick", lwd = 2)
}
mtext(paste0("Baseline daily revenue forecast (H=", H,
             "d) — ARIMA + XGBoost — Prophet excised"),
      outer = TRUE, cex = 1.1)
par(op)
dev.off()
message("Wrote ", file.path(reports_dir, "baseline_forecast.png"))

saveRDS(results, file.path(artifacts_dir, "baseline_models.rds"))
message("Wrote ", file.path(artifacts_dir, "baseline_models.rds"))

message("\nDone.")
