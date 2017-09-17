# is it hot right now
# stefan, mat and james

# app_functions.R

getHistoricalObs <- function() {
  # returns a list of dataframe of historical Tmax and Tmin 90p obs called Tmax and Tmin
  # Get historical obs for Tmax and Tmin
  # Data must have columns:
  # Product.code	BOM.station.number	Year	Month	Day	Max(Min).temperature	Days.of.acumulation	Quality
  # The first two columns are not read in
  SydObs.Tmax <- read.csv("data/IDCJAC0010_066062_1800_Data.csv", header = T,
                          stringsAsFactors = F)[,-c(1,2)]
  SydObs.Tmin <- read.csv("data/IDCJAC0011_066062_1800_Data.csv", header = T,
                          stringsAsFactors = F)[,-c(1,2)]
  return(list(Tmax = SydObs.Tmax, Tmin = SydObs.Tmin))
}

calcHistPercentiles <- function(Obs, date = Sys.Date()) {
  # returns a list of tmax and tmin, each a vector of 6 elements, one for each percentile:
  # 5, 10, 40, 60, 90, 95
  if(missing(Obs)) stop("Error: Missing historical observations")
  if(missing(date)) warning("Warning: Date missing. Calculating percentiles for today's date")
  histPercentiles = lapply(Obs, FUN = calcPercentiles, date = date)
  histPercentiles$Tavg = apply(rbind(histPercentiles$Tmax, histPercentiles$Tmin), 2, mean)
  return(histPercentiles)
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