library(ggplot2)
library(ggridges)
library(lubridate)
library(dplyr)
library(forcats)
library(aws.s3)

source("util.r")

#' Create a timeseries plot
#' 
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param tavg_now: The current average temperature.
#' @param station_id: The id of the station, for saving to s3.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
createTimeseriesPlot <- function(hist_obs, tavg_now, station_id,
  station_tz, station_label) {

  date_now <- Sys.time() |> as.Date(station_tz)

  # rename problematic column
  hist_obs <- rename(hist_obs, ob_date = Date)

  stopifnot(
    "Arg `tavg_now` should be length 1"      = length(tavg_now) == 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))

  # extract percentiles of historical obs (unbound the ends)
  percentiles <- extract_percentiles(hist_obs$Tavg)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)
  hist_50p <- hist_obs %>% pull(Tavg) %>% median(na.rm = TRUE)
  
  percentiles %>% filter(pct_upper == "50%") %>% pull(value_upper)

  # add the bucket colours to eahc observation
  hist_obs |>
    left_join(percentiles,
      join_by(between(Tavg, value_lower, value_upper, bounds = "(]"))) ->
  hist_obs_shaded

  print(percentiles)

  # fit linear trend for label
  # (we're doing it twice; might be worth a benchmark)
  linear_model <- lm(formula = Tavg ~ ob_date, data = hist_obs_shaded)
  trend <- linear_model$coeff[2]

  # conditionally make extra room for the TODAY label either above or below,
  # depending on whether the current temp is in the top/bottom 5%
  if (tavg_now > hist_95p) {
    y_scale_expand <- expansion(mult = c(0.05, 0.15))
  } else if (tavg_now < hist_5p) {
    y_scale_expand <- expansion(mult = c(0.15, 0.05))
  } else {
    y_scale_expand <- expansion(mult = c(0.05, 0.05))
  }

  # today's observation
  tibble(x = date_now, y = tavg_now) |>
    left_join(percentiles,
      join_by(between(y, value_lower, value_upper, bounds = "(]"))) ->
  today_df


  # build the plot
  ts_plot <-
    ggplot(data = hist_obs_shaded) +
    # dashed percentile lines and labels
    # now the observations
    # james - i don't understand what this first geom is for
    geom_point(
      aes(x = ob_date, y = Tavg, colour = rating_colour),
      size = rel(1.1),
      # colour = base_colour,
      alpha = 0.5) +
    geom_smooth(
      aes(x = ob_date, y = Tavg),
      method = lm,
      se = FALSE,
      col = base_colour,
      linewidth = 0.5) +
    # today's point and labels
    geom_point(
      aes(x = x, y = y, colour = rating_colour),
      data = today_df,
      size = rel(5)) +
    annotate_text_iihrn(
      x = today_df$x,
      y = today_df$y,
      vjust = -1.5,
      label = "TODAY",
      highlight = FALSE) +
    annotate_text_iihrn(
      x = today_df$x,
      y = today_df$y,
      vjust = 2.5,
      label = paste0(round(tavg_now, 1), "°C"),
      highlight = FALSE) +
    annotate_text_iihrn(
      x = min(hist_obs_shaded$ob_date, na.rm = TRUE),
      y = hist_95p,
      label = paste0(
        "95th percentile: ", round(hist_95p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5,
      highlight = FALSE) +
    annotate_text_iihrn(
      x = min(hist_obs_shaded$ob_date, na.rm = TRUE),
      y = hist_5p,
      label = paste0(
        "5th percentile: ", round(hist_5p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5,
      highlight = FALSE) +
    annotate_text_iihrn(
      x = min(hist_obs_shaded$ob_date, na.rm = TRUE),
      y = hist_50p,
      label = paste0("Trend: +", round(trend * 365 * 100, 1), "°C/ century"),
      hjust = "inward",
      vjust = -0.5,
      highlight = FALSE) +
    scale_x_date(
      date_breaks = "20 years",
      date_labels = "%Y") +
    scale_y_continuous(
      breaks = seq(0, 100, by = 5),
      labels = scales::label_number(suffix = "°C"),
      expand = y_scale_expand) +
    scale_colour_identity() +
    theme_iihrn() +
    theme(
      axis.line = element_line(),
      axis.text.y = element_text(face = "bold"),
      axis.title.y = element_text(face = "bold", size = rel(0.8))) +
    labs(
      title = paste0(
        station_label,
        " daily average temperatures\nfor the two weeks around ",
        format(date_now, format = "%d %B", tz = station_tz)),
      x = NULL,
      y = "Daily average temperature")

  # write out to disk
  temp_path <- tempfile("timeseries-", fileext = ".png")
  ggsave(
    filename = temp_path,
    plot = ts_plot, bg = bg_colour_today,
    height = 4.5, width = 8, units = "in")
  
  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "timeseries",
      paste0("timeseries-", station_id, ".png")),
    bucket = "isithot-data")

  return(temp_path)
}

#' Create a distribution plot
#'
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param tavg_now: The current average temperature.
#' @param station_id: The id of the station, for saving to s3.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
createDistributionPlot <- function(hist_obs, tavg_now, station_tz,
  station_label) {

  stopifnot(
    "Arg `tavg_now` should be length 1"      = length(tavg_now) == 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))

  record_start <- hist_obs |> slice_min(Date) |> pull(Date)

  # TODO - get hist_obs from s3? or supplied directly in arg?
  # (The historical observations data frame (formerly HistObs).
  #   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.)

  # extract percentiles of historical obs
  # hist_obs %>%
  #   quantile(c(0.05, 0.10, 0.40, 0.50, 0.60, 0.90, 0.95), na.rm = TRUE) ->
  # percentiles

  percentiles <- extract_percentiles(hist_obs$Tavg)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)
  hist_50p <- hist_obs %>% pull(Tavg) %>% median(na.rm = TRUE)

  # TODO - shade distribution based on percentiles

  dist_plot <- ggplot(hist_obs) +
    aes(x = Tavg, y = 1) +
    # geom_density_ridges_gradient(
    #   adjust = 0.7, colour = NA) +
    stat_density_ridges(
      aes(fill = stat(quantile)),
      colour = NA,
      geom = "density_ridges_gradient",
      calc_ecdf = TRUE,
      quantiles = percentiles$frac_lower |> head(-1),
      quantile_lines = TRUE
      ) +
    # dashed vertical percentile lines and labels, plus today's temperature
    geom_vline(xintercept = tavg_now, colour = base_colour, linewidth = rel(1.5)) +
    # geom_vline(xintercept = hist_50p, linetype = 2, alpha = 0.5) +
    # geom_vline(xintercept = hist_5p,  linetype = 2, alpha = 0.5) +
    # geom_vline(xintercept = hist_95p, linetype = 2, alpha = 0.5) +
    annotate_text_iihrn(
      x = hist_5p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0("5th percentile:  ", round(hist_5p, 1), "°C"),
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      x = hist_50p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0(
        "50th percentile: ", round(hist_50p, 1), "°C"),
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      x = hist_95p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0("95th percentile:  ", round(hist_95p, 1), "°C"),
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      x = tavg_now,
      y = Inf,
      vjust = -0.75,
      hjust = 1.1,
      label = paste0("TODAY:  ", tavg_now, "°C"),
      highlight = FALSE,
      size = 4,
      angle = 90,
      alpha = 1) +
    scale_x_continuous(labels = scales::label_number(suffix = "°C")) +
    scale_y_continuous(limits = c(1, 1.32), expand = expansion(0)) +
    scale_fill_manual(values = rating_colours, guide = guide_none()) +
    theme_iihrn() +
    theme(
      axis.title.y = element_blank(),
      axis.text.y = element_blank()) +
    labs(
      x = "Daily average temperature",
      y = NULL,
      title = paste0(
        "Distribution of daily average temperatures\n",
        "for this time of year since ",
        record_start))

  # write out to disk
  temp_path <- tempfile("dist-", fileext = ".png")
  ggsave(
    filename = temp_path,
    plot = dist_plot, bg = bg_colour_today,
    height = 4.5, width = 8, units = "in")

  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "distribution",
      paste0("distribution-", station_id, ".png")),
    bucket = "isithot-data")
  }

#' Creates a plot of this year's ratings
#' 
#' @param obs_thisyear: this year's observations as a dataframe, from
#'   databackup/[id]-[year].csv. cols include date, percentile
#' @param date_now: today's date as a Date object
#' @param station_id: The id of the station, for saving to s3.
#' @param station_label: the station label
createHeatwavePlot <- function(obs_thisyear, date_now, station_label) {

  # extract month and day from the date
  obs_thisyear |>
    filter(!is.na(date)) |>
    mutate(
      month = fct_rev(factor(month(date), labels = month.abb)),
      day = mday(date)) ->
  obs_thisyear_toplot

  hw_plot <-
    ggplot(obs_thisyear_toplot) +
    aes(x = day, y = month) +
    geom_tile(aes(fill = percentile)) +
    geom_text(aes(label = percentile),
      family = "Roboto Condensed", fontface = "bold", size = 3.5) +
    coord_fixed() +
    scale_x_discrete(limits = factor(1:31), position = "top",
      expand = expansion(0)) +
    scale_y_discrete(drop = TRUE, expand = expansion(0)) +
    scale_fill_stepsn(
      colours = rating_colours,
      breaks = c(0, 5, 10, 40, 60, 90, 95, 100),
      limits = c(0, 100),
      na.value = NA,
      # colour bar disables `even.steps` to keep blocks proportional in height
      guide = guide_coloursteps(
        even.steps = FALSE,
        barheight = unit(0.679, "npc"),
        barwidth = unit(0.0125, "npc"),
        frame.colour = base_colour,
        frame.linewidth = 0.25,
        )) +
    labs(
      x = NULL,
      y = NULL,
      fill = NULL,
      title = paste(station_label, "percentiles for", year(date_now)),
      caption = "© isithotrightnow.com") +
    theme_iihrn() +
    theme(
      plot.background = element_rect(fill = NA, colour = NA),
      panel.background = element_rect(fill = NA, colour = NA),
      panel.grid = element_blank(),
      panel.border = element_rect(fill = NA, colour = "black", linewidth = 0.5),
      axis.ticks = element_blank(),
      axis.text = element_text(colour = base_colour, size = rel(0.5)),
      legend.margin = margin(),
      legend.spacing.y = unit(0, "mm"),
      legend.box.spacing = unit(0.0125, "npc"),
      legend.background = element_blank(),
      legend.justification = "center",
      legend.text = element_text(size = rel(0.5)),
      legend.title = element_blank(),
      plot.caption = element_text(size = rel(0.4))
      )

  # write out to disk
  temp_path <- tempfile("timeseries-", fileext = ".png")
  ggsave(
    filename = temp_path,
    plot = hw_plot, bg = bg_colour_hw,
    height = 1060, width = 2400, units = "px")

  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "heatwave",
      paste0("heatwave-", station_id, ".png")),
    bucket = "isithot-data")

}

#' The "test" plotting function
#'
#' Generates a plot from random data, saves it to disk, and then uploads it to
#' S3. Base other plotting functions off this.
createTestPlot <- function() {

  # generate some test data
  some_data <- runif(8, min = 1, max = 12)
  some_numbers <- data.frame(
    n = some_data,
    x = toupper(letters[seq_along(some_data)]))

  # create a plot
  my_plot <-
    ggplot(some_numbers) +
    aes(x, n) +
    geom_col() +
    theme_minimal(base_family = "Roboto Condensed")

  # write out to disk
  test_path <- "/tmp/testplot.png"
  ggsave(test_path, my_plot)

  # save to s3
  isithot_bucket <- "s3://isithot-data/"
  isithot_bucket_region <- "ap-southeast-2"
  bucket_ok <-
    bucket_exists(bucket = isithot_bucket, region = isithot_bucket_region)

  if (!bucket_ok) {
    stop("S3 bucket either doesn't exist or isn't accessible.")
  }

  put_object(test_path,
    object = basename(test_path),
    bucket = isithot_bucket,
    region = isithot_bucket_region)

  return(list(message = message))

}

lambdr::start_lambda()