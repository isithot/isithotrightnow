library(ggplot2)
library(tibble)
library(aws.s3)

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

  if (bucket_ok) {
    tryCatch(
      {
        put_object(test_path, bucket = isithot_bucket,
          region = isithot_bucket_region)
        message <- "Plot saved and uploaded to S3."
      },
      error = {
        message <-
          "Plot saved. Bucket exists, but there was a problem uplaoding."
      })
  } else {
    message <- "Plot saved, but bucket does not exist."
  }

  return(list(message = message))

}

lambdr::start_lambda()