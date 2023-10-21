library(lubridate)
library(tidyverse)
library(jsonlite)
library(plot3D)

# read csv as data frame
obs_thisyear <- read.csv("~/Downloads/066214-2023.csv", colClasses = c("date" = "Date"))
station_id <- "066214"
station_label <- "Sydney Obs Hill"
station_tz <- "Australia/Sydney"

date_now <- Sys.time() |> as.Date(station_tz)

obs_thisyear |>
    filter(!is.na(date)) |>
    mutate(
    #   date = as.Date(date / 86400000, origin = as.Date("1970-01-01")),
      month = fct_rev(factor(month(date), labels = month.abb)),
      day = mday(date)) ->
  obs_thisyear_toplot

# create an empty array to store the daily percentiles for this year
percentileHeatmap_array <- array(dim = c(31,12))
for (m in 1:month(date_now)) {
    month_data <- obs_thisyear_toplot %>% dplyr::filter(month == month.names[m]) %>% dplyr::pull(percentile)
    percentileHeatmap_array[,m][1:length(month_data)] <- month_data
}

# Create the plots
temp_path <- tempfile("timeseries-", fileext = ".png")

png(temp_path, width = 2400, height = 1060)
par(mar = c(0.8,5,8,0.5) + 0.1, bg = '#dddddd', family = "Roboto Condensed")
layout(mat = matrix(c(1,2), byrow = T, ncol = 2), widths = c(1, 0.075))
cols <- rev(c('#b2182b','#ef8a62','#fddbc7','#f7f7f7','#d1e5f0','#67a9cf','#2166ac'))
breaks <- c(0,0.05,0.2,0.4,0.6,0.8,0.95,1)
na.df <- array(data = 1, dim = dim(percentileHeatmap_array))
#image(seq(1, 31), seq(1, 12), na.df, xaxt = "n", yaxt ="n", 
#xlab = "", ylab = "", col = 'white')
image(seq(1, 31), seq(1, 12), 
    percentileHeatmap_array[,ncol(percentileHeatmap_array):1]/100, 
    xaxt = "n", yaxt ="n",
    xlab = "", ylab = "", breaks = breaks, col = cols)
title(paste(station_label, "percentiles for", year(date_now)), 
    cex.main = 4, line = 5.5, col = "#333333")
axis(side = 3, at = seq(1, 31), lwd.ticks = 0, cex.axis = 2.3, font = 2)
axis(side = 2, at = seq(12, 1), labels = month.names, las = 2, lwd.ticks = 0, cex.axis = 2.3, font = 2)
text(expand.grid(1:31, 12:1), labels = percentileHeatmap_array, cex = 2.3)
par(mar = c(0.8,0,8,30) + 0.1, bg = NA)
colbar <- c(cols[1], rep(cols[2], 3), rep(cols[3], 4),rep(cols[4], 4), rep(cols[5], 4), rep(cols[6], 3), cols[7])
colkey(col = colbar, clim = c(0, 1), at = breaks, side = 4, width = 6,
        labels = paste(breaks*100), cex.axis = 2.3)
mtext('© isithotrightnow.com', side=3, line=6, at=9, cex=2)
dev.off()
