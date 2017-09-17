# is it hot right now
# stefan, mat and james

# app_functions.R

getHistoricalObs <- function () {
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