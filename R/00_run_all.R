# R/00_run_all.R
# Rebuild everything: download and verify data, build indicators, render dashboard.
# Run from the project root (open bc-housing-indicators.Rproj first).

library(here)

scripts <- c(
  "01_municipalities.R",
  "02_get_census.R",
  "03_get_cmhc.R",
  "04_housing_targets.R",
  "05_build_indicators.R",
  "06_boundaries.R"
)

for (s in scripts) {
  message("\n==== Running ", s, " ====")
  source(here("R", s), local = new.env())
}

message("\n==== Rendering dashboard ====")
quarto::quarto_render(here("index.qmd"))
message("\nDone. Open docs/index.html to view the dashboard.")
