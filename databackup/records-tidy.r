# A heatmap of thresholds over the past 30 days
library(ggplot2)
library(jsonlite)
library(lubridate)
library(tibble)
library(dplyr)
library(tidyr)
library(readr)
library(RJSONIO)
library(xml2)
library(purrr)
library(plot3D)
select = dplyr::select
filter = dplyr::filter

###################################
# USER INPUT
# Date from which records-tidy.r 
# is to be run. 
# Format: yyyymmdd
# Note that end date will be either current date -1 
# or the end of the year. To run the next year, 
# change start_date to the first of the next year
# and rerun records-tidy.py
start_date <- ymd("20180701")
###################################

# set base path depending on whether this is run on the server
# (the here package would be a better idea for this!)
fullpath <- if_else(Sys.info()["user"] == "ubuntu",
  "/srv/isithotrightnow/", "./")

current_date <- with_tz(Sys.Date(), tzone = "Australia/Sydney") - 1
current_year <- year(start_date)
end_date <- if_else(year(current_date) != current_year, 
                   ymd(paste0(current_year,"1231")),
                   current_date)
dates <- paste0(
  format(seq(start_date, end_date, by = 1), "%y%m%d"),
  "-all.csv")

# load functions from app_functions.R
source(paste0(fullpath, "app_functions_static.R"))

# function for creating an array of categories based on an array of percentiles for a particular year
get_category_array <- function(heatmap_array) {
  if (!all.equal(dim(heatmap_array), c(31,12))) {
    stop("heatmap_array does not have the right dimensions (31,12)")
  }
  category_array <- array(dim = dim(heatmap_array))
  for (i in 1:31) {
    for (j in 1:12) {
      category_array[i, j] <- 
        as.character(cut(heatmap_array[i, j],
                         breaks = c(-100, 5, 10, 40, 60, 90, 95, 100),
                         labels = c("bc","rc","c","a","h","rh","bh"),
                         include.lowest = T, right = F))
    }
  }
  return(category_array)
}

# get list of station ids to process from locations.json
station_set <- fromJSON(paste0(fullpath, "www/locations.json"))
for (i in 1:length(station_set)) {
  station_set[[i]]$percentileHeatmap_array <- array(data = read_csv(paste0(fullpath,"databackup/", station_set[[i]]["id"], 
                                                                           "-", current_year, ".csv"))[["percentile"]],
                                                    dim = c(31,12))
  station_set[[i]]$categoryHeatmap_array <- get_category_array(heatmap_array = station_set[[i]]$percentileHeatmap_array)
}

# run this loop to calculate historical percentiles since the start of the year
# In the future this loop will be replaced by calculation only for the previous
# day and the data will be saved in an R dataframe
for (d in 1:length(dates)) {
  file <- dates[d]
  date <- ymd(substr(file, 1, 6))
  print(file)
  daydata <- read_csv(paste0(fullpath,"databackup/", file))
  daydata <- daydata %>% mutate(tavg = (tmax + tmin) / 2)

  for (i in 1:length(station_set))
  {
    
    # Calculate percentiles of historical data
    HistObs <- getHistoricalObs(station_set[[i]]$id, date = date, window = 7)
    histPercentiles <- calcHistPercentiles(Obs = HistObs)
    
    Tavg.now <- daydata[which(as.numeric(daydata$station_id) == as.numeric(station_set[[i]]$id)), ]$tavg
    
    # don't include the median when binning obs against the climate!
    # (the -100 and 100 allow us to have the lowest and highest bins)
    station_set[[i]]$categoryHeatmap_array[day(date), month(date)] <-
      as.character(cut(Tavg.now,
        breaks = c(
          -100,
          histPercentiles[!rownames(histPercentiles) %in% "50%", "Tavg"],
          100),
        labels = c("bc","rc","c","a","h","rh","bh"),
        include.lowest = T, right = F))
    
    station_set[[i]]$percentileHeatmap_array[day(date), month(date)] <-
      100 * round(ecdf(HistObs$Tavg)(Tavg.now), digits = 2)
  }
}

message("Percentiles calculated; tidying up")

# get the nested list structure into a nested data frame
# (previously in heatmap-tidy.r)
tidy_data =
  station_set %>%
  {
    data_frame(
    id   = map_chr(., pluck, 'id'),
    # name = map_chr(., pluck, 'name'),
    percentiles =
      map(., pluck, 'percentileHeatmap_array') %>%
      map(as_tibble) %>%
      map(set_names, 1:12) %>%
      map(rownames_to_column, 'day') %>%
      map(gather, key = 'month', value = 'percentile', -day),
    categories =
      map(., pluck, 'categoryHeatmap_array') %>%
      map(as_tibble) %>%
      map(set_names, 1:12) %>%
      map(rownames_to_column, 'day') %>%
      map(gather, key = 'month', value = 'category', -day))
  } %>%
  # now unnest, drop the duplicated columns and then nest by station
  unnest() %>%
  mutate(date = as.Date(paste('2018', month, day, sep = '-'))) %>%
  select(id, date, percentile) %>%
  mutate(percentile = as.integer(percentile)) %>%
  nest(-id)

message("And finally, writing out!")

# write 'em out to disk  
walk2(tidy_data$data, tidy_data$id,
  ~ write_csv(.x, paste0(fullpath, "databackup/", .y, '-', current_year, '_test.csv')))
