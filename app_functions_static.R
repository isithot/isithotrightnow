# is it hot right now
# stefan, mat and james

# app_functions.R

monthDay <- function(date) {
  if(missing(date)) stop("Error: Date missing in monthDay()")
  return(sprintf("%04d", month(date)*100 + day(date))) #month(date)*100 + day(date))
}

getHistoricalObs <- function(station_id, date = Sys.Date(), window = 7) {
  # returns a dataframe of historical Tmax, Tmin and Tavg obs for the date provided
  # raw csv data must have columns:
  # Product.code	BOM.station.number	Year	Month	Day	Max(Min).temperature	Days.of.acumulation	Quality
  # The first two columns are not read in
  if(missing(station_id)) stop("Error: Station ID missing")
  if(missing(date)) warning("Warning: Date missing. Calculating percentiles for today's date")
  if(missing(window)) warning("Warning: Window missing. Getting historical obs over +/- 7 day window")
  # Read historical obs
  HistObs.Tmax <- read.table(paste0(fullpath,"data/acorn.sat.maxT.", station_id, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmax"),
                            na.strings = "99999.9")
  HistObs.Tmin <- read.table(paste0(fullpath,"data/acorn.sat.minT.", station_id, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmin"),
                            na.strings = "99999.9")
  HistObs <- merge(HistObs.Tmax, HistObs.Tmin, all = TRUE)
  HistObs$Year <- as.integer(substr(HistObs$Date,1,4))
  HistObs$Month <- as.integer(substr(HistObs$Date,5,6))
  HistObs$Day <- as.integer(substr(HistObs$Date,7,8))
  # Calculate averages
  HistObs = HistObs %>% mutate(Tavg = (Tmax + Tmin)/2, 
                           monthDay = monthDay(ymd(paste(Year, Month, Day))))
  window_dates <- seq(date - window, date + window, by = 1)
  return(
    HistObs %>%
    dplyr::filter(monthDay %in% monthDay(window_dates)) %>%
    select(-monthDay))
}

calcHistPercentiles <- function(Obs) {
  # returns a dataframe with columns Tmax, Tmin and Tavg, each row refering to the 6 percentiles:
  # 5, 10, 40, 60, 90, 95
  if(missing(Obs)) stop("Error: Missing historical observations")
  return(sapply(Obs %>% select(-c(Year, Month, Day)), 
                FUN = quantile, probs = c(0.05,0.1,0.4,0.6,0.9,0.95), na.rm = T))
}

getCurrentObs <- function(req_station_id) {
  # Returns a data frame with the max and min temps reported by the station
  return(
    read_csv(
      paste0(fullpath, "data/latest/latest-all.csv"),
      col_types = cols(
        tmax = col_double(),
        tmin = col_double(),
        .default = col_character())) %>%
    dplyr::filter(station_id == req_station_id) %>%
    select(tmax, tmin) %>%
    print()
  )
}
