# is it hot right now
# stefan, mat and james

library(shiny)
library(ggplot2)
library(jsonlite)
library(lubridate)
library(dplyr)
library(readr)
library(RJSONIO)

# load functions from app_functions.R
source("app_functions_static.R")

# The algorithm
# --
# Take the maximum and minimum temperatures of the last 24h
# and average them to the the avg(Tmax,Tmin)
# then compare this Tavg with the climatology.
# We download daily Tmax and Tmin data from BOM,
# calculate 6 percentiles (0.05,0.1,0.4,0.6,0.9,0.95),
# and figure out which bin our daily Tmax,Tmin or Tavg 
# sits in.
# --

stationId = "IDN60901.94768"

# Get current half hourly data for the past 3 days
SydObs.df <- getCurrentObs(stationId)

# Let's first get the current month, day and current date_time
# Because we are averaging the max and min temperatures over the
# past 24h, the current date is the date 12h ago
current.date_time <- SydObs.df$date_time[13]
current.date <- ymd(substr(current.date_time, 1, 10))

# Calculate percentiles of historical data
SydHistObs <- getHistoricalObs(stationId, date = current.date)
histPercentiles <- calcHistPercentiles(Obs = SydHistObs)
# Now let's get the air_temp max and min over the past
# 24h and average them
Tmax.now <- max(SydObs.df$air_temp[1:48])
Tmin.now <- min(SydObs.df$air_temp[1:48])
# Note this is not a true average, just an average of the 
# max and min values
Tavg.now <- mean(c(Tmax.now, Tmin.now))
# 
message(paste('Updating answer based on: Tavg.now ', Tavg.now, ', histPercentiles ', histPercentiles[,"Tavg"], '\n'))


category.now <- as.character(cut(Tavg.now, breaks = c(-100,histPercentiles[,"Tavg"],100), 
                                 labels = c("bc","rc","c","a","h","rh","bh"),
                                 include.lowest = T, right = F))
# The -100 and 100 allow us to have the lowest and highest bins

isit_answer = switch(category.now, 
                     bc = 'Hell no!',
                     rc = 'Nope!',
                     c = 'No!',
                     a = 'No',
                     h = 'Yup',
                     rh = 'Yeah!',
                     bh = 'Hell yeah!')

isit_comment = switch(category.now,
                      bc = "Are you kidding?! It's bloody cold",
                      rc = "It's actually really cold",
                      c = "It's actually kinda cool",
                      a = "It's about average",
                      h = "It's warmer than average",
                      rh = "It's really hot!",
                      bh = "It's bloody hot!")

average.percent <- 100*round(ecdf(SydHistObs$Tavg)(Tavg.now),digits=2)

################################################################################################

SydHistObs$Date = ymd(paste(SydHistObs$Year, SydHistObs$Month, SydHistObs$Day, sep = '-'))

SydHistObs <- rbind(SydHistObs,
                    data.frame(Year = year(current.date), Month = month(current.date), Day = day(current.date),
                               Tmax = Tmax.now, Tmin = Tmin.now, Tavg = Tavg.now, Date = current.date))

TS.plot <- ggplot(data = SydHistObs, aes(x = Date, y = Tavg)) +
  ggtitle(
    paste0(
      'Daily average temperatures\nsince 1850 for ',
      format(current.date_time, format="%d %B"))) +
  xlab(NULL) + 
  ylab('Daily average temperature (°C)') + 
  geom_point(size = rel(2), colour = '#999999') +
  geom_line(size = 0.2, colour = '#CCCCCC') + 
  geom_point(aes(x = current.date, y = Tavg.now), colour = "firebrick",
             size = rel(5)) +
  geom_hline(aes(yintercept = histPercentiles[,"Tavg"][6]), linetype = 2,
             alpha = 0.5) +
  geom_hline(aes(yintercept = histPercentiles[,"Tavg"][1]), linetype = 2,
             alpha = 0.5) +
  geom_hline(aes(yintercept = median(SydHistObs$Tavg, na.rm = T)), linetype = 2,
             alpha = 0.5) +
  annotate("text", x = current.date, y = Tavg.now, vjust = -1.5,
           label = "TODAY", colour = 'firebrick', size = 4,
           family = 'Roboto Condensed', fontface = "bold") +
  annotate("text", x = current.date, y = Tavg.now, vjust = 2.5,
           label = paste0(Tavg.now,'°C'), colour = 'firebrick', size = 4,
           family = 'Roboto Condensed', fontface = "bold") + 
  annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
           y = histPercentiles[, "Tavg"][6], label = paste0("95th percentile:  ",round(histPercentiles[,"Tavg"][6],1),'°C'),
           alpha = 0.5, size = 4, hjust=0, vjust = -0.5,
           family = 'Roboto Condensed', fontface = "bold") + 
  annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
           y = histPercentiles[, "Tavg"][1], label = paste0("5th percentile:  ",round(histPercentiles[,"Tavg"][1],1),'°C'),
           alpha = 0.5, size = 4, hjust = 0, vjust = -0.5,
           family = 'Roboto Condensed', fontface = "bold") +
  # annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
  #   y = median(SydHistObs$Tavg), label = paste0("50TH PERCENTILE:  ",round(median(SydHistObs$Tavg)),'°C'),
  #   alpha = 0.5, size = 4, hjust = 0, vjust = -0.5,
  #   family = 'Roboto Condensed', fontface = "bold") +
  scale_x_date(
    breaks = ymd(paste0(
      seq(round(min(SydHistObs$Year)/10)*10,
          round(max(SydHistObs$Year)/10)*10, 20),
      "0101")),
    date_labels = '%Y') +
  theme_bw(base_size = 20, base_family = 'Roboto Condensed') +
  theme(panel.background = element_rect(fill = "transparent", colour = NA),
        plot.title = element_text(size = 18, face = "bold", hjust = 0.5,
                                  color = '#333333'),
        panel.grid.minor = element_blank(), panel.grid.major = element_blank(),
        plot.background = element_rect(fill = "transparent", colour = NA),
        panel.border = element_blank(),
        axis.line = element_line(),
        axis.text.x = element_text(family = 'Roboto Condensed', face = "bold"),
        axis.text.y = element_text(family = 'Roboto Condensed', face = "bold"),
        axis.title.y = element_text(family = 'Roboto Condensed', face = "bold",
                                    size = 16))

dist.plot <- ggplot(data = SydHistObs, aes(Tavg)) + 
  ggtitle(
    paste(
      'Distribution of daily average temperatures\nsince 1850 for',
      format(current.date_time, format="%d %B"))) +
  geom_density(adjust = 0.4, colour = '#999999', fill = '#999999') + 
  theme_bw(base_size = 20, base_family = 'Roboto Condensed') +
  theme(panel.background = element_rect(fill = "transparent", colour = NA),
        panel.grid.minor = element_blank(), panel.grid.major = element_blank(),
        plot.background = element_rect(fill = "transparent", colour = NA),
        panel.border = element_blank(),
        plot.title = element_text(family = 'Roboto Condensed', face = "bold",
                                  color = '#333333', size = 18, hjust = 0.5),
        axis.text.x = element_text(family = 'Roboto Condensed', face = "bold"),
        axis.title.x = element_text(family = 'Roboto Condensed', face = "bold",
                                    size = 16),
        axis.title.y = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank()) +
  geom_vline(xintercept = Tavg.now, colour = 'firebrick', size = rel(1.5)) +
  geom_vline(xintercept = median(SydHistObs$Tavg, na.rm = T), linetype = 2, alpha = 0.5) + 
  geom_vline(
    xintercept = histPercentiles[,"Tavg"][1], linetype = 2, alpha = 0.5) +
  geom_vline(
    xintercept = histPercentiles[,"Tavg"][6], linetype = 2, alpha = 0.5) + 
  scale_y_continuous(expand = c(0,0)) +
  xlab("Daily average temperature (°C)") + 
  # annotate("text", x = median(SydHistObs$Tavg), y = Inf, vjust = -0.75,
  #   hjust=1.1,label = "50TH PERCENTILE", size = 4, angle = 90, alpha = 0.5,
  #   family = 'Roboto Condensed', fontface = "bold") +
  annotate("text", x = histPercentiles[,"Tavg"][1], y = Inf, vjust = -0.75,
           hjust=1.1,label = paste0("5th percentile:  ",round(histPercentiles[,"Tavg"][1],1),'°C'), 
           size = 4, angle = 90, alpha = 0.5, family = 'Roboto Condensed', fontface = "bold") +
  annotate("text", x = histPercentiles[,"Tavg"][6], y = Inf, vjust = -0.75,
           hjust=1.1,label = paste0("95th percentile:  ",round(histPercentiles[,"Tavg"][6],1),'°C'),
           size = 4, angle = 90, alpha = 0.5, family = 'Roboto Condensed', fontface = "bold") +
  annotate("text", x = Tavg.now, y = Inf, vjust = -0.75, hjust = 1.1,
           label = paste0("TODAY:  ",Tavg.now,'°C'), colour = 'firebrick', size = 4, angle = 90, alpha = 1,
           family = 'Roboto Condensed', fontface = "bold")

# Save plots in www/output/<station ID>/
ggsave(filename = paste0("srv/isithotrightnow/www/output/", stationId, "/ts_plot.png"), 
       plot = TS.plot,
       height = 4.5, width = 8, units = "in", device = "png")

ggsave(filename = paste0("srv/isithotrightnow/www/output/", stationId, "/density_plot.png"), 
       plot = dist.plot,
       height = 4.5, width = 8, units = "in", device = "png")

# Save JSON file
statsList <- vector(mode = "list", length = 4)
  names(statsList) <- c("isit_answer", "isit_comment", "isit_current", "isit_average")
  statsList[[1]] <- isit_answer
  statsList[[2]] <- isit_comment
  statsList[[3]] <- Tavg.now
  statsList[[4]] <- average.percent

exportJSON <- toJSON(statsList)
write(exportJSON, file = "srv/isithotrightnow/www/output/IDN60901.94768/stats.json")
