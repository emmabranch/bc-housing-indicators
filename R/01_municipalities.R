# R/01_municipalities.R
# Lookup of the 40 BC municipalities with Housing Supply Act
# Housing Target Orders, by group, with 2021 Census subdivision codes.
# Source for group membership: BC Government, Housing targets: Reports page
# https://www2.gov.bc.ca/gov/content/housing-tenancy/local-governments-and-housing/housing-targets/reports
# GeoUIDs verified against StatCan table 98-10-0259-01 in R/02_get_census.R.
# Join on geo_uid only: census names are not unique (e.g. Langley CY and DM).

library(tidyverse)
library(here)

municipalities <- tribble(
  ~municipality,                     ~census_name,       ~csd_type, ~geo_uid,  ~hto_group,
  # Group 1
  "Abbotsford",                      "Abbotsford",       "CY",      "5909052", 1,
  "Delta",                           "Delta",            "CY",      "5915011", 1,
  "District of North Vancouver",     "North Vancouver",  "DM",      "5915046", 1,
  "Kamloops",                        "Kamloops",         "CY",      "5933042", 1,
  "Oak Bay",                         "Oak Bay",          "DM",      "5917030", 1,
  "Port Moody",                      "Port Moody",       "CY",      "5915043", 1,
  "Saanich",                         "Saanich",          "DM",      "5917021", 1,
  "Vancouver",                       "Vancouver",        "CY",      "5915022", 1,
  "Victoria",                        "Victoria",         "CY",      "5917034", 1,
  "West Vancouver",                  "West Vancouver",   "DM",      "5915055", 1,
  # Group 2
  "Chilliwack",                      "Chilliwack",       "CY",      "5909020", 2,
  "Kelowna",                         "Kelowna",          "CY",      "5935010", 2,
  "Maple Ridge",                     "Maple Ridge",      "CY",      "5915075", 2,
  "Nanaimo",                         "Nanaimo",          "CY",      "5921007", 2,
  "City of North Vancouver",         "North Vancouver",  "CY",      "5915051", 2,
  "Surrey",                          "Surrey",           "CY",      "5915004", 2,
  "White Rock",                      "White Rock",       "CY",      "5915007", 2,
  "Central Saanich",                 "Central Saanich",  "DM",      "5917015", 2,
  "Sidney",                          "Sidney",           "T",       "5917010", 2,
  "Esquimalt",                       "Esquimalt",        "DM",      "5917040", 2,
  # Group 3
  "Colwood",                         "Colwood",          "CY",      "5917041", 3,
  "City of Langley",                 "Langley",          "CY",      "5915002", 3,
  "Mission",                         "Mission",          "DM",      "5909056", 3,
  "New Westminster",                 "New Westminster",  "CY",      "5915029", 3,
  "Port Coquitlam",                  "Port Coquitlam",   "CY",      "5915039", 3,
  "Prince George",                   "Prince George",    "CY",      "5953023", 3,
  "West Kelowna",                    "West Kelowna",     "CY",      "5935029", 3,
  "North Cowichan",                  "North Cowichan",   "DM",      "5919008", 3,
  "North Saanich",                   "North Saanich",    "DM",      "5917005", 3,
  "View Royal",                      "View Royal",       "T",       "5917047", 3,
  # Group 4
  "Burnaby",                         "Burnaby",          "CY",      "5915025", 4,
  "Coquitlam",                       "Coquitlam",        "CY",      "5915034", 4,
  "Courtenay",                       "Courtenay",        "CY",      "5926010", 4,
  "Langford",                        "Langford",         "CY",      "5917044", 4,
  "Penticton",                       "Penticton",        "CY",      "5907041", 4,
  "Pitt Meadows",                    "Pitt Meadows",     "CY",      "5915070", 4,
  "Richmond",                        "Richmond",         "CY",      "5915015", 4,
  "Squamish",                        "Squamish",         "DM",      "5931006", 4,
  "Township of Langley",             "Langley",          "DM",      "5915001", 4,
  "Vernon",                          "Vernon",           "CY",      "5937014", 4
)

# Basic integrity checks
stopifnot(
  nrow(municipalities) == 40,
  !any(duplicated(municipalities$geo_uid)),
  all(nchar(municipalities$geo_uid) == 7)
)

write_csv(municipalities, here("data", "municipalities.csv"))
cat("Wrote", nrow(municipalities), "municipalities to data/municipalities.csv\n")
count(municipalities, hto_group)