# Retail Demand Forecasting — End-to-End on Azure

> A production-flavored MLOps showcase: R + tidymodels for forecasting, Azure ML for training and model registry, Shiny for the dashboard, deployed via GitHub Actions to Azure App Service.

## What this is

A working demonstration of how a BI/analytics engineer ships a forecasting product on the Azure stack. Pick a store, see a 6-week demand forecast with confidence intervals, browse rolling-origin backtest accuracy, and inspect what features drove each prediction.

**Live demo:** _coming soon_
**Architecture:** see `docs/architecture.png` _(coming soon)_

## Tech stack

| Layer | Tool |
|---|---|
| Data | Azure Blob Storage |
| Modeling | R 4.5 · tidymodels · modeltime · prophet |
| Training & registry | Azure Machine Learning |
| Explainability | DALEX |
| Dashboard | Shiny + bslib |
| Container | Docker · Azure Container Registry |
| Hosting | Azure App Service for Containers |
| Secrets | Azure Key Vault |
| CI/CD | GitHub Actions |

## Repo layout
## Project status

Built in the open as a learning project. See commit history for progression.

- [x] Cloud dev environment (Azure ML Compute Instance)
- [x] Repo scaffold
- [ ] Data ingestion to Blob
- [x] Feature engineering pipeline
- [ ] Baseline forecast model
- [ ] Azure ML training job
- [ ] Shiny dashboard skeleton
- [ ] Containerization
- [ ] App Service deployment
- [ ] CI/CD pipeline
- [ ] Explainability tab
- [ ] Polish + writeup

## Cost

Designed to fit within the $150/month Visual Studio Azure credit. Target run rate ~$45/month with the Compute Instance and App Service stopped/idle when not in use. See `infra/teardown.sh` for full cleanup.

## License

MIT — see LICENSE.
