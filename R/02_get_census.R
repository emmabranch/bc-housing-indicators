# R/02_get_census.R
# Download Statistics Canada table 98-10-0259-01:
# "Housing indicators by tenure: Canada, provinces and territories,
#  census divisions and census subdivisions" (2016 and 2021 Census).
# Keep BC only, cache locally, and verify municipality codes.

library(tidyverse)
library(cansim)
library(here)

munis <- read_csv(here("data", "municipalities.csv"),
                  col_types = cols(.default = "c"))

cache_dir <- here("data-raw", "cansim")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 1. Download (cached after first run) ----
con <- get_cansim_connection("98-10-0259-01", cache_path = cache_dir)

census_bc <- con |>
  filter(substr(GeoUID, 1, 2) == "59") |>   # BC province = 59, BC CSDs start with 59
  collect_and_normalize(disconnect = TRUE)

saveRDS(census_bc, here("data-raw", "census_98100259_bc.rds"))
cat("\nRows for BC:", nrow(census_bc), "\n")

# ---- 2. Structure of the table ----
cat("\n==== Column names ====\n")
print(names(census_bc))

# Print the categories of every short categorical column,
# so we can see the dimensions (year, tenure, indicator) and status flags
dim_cols <- census_bc |>
  select(where(~ (is.character(.x) || is.factor(.x)) && n_distinct(.x) <= 60)) |>
  names()

for (col in dim_cols) {
  cat("\n==== ", col, " ====\n", sep = "")
  print(unique(as.character(census_bc[[col]])))
}

# ---- 3. Verify the 40 municipality codes ----
geo_lookup <- census_bc |>
  distinct(GeoUID, GEO) |>
  mutate(GeoUID = as.character(GeoUID), GEO = as.character(GEO))

geo_check <- munis |>
  left_join(geo_lookup, by = c("geo_uid" = "GeoUID")) |>
  mutate(name_ok = !is.na(GEO) &
           str_detect(str_to_lower(GEO), fixed(str_to_lower(census_name))))

cat("\n==== Municipality code check ====\n")
print(geo_check |> select(hto_group, municipality, geo_uid, GEO, name_ok), n = Inf)
cat("\nMatched with correct name:", sum(geo_check$name_ok), "of", nrow(munis), "\n")

# For any problems, show candidate codes by name so we can fix them
problems <- geo_check |> filter(!name_ok)
if (nrow(problems) > 0) {
  cat("\n==== Candidates for problem rows ====\n")
  for (nm in unique(problems$census_name)) {
    cat("\n--", nm, "--\n")
    print(geo_lookup |> filter(str_detect(str_to_lower(GEO), fixed(str_to_lower(nm)))))
  }
}

# BC total (benchmark row)
cat("\nBC total row present:", "59" %in% geo_lookup$GeoUID, "\n")