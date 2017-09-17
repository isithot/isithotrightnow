# is it hot right now
# stefan, mat and james

# app_functions.R

getHistoricalObs <- function() {
  # returns a list of dataframe of historical Tmax and Tmin 90p obs called Tmax and Tmin
  # Get Climatology data
  # Use Mat's pre-calculated Tmax 90th pc data
  SydObs.tmax90p.clim.raw <- read.csv("data/tmax90p_066062.csv", header = F,
                                      stringsAsFactors = F)
  names(SydObs.tmax90p.clim.raw) <- c("Month", "Day", "Tmax90p")
  SydObs.tmin90p.clim.raw <- read.csv("data/tmin90p_066062.csv", header = F,
                                      stringsAsFactors = F)
  names(SydObs.tmin90p.clim.raw) <- c("Month", "Day", "Tmin90p")
  return(list(Tmax = SydObs.tmax90p.clim.raw, Tmin = SydObs.tmin90p.clim.raw))
}

getCurrentObs <- function() {
  # Returns a data frame with latest 3 day half hourly obs called SydObs.df
  SydObs.data <- fromJSON("data/IDN60901.94768.json")
  # Create a dataframe with Date_time in first column and air_temp in second column
  date_time <- ymd_hms(SydObs.data$observations$data$local_date_time_full,
                       tz = "Australia/Sydney")
  air_temp <- SydObs.data$observations$data$air_temp
  # Now create the data frame
  SydObs.df <- data.frame(date_time, air_temp)
  return(SydObs.df)
}