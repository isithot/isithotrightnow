
# iihrn_colour: highlight colour
iihrn_colour <- "firebrick"
base_colour <- "#333333"
bg_colour_today <- "#eeeeee"
bg_colour_hw <- "#dddddd"

rating_colours <- c(
  "#2166ac", 0-5
  "#4393c3", 5-10
  "#92c5de", 10-40
  "#d1e5f0", 40-50
  "#fddbc7", 50-60
  "#f4a582", 60-90
  "#d6604d", 90-95
  "#b2182b") 95-100

#' Return a data frame of lower and upper limits for shading graphics based on
#' our ratings.
#' @param obs A vector of temperatures from which to extract percentiles
#' @return A data frame with columns:
#'   - pct_upper <chr>: the upper percentile of the region
#'   - pct_lower <chr>: the lower percentile of the region
#'   - value_upper <dbl>: the upper temperature threshold the region
#'   - value_lower <dbl>: the lower temperature threshold of the region
#'   - rating_colour <chr>: the hex code of the colour to use
extract_percentiles <- function(obs) {
  obs %>%
    quantile(
      c(0, 0.05, 0.10, 0.40, 0.50, 0.60, 0.90, 0.95, 1),
      na.rm = TRUE) %>%
    tibble(
      pct_upper = names(.),
      pct_lower = lag(names(.), 1),
      value_upper = .,
      value_lower = lag(., 1)) %>%
    # we don't need to categorise temps lower than the lowest
    slice(-1) %>%
    mutate(rating_colour = rating_colours) ->
  percentiles

  # unbound the ends
  percentiles$lower[1] <- Inf
  percentiles$upper[nrow(percentiles)] <- Inf

  return(percentiles)
}

#' Define some sensible defaults for text annotations
#' 
#' @param size: The size of the text. Defaults to 50% of the base size.
#' @param highlight: If true, use the highlight text colour.
#' @param ...: Other arguments passed to annotate.
annotate_text_iihrn <- function(size = rel(0.5),
  highlight = c(FALSE, TRUE), ...) {
  annotate(
    geom = "text",
    family = "Roboto Condensed",
    fontface = "bold",
    colour = ifelse(highlight, iihrn_colour, base_colour),
    size = size,
    ...)
}

#' Common theme elements for all Is is hot right now plots
#' 
#' @param base_family: The base font family to use.
#' @param base_size: The base font size to use.
theme_iihrn <- function(base_family = "Roboto Condensed", base_size = 20) {
  theme_bw(base_family = base_family, base_size = base_size) +
  theme(
    # transparent background
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    # no axis gridlines
    panel.grid.minor = element_blank(),
    panel.grid.major = element_blank(),
    panel.border = element_blank(),
    # consistent text
    plot.title = element_text(
      face = "bold",
      color = base_colour,
      size = rel(0.9),
      hjust = 0.5),
    axis.text = element_text(face = "bold"),
    axis.title = element_text(face = "bold", size = rel(0.8)),
    axis.ticks.y = element_blank())
}


