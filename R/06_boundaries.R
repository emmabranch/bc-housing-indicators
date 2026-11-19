# R/06_boundaries.R
# Municipal boundaries for the 40 Housing Target Order municipalities.
# Source: Statistics Canada, 2021 Census Cartographic Boundary Files,
#   census subdivisions (lcsd000b21), via StatCan's ArcGIS REST service:
#   https://geo.statcan.gc.ca/geo_wa/rest/services/2021/Cartographic_boundary_files/MapServer
# (The bcmaps/BC Data Catalogue WFS returned HTTP 400 on 2026-11-19.)
# Output: data/municipal_boundaries.geojson (simplified, WGS84 for leaflet)

library(tidyverse)
library(sf)
library(leaflet)
library(here)

munis <- read_csv(here("data", "municipalities.csv"),
                  col_types = cols(.default = "c"))

# ---- 1. Request only our 40 census subdivisions ----
ids   <- paste0("'", munis$geo_uid, "'", collapse = ",")
where <- URLencode(paste0("CSDUID IN (", ids, ")"), reserved = TRUE)

query_url <- paste0(
  "https://geo.statcan.gc.ca/geo_wa/rest/services/2021/",
  "Cartographic_boundary_files/MapServer/9/query",
  "?where=", where,
  "&outFields=CSDUID,CSDNAME,CSDTYPE",
  "&outSR=4326",
  "&f=geojson"
)

raw_file <- here("data-raw", "statcan_csd_2021_40.geojson")
if (!file.exists(raw_file)) {
  download.file(query_url, raw_file, mode = "wb", quiet = TRUE)
}
csd40 <- st_read(raw_file, quiet = TRUE)

cat("==== Downloaded layer ====\n")
cat("Columns:", paste(names(csd40), collapse = ", "), "\n")
cat("Features:", nrow(csd40), "\n")

# ---- 2. Check the join: codes, names, and municipality types ----
check <- csd40 |>
  st_drop_geometry() |>
  distinct(geo_uid = as.character(CSDUID), CSDNAME, CSDTYPE) |>
  right_join(munis |> select(geo_uid, municipality, census_name, csd_type),
             by = "geo_uid") |>
  mutate(
    found   = !is.na(CSDNAME),
    name_ok = found & str_detect(str_to_lower(CSDNAME), fixed(str_to_lower(census_name))),
    type_ok = found & CSDTYPE == csd_type
  )

cat("\nMatched codes:   ", sum(check$found),   "of", nrow(munis), "\n")
cat("Names match:     ", sum(check$name_ok), "of", nrow(munis), "\n")
cat("Types match:     ", sum(check$type_ok), "of", nrow(munis), "\n")

problems <- check |> filter(!found | !name_ok | !type_ok)
if (nrow(problems) > 0) {
  cat("\n==== Rows to review ====\n")
  print(problems |> select(municipality, geo_uid, CSDNAME, CSDTYPE, csd_type), n = Inf)
}

cat("\n==== City / District pairs ====\n")
check |>
  filter(geo_uid %in% c("5915001", "5915002", "5915046", "5915051")) |>
  select(municipality, geo_uid, CSDNAME, CSDTYPE) |>
  print()

# ---- 3. Dissolve, simplify, save ----
boundaries <- csd40 |>
  mutate(geo_uid = as.character(CSDUID)) |>
  st_make_valid() |>
  group_by(geo_uid) |>
  summarise(.groups = "drop") |>                       # one (multi)polygon each
  st_transform(3005) |>                                # BC Albers (metres)
  st_simplify(dTolerance = 50, preserveTopology = TRUE) |>
  st_transform(4326) |>                                # WGS84 for leaflet
  left_join(munis |> select(geo_uid, municipality, hto_group), by = "geo_uid")

out_file <- here("data", "municipal_boundaries.geojson")
st_write(boundaries, out_file, delete_dsn = TRUE, quiet = TRUE)
cat("\nWrote", out_file, "\n")
cat("File size:", round(file.size(out_file) / 1024), "KB\n")

# ---- 4. Visual check ----
boundary_map <- leaflet(boundaries) |>
  addProviderTiles("Esri.WorldGrayCanvas") |>
  addPolygons(weight = 1, color = "#333333", fillOpacity = 0.3,
              label = ~ paste0(municipality, " (Group ", hto_group, ")"))
print(boundary_map)