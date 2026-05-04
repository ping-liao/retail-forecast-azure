# R/ — pipeline scripts

- `ingest.R`  — Download Rossmann data, land it in Azure Blob (raw)
- `prep.R`    — Clean, feature-engineer, write curated parquet to Blob
- `train.R`   — Train modeltime ensemble, register model in Azure ML
- `score.R`   — Generate forecasts for the dashboard
