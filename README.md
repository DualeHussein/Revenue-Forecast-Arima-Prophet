# Revenue Forecast (R): ARIMA vs Prophet

Baseline weekly revenue forecasting for planning. Compares **ARIMA** (`forecast` package) vs **Prophet** on a synthetic retail-like dataset (trend + seasonality + promos). Outputs forecast plots, intervals, and **MAPE** on a 12‑week holdout.

## Repo Structure
```
.
├── data/
│   └── revenue_weekly.csv          # weekly revenue (synthetic)
├── src/
│   └── forecast_arima_prophet.R    # run this script
├── reports/                        # metrics and charts saved here
├── .gitignore
└── LICENSE
```

## Quickstart (R)
```r
# 1) Open R (4.2+ recommended)
# 2) Install packages once:
install.packages(c("tidyverse", "forecast", "prophet"))   # prophet may require C++ toolchain
# 3) Run the script
source("src/forecast_arima_prophet.R")
```

### What it does
- Loads **weekly revenue** from `data/revenue_weekly.csv`
- Splits **last 12 weeks** as holdout
- Fits **ARIMA** (`auto.arima`) and **Prophet**
- Forecast horizon **h = 12**
- Computes **MAPE** on holdout
- Saves:
  - `reports/metrics.json` – ARIMA vs Prophet error metrics
  - `reports/forecast_out.csv` – point forecasts & intervals
  - `reports/forecasts_arima_prophet.png` – chart with 80/95% bands

> Target quality: **MAPE ≈ 8–12%** on the synthetic holdout (your run may vary ±1–2%).

## Notes
- The dataset is synthetic and safe to publish.
- Prophet may need a working C++ toolchain; if install is hard in R, feel free to only run ARIMA.
- This repo is a **baseline planning aid**—a place to start before adding richer drivers (price, promos, holidays, stockouts).
