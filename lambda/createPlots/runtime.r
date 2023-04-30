library(ggplot2)
library(lubridate)
library(aws.s3)

source("util.r")

#' Just prints a message
#'
#' Here as a default so that you can verify your lambda config (and to make it
#' clear if you've forgotten to override the entrypoint)
defaultFunc <- function() {
  return(list(message = paste(
    "This is the default function for the Is it hot right now R runtime.",
    "If you're configuring a new Lambda function, you should override the",
    "Lambda's entrypoint to be the name of one of the other functions in this",
    "file.")))
}

#' Create a timeseries plot
#' 
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param today: Today's date (in UTC?)
#' @param tavg_now: The current average temperature.
#' @param hist_percentiles: An array of historical percentiles (formerly
#'   HistPercentiles).
#' @param hist_5p The 5th percentile of historical temperatures.
#' @param hist_50p The median of historical temperatures.
#' @param hist_95p The 95th percentile of historical temperatures.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
#' @param output_path
createTimeseriesPlot <- function(hist_obs, date_now, tavg_now, hist_5p,
  hist_50p, hist_95p, station_tz, station_label, output_path) {

  stopifnot(
    "Arg `today` should be length 1"         = length(today) != 1,
    "Arg `tavg_now` should be length 1"      = length(tavg_now) != 1,
    "Arg `hist_5p` should be length 1"       = length(hist_5p) != 1,
    "Arg `hist_50p` should be length 1"      = length(hist_50p) != 1,
    "Arg `hist_95p` should be length 1"      = length(hist_95p) != 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) != 1,
    "Arg `station_label` should be length 1" = length(station_label) != 1,
    "Arg `output_path` should be length 1"   = length(output_path) != 1,
    "Arg `today` should be a date"           = is(today, "Date"),
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `hist_5p` should be a number"       = is(hist_5p, "numeric"),
    "Arg `hist_50p` should be a number"      = is(hist_50p, "numeric"),
    "Arg `hist_95p` should be a number"      = is(hist_95p, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"),
    "Arg `output_path` should be a string"   = is(output_path, "character"))

  # fit linear trend for label
  # (we're doing it twice; might be worth a benchmark)
  linear_model <- lm(formula = Tavg ~ Date, data = hist_obs)
  trend <- linear_model$coeff[2]

  # conditionally make extra room for the TODAY label either above or below,
  # depending on whether the current temp is in the top/bottom 5%
  y_scale_expand = ifelse(
    Tavg.now > hist_95p,
    expansion(mult = c(0.05, 0.15)),
    ifelse(
      Tavg.now < hist_5p,
      expansion(mult = c(0.15, 0.05)),
      expansion(mult = c(0.05, 0.05))))

  # build the plot
  plot_ts <-
    ggplot(data = obs) +
    aes(x = Date, y = Tavg) +
    # james - i don't understand what this first geom is for
    # geom_line(size = 0.0, colour = "#CCCCCC") +
    geom_point(size = rel(1.5), colour = base_colour, alpha = 0.25) +
    geom_smooth(method = lm, se = FALSE, col = "gray60", size = 0.5) +
    # today's point and labels
    geom_point(
      aes(x = x, y = y),
      data = data.frame(x = date_now, y = tavg_now),
      colour = iihrn_colour,
      size = rel(5)) +
    annotate_text_iihrn(
      x = today,
      y = tavg_now,
      vjust = -1.5,
      label = "TODAY",
      colour = iihrn_colour) +
    annotate_text_iihrn(
      x = today,
      y = tavg_now,
      vjust = 2.5,
      label = paste0(round(tavg_now, 1), "°C"),
      highlight = TRUE) +
    # dashed percentile lines and labels
    geom_hline(aes(yintercept = hist_95p), linetype = 2, alpha = 0.5) +
    geom_hline(aes(yintercept = hist_5p), linetype = 2, alpha = 0.5) +
    # james - perhaps we should consider replacing the dotted lines with blocks
    # of colour that are the same as our category colours?
    annotate_text_iihrn(
      x = min(hist_obs$Date, na.rm = TRUE),
      y = hist_95p,
      label = paste0(
        "95th percentile: ", round(hist_95p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = min(hist_obs$Date, na.rm = TRUE),
      y = hist_5p,
      label = paste0(
        "5th percentile: ", round(hist_5p, 1), "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = min(hist_obs$Date, na.rm = TRUE),
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
  ggsave(filename = output_path, plot = plot_ts, bg = bg_colour,
    height = 4.5, width = 8, units = "in")

}

#' Create a distribution plot
#'
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param today: Today's date (in UTC?)
#' @param tavg_now: The current average temperature.
#' @param hist_percentiles: An array of historical percentiles (formerly
#'   HistPercentiles).
#' @param hist_5p The 5th percentile of historical temperatures.
#' @param hist_50p The median of historical temperatures.
#' @param hist_95p The 95th percentile of historical temperatures.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
#' @param record_start: The date of the first record in the obs
#' @param output_path
createDistributionPlot <- function(hist_obs, date_now, tavg_now, hist_5p,
  hist_50p, hist_95p, station_tz, station_label, record_start, output_path) {

  stopifnot(
    "Arg `today` should be length 1"         = length(today) != 1,
    "Arg `tavg_now` should be length 1"      = length(tavg_now) != 1,
    "Arg `hist_5p` should be length 1"       = length(hist_5p) != 1,
    "Arg `hist_50p` should be length 1"      = length(hist_50p) != 1,
    "Arg `hist_95p` should be length 1"      = length(hist_95p) != 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) != 1,
    "Arg `record_start` should be length 1"  = length(record_start) != 1,
    "Arg `station_label` should be length 1" = length(station_label) != 1,
    "Arg `output_path` should be length 1"   = length(output_path) != 1,
    "Arg `today` should be a date"           = is(today, "Date"),
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `hist_5p` should be a number"       = is(hist_5p, "numeric"),
    "Arg `hist_50p` should be a number"      = is(hist_50p, "numeric"),
    "Arg `hist_95p` should be a number"      = is(hist_95p, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"),
    "Arg `record_start` should be a date"    = is(record_start, "Date"),
    "Arg `output_path` should be a string"   = is(output_path, "character"))

  dist_plot <- ggplot(hist_obs) +
    aes(x = Tavg) +
    geom_density(adjust = 0.7, colour = NA, fill = base_colour, alpha = 0.3) +
    # dashed vertical percentile lines and labels, plus today's temperature
    geom_vline(xintercept = tavg_now, colour = iihrn_colour, size = rel(1.5)) +
    geom_vline(xintercept = hist_50p, linetype = 2, alpha = 0.5) +
    geom_vline(xintercept = hist_5p,  linetype = 2, alpha = 0.5) +
    geom_vline(xintercept = hist_95p, linetype = 2, alpha = 0.5) +
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
      highlight = TRUE,
      size = 4,
      angle = 90,
      alpha = 1) +
    scale_x_continuous(labels = scales::label_number(suffix = "°C"))
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
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
  ggsave(filename = output_path, plot = dist_plot, bg = bg_colour,
    height = 4.5, width = 8, units = "in")

  }

# createTestPlot: our "test" plotting function. generates a plot from random
# data, saves it to disk, and then uploads it to S3. base other plotting
# functions off this
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