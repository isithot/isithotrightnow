# is it hot right now
# stefan, mat and james

# app_functions.R

getHistoricalObs <- function(date = Sys.Date()) {
  # returns a dataframe of historical Tmax, Tmin and Tavg obs
  # Get historical obs for Tmax and Tmin
  # Data must have columns:
  # Product.code	BOM.station.number	Year	Month	Day	Max(Min).temperature	Days.of.acumulation	Quality
  # The first two columns are not read in
  if(missing(date)) warning("Warning: Date missing. Calculating percentiles for today's date")
  SydObs.Tmax <- read.csv("data/IDCJAC0010_066062_1800_Data.csv", header = T,
                          stringsAsFactors = F)[,c(3:6)]
  SydObs.Tmin <- read.csv("data/IDCJAC0011_066062_1800_Data.csv", header = T,
                          stringsAsFactors = F)[,c(3:6)]
  SydObs <- merge(SydObs.Tmax, SydObs.Tmin, all = TRUE)
  names(SydObs)[4:5] <- c("Tmax", "Tmin")
  SydObs = mutate(SydObs, Tavg = (Tmax + Tmin)/2)
  return(SydObs %>% filter(Month == month(date), Day == day(date)))
}

calcHistPercentiles <- function(Obs) {
  # returns a list of Tmax, Tmin and Tavg, each element being a vector of 6 percentiles:
  # 5, 10, 40, 60, 90, 95
  if(missing(Obs)) stop("Error: Missing historical observations")
  return(sapply(SydHistObs %>% select(-c(Year, Month, Day)), 
                FUN = quantile, probs = c(0.05,0.1,0.4,0.6,0.9,0.95)))
}

calcPercentiles <- function(obsSingleVar, date) {
  # calculates percentiles and returns a vector
  return(quantile(obsSingleVar[which(obsSingleVar$Day == day(date) & 
                                    obsSingleVar$Month == month(date)),4],
           probs = c(0.05, 0.1, 0.4, 0.6, 0.9, 0.95)))
  # the column index 4 in the above line is because Tmax/Tmin should be the 4th column
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
