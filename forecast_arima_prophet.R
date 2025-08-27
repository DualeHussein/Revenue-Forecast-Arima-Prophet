# src/forecast_arima_prophet.R
suppressPackageStartupMessages({
  library(tidyverse)
  library(forecast)
  library(prophet)
})

`%||%` <- function(a,b) if (!is.null(a)) a else b
ROOT <- normalizePath(file.path(dirname(this.path <- sys.frames()[[1]]$ofile %||% "."), ".."), mustWork = FALSE)
dir.create(file.path(ROOT, "reports"), showWarnings = FALSE, recursive = TRUE)

mape <- function(actual, pred) mean(abs((actual - pred) / pmax(1e-8, actual))) * 100

df <- read_csv(file.path(ROOT, "data", "revenue_weekly.csv"), show_col_types = FALSE) |>
  mutate(date = as.Date(date)) |>
  arrange(date)

h <- 12
train <- head(df, nrow(df) - h)
test  <- tail(df, h)

# ARIMA
y_ts <- ts(train$revenue, frequency = 52)
fit_arima <- auto.arima(y_ts, seasonal = TRUE, stepwise = FALSE, approximation = FALSE)
fc_arima <- forecast(fit_arima, h = h, level = c(80,95))
arima_pred <- as.numeric(fc_arima$mean)
arima_mape <- mape(test$revenue, arima_pred)

# Prophet
prop_df <- df |> transmute(ds = date, y = revenue)
prop_train <- head(prop_df, nrow(prop_df) - h)
m <- prophet(prop_train, yearly.seasonality = TRUE, weekly.seasonality = FALSE, daily.seasonality = FALSE,
             interval.width = 0.95, changepoint.prior.scale = 0.05)
future <- make_future_dataframe(m, periods = h, freq = "week")
forecast_p <- predict(m, future)
prop_fc <- forecast_p |> select(ds, yhat, yhat_lower, yhat_upper) |> tail(h)
prop_mape <- mape(test$revenue, prop_fc$yhat)

metrics <- list(horizon_weeks = h,
                arima = list(mape = unname(arima_mape)),
                prophet = list(mape = unname(prop_mape)))
jsonlite::write_json(metrics, file.path(ROOT, "reports", "metrics.json"), auto_unbox = TRUE, pretty = TRUE)

out <- tibble(
  model = c(rep("arima", h), rep("prophet", h)),
  ds    = rep(test$date, 2),
  y     = rep(test$revenue, 2),
  yhat  = c(arima_pred, prop_fc$yhat),
  yhat_lower = c(rep(NA_real_, h), prop_fc$yhat_lower),
  yhat_upper = c(rep(NA_real_, h), prop_fc$yhat_upper)
)
readr::write_csv(out, file.path(ROOT, "reports", "forecast_out.csv"))

plot_df <- df |> mutate(set = if_else(date <= max(train$date), "train", "test"))
arima_plot <- tibble(date = test$date, yhat = arima_pred, model = "ARIMA")
prophet_plot <- tibble(date = prop_fc$ds, yhat = prop_fc$yhat,
                       lo95 = prop_fc$yhat_lower, hi95 = prop_fc$yhat_upper, model = "Prophet")

p <- ggplot(plot_df, aes(date, revenue, color = set)) +
  geom_line(size = 0.6) +
  geom_line(data = arima_plot, aes(date, yhat), color = "#1f77b4", size = 0.8) +
  geom_ribbon(data = prophet_plot, aes(x = date, ymin = lo95, ymax = hi95),
              inherit.aes = FALSE, alpha = 0.15, fill = "#ff7f0e") +
  geom_line(data = prophet_plot, aes(date, yhat), color = "#ff7f0e", size = 0.8) +
  scale_color_manual(values = c(train = "#7f7f7f", test = "#2ca02c")) +
  labs(title = "Weekly Revenue Forecast — ARIMA (blue) vs Prophet (orange)",
       subtitle = sprintf("Holdout MAPE — ARIMA: %.1f%%  |  Prophet: %.1f%%", arima_mape, prop_mape),
       x = NULL, y = "Revenue") +
  theme_minimal(base_size = 12)

ggsave(filename = file.path(ROOT, "reports", "forecasts_arima_prophet.png"),
       plot = p, width = 10, height = 6, dpi = 150)
cat("Done. Outputs in reports/\n")
