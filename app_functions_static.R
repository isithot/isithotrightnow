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
  SydObs.Tmax <- read.table(paste0(fullpath,"data/acorn.sat.maxT.", station_id, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmax"),
                            na.strings = "99999.9")
  SydObs.Tmin <- read.table(paste0(fullpath,"data/acorn.sat.minT.", station_id, ".daily.txt"),
                            header = FALSE, skip = 1,
                            col.names = c("Date","Tmin"),
                            na.strings = "99999.9")
  SydObs <- merge(SydObs.Tmax, SydObs.Tmin, all = TRUE)
  SydObs$Year <- as.integer(substr(SydObs$Date,1,4))
  SydObs$Month <- as.integer(substr(SydObs$Date,5,6))
  SydObs$Day <- as.integer(substr(SydObs$Date,7,8))
  # SydObs = mutate(SydObs, Tavg = (Tmax + Tmin)/2)
  SydObs = SydObs %>% mutate(Tavg = (Tmax + Tmin)/2, 
                           monthDay = monthDay(ymd(paste(Year, Month, Day))))
  window_dates <- seq(date - window, date + window, by = 1)

  return(
    SydObs %>%
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

getCurrentObs <- function(station_id) {
  # Returns a data frame with the max and min temps reported by the station

  # infer the state from the station id
  region_code <- as.integer(substr(station_id, 2, 3))
  state <- case_when(
    between(region_code, 1, 13) ~ "wa",
    between(region_code, 14, 15) ~ "nt",
    between(region_code, 16, 26) ~ "sa",
    between(region_code, 27, 45) ~ "qld",
    between(region_code, 46, 75) ~ "nsw",
    between(region_code, 76, 90) ~ "vic",
    between(region_code, 91, 99) ~ "tas",
    TRUE ~ "err")
  if (state == "err" | state == "")
    stop ("Invalid station ID")

  # get the current max and min from the xml file
  # TODO - is there an edge case that requires us to look at the las ttwo days?
  obs_data <-
    read_xml(paste0(fullpath, "data/latest/latest-", state, ".xml")) %>%
    xml_find_first(paste0("//station[@bom-id='", station_id, "']"))

  # note: there's code here tte also include max/min timestamps
  # (if we need them later)
  return(
    data.frame(
      # tmax_time = obs_data %>%
      #   xml_find_first("//element[@type='maximum_air_temperature']") %>%
      #   xml_attr("time-local"),
      tmax = obs_data %>%
        xml_find_first("//element[@type='maximum_air_temperature']") %>%
        xml_text() %>%
        as.numeric(),
      # tmin_time = obs_data %>%
      #   xml_find_first("//element[@type='minimum_air_temperature']") %>%
      #   xml_attr("time-local"),
      tmin = obs_data %>%
        xml_find_first("//element[@type='minimum_air_temperature']") %>%
        xml_text() %>%
        as.numeric())
  )
}
