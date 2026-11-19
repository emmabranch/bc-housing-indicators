# R/07_render_report_cards.R
# Render the parameterised report card (reports/report_card.qmd) for all 40
# municipalities into docs/reports/<municipality>.html.
# Run after R/05_build_indicators.R. Takes about 2 to 4 minutes.

library(tidyverse)
library(here)
library(quarto)
source(here("R", "dashboard_helpers.R"))

munis <- read_csv(here("data", "municipalities.csv"), col_types = cols(.default = "c"))

out_dir <- here("docs", "reports")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

template <- here("reports", "report_card.qmd")
rendered <- here("reports", "report_card.html")   # Quarto's default output name

results <- tibble(municipality = munis$municipality, geo_uid = munis$geo_uid,
                  file = paste0(slugify(munis$municipality), ".html"), ok = NA)

for (i in seq_len(nrow(results))) {
  message(sprintf("[%d/%d] %s", i, nrow(results), results$municipality[i]))
  ok <- tryCatch({
    quarto_render(template, execute_params = list(geo_uid = results$geo_uid[i]), quiet = TRUE)
    file.copy(rendered, file.path(out_dir, results$file[i]), overwrite = TRUE)
  }, error = function(e) { message("   FAILED: ", conditionMessage(e)); FALSE })
  results$ok[i] <- ok
}
if (file.exists(rendered)) invisible(file.remove(rendered))

cat("\nReport cards rendered:", sum(results$ok), "of", nrow(results), "\n")
cat("Folder:", out_dir, "\n")
if (any(!results$ok)) print(results |> filter(!ok))
