# Retail Demand Forecasting — End-to-End on Azure

> "A production-flavored MLOps showcase: R + tidymodels for forecasting, Azure ML for training, Shiny for the dashboard, deployed via GitHub Actions to Azure App Service."

## Live demo

**[https://retail-forecast-app.azurewebsites.net](https://retail-forecast-app.azurewebsites.net)**

Select a country, view 42-day forward revenue forecasts, and browse holdout accuracy metrics across ARIMA and XGBoost models.

## What this is

A working demonstration of how a BI/analytics engineer ships a forecasting product on the Azure stack. Pick a country, see a 6-week demand forecast, and browse rolling-origin backtest accuracy by model.

## Tech stack

| Layer | Tool |
|---|---|
| Data | Azure Blob Storage (Parquet via `arrow`) |
| Modeling | R 4.4 · tidymodels · modeltime · ARIMA · XGBoost |
| Training | Azure ML Compute Instance |
| Dashboard | Shiny + bslib + plotly |
| Container | Docker · rocker/shiny:4.4.2 · Azure Container Registry |
| Hosting | Azure App Service for Containers |
| CI/CD | GitHub Actions |

> **Coming in later steps:** Prophet models, DALEX explainability tab, Azure ML model registry, renv.lock dependency pinning.

## Repo layout
R/
ingest.R # Download Rossmann data → Azure Blob (raw)
prep.R # Clean + feature-engineer → curated Parquet
train.R # Train ARIMA + XGBoost ensemble, save artifacts
score.R # Generate 42-day forward forecasts
app/
app.R # Three-tab Shiny dashboard
Dockerfile # rocker/shiny:4.4.2 based container
azureml/
Dockerfile # Training image (rocker/tidyverse:4.4.2)
environment.yml # Azure ML environment definition
dev/
session.sh # Sets AZ_RG and AZ_STORAGE env vars
infra/
setup.sh # Azure resource provisioning
teardown.sh # Full resource cleanup
.github/workflows/
deploy.yml # Build → push to ACR → deploy to App Service

## Project status
- [x] Cloud dev environment (Azure ML Compute Instance)
- [x] Repo scaffold
- [x] Data ingestion to Blob Storage
- [x] Feature engineering pipeline (`prep.R`)
- [x] Baseline forecast models — ARIMA + XGBoost per country (`train.R`)
- [x] Scoring pipeline — 42-day forward forecasts (`score.R`)
- [x] Shiny dashboard — Forecast + Backtest tabs
- [x] Containerization (Docker + Azure Container Registry)
- [x] App Service deployment
- [x] CI/CD pipeline (GitHub Actions)
- [ ] Prophet models (deferred — rstan/Stan compile issues on R 4.5)
- [ ] DALEX explainability tab
- [ ] Azure ML model registry integration
- [ ] renv.lock dependency pinning
## Cost
Designed to fit within the $150/month Visual Studio Azure credit. Target run rate ~$45/month with the Compute Instance stopped when not in use. Run `infra/teardown.sh` for full cleanup.
## License
MIT — see LICENSE.
