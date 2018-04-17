# A heatmap of thresholds over the past 30 days


library(ggplot2)
library(jsonlite)
library(lubridate)
library(dplyr)
library(readr)
library(RJSONIO)
library(xml2)
library(purrr)
library(plot3D)

if (Sys.info()["user"] == "ubuntu")
{
  # running on the server
  fullpath = "/srv/isithotrightnow/"
  dates <- seq(ymd("20180101"), Sys.Date(), 1)
} else {
  # testing locally
  fullpath = "./"
  dates <- seq(ymd("20180101"), Sys.Date() - 1, 1)
}


# load functions from app_functions.R
source(paste0(fullpath, "app_functions_static.R"))

# get list of station ids to process from locations.json
station_set <- fromJSON(paste0(fullpath, "www/locations.json"))
for (i in 1:length(station_set)) {
  station_set[[i]]$percentileHeatmap_array <- array(dim = c(31,12))
  station_set[[i]]$categoryHeatmap_array <- array(dim = c(31,12))
}

# Run this loop to calculate historical percentiles since the start of the year
# In the future this loop will be replaced by calculation only for the previous
# day and the data will be saved in an R dataframe
for (d in 1:length(dates)) {
  date <- dates[d]
  file <- paste0(substr(year(date), 3, 4), sprintf("%02d", month(date)), sprintf("%02d", day(date)), "-all.csv")
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
  png(paste0(fullpath,"www/output/",station_set[[i]]$id,"/heatmap.png"), width = 2400, height = 1060)
  par(mar = c(0.8,5,8,0.5) + 0.1, bg = NA, family = "Roboto Condensed")
  layout(mat = matrix(c(1,2), byrow = T, ncol = 2), widths = c(1, 0.075))
  cols <- rev(c('#b2182b','#ef8a62','#fddbc7','#f7f7f7','#d1e5f0','#67a9cf','#2166ac'))
  breaks <- c(0,0.05,0.2,0.4,0.6,0.8,0.95,1)
  month.names = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  na.df <- array(data = 1, dim = dim(station_set[[i]]$percentileHeatmap_array))
  #image(seq(1, 31), seq(1, 12), na.df, xaxt = "n", yaxt ="n", 
        #xlab = "", ylab = "", col = 'white')
  image(seq(1, 31), seq(1, 12), 
        station_set[[i]]$percentileHeatmap_array[,ncol(station_set[[i]]$percentileHeatmap_array):1]/100, 
        xaxt = "n", yaxt ="n",
        xlab = "", ylab = "", breaks = breaks, col = cols)
  title(paste(station_set[[i]]$label, "percentiles for 2018"), 
        cex.main = 4, line = 5.5, col = "#333333")
  axis(side = 3, at = seq(1, 31), lwd.ticks = 0, cex.axis = 2.3)
  axis(side = 2, at = seq(12, 1), labels = month.names, las = 2, lwd.ticks = 0, cex.axis = 2.3)
  text(expand.grid(1:31, 12:1), labels = station_set[[i]]$percentileHeatmap_array, cex = 2.3)
  par(mar = c(0.8,0,8,30) + 0.1, bg = NA)
  colbar <- c(cols[1], rep(cols[2], 3), rep(cols[3], 4),rep(cols[4], 4), rep(cols[5], 4), rep(cols[6], 3), cols[7])
  colkey(col = colbar, clim = c(0, 1), at = breaks, side = 4, width = 6,
         labels = paste(breaks*100), cex.axis = 2.3)
  dev.off()
}


