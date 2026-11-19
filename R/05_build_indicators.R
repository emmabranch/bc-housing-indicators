# R/05_build_indicators.R
# Build the tidy indicator database, the latest-value scorecard with
# red/amber/green (RAG) status, the indicator framework, and the data dictionary.
#
# Inputs (from earlier scripts):
#   data/municipalities.csv, data/housing_targets.csv
#   data-raw/census_98100259_bc.rds, data-raw/cmhc_*.rds
# Outputs:
#   data/indicators_long.csv     one row per geography x indicator x year
#   data/scorecard_latest.csv    one row per geography x indicator (latest value + status)
#   data/indicator_framework.csv one row per indicator (definitions, sources, rules, limitations)
#   data/data_dictionary.csv     one row per column of each output file

library(tidyverse)
library(here)

# ---- 0. Inputs ----------------------------------------------------------------
munis   <- read_csv(here("data", "municipalities.csv"), col_types = cols(.default = "c"))
targets <- read_csv(here("data", "housing_targets.csv"),
                    col_types = cols(geo_uid = "c", .default = col_guess()))

census  <- readRDS(here("data-raw", "census_98100259_bc.rds"))
vac     <- readRDS(here("data-raw", "cmhc_vacancy.rds"))
rent    <- readRDS(here("data-raw", "cmhc_rent.rds"))
rentchg <- readRDS(here("data-raw", "cmhc_rent_change.rds"))
compl   <- readRDS(here("data-raw", "cmhc_completions.rds"))

geos <- tibble(
  geo_uid   = c("59", munis$geo_uid),
  geo_name  = c("British Columbia", munis$municipality),
  geo_level = c("Province", rep("Municipality", nrow(munis))),
  hto_group = c(NA_integer_, as.integer(munis$hto_group))
)

# ---- 1. Census indicators (2016 and 2021) --------------------------------------
census_clean <- census |>
  mutate(across(everything(), ~ if (is.factor(.x)) as.character(.x) else .x)) |>
  transmute(
    geo_uid   = as.character(GeoUID),
    year      = as.integer(`Census year (2)`),
    indicator = `Housing indicators (9)`,
    tenure    = `Tenure (4)`,
    value     = as.numeric(VALUE),
    symbol    = as.character(Symbol)
  ) |>
  filter(geo_uid %in% geos$geo_uid)

census_map <- tribble(
  ~indicator_id, ~indicator,                                      ~tenure,
  "CHN_ALL",     "Percent of households in core housing need",    "Total - Tenure",
  "CHN_RENT",    "Percent of households in core housing need",    "Renter",
  "UNAFF_RENT",  "Percent of households in unaffordable housing", "Renter"
)

census_long <- census_clean |>
  inner_join(census_map, by = c("indicator", "tenure")) |>
  mutate(
    value   = if_else(symbol %in% c("x", "..."), NA_real_, value),
    quality = case_when(symbol == "x"   ~ "Suppressed (x)",
                        symbol == "..." ~ "Not available (...)",
                        TRUE            ~ NA_character_)
  ) |>
  select(geo_uid, indicator_id, year, value, quality)

# Percentages should be on a 0 to 100 scale; convert if StatCan supplied proportions
if (max(census_long$value, na.rm = TRUE) <= 1) {
  message("Census percentages were proportions; converting to 0-100 scale.")
  census_long <- census_long |> mutate(value = value * 100)
}

# Households (2021) for the completions rate denominator
households_2021 <- census_clean |>
  filter(year == 2021,
         indicator == "Total - Housing indicators",
         tenure == "Total - Tenure") |>
  select(geo_uid, households_2021 = value)

# ---- 2. CMHC indicators (annual) -----------------------------------------------
cmhc_total <- function(df, dim_col, total_label, id) {
  df |>
    filter(as.character(.data[[dim_col]]) == total_label) |>
    transmute(
      geo_uid      = as.character(GeoUID),
      indicator_id = id,
      year         = as.integer(lubridate::year(Date)),
      value        = as.numeric(Value),
      quality      = as.character(Quality)
    )
}

cmhc_long <- bind_rows(
  cmhc_total(vac,     "Bedroom Type",  "Total", "VAC"),
  cmhc_total(rent,    "Bedroom Type",  "Total", "RENT_AVG"),
  cmhc_total(rentchg, "Bedroom Type",  "Total", "RENT_CHG"),
  cmhc_total(compl,   "Dwelling Type", "All",   "COMPL")
) |>
  filter(geo_uid %in% geos$geo_uid)

# Completions per 1,000 households: 3-year average of annual completions
# (latest three years) divided by 2021 Census households
compl_last_year <- max(cmhc_long$year[cmhc_long$indicator_id == "COMPL" & !is.na(cmhc_long$value)])

compl_rate <- cmhc_long |>
  filter(indicator_id == "COMPL", year %in% (compl_last_year - 2):compl_last_year) |>
  group_by(geo_uid) |>
  summarise(n_years = sum(!is.na(value)),
            avg_completions = if (n_years == 3) mean(value) else NA_real_,
            .groups = "drop") |>
  left_join(households_2021, by = "geo_uid") |>
  transmute(
    geo_uid,
    indicator_id = "COMPL_RATE",
    year         = compl_last_year,
    value        = round(1000 * avg_completions / households_2021, 1),
    quality      = NA_character_
  )

# ---- 3. Housing Supply Act target progress -------------------------------------
hto_long <- targets |>
  transmute(
    geo_uid,
    indicator_id = "HTO_Y1",
    year         = as.integer(substr(y1_period_end, 1, 4)),
    value        = y1_pct_of_target,
    quality      = if_else(y1_verified_primary,
                           "Verified against primary source",
                           "Secondary source, not independently verified")
  )

# ---- 4. Long indicator table ---------------------------------------------------
indicators_long <- bind_rows(census_long, cmhc_long, compl_rate, hto_long) |>
  left_join(geos, by = "geo_uid") |>
  select(geo_uid, geo_name, geo_level, hto_group, indicator_id, year, value, quality) |>
  arrange(indicator_id, geo_uid, year)

# ---- 5. Indicator framework ----------------------------------------------------
framework <- tribble(
  ~indicator_id, ~indicator_name, ~domain, ~kpi_type, ~unit, ~direction,
  ~definition, ~source, ~source_detail, ~frequency, ~comparator_type, ~comparator, ~rag_rule, ~limitations,

  "HTO_Y1", "Housing target progress (Year 1)", "Supply", "Headline KPI (RAG)", "% of Year 1 target", "Higher is better",
  "Net new units completed in the municipality's first Housing Target Order year, as a percentage of its Year 1 target. Net new units = completions (occupancy permits) minus demolitions.",
  "BC Government news releases; Storeys housing targets tracker", "See data/housing_targets.csv for per-row source URLs", "Annual (period differs by group)",
  "Target", "100% of Year 1 target",
  "Green: 100% or more. Amber: 75% to 99.9%. Red: below 75%. Group 4: not yet assessed.",
  "Year 1 periods differ by group, so results are not for the same 12 months. Some values from a secondary source (flagged). Municipal reports, not audited figures. Targets measure completions, which lag approvals by years.",

  "COMPL_RATE", "Housing completions per 1,000 households", "Supply", "Headline KPI (RAG)", "Completions per 1,000 households per year", "Higher is better",
  "Average annual housing completions over the latest three years, per 1,000 households counted in the 2021 Census.",
  "CMHC Starts and Completions Survey; Statistics Canada 2021 Census", "CMHC HMIP via cmhc R package; StatCan 98-10-0259-01", "Annual",
  "Benchmark", "BC rate",
  "Green: at or above the BC rate. Amber: 75% to 99.9% of the BC rate. Red: below 75% of the BC rate.",
  "Completions are gross (demolitions not subtracted), so they differ from Housing Supply Act net new units. The 2021 household denominator ages over time and understates current households in fast-growing places. CMHC's provincial total may not cover exactly the same areas as the household count.",

  "CHN_ALL", "Households in core housing need", "Need", "Headline KPI (RAG)", "% of households", "Lower is better",
  "Percentage of private households in core housing need: living in housing that is unaffordable, inadequate (needs major repairs), or unsuitable (too few bedrooms), and unable to afford the median rent of acceptable alternative local housing.",
  "Statistics Canada, Census of Population", "Table 98-10-0259-01", "Every 5 years (2016, 2021)",
  "Benchmark", "BC rate (same year)",
  "Green: at or below the BC rate. Amber: up to 2 percentage points above. Red: more than 2 points above.",
  "2021 is the latest available year. Temporary pandemic income benefits in 2020 (the income year used by the 2021 Census) likely lowered measured need, so 2016 to 2021 changes should be read with caution. Excludes households on reserve, in farm dwellings, with zero or negative income, and some student-led households.",

  "CHN_RENT", "Renter households in core housing need", "Need", "Headline KPI (RAG)", "% of renter households", "Lower is better",
  "As above, for renter households only.",
  "Statistics Canada, Census of Population", "Table 98-10-0259-01", "Every 5 years (2016, 2021)",
  "Benchmark", "BC rate (same year)",
  "Green: at or below the BC rate. Amber: up to 2 percentage points above. Red: more than 2 points above.",
  "As for CHN_ALL. Small renter populations give less stable rates; suppressed cells shown as missing.",

  "UNAFF_RENT", "Renter households spending 30%+ of income on shelter", "Affordability", "Headline KPI (RAG)", "% of renter households", "Lower is better",
  "Percentage of renter households whose shelter-cost-to-income ratio is 30% or more. Shelter costs include rent and utilities.",
  "Statistics Canada, Census of Population", "Table 98-10-0259-01", "Every 5 years (2016, 2021)",
  "Benchmark", "BC rate (same year)",
  "Green: at or below the BC rate. Amber: up to 2 percentage points above. Red: more than 2 points above.",
  "Uses before-tax income. Some households (e.g. students, people with temporarily low incomes) exceed 30% without being in housing need, which is why core housing need is the preferred headline measure.",

  "VAC", "Rental vacancy rate", "Rental market", "Headline KPI (RAG)", "% of purpose-built rental units", "Higher is better (up to a point)",
  "Percentage of purpose-built rental units (buildings with 3 or more rental units) that are vacant and available for rent in October.",
  "CMHC Rental Market Survey", "CMHC HMIP via cmhc R package", "Annual (October)",
  "Reference", "3% (industry rule of thumb for a balanced market)",
  "Green: 3.0% or above. Amber: 2.0% to 2.9%. Red: below 2.0%.",
  "Covers purpose-built rentals only, not rented condos or secondary suites. CMHC's 2026 mid-year rental market update notes the balanced vacancy rate varies by market, so 3% is a reference point, not a target. Small rental universes give unstable rates; suppressed years are missing.",

  "RENT_CHG", "Average rent change (same units)", "Rental market", "Supporting", "% change from previous year", "Context",
  "Year-over-year percentage change in average rent for units in the CMHC sample in both years (same-sample), so new buildings do not distort the change.",
  "CMHC Rental Market Survey", "CMHC HMIP via cmhc R package", "Annual (October)",
  "None", NA,
  "Not rated.",
  "Frequently suppressed for smaller municipalities; latest year shown and flagged when out of date.",

  "RENT_AVG", "Average rent (all bedroom types)", "Rental market", "Supporting", "$ per month", "Context",
  "Average monthly rent for purpose-built rental units, all bedroom types.",
  "CMHC Rental Market Survey", "CMHC HMIP via cmhc R package", "Annual (October)",
  "None", NA,
  "Not rated.",
  "Average across all units including long-term tenancies, so it is below current asking rents. Mix of unit sizes affects comparisons between municipalities.",

  "COMPL", "Housing completions", "Supply", "Supporting", "Dwelling units", "Context",
  "Number of new dwelling units completed in the calendar year, all dwelling types.",
  "CMHC Starts and Completions Survey", "CMHC HMIP via cmhc R package", "Annual",
  "None", NA,
  "Not rated.",
  "Gross completions; demolitions not subtracted."
)

# ---- 6. Latest values and RAG status -------------------------------------------
latest <- indicators_long |>
  filter(!is.na(value)) |>
  group_by(geo_uid, indicator_id) |>
  arrange(year, .by_group = TRUE) |>
  summarise(
    latest_year   = last(year),
    latest_value  = last(value),
    latest_quality = last(quality),
    prior_year    = nth(year, -2, default = NA_integer_),
    prior_value   = nth(value, -2, default = NA_real_),
    .groups = "drop"
  )

series_latest <- indicators_long |>
  filter(!is.na(value), geo_level == "Municipality") |>
  group_by(indicator_id) |>
  summarise(series_latest_year = max(year), .groups = "drop")

bc_benchmarks <- indicators_long |>
  filter(geo_uid == "59", !is.na(value)) |>
  select(indicator_id, year, bc_value = value)

scorecard_latest <- expand_grid(geos, indicator_id = framework$indicator_id) |>
  left_join(latest, by = c("geo_uid", "indicator_id")) |>
  left_join(series_latest, by = "indicator_id") |>
  left_join(bc_benchmarks, by = c("indicator_id", "latest_year" = "year")) |>
  left_join(framework |> select(indicator_id, kpi_type), by = "indicator_id") |>
  mutate(
    change_from_prior = latest_value - prior_value,
    # Housing target periods differ by group by design, so they are never "out of date"
    out_of_date = indicator_id != "HTO_Y1" & !is.na(latest_year) &
                  latest_year < series_latest_year,
    comparator_value = case_when(
      indicator_id == "HTO_Y1" ~ 100,
      indicator_id == "VAC"    ~ 3,
      indicator_id %in% c("CHN_ALL", "CHN_RENT", "UNAFF_RENT", "COMPL_RATE") ~ bc_value,
      TRUE ~ NA_real_
    ),
    status = case_when(
      kpi_type == "Supporting"                                   ~ "Not rated",
      indicator_id == "HTO_Y1" & geo_level == "Province"         ~ "Not applicable",
      indicator_id == "HTO_Y1" & hto_group == 4                  ~ "Not yet assessed",
      is.na(latest_value)                                        ~ "No data",
      geo_level == "Province" & indicator_id != "VAC"            ~ "Benchmark",
      indicator_id == "HTO_Y1" & latest_value >= 100             ~ "Green",
      indicator_id == "HTO_Y1" & latest_value >= 75              ~ "Amber",
      indicator_id == "HTO_Y1"                                   ~ "Red",
      indicator_id == "VAC" & latest_value >= 3                  ~ "Green",
      indicator_id == "VAC" & latest_value >= 2                  ~ "Amber",
      indicator_id == "VAC"                                      ~ "Red",
      indicator_id == "COMPL_RATE" & latest_value >= comparator_value        ~ "Green",
      indicator_id == "COMPL_RATE" & latest_value >= 0.75 * comparator_value ~ "Amber",
      indicator_id == "COMPL_RATE"                                           ~ "Red",
      indicator_id %in% c("CHN_ALL", "CHN_RENT", "UNAFF_RENT") & latest_value <= comparator_value     ~ "Green",
      indicator_id %in% c("CHN_ALL", "CHN_RENT", "UNAFF_RENT") & latest_value <= comparator_value + 2 ~ "Amber",
      indicator_id %in% c("CHN_ALL", "CHN_RENT", "UNAFF_RENT")                                        ~ "Red",
      TRUE ~ "Not rated"
    )
  ) |>
  select(geo_uid, geo_name, geo_level, hto_group, indicator_id, kpi_type,
         latest_year, latest_value, latest_quality, prior_year, prior_value,
         change_from_prior, comparator_value, status, out_of_date) |>
  arrange(geo_level != "Province", hto_group, geo_name, indicator_id)

# Add latest period to the framework
framework <- framework |>
  left_join(series_latest |> rename(latest_period = series_latest_year), by = "indicator_id") |>
  relocate(latest_period, .after = frequency)

# ---- 7. Data dictionary --------------------------------------------------------
data_dictionary <- tribble(
  ~file, ~column, ~type, ~description,
  "municipalities.csv", "municipality", "text", "Municipality display name",
  "municipalities.csv", "census_name", "text", "Name as it appears in Statistics Canada tables (not unique)",
  "municipalities.csv", "csd_type", "text", "Census subdivision type: CY city, DM district municipality, T town",
  "municipalities.csv", "geo_uid", "text", "Statistics Canada census subdivision code (2021). Primary join key",
  "municipalities.csv", "hto_group", "integer", "Housing Target Order group (1 to 4)",
  "housing_targets.csv", "target_5yr", "integer", "Cumulative five-year net new unit target",
  "housing_targets.csv", "target_y1", "integer", "Year 1 net new unit target",
  "housing_targets.csv", "y1_net_new", "integer", "Net new units reported for Year 1 (completions minus demolitions)",
  "housing_targets.csv", "y1_pct_of_target", "number", "y1_net_new as a percentage of target_y1",
  "housing_targets.csv", "y1_period_start / y1_period_end", "date", "Year 1 reporting period for the municipality's group",
  "housing_targets.csv", "target_src / y1_src", "text", "Source codes: G1T, G2T, G3R = BC Government news releases; STY = Storeys tracker (secondary)",
  "housing_targets.csv", "target_src_url / y1_src_url", "text", "Source URLs",
  "housing_targets.csv", "y1_src_type", "text", "Primary (BC Government) or Secondary (news tracker)",
  "housing_targets.csv", "y1_verified_primary", "logical", "TRUE if the Year 1 value was checked against a primary source",
  "indicators_long.csv", "geo_uid", "text", "Census subdivision code; 59 = British Columbia",
  "indicators_long.csv", "geo_name", "text", "Geography name",
  "indicators_long.csv", "geo_level", "text", "Province or Municipality",
  "indicators_long.csv", "hto_group", "integer", "Housing Target Order group; blank for BC",
  "indicators_long.csv", "indicator_id", "text", "Indicator code; see indicator_framework.csv",
  "indicators_long.csv", "year", "integer", "Reference year (Census year, CMHC survey year, or end year of target period)",
  "indicators_long.csv", "value", "number", "Indicator value in the unit given in indicator_framework.csv; blank if suppressed or unavailable",
  "indicators_long.csv", "quality", "text", "CMHC reliability rating, Census symbol meaning, or target source verification status",
  "scorecard_latest.csv", "kpi_type", "text", "Headline KPI (RAG) or Supporting",
  "scorecard_latest.csv", "latest_year / latest_value", "integer / number", "Most recent year with a non-missing value, and that value",
  "scorecard_latest.csv", "latest_quality", "text", "Quality note for the latest value",
  "scorecard_latest.csv", "prior_year / prior_value", "integer / number", "Previous year with a value (for Census, 2016)",
  "scorecard_latest.csv", "change_from_prior", "number", "latest_value minus prior_value",
  "scorecard_latest.csv", "comparator_value", "number", "Target, benchmark (BC value), or reference value used for status",
  "scorecard_latest.csv", "status", "text", "Green, Amber, Red, Benchmark, No data, Not yet assessed, Not applicable, or Not rated",
  "scorecard_latest.csv", "out_of_date", "logical", "TRUE if the latest value is older than the most recent year published for any municipality",
  "indicator_framework.csv", "(all columns)", "text", "Indicator metadata: definition, source, frequency, latest period, comparator, RAG rule, limitations"
)

# ---- 8. Checks -----------------------------------------------------------------
stopifnot(
  # one row per geography x indicator x year
  !any(duplicated(indicators_long[c("geo_uid", "indicator_id", "year")])),
  # one row per geography x indicator in the scorecard
  nrow(scorecard_latest) == nrow(geos) * nrow(framework),
  # every indicator in the data is documented
  all(unique(indicators_long$indicator_id) %in% framework$indicator_id),
  # percentages in range
  all(between(indicators_long$value[indicators_long$indicator_id %in%
        c("CHN_ALL", "CHN_RENT", "UNAFF_RENT", "VAC")], 0, 100), na.rm = TRUE)
)

# ---- 9. Write outputs ----------------------------------------------------------
write_csv(indicators_long,  here("data", "indicators_long.csv"), na = "")
write_csv(scorecard_latest, here("data", "scorecard_latest.csv"), na = "")
write_csv(framework,        here("data", "indicator_framework.csv"), na = "")
write_csv(data_dictionary,  here("data", "data_dictionary.csv"), na = "")

# ---- 10. Summary for review ----------------------------------------------------
cat("\nRows in indicators_long:", nrow(indicators_long), "\n")
cat("Rows in scorecard_latest:", nrow(scorecard_latest), "\n\n")

cat("==== BC benchmark values (latest) ====\n")
scorecard_latest |>
  filter(geo_uid == "59", kpi_type == "Headline KPI (RAG)") |>
  select(indicator_id, latest_year, latest_value, prior_year, prior_value) |>
  print()

cat("\n==== Status counts, 40 municipalities ====\n")
scorecard_latest |>
  filter(geo_level == "Municipality", kpi_type == "Headline KPI (RAG)") |>
  count(indicator_id, status) |>
  pivot_wider(names_from = status, values_from = n, values_fill = 0) |>
  print(width = Inf)

cat("\n==== Out-of-date latest values (municipalities) ====\n")
scorecard_latest |>
  filter(geo_level == "Municipality", out_of_date) |>
  count(indicator_id, name = "n_out_of_date") |>
  print()

cat("\n==== Example: Vancouver ====\n")
scorecard_latest |>
  filter(geo_name == "Vancouver") |>
  select(indicator_id, latest_year, latest_value, comparator_value, status, out_of_date) |>
  print(width = Inf)
