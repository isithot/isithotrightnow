library(ggplot2)
library(ggridges)
library(lubridate)
library(dplyr)
library(jsonlite)
library(forcats)
library(aws.s3)
library(plot3D)

source("/lambda/util.r")

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

  message("Beginning function")
  flush.console()

  date_now <- Sys.time() |> as.Date(station_tz)

  # hist_obs comes as a JSON string when invoked externally rather than through
  # the console. we need to convert it manually
  if (is.character(hist_obs)) {
    message("De-serialising observations")
    flush.console()
    hist_obs <- fromJSON(hist_obs)
  }
  
  message("Validating arguments")
  flush.console()

  stopifnot(
    "Arg `hist_obs` should be a data frame"  = is.data.frame(hist_obs),
    "Arg `hist_obs` should include the columns `Date` and `Tavg`" =
      c("Date", "Tavg") %in% names(hist_obs) |> all(),
    "Arg `tavg_now` should be length 1"      = length(tavg_now) == 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))
  
  message("Casting observation dates")
  flush.console()

  # cast dates ({jsonlite} doesn't do it for us)
  hist_obs <-
    hist_obs %>%
    mutate(ob_date = as.Date(Date))

  message("Extracting percentiles")
  flush.console()

  # extract percentiles of historical obs (unbound the ends)
  percentiles <- extract_percentiles(hist_obs$Tavg)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)
  hist_50p <- hist_obs %>% pull(Tavg) %>% median(na.rm = TRUE)

  message("Joining percentile colours to observations")
  flush.console()

  # add the bucket colours to eahc observation
  hist_obs |>
    left_join(percentiles,
      join_by(between(Tavg, value_lower, value_upper, bounds = "(]"))) ->
  hist_obs_shaded

  message("Fitting linear trend")
  flush.console()

  # fit linear trend for label
  # (we're doing it twice; might be worth a benchmark)
  linear_model <- lm(formula = Tavg ~ ob_date, data = hist_obs_shaded)
  trend <- linear_model$coeff[2]

  message("Calculating Y scale expansion")
  flush.console()

  # conditionally make extra room for the TODAY label either above or below,
  # depending on whether the current temp is in the top/bottom 5%
  if (tavg_now > hist_95p) {
    y_scale_expand <- expansion(mult = c(0.05, 0.15))
  } else if (tavg_now < hist_5p) {
    y_scale_expand <- expansion(mult = c(0.15, 0.05))
  } else {
    y_scale_expand <- expansion(mult = c(0.05, 0.05))
  }

  message("Building today's observation")
  flush.console()

  # today's observation
  tibble(x = date_now, y = tavg_now) |>
    left_join(percentiles,
      join_by(between(y, value_lower, value_upper, bounds = "(]"))) ->
  today_df

  message("Building the plot")
  flush.console()

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
    # 5th/95th percentile lines and labels
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
    geom_hline(yintercept = hist_5p, colour = base_colour,
      linetype = "longdash") +
    geom_hline(yintercept = hist_95p, colour = base_colour,
      linetype = "longdash") +
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
    # trend line and label
    geom_smooth(
      aes(x = ob_date, y = Tavg),
      method = lm,
      se = FALSE,
      col = base_colour,
      linewidth = 0.5) +
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

  message("Writing the plot out to disk temporarily")
  flush.console()

  # write out to disk
  temp_path <- tempfile("timeseries-", fileext = ".png")
  ggsave(
    filename = temp_path,
    plot = ts_plot, bg = bg_colour_today,
    height = 4.5, width = 8, units = "in")

  message("Uploading the plot to S3 bucket")
  flush.console()
  
  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "timeseries",
      paste0("timeseries-", station_id, ".png")),
    bucket = "isithot-data")

  message("All done!")
  flush.console()
  return()
}

#' Create a distribution plot
#'
#' @param hist_obs: The historical observations data frame (formerly HistObs).
#'   Cols include Year, Month, Day, Tmax, Tmin, Tavg, Date.
#' @param tavg_now: The current average temperature.
#' @param station_id: The id of the station, for saving to s3.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: The name of the station's area.
createDistributionPlot <- function(hist_obs, tavg_now, station_id, station_tz,
  station_label) {

  message("Beginning function")
  flush.console()

  date_now <- Sys.time() |> as.Date(station_tz)

  # hist_obs comes as a JSON string when invoked externally rather than through
  # the console. we need to convert it manually
  if (is.character(hist_obs)) {
    message("De-serialising observations")
    flush.console()
    hist_obs <- fromJSON(hist_obs)
  }

  message("Validating arguments")
  flush.console()

  stopifnot(
    "Arg `hist_obs` should be a data frame"  = is.data.frame(hist_obs),
    "Arg `hist_obs` should include the columns `Date` and `Tavg`" =
      c("Date", "Tavg") %in% names(hist_obs) |> all(),
    "Arg `tavg_now` should be length 1"      = length(tavg_now) == 1,
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `tavg_now` should be a number"      = is(tavg_now, "numeric"),
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))
  
  message("Casting observation dates")
  flush.console()

  # cast dates ({jsonlite} doesn't do it for us)
  hist_obs <-
    hist_obs %>%
    mutate(ob_date = as.Date(Date))

  message("Getting start of observation record")
  flush.console()

  record_start <- hist_obs %>% slice_min(ob_date) %>% pull(ob_date) %>% year()

  message("Extracting percntiles")
  flush.console()

  percentiles <- extract_percentiles(hist_obs$Tavg)
  hist_5p  <- percentiles %>% filter(pct_upper == "5%")  %>% pull(value_upper)
  hist_95p <- percentiles %>% filter(pct_upper == "95%") %>% pull(value_upper)
  hist_50p <- hist_obs %>% pull(Tavg) %>% median(na.rm = TRUE)

  message("Building plot")
  flush.console()

  dist_plot <- ggplot(hist_obs) +
    aes(x = Tavg, y = 0) +
    # today line (behind density curve)
    geom_vline(xintercept = tavg_now, colour = base_colour,
      linewidth = rel(1.25)) +
    # density curve
    stat_density_ridges(
      aes(fill = stat(quantile)),
      colour = NA,
      geom = "density_ridges_gradient",
      from = min(hist_obs$Tavg, na.rm = TRUE),
      to = max(hist_obs$Tavg, na.rm = TRUE),
      calc_ecdf = TRUE,
      quantiles = percentiles$frac_lower |> head(-1),
      quantile_lines = TRUE
      ) +
    # today marker line, again, but in front (and semi-transparent)
    geom_vline(xintercept = tavg_now, colour = base_colour,
      linewidth = rel(1.25), alpha = 0.35) +
    # today text (fully opaque)
    annotate_text_iihrn(
      x = tavg_now,
      y = Inf,
      vjust = -0.75,
      hjust = 1.1,
      label = paste0("TODAY:  ", tavg_now, "°C"),
      highlight = FALSE,
      size = 4,
      angle = 90) +
    # lines for 5th/95th percentiles
    # geom_vline(xintercept = hist_5p,  linetype = 2, colour = base_colour,
    #   alpha = 0.8) +
    # geom_vline(xintercept = hist_95p, linetype = 2, colour = base_colour,
    #   alpha = 0.8) +
    annotate_text_iihrn(
      x = hist_5p,
      y = 0,
      vjust = 1.75,
      hjust = -0.05,
      label = paste0("5th percentile:  ", round(hist_5p, 1), "°C"),
      highlight = FALSE,
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      x = hist_50p,
      y = 0,
      hjust = -0.05,
      label = paste0(
        "50th percentile: ", round(hist_50p, 1), "°C"),
      highlight = FALSE,
      size = 4,
      angle = 90,
      alpha = 0.9) +
    annotate_text_iihrn(
      x = hist_95p,
      y = 0,
      vjust = -0.75,
      hjust = -0.05,
      label = paste0("95th percentile:  ", round(hist_95p, 1), "°C"),
      highlight = FALSE,
      size = 4,
      angle = 90,
      alpha = 0.9) +
    scale_x_continuous(labels = scales::label_number(suffix = "°C")) +
    scale_y_continuous(expand = expansion(add = c(0, 0.015))) +
    scale_fill_manual(values = rating_colours, guide = guide_none()) +
    theme_iihrn() +
    theme(
      axis.title.y = element_blank(),
      axis.text.y = element_blank()) +
    labs(
      x = "Daily average temperature",
      y = NULL,
      title = paste0(
        station_label,
        " daily average temperatures\nfor the two weeks around ",
        format(date_now, format = "%d %B", tz = station_tz),
        " since ", record_start))

  message("Writing plot out to disk temporarily")
  flush.console()

  # write out to disk
  temp_path <- tempfile("dist-", fileext = ".png")
  ggsave(
    filename = temp_path,
    plot = dist_plot, bg = bg_colour_today,
    height = 4.5, width = 8, units = "in")

  message("Uploading plot to S3 bucket")
  flush.console()

  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "distribution",
      paste0("distribution-", station_id, ".png")),
    bucket = "isithot-data")

  message("All done!")
  flush.console()
  return()
}

#' Creates a plot of this year's ratings
#' 
#' @param obs_thisyear: this year's observations as a dataframe, from
#'   databackup/[id]-[year].csv. cols include date, percentile
#' @param station_id: The id of the station, for saving to s3.
#' @param station_tz: The tz of the station, for printing local date.
#' @param station_label: the station label
createHeatmapPlot <- function(obs_thisyear, station_id, station_tz, station_label) {

  message("Beginning function")
  flush.console()

  date_now <- Sys.time() |> as.Date(station_tz)

  # obs_thisyear comes as a JSON string when invoked externally rather
  # than through the console. we need to convert it manually
  if (is.character(obs_thisyear)) {
    message("De-serialising observations")
    flush.console()
    obs_thisyear <- fromJSON(obs_thisyear)
  }

  message("Validating arguments")
  flush.console()

  stopifnot(
    "Arg `obs_thisyear` should be a data frame"  = is.data.frame(obs_thisyear),
    "Arg `obs_thisyear` should include the columns `Date` and `Tavg`" =
      c("date", "percentile") %in% names(obs_thisyear) |> all(),
    "Arg `station_tz` should be length 1"    = length(station_tz) == 1,
    "Arg `station_label` should be length 1" = length(station_label) == 1,
    "Arg `station_tz` should be a string"    = is(station_tz, "character"),
    "Arg `station_label` should be a string" = is(station_label, "character"))

  message("Extracting observation day/month components")
  flush.console()

  # convert date (python sends unix epoch as ms; r uses days)
  # extract month and day from the date
  obs_thisyear |>
    filter(!is.na(date)) |>
    mutate(
      date = as.Date(date / 86400000, origin = as.Date("1970-01-01")),
      month = fct_rev(factor(month(date), labels = month.abb)),
      day = mday(date)) ->
  obs_thisyear_toplot

  # create an array of percentiles for plotting with image()
  month_names = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  percentileHeatmap_array <- array(dim = c(31,12))
  for (m in 1:month(date_now)) {
      month_data <- obs_thisyear_toplot %>% dplyr::filter(month == month_names[m]) %>% dplyr::pull(percentile)
      percentileHeatmap_array[,m][1:length(month_data)] <- month_data
  }

  message("Building plot")
  flush.console()

  # tempfile for saving plot
  temp_path <- tempfile("heatmap-", fileext = ".png")
  # Now plot the heatmap
  png(temp_path, width = 2400, height = 1060)
  par(mar = c(0.8,5,8,0.5) + 0.1, bg = '#dddddd', family = "Roboto Condensed")
  layout(mat = matrix(c(1,2), byrow = T, ncol = 2), widths = c(1, 0.075))
  cols <- rev(c('#b2182b','#ef8a62','#fddbc7','#f7f7f7','#d1e5f0','#67a9cf','#2166ac'))
  breaks <- c(0,0.05,0.2,0.4,0.6,0.8,0.95,1)
  na.df <- array(data = 1, dim = dim(percentileHeatmap_array))
  image(seq(1, 31), seq(1, 12), 
      percentileHeatmap_array[,ncol(percentileHeatmap_array):1]/100, 
      xaxt = "n", yaxt ="n",
      xlab = "", ylab = "", breaks = breaks, col = cols)
  title(paste(station_label, "percentiles for", year(date_now)), 
      cex.main = 4, line = 5.5, col = "#333333")
  axis(side = 3, at = seq(1, 31), lwd.ticks = 0, cex.axis = 2.3, font = 2)
  axis(side = 2, at = seq(12, 1), labels = month_names, las = 2, lwd.ticks = 0, cex.axis = 2.3, font = 2)
  text(expand.grid(1:31, 12:1), labels = percentileHeatmap_array, cex = 2.3)
  par(mar = c(0.8,0,8,30) + 0.1, bg = NA)
  colbar <- c(cols[1], rep(cols[2], 3), rep(cols[3], 4),rep(cols[4], 4), rep(cols[5], 4), rep(cols[6], 3), cols[7])
  colkey(col = colbar, clim = c(0, 1), at = breaks, side = 4, width = 6,
          labels = paste(breaks*100), cex.axis = 2.3)
  mtext('© isithotrightnow.com', side=3, line=6, at=9, cex=2)
  dev.off()

  message("Uploading plot to S3 bucket")
  flush.console()

  # upload to s3
  put_object(
    file = temp_path,
    object = file.path("www", "plots", "heatmap",
      paste0("heatmap-", station_id, ".png")),
    bucket = "isithot-data")

  message("All done!")
  flush.console()
  return()
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
