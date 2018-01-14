# is it hot right now
# stefan, mat and james

# app_functions.R


getHistoricalObs <- function(stationId, date = Sys.Date()) {
  # returns a dataframe of historical Tmax, Tmin and Tavg obs for the date provided
  # raw csv data must have columns:
  # Product.code	BOM.station.number	Year	Month	Day	Max(Min).temperature	Days.of.acumulation	Quality
  # The first two columns are not read in
  if(missing(stationId)) stop("Error: Station ID missing")
  if(missing(date)) warning("Warning: Date missing. Calculating percentiles for today's date")
  SydObs.Tmax <- read.table(paste0(fullpath,"data/acorn.sat.maxT.", stationId, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmax"),
                            na.strings = "99999.9")
  SydObs.Tmin <- read.table(paste0(fullpath,"data/acorn.sat.minT.", stationId, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmin"),
                            na.strings = "99999.9")
  SydObs <- merge(SydObs.Tmax, SydObs.Tmin, all = TRUE)
  SydObs$Year <- as.integer(substr(SydObs$Date,1,4))
  SydObs$Month <- as.integer(substr(SydObs$Date,5,6))
  SydObs$Day <- as.integer(substr(SydObs$Date,7,8))
  SydObs = mutate(SydObs, Tavg = (Tmax + Tmin)/2)
  return(SydObs %>% filter(Month == month(date), Day == day(date)))
}

calcHistPercentiles <- function(Obs) {
  # returns a dataframe with columns Tmax, Tmin and Tavg, each row refering to the 6 percentiles:
  # 5, 10, 40, 60, 90, 95
  if(missing(Obs)) stop("Error: Missing historical observations")
  return(sapply(Obs %>% select(-c(Year, Month, Day)), 
                FUN = quantile, probs = c(0.05,0.1,0.4,0.6,0.9,0.95), na.rm = T))
}

getCurrentObs <- function(stationId) {
  # Returns a data frame with latest 3 day half hourly obs called SydObs.df
  SydObs.data <- read_csv(file = paste0(fullpath,"data/", stationId, ".axf"), skip = 19)[,c(6,19)]
  # Create a dataframe with Date_time in first column and air_temp in second column
  date_time <- ymd_hms(SydObs.data$`local_date_time_full[80]`,
                       tz = "Australia/Sydney")
  air_temp <- SydObs.data$air_temp
  # Now create the data frame
  SydObs.df <- data.frame(date_time, air_temp)
  return(SydObs.df)
}
