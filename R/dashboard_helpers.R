# R/dashboard_helpers.R
# Shared helpers for the dashboard (index.qmd) and municipality report cards.
# Status colours follow a fixed status palette and are always paired with an
# icon and a text label, so status is never shown by colour alone.

library(tidyverse)
library(htmltools)

# ---- Status palette ----
status_style <- tribble(
  ~status,            ~fill,     ~ink,      ~icon,  ~label,
  "Green",            "#0ca30c", "#ffffff", "✓", "Meets target or benchmark",
  "Amber",            "#fab219", "#0b0b0b", "!",      "Near target or benchmark",
  "Red",              "#d03b3b", "#ffffff", "✕", "Below target or benchmark",
  "No data",          "#e1e0d9", "#52514e", "–", "No data published",
  "Not yet assessed", "#f0efec", "#52514e", "…", "Results not yet published",
  "Benchmark",        "#383835", "#ffffff", "BC",     "Provincial benchmark",
  "Not applicable",   "#f0efec", "#52514e", "–", "Not applicable",
  "Not rated",        "#f0efec", "#52514e", "",       "Context only, not rated"
)

style_for <- function(s) {
  row <- status_style[match(s, status_style$status), ]
  if (nrow(row) == 0 || is.na(row$status)) row <- status_style[status_style$status == "Not rated", ]
  row
}

# ---- Number formatting by indicator ----
fmt_value <- function(indicator_id, x) {
  if (length(x) == 0 || is.na(x)) return("–")
  switch(indicator_id,
    HTO_Y1     = paste0(format(round(x), big.mark = ","), "%"),
    COMPL_RATE = formatC(x, format = "f", digits = 1),
    CHN_ALL    = , CHN_RENT = , UNAFF_RENT = , VAC = , RENT_CHG = paste0(formatC(x, format = "f", digits = 1), "%"),
    RENT_AVG   = paste0("$", format(round(x), big.mark = ",")),
    COMPL      = format(round(x), big.mark = ","),
    as.character(round(x, 1))
  )
}

# ---- Status chip: icon + value, with a text tooltip ----
status_chip <- function(status, value_text, tooltip = NULL, out_of_date = FALSE) {
  st <- style_for(status)
  tip <- paste0(status, ": ", st$label, if (!is.null(tooltip)) paste0(". ", tooltip) else "")
  span(
    class = "chip",
    style = sprintf("background:%s;color:%s;", st$fill, st$ink),
    title = tip,
    `aria-label` = tip,
    if (nzchar(st$icon)) span(class = "chip-icon", st$icon),
    span(value_text),
    if (isTRUE(out_of_date)) span(class = "chip-flag", "†")
  )
}

# ---- Inline SVG sparkline (no extra packages) ----
svg_sparkline <- function(years, values, width = 120, height = 30, ref = NULL,
                          label = "", value_fmt = function(v) round(v, 1)) {
  ok <- !is.na(values)
  years <- years[ok]; values <- values[ok]
  if (length(values) < 2) return(span(class = "muted", "–"))
  pad <- 4
  yr  <- range(c(values, ref), na.rm = TRUE)
  if (diff(yr) == 0) yr <- yr + c(-1, 1)
  sx <- function(x) pad + (x - min(years)) / max(1, diff(range(years))) * (width - 2 * pad)
  sy <- function(y) height - pad - (y - yr[1]) / diff(yr) * (height - 2 * pad)
  pts <- paste(sprintf("%.1f,%.1f", sx(years), sy(values)), collapse = " ")
  ref_line <- if (!is.null(ref)) sprintf(
    '<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#c3c2b7" stroke-width="1" stroke-dasharray="3,2"/>',
    pad, width - pad, sy(ref), sy(ref)) else ""
  tip <- sprintf("%s %d: %s; %d: %s", label, min(years), value_fmt(values[1]),
                 max(years), value_fmt(values[length(values)]))
  HTML(sprintf(
    '<svg width="%d" height="%d" role="img" aria-label="%s"><title>%s</title>%s<polyline fill="none" stroke="#2a5d8f" stroke-width="2" stroke-linejoin="round" points="%s"/><circle cx="%.1f" cy="%.1f" r="3" fill="#2a5d8f"/></svg>',
    width, height, tip, tip, ref_line, pts,
    sx(years[length(years)]), sy(values[length(values)])))
}

# ---- Larger SVG line chart with per-point tooltips ----
svg_linechart <- function(years, values, width = 560, height = 220, ref = NULL,
                          ref_label = NULL, y_label = "", value_fmt = function(v) round(v, 1)) {
  ok <- !is.na(values); years <- years[ok]; values <- values[ok]
  ml <- 40; mr <- 16; mt <- 14; mb <- 26
  yr <- range(c(0, values, ref), na.rm = TRUE); yr[2] <- yr[2] * 1.08
  sx <- function(x) ml + (x - min(years)) / diff(range(years)) * (width - ml - mr)
  sy <- function(y) height - mb - (y - yr[1]) / diff(yr) * (height - mt - mb)
  ticks <- pretty(yr, n = 4); ticks <- ticks[ticks >= yr[1] & ticks <= yr[2]]
  grid <- paste(sprintf(
    '<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e1e0d9"/><text x="%d" y="%.1f" font-size="11" fill="#52514e" text-anchor="end">%s</text>',
    ml, width - mr, sy(ticks), sy(ticks), ml - 6, sy(ticks) + 4, ticks), collapse = "")
  xt <- pretty(years, n = 6); xt <- xt[xt >= min(years) & xt <= max(years)]
  xlab <- paste(sprintf('<text x="%.1f" y="%d" font-size="11" fill="#52514e" text-anchor="middle">%d</text>',
                        sx(xt), height - 8, xt), collapse = "")
  ref_svg <- if (!is.null(ref)) sprintf(
    '<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#52514e" stroke-dasharray="4,3"/><text x="%d" y="%.1f" font-size="11" fill="#52514e" text-anchor="start" stroke="#ffffff" stroke-width="3" paint-order="stroke">%s</text>',
    ml, width - mr, sy(ref), sy(ref), ml + 4, sy(ref) - 5, ref_label) else ""
  pts <- paste(sprintf("%.1f,%.1f", sx(years), sy(values)), collapse = " ")
  dots <- paste(sprintf(
    '<circle cx="%.1f" cy="%.1f" r="7" fill="transparent"><title>%d: %s</title></circle><circle cx="%.1f" cy="%.1f" r="2.5" fill="#2a5d8f" pointer-events="none"/>',
    sx(years), sy(values), years, sapply(values, value_fmt), sx(years), sy(values)), collapse = "")
  HTML(sprintf(
    '<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="%s">%s%s%s<polyline fill="none" stroke="#2a5d8f" stroke-width="2" stroke-linejoin="round" points="%s"/>%s</svg>',
    width, height, y_label, grid, xlab, ref_svg, pts, dots))
}

# ---- Horizontal stacked status bar for a KPI tile ----
status_bar <- function(counts) {
  order <- c("Green", "Amber", "Red", "No data", "Not yet assessed")
  counts <- counts[intersect(order, names(counts))]
  total <- sum(counts)
  segs <- lapply(names(counts), function(s) {
    st <- style_for(s)
    div(class = "bar-seg",
        style = sprintf("width:%.2f%%;background:%s;", 100 * counts[[s]] / total, st$fill),
        title = sprintf("%s: %d of %d", s, counts[[s]], total))
  })
  div(class = "status-bar", segs)
}

status_legend_line <- function(counts) {
  order <- c("Green", "Amber", "Red", "No data", "Not yet assessed")
  counts <- counts[intersect(order, names(counts))]
  div(class = "status-counts",
      lapply(names(counts), function(s) {
        st <- style_for(s)
        span(class = "count-item",
             span(class = "dot", style = sprintf("background:%s;color:%s;", st$fill, st$ink), st$icon),
             sprintf("%s %d", s, counts[[s]]))
      }))
}

# ---- File-name slug for report cards (e.g. "City of Langley" -> "city-of-langley") ----
slugify <- function(x) {
  x |> str_to_lower() |> str_replace_all("[^a-z0-9]+", "-") |> str_remove_all("^-|-$")
}
