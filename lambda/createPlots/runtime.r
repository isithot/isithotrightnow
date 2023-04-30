library(ggplot2)
library(tibble)
library(aws.s3)

source("util.r")

# defaultFunc: just prints a message. here as a default so that you can verify
# your lambda config (and to make it clear if you've forgotten to override
# the entrypoint)
defaultFunc <- function() {
  return(list(message = paste(
    "This is the default function for the Is it hot right now R runtime.",
    "If you're configuring a new Lambda function, you should override the",
    "Lambda's entrypoint to be the name of one of the other functions in this",
    "file.")))
}

createTimeseriesPlot <- function() {

  # things we need:
  # - HistObs: data frame of historical obs, including cols:
  #    - Year, Month, Day, Tmax, Tmin, Tavg, Date, current.date, Tavg.now
  # - histPercentiles: array? dims include 5%, 95%, Tavg
  # - this_station: cols record_start_date, label

  TS.plot <-
    ggplot(data = HistObs) +
    aes(x = Date, y = Tavg) +
    # james - i don't understand what these two geoms are for
    # geom_line(size = 0.0, colour = '#CCCCCC') + 
    # geom_point(size = rel(1.5), colour = "#999999", alpha = 0.5) +
    geom_smooth(method = lm, se = FALSE, col = "gray60", size = 0.5) + 
    geom_point(
      aes(x = current.date, y = Tavg.now),
      colour = iihrn_colour,
      size = rel(5)) +
    geom_hline(
      aes(yintercept = histPercentiles["95%", "Tavg"]),
      linetype = 2,
      alpha = 0.5) +
    geom_hline(
      aes(yintercept = histPercentiles["5%", "Tavg"]),
      linetype = 2,
      alpha = 0.5) +
    scale_x_date(
      date_breaks = "20 years",
      date_labels = "%Y") +
    scale_y_continuous(
      # james - the limits can be handled by the `expand` argument, but the
      # default is probably fine
      breaks = seq(0, 100, by = 5)) +
    annotate_text_iihrn(
      x = current.date,
      y = Tavg.now,
      vjust = -1.5,
      label = "TODAY",
      colour = iihrn_colour) +
    annotate_text_iihrn(
      x = current.date,
      y = Tavg.now,
      vjust = 2.5,
      label = paste0(Tavg.now, "°C"), hl = TRUE) +
    # james - perhaps we should consider replacing the dotted lines with blocks
    # of colour that are the same as our category colours?
    annotate_text_iihrn(
      x = -Inf,
      y = histPercentiles["95%", "Tavg"],
      label = paste0(
        "95th percentile: ",
        round(histPercentiles["95%", "Tavg"], 1),
        "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = -Inf,
      y = histPercentiles["5%", "Tavg"],
      label = paste0(
        "5th percentile: ",
        round(histPercentiles["5%", "Tavg"], 1),
        "°C"),
      hjust = "inward",
      vjust = -0.5) +
    annotate_text_iihrn(
      x = -Inf,
      y = histPercentiles["50%", "Tavg"],
      label = paste0("Trend: +", round(trend * 365 * 100, 1), "°C/ century"),
      hjust = "inward",
      vjust = -0.5) +
    theme_iihrn() +
    theme(
      axis.line = element_line(),
      axis.text.y = element_text(face = "bold"),
      axis.title.y = element_text(face = "bold", size = rel(0.8))
    ) +
    labs(
      title = paste0(
        this_station[["label"]],
        " daily average temperatures\nfor the two weeks around ",
        format(current.date, format = "%d %B", tz = this_station[["tz"]])),
      x = NULL,
      y = "Daily average temperature (°C)")

}

# createTestPlot: our "test" plotting function. generates a plot from random
# data, saves it to disk, and then uploads it to S3. base other plotting
# functions off this
createTestPlot <- function() {

  # generate some test data
  some_numbers <- tibble(
    n = runif(8, min = 1, max = 12),
    x = toupper(letters[seq_along(n)]))

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