# R/03_get_cmhc.R
# Pull CMHC Housing Market Information Portal data for the 40 Housing
# Target Order municipalities plus BC, using the cmhc package.
#   - Rental Market Survey (Rms): vacancy rate, average rent, average rent change
#   - Starts and Completions Survey (Scss): completions (annual)
# Source: Adapted from Canada Mortgage and Housing Corporation,
#   Housing Market Information Portal, accessed 2026-11.

library(tidyverse)
library(cmhc)
library(here)

munis <- read_csv(here("data", "municipalities.csv"),
                  col_types = cols(.default = "c"))

geos <- c("59", munis$geo_uid)   # 59 = British Columbia (benchmark)

geo_names <- tibble(
  GeoUID = c("59", munis$geo_uid),
  name   = c("British Columbia", munis$municipality)
)

# ---- 1. Helper: pull one series for every geography ----
pull_series <- function(survey, series, dimension, frequency = NULL) {
  map(geos, function(g) {
    message(series, ": ", g)
    Sys.sleep(0.3)  # be polite to the CMHC server
    d <- tryCatch(
      suppressWarnings(get_cmhc(
        survey    = survey,
        series    = series,
        dimension = dimension,
        breakdown = "Historical Time Periods",
        geo_uid   = g,
        frequency = frequency
      )),
      error = function(e) {
        message("   error: ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(d) || nrow(d) == 0) {
      message("   no data")
      return(NULL)
    }
    if (!"Quality" %in% names(d)) d$Quality <- NA_character_
    d |>
      mutate(GeoUID = g,
             Quality = as.character(Quality),
             series = series,
             survey = survey)
  }) |>
    list_rbind()
}

# ---- 2. Pull the four series ----
cmhc_vacancy <- pull_series("Rms",  "Vacancy Rate",        "Bedroom Type")
cmhc_rent    <- pull_series("Rms",  "Average Rent",        "Bedroom Type")
cmhc_rentchg <- pull_series("Rms",  "Average Rent Change", "Bedroom Type")
cmhc_compl   <- pull_series("Scss", "Completions",         "Dwelling Type",
                            frequency = "Annual")

saveRDS(cmhc_vacancy, here("data-raw", "cmhc_vacancy.rds"))
saveRDS(cmhc_rent,    here("data-raw", "cmhc_rent.rds"))
saveRDS(cmhc_rentchg, here("data-raw", "cmhc_rent_change.rds"))
saveRDS(cmhc_compl,   here("data-raw", "cmhc_completions.rds"))

# ---- 3. Structure check ----
show_structure <- function(df, dim_col, label) {
  cat("\n==== ", label, " ====\n", sep = "")
  cat("Rows:", nrow(df), " | Columns:", paste(names(df), collapse = ", "), "\n")
  cat("Categories in '", dim_col, "': ",
      paste(unique(as.character(df[[dim_col]])), collapse = " | "), "\n", sep = "")
  cat("Date strings (first 3 / last 3): ",
      paste(head(unique(df$DateString), 3), collapse = ", "), " ... ",
      paste(tail(unique(df$DateString), 3), collapse = ", "), "\n", sep = "")
  cat("Quality labels: ",
      paste(unique(df$Quality), collapse = " | "), "\n", sep = "")
}

show_structure(cmhc_vacancy, "Bedroom Type",  "Vacancy rate")
show_structure(cmhc_rent,    "Bedroom Type",  "Average rent")
show_structure(cmhc_rentchg, "Bedroom Type",  "Average rent change")
show_structure(cmhc_compl,   "Dwelling Type", "Completions")

# ---- 4. Coverage: latest available value per geography (total category) ----
latest_total <- function(df, dim_col, label) {
  df |>
    filter(as.character(.data[[dim_col]]) %in% c("Total", "All")) |>
    filter(!is.na(Value)) |>
    arrange(GeoUID, Date) |>
    group_by(GeoUID) |>
    summarise(
      "{label}_years"  := n(),
      "{label}_first"  := year(first(Date)),
      "{label}_last"   := year(last(Date)),
      "{label}_value"  := last(Value),
      "{label}_qual"   := last(Quality),
      .groups = "drop"
    )
}

coverage <- geo_names |>
  left_join(latest_total(cmhc_vacancy, "Bedroom Type",  "vac"),   by = "GeoUID") |>
  left_join(latest_total(cmhc_rentchg, "Bedroom Type",  "rchg"),  by = "GeoUID") |>
  left_join(latest_total(cmhc_compl,   "Dwelling Type", "compl"), by = "GeoUID")

cat("\n==== Coverage (latest year with a value, total category) ====\n")
coverage |>
  select(name, GeoUID,
         vac_first, vac_last, vac_value, vac_qual,
         rchg_last, rchg_value,
         compl_first, compl_last, compl_value) |>
  print(n = Inf, width = Inf)

cat("\nGeographies with vacancy data:    ", sum(!is.na(coverage$vac_last)),   "of", nrow(coverage), "\n")
cat("Geographies with rent change data:", sum(!is.na(coverage$rchg_last)),  "of", nrow(coverage), "\n")
cat("Geographies with completions data:", sum(!is.na(coverage$compl_last)), "of", nrow(coverage), "\n")