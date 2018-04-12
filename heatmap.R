# A heatmap of thresholds over the past 30 days


library(ggplot2)
library(jsonlite)
library(lubridate)
library(dplyr)
library(readr)
library(RJSONIO)
library(xml2)
library(purrr)

if (Sys.info()["user"] == "ubuntu")
{
  # running on the server
  fullpath = "/srv/isithotrightnow/"
} else {
  # testing locally
  fullpath = "./"
}


# load functions from app_functions.R
source(paste0(fullpath, "app_functions_static.R"))

dates <- seq(ymd("20180101"), Sys.Date() - 1, 1)

# get list of station ids to process from locations.json
station_set <- fromJSON(paste0(fullpath, "www/locations.json"))
for (i in 1:length(station_set)) {
  station_set[[i]]$percentileHeatmap_array <- array(dim = c(31,12))
  station_set[[i]]$categoryHeatmap_array <- array(dim = c(31,12))
}

for (d in 1:length(dates)) {
  date <- dates[d]
  file <- paste0(substr(year(date), 3, 4), sprintf("%02d", month(date)), sprintf("%02d", day(date)), "-all.csv")
  print(file)
  daydata <- read_csv(paste0("databackup/", file))
  daydata <- daydata %>% mutate(tavg = (tmax + tmin) / 2)
  
  for (i in 1:length(station_set))
  {
    
    # Calculate percentiles of historical data
    HistObs <- getHistoricalObs(station_set[[i]]$id, date = date, window = 7)
    histPercentiles <- calcHistPercentiles(Obs = HistObs)
    
    Tavg.now <- daydata[which(as.numeric(daydata$station_id) == as.numeric(station_set[[i]]$id)), ]$tavg
    
    # don't include the median when binning obs against the climate!
    station_set[[i]]$categoryHeatmap_array[day(date), month(date)] <- as.character(cut(Tavg.now,
                                                                                       breaks =
                                                                                         c(-100,
                                                                                           histPercentiles[!rownames(histPercentiles) %in% "50%", "Tavg"],
                                                                                           100), 
                                                                                       labels = c("bc","rc","c","a","h","rh","bh"),
                                                                                       include.lowest = T, right = F))
    # The -100 and 100 allow us to have the lowest and highest bins
    
    station_set[[i]]$percentileHeatmap_array[day(date), month(date)] <- 100*round(ecdf(HistObs$Tavg)(Tavg.now),digits=2)
    
  }

}

for (i in 1:length(station_set)) {
  par(mar = c(0,3,5,0.5) + 0.1)
  cols <- rev(c('#b2182b','#ef8a62','#fddbc7','#f7f7f7','#d1e5f0','#67a9cf','#2166ac'))
  breaks <- c(0,0.05,0.2,0.4,0.6,0.8,0.95,1)
  month.names = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  na.df <- array(data = 1, dim = dim(station_set[[i]]$percentileHeatmap_array))
  image(seq(1, 31), seq(1, 12), na.df, xaxt = "n", yaxt ="n", 
        xlab = "", ylab = "", col = 'gray')
  title(station_set[[i]]$label, cex.main = 2, line = 3.5)
  image(seq(1, 31), seq(1, 12), 
        station_set[[i]]$percentileHeatmap_array[,ncol(station_set[[i]]$percentileHeatmap_array):1]/100, 
        xaxt = "n", yaxt ="n", add = T,
        xlab = "", ylab = "", breaks = breaks, col = cols)
  axis(side = 3, at = seq(1, 31),lwd.ticks = 0, )
  axis(side = 2, at = seq(12, 1), labels = month.names, las = 2, lwd.ticks = 0)
  text(expand.grid(1:31, 12:1), labels = station_set[[i]]$percentileHeatmap_array)
}


dummy.data <- rnorm(30, mean = 0.60, sd = 0.4)
dummy.data[which(dummy.data > 1.0)] <- 1.0

image(matrix(dummy.data, ncol = 1), xaxt = "n", yaxt = "n")
