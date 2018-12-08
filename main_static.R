# By Mat Lipson, Steefan Contractor and James Goldie.
# © 2018 under the MIT licence. Data from the Bureau of Meteorology.

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
} else {
  # testing locally
  fullpath = "./"
}

# load functions from app_functions.R
source(paste0(fullpath, "app_functions_static.R"))

# get list of station ids to process from locations.json
station_set <- fromJSON(paste0(fullpath, "www/locations.json"))

for (this_station in station_set)
{
  # The algorithm
  # --
  # Take the maximum and minimum temperatures reported from the last
  # daytime and nighttime periods and average them.
  # Then compare this Tavg with the climatology.
  # We download daily Tmax and Tmin data from BOM,
  # calculate 6 percentiles (0.05,0.1,0.4,0.6,0.9,0.95),
  # and figure out which bin our daily Tmax,Tmin or Tavg 
  # sits in.
  # --

  dir.create(paste0(fullpath, "www/output/", this_station[["id"]]),
    showWarnings = FALSE)

  # Get current max and min temperatures for this_station
  CurrObs.df <- getCurrentObs(this_station[["id"]])
  current.date_time <- Sys.time()
  current.date <- current.date_time %>% as.Date(tz = this_station[["tz"]])

  # Calculate percentiles of historical data
  HistObs <- getHistoricalObs(this_station[["id"]], date = current.date, window = 7)
  histPercentiles <- calcHistPercentiles(Obs = HistObs)

  # Now let's get the air_temp max and min over the past
  # 24h and average them
  Tmax.now <- CurrObs.df$tmax
  Tmin.now <- CurrObs.df$tmin

  # Note this is not a true average, just a simple average of the 
  # max and min values (which is the way daily avg. temp is usually done)
  Tavg.now <- mean(c(Tmax.now, Tmin.now))
  message(paste('Updating station:', this_station))
  message(paste('Updating answer based on: Tavg.now ', Tavg.now,
    ', histPercentiles ', histPercentiles[,"Tavg"], '\n'))

  # don't include the median when binning obs against the climate!
  category.now <- as.character(cut(Tavg.now,
    breaks =
      c(-100,
      histPercentiles[!rownames(histPercentiles) %in% "50%", "Tavg"],
      100), 
    labels = c("bc","rc","c","a","h","rh","bh"),
    include.lowest = T, right = F))
  # The -100 and 100 allow us to have the lowest and highest bins

  isit_answer = switch(category.now, 
                      bc = 'Hell no!',
                      rc = 'No!',
                      c = 'Nope',
                      a = 'Not really',
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

  average.percent <- 100*round(ecdf(HistObs$Tavg)(Tavg.now),digits=2)

  ################################################################################################

  HistObs <- HistObs %>% 
    mutate(Date = ymd(paste(HistObs$Year, HistObs$Month, HistObs$Day, sep = '-'))) %>%
    rbind(data.frame(Year = year(current.date), Month = month(current.date), Day = day(current.date),
                    Tmax = Tmax.now, Tmin = Tmin.now, Tavg = Tavg.now, Date = current.date))

  # first the distribution plot because it uses all historical data
  dist.plot <- ggplot(data = HistObs, aes(Tavg)) + 
    ggtitle(
      paste0(
        "Distribution of daily average temperatures\nfor this time of year since ",
        this_station[["record_start"]])) +
    geom_density(adjust = 0.7, colour = '#999999', fill = '#999999') + 
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
    geom_vline(xintercept = median(HistObs$Tavg, na.rm = T), linetype = 2, alpha = 0.5) + 
    geom_vline(
      xintercept = histPercentiles["5%", "Tavg"], linetype = 2, alpha = 0.5) +
    geom_vline(
      xintercept = histPercentiles["95%", "Tavg"], linetype = 2, alpha = 0.5) + 
    scale_y_continuous(expand = c(0,0)) +
    xlab("Daily average temperature (°C)") + 
    # annotate("text", x = median(HistObs$Tavg), y = Inf, vjust = -0.75,
    #   hjust=1.1,label = "50TH PERCENTILE", size = 4, angle = 90, alpha = 0.5,
    #   family = 'Roboto Condensed', fontface = "bold") +
    annotate("text", x = histPercentiles["5%", "Tavg"], y = 0, vjust = -0.75,
            hjust=-0.05,label = paste0("5th percentile:  ",round(histPercentiles["5%", "Tavg"],1),'°C'), 
            size = 4, angle = 90, alpha = 0.9, family = 'Roboto Condensed', fontface = "bold") +
    annotate("text", x = histPercentiles["50%", "Tavg"], y = 0, vjust = -0.75,
            hjust=-0.05,label = paste0("50th percentile:  ",round(histPercentiles["50%", "Tavg"],1),'°C'), 
            size = 4, angle = 90, alpha = 0.9, family = 'Roboto Condensed', fontface = "bold") +
    annotate("text", x = histPercentiles["95%", "Tavg"], y = 0, vjust = -0.75,
            hjust=-0.05,label = paste0("95th percentile:  ",round(histPercentiles["95%", "Tavg"],1),'°C'),
            size = 4, angle = 90, alpha = 0.9, family = 'Roboto Condensed', fontface = "bold") +
    annotate("text", x = Tavg.now, y = Inf, vjust = -0.75, hjust = 1.1,
            label = paste0("TODAY:  ",Tavg.now,'°C'), colour = 'firebrick', size = 4, angle = 90, alpha = 1,
            family = 'Roboto Condensed', fontface = "bold")

  # Now for the time series the historical data must only include days with the same monthDay
  CurrentMonthDayHistObs <- HistObs %>%
                dplyr::filter(
                  month(Date) == month(current.date),
                  day(Date) == day(current.date))
    

  TS.plot <- ggplot(data = CurrentMonthDayHistObs, aes(x = Date, y = Tavg)) +
    ggtitle(
      paste0(
        "Daily average temperatures\nfor ",
        format(current.date_time, format="%d %B", tz = this_station[["tz"]])," since ",
        this_station[["record_start"]])) +
    xlab(NULL) + 
    ylab('Daily average temperature (°C)') + 
    geom_line(size = 0.5, colour = '#CCCCCC') + 
    geom_point(size = rel(2), colour = '#999999') +
    geom_point(aes(x = current.date, y = Tavg.now), colour = "firebrick",
              size = rel(5)) +
    geom_hline(aes(yintercept = histPercentiles["95%", "Tavg"]), linetype = 2,
              alpha = 0.5) +
    geom_hline(aes(yintercept = histPercentiles["5%", "Tavg"]), linetype = 2,
              alpha = 0.5) +
    geom_hline(aes(yintercept = median(HistObs$Tavg, na.rm = T)), linetype = 2,
              alpha = 0.5) +
    annotate("text", x = current.date, y = Tavg.now, vjust = -1.5,
            label = "TODAY", colour = 'firebrick', size = 4,
            family = 'Roboto Condensed', fontface = "bold") +
    annotate("text", x = current.date, y = Tavg.now, vjust = 2.5,
            label = paste0(Tavg.now,'°C'), colour = 'firebrick', size = 4,
            family = 'Roboto Condensed', fontface = "bold") + 
    annotate("text", x = ymd(paste0(round(min(HistObs$Year)/10)*10,"0101")),
            y = histPercentiles["95%", "Tavg"], label = paste0("95th percentile:  ",round(histPercentiles["95%", "Tavg"],1),'°C'),
            alpha = 0.9, size = 4, hjust=0, vjust = -0.5,
            family = 'Roboto Condensed', fontface = "bold") + 
    annotate("text", x = ymd(paste0(round(min(HistObs$Year)/10)*10,"0101")),
            y = median(HistObs$Tavg, na.rm = T), label = paste0("50th percentile:  ",round(histPercentiles["50%", "Tavg"],1),'°C'),
            alpha = 0.9, size = 4, hjust=0, vjust = -0.5,
            family = 'Roboto Condensed', fontface = "bold") + 
    annotate("text", x = ymd(paste0(round(min(HistObs$Year)/10)*10,"0101")),
            y = histPercentiles["5%", "Tavg"], label = paste0("5th percentile:  ",round(histPercentiles["5%", "Tavg"],1),'°C'),
            alpha = 0.9, size = 4, hjust = 0, vjust = -0.5,
            family = 'Roboto Condensed', fontface = "bold") +
    # annotate("text", x = ymd(paste0(round(min(HistObs$Year)/10)*10,"0101")),
    #   y = median(HistObs$Tavg), label = paste0("50TH PERCENTILE:  ",round(median(HistObs$Tavg)),'°C'),
    #   alpha = 0.5, size = 4, hjust = 0, vjust = -0.5,
    #   family = 'Roboto Condensed', fontface = "bold") +
    scale_x_date(
      breaks = ymd(paste0(
        seq(round(min(HistObs$Year)/10)*10,
            round(max(HistObs$Year)/10)*10, 20),
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

  # Save plots in www/output/<station ID>/
  ggsave(filename = paste0(fullpath,"www/output/", this_station[["id"]], "/ts_plot.png"), 
        plot = TS.plot, bg = "transparent", 
        height = 4.5, width = 8, units = "in", device = "png")

  ggsave(filename = paste0(fullpath,"www/output/", this_station[["id"]], "/density_plot.png"), 
        plot = dist.plot, bg = "transparent", 
        height = 4.5, width = 8, units = "in", device = "png")

  # Save JSON file
  statsList <- vector(mode = "list", length = 9)
    names(statsList) <- c("isit_answer","isit_comment","isit_maximum","isit_minimum","isit_current","isit_average", "isit_name", "isit_label", "isit_span")
    statsList[[1]] <- isit_answer
    statsList[[2]] <- isit_comment
    statsList[[3]] <- Tmax.now
    statsList[[4]] <- Tmin.now
    statsList[[5]] <- Tavg.now
    statsList[[6]] <- average.percent
    statsList[[7]] <- this_station[["name"]]
    statsList[[8]] <- this_station[["label"]]
    statsList[[9]] <- paste0(
      this_station[["record_start"]], "–", this_station[["record_end"]])

  # send everyone an email if there are problems with the output!
  if (any(is.na(statsList)) | any(is.null(statsList))) {
    report = paste0(
      "Problems with Isithot output:\n\n",
      paste(statsList, collapse = '\n'))
    
    system(paste(
      'echo', report, '| mail -s "Isithot: error in station',
      statsList[[7]], statsList[[8]],
      '" me@rensa.co m.lipson@unsw.edu.au stefan.contractor@gmail.com'))
  }


  exportJSON <- toJSON(statsList)
  write(
    exportJSON,
    file = paste0(fullpath, "www/output/", this_station[["id"]], "/stats.json"))
  
  ######################################################################################################################
  # HEATMAP
  
  year <- year(current.date)
  year_percentiles_file <- paste0(this_station["id"], "-", year, ".csv")
  station_year_data <- read_csv(paste0(fullpath, "databackup/", year_percentiles_file))
  
  # create an empty array to store the daily percentiles for this year
  percentileHeatmap_array <- array(dim = c(31,12))
  for (m in 1:month(current.date)) {
    month_data <- station_year_data %>% dplyr::filter(month(date) == m) %>% dplyr::pull(percentile)
    percentileHeatmap_array[,m][1:length(month_data)] <- month_data
  }
  
  # add today's data to the percentileHeatmap_array object
  percentileHeatmap_array[day(current.date), month(current.date)] <- average.percent
  
  # Write out today's percentile as the last row if a row does not already exist
  # and if average.percent is not NA
  current.row <- which(station_year_data$date == current.date)
  if (!is.na(average.percent)) {
    if (!is.na(current.row)) {
      station_year_data$date[current.row] <- current.date
      station_year_data$percentile[current.row] <- average.percent
    } else {
      station_year_data <- station_year_data %>% bind_rows %>% 
        data_frame(date = current.date, percentile = average.percent)
    }
  }
  write_csv(station_year_data, path = paste0(fullpath, "databackup/", year_percentiles_file))
  
  # Now plot the heatmap
  # Create the plots
  png(paste0(fullpath,"www/output/",this_station["id"], "/heatmap_", year, ".png"), width = 2400, height = 1060)
  par(mar = c(0.8,5,8,0.5) + 0.1, bg = NA, family = "Roboto Condensed")
  layout(mat = matrix(c(1,2), byrow = T, ncol = 2), widths = c(1, 0.075))
  cols <- rev(c('#b2182b','#ef8a62','#fddbc7','#f7f7f7','#d1e5f0','#67a9cf','#2166ac'))
  breaks <- c(0,0.05,0.2,0.4,0.6,0.8,0.95,1)
  month.names = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  na.df <- array(data = 1, dim = dim(percentileHeatmap_array))
  #image(seq(1, 31), seq(1, 12), na.df, xaxt = "n", yaxt ="n", 
  #xlab = "", ylab = "", col = 'white')
  image(seq(1, 31), seq(1, 12), 
        percentileHeatmap_array[,ncol(percentileHeatmap_array):1]/100, 
        xaxt = "n", yaxt ="n",
        xlab = "", ylab = "", breaks = breaks, col = cols)
  title(paste(this_station["label"], "percentiles for", year), 
        cex.main = 4, line = 5.5, col = "#333333")
  axis(side = 3, at = seq(1, 31), lwd.ticks = 0, cex.axis = 2.3)
  axis(side = 2, at = seq(12, 1), labels = month.names, las = 2, lwd.ticks = 0, cex.axis = 2.3)
  text(expand.grid(1:31, 12:1), labels = percentileHeatmap_array, cex = 2.3)
  par(mar = c(0.8,0,8,30) + 0.1, bg = NA)
  colbar <- c(cols[1], rep(cols[2], 3), rep(cols[3], 4),rep(cols[4], 4), rep(cols[5], 4), rep(cols[6], 3), cols[7])
  colkey(col = colbar, clim = c(0, 1), at = breaks, side = 4, width = 6,
         labels = paste(breaks*100), cex.axis = 2.3)
  dev.off()
}
