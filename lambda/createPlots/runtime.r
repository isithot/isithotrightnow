library(ggplot2)
library(tibble)
library(aws.s3)

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