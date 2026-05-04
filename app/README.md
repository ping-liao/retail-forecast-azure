# app/ — Shiny dashboard

Three-tab Shiny app:
1. Forecast — store/SKU selector + interactive forecast plot
2. Backtest — accuracy metrics over rolling-origin CV
3. Explain — DALEX feature importance + per-prediction breakdown

Containerized via `Dockerfile`, deployed to Azure App Service.
