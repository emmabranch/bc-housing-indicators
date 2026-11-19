# R/04_housing_targets.R
# Housing Supply Act targets and Year 1 results for the 40 municipalities
# with Housing Target Orders. Hand-compiled: no machine-readable source exists.
#
# Sources (accessed 2026-11-19):
#  [G1T] BC Gov news release, Group 1 targets (Sept 2023): https://news.gov.bc.ca/29574
#  [G2T] BC Gov news release, Group 2 targets (June 2024):
#        https://news.gov.bc.ca/releases/2024HOUS0113-001012
#  [G3R] BC Gov news release, Group 3 Year 1 results (Nov 27, 2025):
#        https://news.gov.bc.ca/releases/2025HMA0116-001177
#  [STY] Storeys, "BC housing supply targets progress tracker" (updated Aug 21, 2025),
#        secondary source: https://storeys.com/bc-housing-supply-targets-progress-tracker/
#  Primary PDFs for verification: BC Gov Housing targets: Reports page
#        https://www2.gov.bc.ca/gov/content/housing-tenancy/local-governments-and-housing/housing-targets/reports
#
# Definitions: net new units = completions (occupancy permits) minus demolitions.
# target_y1 = Year 1 target; target_5yr = cumulative five-year target.

library(tidyverse)
library(here)

munis <- read_csv(here("data", "municipalities.csv"),
                  col_types = cols(.default = "c"))

targets_raw <- tribble(
  ~municipality,                 ~target_5yr, ~target_y1, ~y1_net_new, ~target_src, ~y1_src, ~y1_verified_primary,
  # Group 1: Year 1 = 2023-10-01 to 2024-09-30
  "Abbotsford",                   7240,  1022,   602, "G1T", "STY", TRUE,   # confirmed in Abbotsford Year 2 council report
  "Delta",                        3607,   514,   561, "G1T", "STY", FALSE,
  "District of North Vancouver",  2838,   499,   500, "G1T", "STY", FALSE,
  "Kamloops",                     4236,   679,   449, "G1T", "STY", FALSE,
  "Oak Bay",                       664,    56,    16, "G1T", "STY", FALSE,
  "Port Moody",                   1694,   231,   168, "G1T", "STY", FALSE,
  "Saanich",                      4610,   440,   338, "G1T", "STY", FALSE,
  "Vancouver",                   28900,  5202,  4143, "G1T", "STY", FALSE,
  "Victoria",                     4902,   659,  1477, "G1T", "STY", FALSE,
  "West Vancouver",               1432,   220,    58, "G1T", "STY", FALSE,
  # Group 2: Year 1 = 2024-07-01 to 2025-06-30
  "Chilliwack",                   4594,   659,  1069, "G2T", "STY", TRUE,
  "Kelowna",                      8774,  1363,  3467, "G2T", "STY", FALSE,
  "Maple Ridge",                  3954,   612,   751, "G2T", "STY", FALSE,
  "Nanaimo",                      4703,   783,   875, "G2T", "STY", TRUE,
  "City of North Vancouver",      3320,   581,   547, "G2T", "STY", FALSE,
  "Surrey",                      27256,  4233,  6488, "G2T", "STY", FALSE,
  "White Rock",                   1067,   189,   133, "G2T", "STY", TRUE,
  "Central Saanich",               588,    77,   314, "G2T", "STY", FALSE,
  "Sidney",                        468,    90,    90, "G2T", "STY", FALSE,
  "Esquimalt",                     754,    81,   369, "G2T", "STY", FALSE,
  # Group 3: Year 1 = 2024-08-01 to 2025-07-31
  "Colwood",                       940,   178,   397, "STY", "G3R", TRUE,
  "City of Langley",              1844,   251,   533, "STY", "G3R", TRUE,
  "Mission",                      1798,   211,   314, "STY", "G3R", TRUE,
  "New Westminster",              4432,   656,  1175, "STY", "G3R", TRUE,
  "Port Coquitlam",               2279,   343,   191, "STY", "G3R", TRUE,
  "Prince George",                1803,   273,   284, "STY", "G3R", TRUE,
  "West Kelowna",                 2266,   289,   331, "STY", "G3R", TRUE,
  "North Cowichan",               1233,   191,   141, "STY", "G3R", TRUE,
  "North Saanich",                 419,    60,    12, "STY", "G3R", TRUE,
  "View Royal",                    585,    99,   260, "STY", "G3R", TRUE,
  # Group 4: Year 1 = 2025-09-01 to 2026-08-31 (results not yet published at time of compilation)
  "Burnaby",                     10240,  1536,    NA, "STY", NA,    FALSE,
  "Coquitlam",                    6481,   972,    NA, "STY", NA,    FALSE,
  "Courtenay",                    1334,   200,    NA, "STY", NA,    FALSE,
  "Langford",                     2993,   449,    NA, "STY", NA,    FALSE,
  "Penticton",                     908,   136,    NA, "STY", NA,    FALSE,
  "Pitt Meadows",                  727,   109,    NA, "STY", NA,    FALSE,
  "Richmond",                     6753,  1013,    NA, "STY", NA,    FALSE,
  "Squamish",                     1069,   160,    NA, "STY", NA,    FALSE,
  "Township of Langley",          6596,   989,    NA, "STY", NA,    FALSE,
  "Vernon",                       1849,   277,    NA, "STY", NA,    FALSE
)

source_lookup <- c(
  G1T = "https://news.gov.bc.ca/29574",
  G2T = "https://news.gov.bc.ca/releases/2024HOUS0113-001012",
  G3R = "https://news.gov.bc.ca/releases/2025HMA0116-001177",
  STY = "https://storeys.com/bc-housing-supply-targets-progress-tracker/"
)

housing_targets <- targets_raw |>
  left_join(munis |> select(municipality, geo_uid, hto_group), by = "municipality") |>
  mutate(
    hto_group = as.integer(hto_group),
    y1_period_start = case_when(hto_group == 1 ~ "2023-10-01", hto_group == 2 ~ "2024-07-01",
                                hto_group == 3 ~ "2024-08-01", hto_group == 4 ~ "2025-09-01"),
    y1_period_end   = case_when(hto_group == 1 ~ "2024-09-30", hto_group == 2 ~ "2025-06-30",
                                hto_group == 3 ~ "2025-07-31", hto_group == 4 ~ "2026-08-31"),
    y1_pct_of_target = round(100 * y1_net_new / target_y1, 1),
    target_src_url = unname(source_lookup[target_src]),
    y1_src_url     = unname(source_lookup[y1_src]),
    y1_src_type    = case_when(y1_src %in% c("G3R") ~ "Primary (BC Government)",
                               y1_src == "STY"       ~ "Secondary (news tracker)",
                               TRUE                  ~ NA_character_)
  ) |>
  relocate(geo_uid, municipality, hto_group)

# Integrity checks
stopifnot(
  nrow(housing_targets) == 40,
  !any(is.na(housing_targets$geo_uid)),      # every name matched the lookup
  all(housing_targets$target_y1 < housing_targets$target_5yr),
  all(is.na(housing_targets$y1_net_new[housing_targets$hto_group == 4]))
)

write_csv(housing_targets, here("data", "housing_targets.csv"))
cat("Wrote data/housing_targets.csv\n\n")

housing_targets |>
  select(hto_group, municipality, target_y1, y1_net_new, y1_pct_of_target,
         y1_src_type, y1_verified_primary) |>
  arrange(hto_group, desc(y1_pct_of_target)) |>
  print(n = Inf)

cat("\nRows with Year 1 result:", sum(!is.na(housing_targets$y1_net_new)), "of 40\n")
cat("Year 1 results verified against a primary source:",
    sum(housing_targets$y1_verified_primary), "of",
    sum(!is.na(housing_targets$y1_net_new)), "\n")