# app/Dockerfile — Shiny dashboard
FROM rocker/shiny:4.4.2

# Install app dependencies
RUN R -e "install.packages( \
      c('bslib','plotly','readr','dplyr'), \
      repos='https://packagemanager.posit.co/cran/__linux__/jammy/latest', \
      Ncpus=2)"

# Copy app and data
WORKDIR /srv/shiny-server/retail
COPY app/app.R         ./app.R
COPY reports/baseline_accuracy.csv ./data/baseline_accuracy.csv
COPY artifacts/scored_forecast.rds  ./data/scored_forecast.rds

# Point app at the local data dir
ENV DATA_DIR=/srv/shiny-server/retail/data

# Shiny config: single-app mode on port 8080
RUN echo 'run_as shiny;\n\
server {\n\
  listen 8080;\n\
  location / {\n\
    app_dir /srv/shiny-server/retail;\n\
    log_dir /var/log/shiny-server;\n\
  }\n\
}' > /etc/shiny-server/shiny-server.conf

EXPOSE 8080
CMD ["/usr/bin/shiny-server"]
