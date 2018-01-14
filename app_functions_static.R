# is it hot right now
# stefan, mat and james

# app_functions.R

monthDay <- function(date) {
  if(missing(date)) stop("Error: Date missing in monthDay()")
  return(sprintf("%04d", month(date)*100 + day(date))) #month(date)*100 + day(date))
}

getHistoricalObs <- function(stationId, date = Sys.Date()) {
  # returns a dataframe of historical Tmax, Tmin and Tavg obs for the date provided
  # raw csv data must have columns:
  # Product.code	BOM.station.number	Year	Month	Day	Max(Min).temperature	Days.of.acumulation	Quality
  # The first two columns are not read in
  if(missing(stationId)) stop("Error: Station ID missing")
  if(missing(date)) warning("Warning: Date missing. Calculating percentiles for today's date")
  SydObs.Tmax <- read.csv(paste0(fullpath,"data/", stationId, "_TMAX.csv"), header = T,
                          stringsAsFactors = F)[,c(3:6)]
  SydObs.Tmin <- read.csv(paste0(fullpath,"data/", stationId, "_TMIN.csv"), header = T,
                          stringsAsFactors = F)[,c(3:6)]
  SydObs <- merge(SydObs.Tmax, SydObs.Tmin, all = TRUE)
  names(SydObs)[4:5] <- c("Tmax", "Tmin")
  SydObs = SydObs %>% mutate(Tavg = (Tmax + Tmin)/2, 
                             monthDay = monthDay(ymd(paste(Year, Month, Day))))
  dates <- seq(date - 7, date + 7, by = 1)
  return(SydObs %>% filter(monthDay %in% monthDay(dates)) %>% select(-monthDay))
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
