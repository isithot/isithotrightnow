
# iihrn_colour: highlight colour
iihrn_colour <- "firebrick"
base_colour <- "#333333"
bg_colour <- "#eeeeee"

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


