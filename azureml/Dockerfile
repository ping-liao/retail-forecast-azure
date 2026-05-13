# azureml/Dockerfile — Step 4 training image
# Base R 4.4.x to dodge the rstan onLoad bug we hit on the AML CI's R 4.5.x.
# Rocker's RSPM snapshot pins ggplot2 to 3.5.x for this base.

FROM rocker/tidyverse:4.4.2

LABEL org.opencontainers.image.source="https://github.com/ping-liao/retail-forecast-azure"
LABEL org.opencontainers.image.description="R training image: tidymodels + modeltime + prophet + xgboost"

# System deps: azure-cli for blob download from R/train.R
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl gnupg lsb-release ca-certificates apt-transport-https \
    && mkdir -p /etc/apt/keyrings \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
       gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
       https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Stage 0: refresh the markdown/knitr/xfun ecosystem before anything else.
# rocker/tidyverse:4.4.2 ships these slightly stale and the version skew
# manifests as "object 'attr' is not exported by 'namespace:xfun'" during
# downstream package vignette processing (hits us via GauPro -> tune -> modeltime).
RUN R -e "p <- c('xfun','knitr','rmarkdown','markdown'); \
          install.packages(p, repos='https://cloud.r-project.org', Ncpus=2); \
          m <- setdiff(p, rownames(installed.packages())); \
          if (length(m)) stop('Stage 0 missing: ', paste(m, collapse=', '))"

# Stage 1: tidymodels primitives
RUN R -e "p <- c('parsnip','recipes','workflows','rsample','yardstick'); \
          install.packages(p, repos='https://cloud.r-project.org', Ncpus=2); \
          m <- setdiff(p, rownames(installed.packages())); \
          if (length(m)) stop('Stage 1 missing: ', paste(m, collapse=', '))"

# Stage 2: parquet I/O + xgboost + ts utilities
RUN R -e "p <- c('arrow','xgboost','timetk'); \
          install.packages(p, repos='https://cloud.r-project.org', Ncpus=2); \
          m <- setdiff(p, rownames(installed.packages())); \
          if (length(m)) stop('Stage 2 missing: ', paste(m, collapse=', '))"

# Stage 3: prophet (slow — Stan compile)
RUN R -e "install.packages('prophet', repos='https://cloud.r-project.org', Ncpus=2); \
          if (!'prophet' %in% rownames(installed.packages())) stop('Stage 3: prophet missing')"

# Stage 4: modeltime (must come AFTER prophet — modeltime Imports prophet)
RUN R -e "install.packages('modeltime', repos='https://cloud.r-project.org', Ncpus=2); \
          if (!'modeltime' %in% rownames(installed.packages())) stop('Stage 4: modeltime missing')"

# Build-time verification: every lib needed by R/train.R loads cleanly
RUN R -e "suppressPackageStartupMessages({ \
    library(arrow); library(dplyr); library(tidyr); library(lubridate); \
    library(ggplot2); library(parsnip); library(recipes); library(workflows); \
    library(rsample); library(yardstick); library(modeltime); library(timetk); \
    library(prophet); library(xgboost); \
  }); cat('All libs load OK in container\n')"

WORKDIR /workspace
COPY R/ /workspace/R/

CMD ["R", "--no-save", "-e", "cat('R: ', as.character(getRversion()), '\\nprophet: ', as.character(packageVersion('prophet')), '\\nmodeltime: ', as.character(packageVersion('modeltime')), '\\nggplot2: ', as.character(packageVersion('ggplot2')), '\\nrstan: ', as.character(packageVersion('rstan')), '\\n', sep='')"]
