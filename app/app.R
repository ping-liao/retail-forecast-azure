# app/app.R
library(shiny)
library(bslib)
library(dplyr)
library(plotly)
library(readr)

data_dir <- Sys.getenv("DATA_DIR", normalizePath(".."))
fc  <- readRDS(file.path(data_dir, "artifacts", "scored_forecast.rds"))
acc <- read_csv(file.path(data_dir, "reports", "baseline_accuracy.csv"),
                show_col_types = FALSE)

countries <- sort(unique(fc$country))

ui <- page_navbar(
  title = "Retail Forecast",
  theme = bs_theme(bootswatch = "darkly", primary = "#E05A2B"),

  nav_panel("Forecast",
    layout_sidebar(
      sidebar = sidebar(width = 220,
        selectInput("country", "Country", choices = countries),
        hr(),
        helpText("42-day forward forecast. Winner model selected by lowest RMSE on hold-out.")
      ),
      card(plotlyOutput("forecast_plot", height = "520px"))
    )
  ),

  nav_panel("Backtest",
    card(
      card_header("Model accuracy — hold-out test set"),
      tableOutput("accuracy_table")
    )
  ),

  nav_panel("Explain",
    card(card_body(
      h4("DALEX feature importance — coming in Step 5"),
      p("Per-prediction breakdown and global feature importance will appear here.")
    ))
  )
)

server <- function(input, output, session) {

  fc_sel <- reactive({
    fc |> filter(country == input$country)
  })

  output$forecast_plot <- renderPlotly({
    d      <- fc_sel()
    actual <- d |> filter(.key == "actual")
    pred   <- d |> filter(.key == "prediction")

    plot_ly() |>
      add_lines(data = actual, x = ~.index, y = ~.value,
                name = "Actual", line = list(color = "#5B9BD5", width = 1.5)) |>
      add_lines(data = pred, x = ~.index, y = ~.value,
                name = "Forecast", line = list(color = "#E05A2B", width = 2.5, dash = "dash")) |>
      layout(
        title  = list(text = paste("Revenue Forecast —", input$country), x = 0.02),
        xaxis  = list(title = ""),
        yaxis  = list(title = "Revenue (£)", tickformat = ",.0f"),
        hovermode = "x unified",
        legend = list(orientation = "h", y = -0.15),
        paper_bgcolor = "#222", plot_bgcolor = "#222",
        font = list(color = "#ddd")
      )
  })

  output$accuracy_table <- renderTable({
    acc |>
      select(country, .model_desc, mae, rmse, rsq) |>
      rename(Country = country, Model = .model_desc,
             MAE = mae, RMSE = rmse, `R²` = rsq) |>
      arrange(Country, RMSE)
  }, digits = 1, na = "—", striped = TRUE, hover = TRUE, bordered = TRUE)
}

shinyApp(ui, server)
