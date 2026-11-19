# Data quality log

Running record of data issues found and how each was handled.
Summarised in the README.

| # | Date | Source | Issue | Handling |
|---|------|--------|-------|----------|
| 1 | 2026-11-19 | Municipality lookup | 6 of 40 census subdivision codes were initially wrong (Oak Bay, Saanich, Esquimalt, Colwood, View Royal, Vernon). | Automated name check against StatCan 98-10-0259-01 flagged them; corrected and re-verified (40 of 40). |
| 2 | 2026-11-19 | StatCan 98-10-0259-01 | Geography names are not unique (e.g. Langley City and Township; North Vancouver City and District; Esquimalt municipality and Esquimalt reserve). | All joins use GeoUID only. City/District pairs checked by household counts. |
| 3 | 2026-11-19 | StatCan 98-10-0259-01 | Symbol "x" = suppressed for confidentiality; "..." = not available. | Treated as missing; counted and reported per indicator in data quality checks. |
| 4 | 2026-11-19 | StatCan 98-10-0259-01 | REF_DATE is 2021 for all rows; the 2016 values are distinguished by the "Census year" dimension. | Year taken from "Census year (2)", not REF_DATE. |
| 5 | 2026-11-19 | StatCan 98-10-0259-01 | A fourth tenure category (housing provided by local government, First Nation or Indian band) is included in totals. | Totals used as published; renter and owner indicators exclude this category. Noted in README. |
| 6 | 2026-11-19 | CMHC Rental Market Survey | North Saanich has no vacancy or rent data (very small purpose-built rental universe). | Shown as "No data" in the scorecard; not imputed. |
| 7 | 2026-11-19 | CMHC Rental Market Survey | Latest vacancy value is older than 2025 for Colwood (2023), Pitt Meadows (2021), Port Coquitlam (2024), and Coquitlam (2024), because later years were suppressed. Colwood and Pitt Meadows report 0% from small rental stocks. | Latest available value shown with its year and flagged as out of date; CMHC quality rating displayed. |
| 8 | 2026-11-19 | CMHC Rental Market Survey | Average rent change has a 2025 value for only 15 of 40 municipalities. | Used as a supporting indicator only (no RAG status); latest year shown. |
| 9 | 2026-11-19 | CMHC | The 3% "balanced market" vacancy benchmark is a long-standing industry rule of thumb that CMHC's 2026 mid-year update says does not hold across all markets. | 3% used as a labelled reference point, not a target; caveat cited in the indicator framework. |
| 10 | 2026-11-19 | Housing Supply Act targets | No machine-readable source. Values compiled from BC Government news releases (primary) and a news tracker (secondary). Secondary and primary sources disagreed on some interim (6-month) figures, e.g. Chilliwack and Nanaimo. | Only full Year 1 results used. Each row records its source and whether it was verified against a primary source; a sample of Group 2 rows checked against municipal progress report PDFs. |
| 11 | 2026-11-19 | Housing Supply Act targets | Year 1 periods differ by group (Group 1 ends Sep 2024; Group 2 Jun 2025; Group 3 Jul 2025). Group 4 Year 1 results not yet published. | Periods stored per row and shown in the dashboard; Group 4 shown as "Not yet assessed". |
| 12 | 2026-11-19 | Validation | Pipeline output checked against Statistics Canada published figures. | BC core housing need 2016 14.9% and 2021 13.4%; renters 29.9% and 24.7%: all four match StatCan's published table exactly. |
| 13 | 2026-11-19 | Geography | Published figures are often for census metropolitan areas (CMAs), not municipalities (census subdivisions). | Scorecard uses municipal (CSD) values throughout; README warns against comparing them with CMA figures. |
| 14 | 2026-11-19 | Boundaries | BC Data Catalogue WFS (via bcmaps) returned HTTP 400. | Switched to Statistics Canada 2021 cartographic boundary files (same CSD codes as the census data); codes, names, and municipality types checked. |
| 15 | 2026-11-19 | Basemap | CARTO basemap tiles now require an API key (watermarked without one). | Switched to Esri World Gray Canvas tiles, which need no key; attribution shown on the map. |
