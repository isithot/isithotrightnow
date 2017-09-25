# is it hot right now
# stefan, mat and james

library(shiny)
library(ggplot2)
library(jsonlite)
library(lubridate)
library(dplyr)

# load functions from app_functions.R
source("app_functions.R")

# server logic: calc output based on inputs
server <- function(input, output) {
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
  
  # Get current half hourly data for the past 3 days
  SydObs.df <- getCurrentObs()
  
  # Let's first get the current month, day and current date_time
  # Because we are averaging the max and min temperatures over the
  # past 24h, the current date is the date 12h ago
  current.date_time <- SydObs.df$date_time[13]
  current.date <- ymd(substr(current.date_time, 1, 10))
  
  # Calculate percentiles of historical data
  SydHistObs <- getHistoricalObs(date = current.date)
  histPercentiles <- calcHistPercentiles(Obs = SydHistObs)
  
  # sample plot
  # plot_ly(x = ~date_time, y = ~air_temp, type = 'scatter', mode = 'lines') %>%
  #   layout(xaxis = list(title = "Time"),
  #          yaxis = list(title = "Temperature (Degrees C)"))
  
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
  
  output$isit_answer = renderText({switch(category.now, 
                              bc = 'Hell no!',
                              rc = 'Nope!',
                              c = 'No!',
                              a = 'No',
                              h = 'Yup',
                              rh = 'Yeah!',
                              bh = 'Hell yeah!')})
  
  output$isit_comment = renderText({switch(category.now,
                               bc = "Are you kidding?! It's bloody cold",
                               rc = "It's actually really cold",
                               c = "It's actually kinda cool",
                               a = "It's about average",
                               h = "It's warmer than average",
                               rh = "It's really hot!",
                               bh = "It's bloody hot!")})
  
  #### latest info no longer being used ####
  # latest.time <- substr(head(SydObs.df, 1)[1,1],12,16)
  # latest.temp <- head(SydObs.df, 1)[1,2]
  # latest.string <- paste(latest.temp,'°C','at', latest.time,'at Sydney Observatory')
  average.percent <- 100*round(ecdf(SydHistObs$Tavg)(Tavg.now),digits=2)
  # render current conditions to output$isit_current
  output$isit_current = renderText({Tavg.now})
  output$isit_average = renderText({average.percent})
  
  ################################################################################################

  SydHistObs$Date = ymd(paste(SydHistObs$Year, SydHistObs$Month, SydHistObs$Day, sep = '-'))
  
  SydHistObs <- rbind(SydHistObs,
                      data.frame(Year = year(current.date), Month = month(current.date), Day = day(current.date),
                                 Tmax = Tmax.now, Tmin = Tmin.now, Tavg = Tavg.now, Date = current.date))

  TS.plot <- ggplot(data = SydHistObs, aes(x = Date, y = Tavg)) +
    ggtitle(paste0('Daily average temperatures\nsince 1850 for ', format(current.date_time, format="%d %B"))) +
    xlab(NULL) + 
    ylab('Daily average temperature (°C)') + 
    # annotate("text",x=ymd("18700101"),y=20,label = 'test') +
    geom_line(size = 1.05, colour = '#999999') +
    geom_point(aes(x = current.date, y = Tavg.now), colour = "firebrick", size = rel(5)) +
    geom_hline(aes(yintercept = histPercentiles[,"Tavg"][6]), linetype = 2, alpha = 0.5) +
    geom_hline(aes(yintercept = histPercentiles[,"Tavg"][1]), linetype = 2, alpha = 0.5) +
    geom_hline(aes(yintercept = median(SydHistObs$Tavg)), linetype = 2, alpha = 0.5) +
    annotate("text", x = current.date, y = Tavg.now, vjust = -1.5,label = "Today", colour = 'firebrick', size = 4) + 
    annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
             y = histPercentiles[,"Tavg"][6], label = "95th percentile", alpha = 0.5, size = 4, hjust=0, vjust = -0.5) + 
    annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
             y = histPercentiles[,"Tavg"][1], label = "5th percentile", alpha = 0.5, size = 4, hjust = 0, vjust = 1.5) +
    annotate("text", x = ymd(paste0(round(min(SydHistObs$Year)/10)*10,"0101")),
             y = median(SydHistObs$Tavg), label = "50th percentile", alpha = 0.5, size = 4, hjust = 0, vjust = -0.5) +
    # annotate("text", x = ymd(paste0(substr(current.date,1,4),"0101")),
    #          y = histPercentiles[,"Tavg"][6], label = paste(round(histPercentiles[,"Tavg"][6],1),'°C'), alpha = 0.5, size = 4, hjust=0, vjust = -0.5) + 
    # annotate("text", x = ymd(paste0(substr(current.date,1,4),"0101")),
    #          y = histPercentiles[,"Tavg"][1], label = paste(round(histPercentiles[,"Tavg"][1],1),'°C'), alpha = 0.5, size = 4, hjust=0, vjust = -0.5) + 
    # annotate("text", x = ymd(paste0(substr(current.date,1,4),"0101")),
             # y = median(SydHistObs$Tavg), label = paste(round(median(SydHistObs$Tavg)),'°C'), alpha = 0.5, size = 4, hjust=0, vjust = -0.5) + 
    scale_x_date(breaks = ymd(paste0(seq(round(min(SydHistObs$Year)/10)*10, round(max(SydHistObs$Year)/10)*10, 20),"0101")),
                 date_labels = '%Y') +
    theme_bw(base_size = 20, base_family = 'Roboto Condensed') +
    theme(panel.background = element_rect(fill = "transparent", colour = NA),
          plot.title = element_text(size = 18, face = "bold", hjust = 0.5, color = '#333333'),
          panel.grid.minor = element_blank(), panel.grid.major = element_blank(),
          plot.background = element_rect(fill = "transparent", colour = NA),
          panel.border = element_blank(),
          axis.line = element_line(),
          axis.text.x = element_text(face = "bold"),
          axis.text.y = element_text(face = "bold"),
          axis.title.y = element_text(face = "bold", size = 16))

  output$detail_normal_plot <- renderPlot({TS.plot}, bg = "transparent", execOnResize = TRUE)

  dist.plot <- ggplot(data = SydHistObs, aes(Tavg)) + 
    ggtitle(paste('Distribution of daily average temperatures\n since 1850 for',format(current.date_time, format="%d %B"))) +
    geom_density(adjust = 0.4, colour = '#999999', fill = '#999999') + 
    theme_bw(base_size = 20, base_family = 'Roboto Condensed') +
    theme(panel.background = element_rect(fill = "transparent", colour = NA),
          panel.grid.minor = element_blank(), panel.grid.major = element_blank(),
          plot.background = element_rect(fill = "transparent", colour = NA),
          panel.border = element_blank(),
          plot.title = element_text(face = "bold", color = '#333333'),
          axis.text.x = element_text(face = "bold"),
          axis.title.x = element_text(face = "bold", size = 16)) +
    geom_vline(xintercept = Tavg.now, colour = 'firebrick', size = rel(1.5)) +
    geom_vline(xintercept = median(SydHistObs$Tavg), linetype = 2, alpha = 0.5) + 
    geom_vline(xintercept = histPercentiles[,"Tavg"][1], linetype = 2, alpha = 0.5) +
    geom_vline(xintercept = histPercentiles[,"Tavg"][6], linetype = 2, alpha = 0.5) + 
    theme(axis.title.y = element_blank(),
          plot.title = element_text(size = 18, hjust = 0.5),
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank()) +
    scale_y_continuous(expand = c(0,0)) +
    xlab("Daily average temperature (°C)") + 
    annotate("text", x = median(SydHistObs$Tavg), y = Inf, vjust = -0.75,hjust=1.1,label = "50th percentile", size = 4, angle = 90, alpha = 0.5) +
    annotate("text", x = histPercentiles[,"Tavg"][1], y = Inf, vjust = -0.75,hjust=1.1,label = "5th percentile", size = 4, angle = 90, alpha = 0.5) +
    annotate("text", x = histPercentiles[,"Tavg"][6], y = Inf, vjust = -0.75,hjust=1.1,label = "95th percentile", size = 4, angle = 90, alpha = 0.5) +
    annotate("text", x = Tavg.now, y = Inf, vjust = -0.75, hjust=1.1,label = "Today", colour = 'firebrick', size = 4, angle = 90, alpha = 1)
  
  
  output$detail_normal_plot <- renderPlot({TS.plot}, bg = "transparent", execOnResize = TRUE)
  output$detail_dist_plot <- renderPlot({dist.plot}, bg= "transparent", execOnResize = TRUE)

  # output$detail_normal_plot <- renderPlotly({
  # plot_ly(y = ~Tavg, x = ~Year, data = SydHistObs, type = 'scatter', mode = "lines")
  # })
  # plotPNG(func = function() {
  #   plot(Tavg ~ Year, data = SydHistObs, type = 'n')
  #   lines(Tavg ~ Year, data = SydHistObs)},
  #   filename = "www/assets/detail_normal_plot.png")

  # comments on the (currently two) plots
  # output$detail_normal_caption <-
  # output$detail_cc_caption <-
}

shinyApp(ui = htmlTemplate("www/index.html"), server)
