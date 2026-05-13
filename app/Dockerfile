FROM rocker/shiny:4.4.2

RUN R -e "install.packages( \
      c('bslib','plotly','readr','dplyr'), \
      repos='https://packagemanager.posit.co/cran/__linux__/jammy/latest', \
      Ncpus=2)"

WORKDIR /srv/shiny-server/retail
COPY app/app.R         ./app.R
COPY reports/baseline_accuracy.csv ./data/baseline_accuracy.csv
COPY artifacts/scored_forecast.rds  ./data/scored_forecast.rds

ENV DATA_DIR=/srv/shiny-server/retail/data

EXPOSE 8080
CMD ["Rscript", "-e", "shiny::runApp('/srv/shiny-server/retail', port=8080, host='0.0.0.0', launch.browser=FALSE)"]
