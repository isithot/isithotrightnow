library(ggplot2)
library(lubridate)
library(dplyr)
library(stringr)
library(forcats)
library(aws.s3)

source("util.r")

#' Create a timeseries plot
#' 
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param date_now: Today's date (in UTC?)
#' @param tavg_now: The current average temperature.
#' @param station_id: The id of the station, for saving to s3.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
createTimeseriesPlot <- function(hist_obs, date_now, tavg_now, station_id,
  station_tz, station_label) {

  # rename problematic column
  hist_obs %>%
    rename(ob_date = Date) ->
  hist_obs

  stopifnot(
    "Arg `date_now` should be length 1"      = length(date_now) == 1,
    "Arg `tavg_now` should be length 1"      = length(tavg_now) == 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `date_now` should be a date"        = is(date_now, "Date"),
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))

  # extract percentiles of historical obs (unbound the ends)
  percentiles <- extract_percentiles(hist_obs$Tavg)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_50p <- percentiles %>% filter(pct_upper == "50%") %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)

  print(percentiles)

  # fit linear trend for label
  # (we're doing it twice; might be worth a benchmark)
  linear_model <- lm(formula = Tavg ~ ob_date, data = hist_obs)
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

  # build the plot
  ts_plot <-
    ggplot(data = hist_obs) +
    # dashed percentile lines and labels
    geom_rect(
      aes(
        xmin = as.Date(-Inf),
        xmax = as.Date(Inf),
        ymin = value_lower,
        ymax = value_upper,
        fill = rating_colour),
      data = percentiles,
      alpha = 0.5) +
    # now the observations
    # james - i don't understand what this first geom is for
    # geom_line(linewidth = 0.0, colour = "#CCCCCC") +
    geom_point(
      aes(x = ob_date, y = Tavg),
      size = rel(1.1),
      colour = base_colour,
      alpha = 0.25) +
    geom_smooth(
      aes(x = ob_date, y = Tavg),
      method = lm,
      se = FALSE,
      col = base_colour,
      linewidth = 0.5) +
    # today's point and labels
    geom_point(
      aes(x = x, y = y),
      data = data.frame(x = date_now, y = tavg_now),
      colour = iihrn_colour,
      size = rel(5)) +
    annotate_text_iihrn(
      x = date_now,
      y = tavg_now,
      vjust = -1.5,
      label = "TODAY",
      colour = iihrn_colour) +
    annotate_text_iihrn(
      x = date_now,
      y = tavg_now,
      vjust = 2.5,
      label = paste0(round(tavg_now, 1), "°C"),
      highlight = TRUE) +
    annotate_text_iihrn(
      x = min(hist_obs$ob_date, na.rm = TRUE),
      y = hist_95p,
      label = paste0(
        "95th percentile: ", round(hist_95p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = min(hist_obs$ob_date, na.rm = TRUE),
      y = hist_5p,
      label = paste0(
        "5th percentile: ", round(hist_5p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = min(hist_obs$ob_date, na.rm = TRUE),
      y = hist_50p,
      label = paste0("Trend: +", round(trend * 365 * 100, 1), "°C/ century"),
      hjust = "inward",
      vjust = -0.5) +
    scale_x_date(
      date_breaks = "20 years",
      date_labels = "%Y") +
    scale_y_continuous(
      breaks = seq(0, 100, by = 5),
      labels = scales::label_number(suffix = "°C"),
      expand = y_scale_expand) +
    scale_fill_identity() +
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

  percentiles <-
    extract_percentiles(hist_obs$Tavg) |>
    mutate(
      pct_upper_num = as.numeric(str_remove(pct_upper, "%")) / 100,
      pct_lower_num = as.numeric(str_remove(pct_lower, "%")) / 100)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_50p <- percentiles %>% filter(pct_upper == "50%") %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)

  # going to manually calculate the distribution so that we can
  # shade it by bucket!
  tavg_density <- density(hist_obs$Tavg, na.rm = TRUE)
  tavg_density_df <-
    tibble(x = tavg_density$x, y = tavg_density$y) |>
    left_join(percentiles,
      join_by(between(x, value_lower, value_upper, bounds = "[)")))

  # unfortunately we also have to "overlap" the breakpoitns to ensure they
  # don't leave seams behind... ugh, this is uglier than it ought to be
  breakpoints <-
    tavg_density_df |>
    arrange(x) |>
    mutate(
      prev_rating_colour = lag(rating_colour),
      is_break = rating_colour != prev_rating_colour) |>
    filter(is_break) |>
    mutate(rating_colour = prev_rating_colour) |>
    select(-prev_rating_colour, -is_break)

  tavg_density_bound <- bind_rows(tavg_density_df, breakpoints)

  dist_plot <- ggplot(hist_obs) +
    aes(x = Tavg) +
    # geom_density(adjust = 0.7, colour = NA, fill = base_colour, alpha = 0.3) +
    # shade each bucket separately
    geom_area(
      aes(x, y, fill = rating_colour),
      data = tavg_density_bound,
      colour = NA) +
    # dashed vertical percentile lines and labels, plus today's temperature
    geom_vline(xintercept = tavg_now, colour = base_colour, linewidth = rel(1.5)) +
    annotate_text_iihrn(
      highlight = FALSE,
      x = hist_5p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0("5th percentile:  ", round(hist_5p, 1), "°C"),
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      highlight = FALSE,
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
      highlight = FALSE,
      x = hist_95p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0("95th percentile:  ", round(hist_95p, 1), "°C"),
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      highlight = FALSE,
      x = tavg_now,
      y = Inf,
      vjust = -0.75,
      hjust = 1.1,
      label = paste0("TODAY:  ", tavg_now, "°C"),
      size = 4,
      angle = 90,
      alpha = 1) +
    scale_x_continuous(labels = scales::label_number(suffix = "°C")) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    scale_fill_identity() +
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
  temp_path <- tempfile("timeseries-", fileext = ".png")
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
      breaks = c(0, 5, 10, 40, 50, 60, 90, 95, 100),
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