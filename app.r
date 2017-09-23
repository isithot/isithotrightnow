# is it hot right now
# stefan, mat and james

library(shiny)
library(ggplot2)
library(jsonlite)
library(lubridate)
library(plotly)
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
                              bc = 'Hell No!',
                              rc = 'Nope!',
                              c = 'No!',
                              a = 'No',
                              h = 'Yup',
                              rh = 'Yeah!',
                              bh = 'Hell Yeah!')})
  
  output$isit_comment = renderText({switch(category.now,
                               bc = "Are you kidding?! It's bloody cold",
                               rc = "it's actually really cold",
                               c = "it's actually kinda cool",
                               a = "it's about average",
                               h = "it's warmer than average",
                               rh = "it's really hot!",
                               bh = "it's bloody hot!")})
  
  #### latest info no longer being used ####
  # latest.time <- substr(head(SydObs.df, 1)[1,1],12,16)
  # latest.temp <- head(SydObs.df, 1)[1,2]
  # latest.string <- paste(latest.temp,'°C','at', latest.time,'at Sydney Observatory')
  current.string <- paste('The average of the max and min temperatures over the last 24 hours was', Tavg.now,'°C')
  average.percent <- 100*round(ecdf(SydHistObs$Tavg)(Tavg.now),digits=2)
  average.string <- paste0('This is warmer than ',average.percent,'% of average temperatures for todays date')
  # render current conditions to output$isit_current
  output$isit_current = renderText({current.string})
  output$isit_average = renderText({average.string})

  SydHistObs$Date = ymd(paste(SydHistObs$Year, SydHistObs$Month, SydHistObs$Day, sep = '-'))  
  
  SydHistObs <- rbind(SydHistObs,
                      data.frame(Year = year(current.date), Month = month(current.date), Day = day(current.date),
                                 Tmax = Tmax.now, Tmin = Tmin.now, Tavg = Tavg.now, Date = current.date))
  
  TS.plot <- ggplot(data = SydHistObs, aes(x = Date, y = Tavg)) +
    geom_line() +
    geom_point(aes(x = current.date, y = Tavg.now), colour = "firebrick", size = rel(5)) +
    geom_hline(aes(yintercept = histPercentiles[,"Tavg"][6]), linetype = 2, colour = 'red') +
    geom_hline(aes(yintercept = histPercentiles[,"Tavg"][1]), linetype = 2, colour = 'blue') +
    scale_x_date(breaks = ymd(paste0(seq(round(min(SydHistObs$Year)/10)*10, round(max(SydHistObs$Year)/10)*10, 20),"0101")),
                 date_labels = '%Y') +
    theme_bw(base_size = 20) +
    theme(panel.background = element_rect(fill = "transparent", colour = NA),
          panel.grid.minor = element_blank(), panel.grid.major = element_blank(),
          plot.background = element_rect(fill = "transparent", colour = NA))

  output$detail_normal_plot <- renderPlot({switch(category.now,
                                                  bc = TS.plot +
                                                    geom_ribbon(ymin = -100,
                                                                ymax = histPercentiles[,"Tavg"][1],
                                                                alpha = 0.2, fill = "darkblue"),
                                                  rc = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][1],
                                                                ymax = histPercentiles[,"Tavg"][2],
                                                                alpha = 0.2, fill = "darkblue"),
                                                  c = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][2],
                                                                ymax = histPercentiles[,"Tavg"][3],
                                                                alpha = 0.2, fill = "blue"),
                                                  a = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][3],
                                                                ymax = histPercentiles[,"Tavg"][4],
                                                                alpha = 0.2, fill = "gray"),
                                                  h = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][4],
                                                                ymax = histPercentiles[,"Tavg"][5],
                                                                alpha = 0.2, fill = "red"),
                                                  rh = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][5],
                                                                ymax = histPercentiles[,"Tavg"][6],
                                                                alpha = 0.2, fill = "darkred"),
                                                  bh = TS.plot +
                                                    geom_ribbon(ymin = histPercentiles[,"Tavg"][6],
                                                                ymax = 100,
                                                                alpha = 0.2, fill = "darkred"))})


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
