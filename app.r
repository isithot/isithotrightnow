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

  if (Tavg.now < histPercentiles[,"Tavg"][1]) {
    output$isit_answer = renderText({"No"})
    output$isit_comment = renderText({"Are you kidding?! It's bloody cold"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][1] & Tavg.now < histPercentiles[,"Tavg"][2]) {
    output$isit_answer = renderText({'No'})
    output$isit_comment = renderText({"it's actually really cold"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][2] & Tavg.now < histPercentiles[,"Tavg"][3]) {
    output$isit_answer = renderText({'No'})
    output$isit_comment = renderText({"it's actually kinda cool"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][3] & Tavg.now < histPercentiles[,"Tavg"][4]) {
    output$isit_answer = renderText({'No'})
    output$isit_comment = renderText({"it's about average"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][4] & Tavg.now < histPercentiles[,"Tavg"][5]) {
    output$isit_answer = renderText({'Yes'})
    output$isit_comment = renderText({"it's warmer than average"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][5] & Tavg.now < histPercentiles[,"Tavg"][6]) {
    output$isit_answer = renderText({'Yes'})
    output$isit_comment = renderText({"it's really hot!"})
  } else if (Tavg.now >= histPercentiles[,"Tavg"][6]) {
    output$isit_answer = renderText({'Yes'})
    output$isit_comment = renderText({"it's bloody hot!"})
  } else
  {
    output$isit_answer = renderText({'ERROR'})
  }
  
  # output$detail_normal_plot <- renderPlotly({
  # plot_ly(y = ~Tavg, x = ~Year, data = SydHistObs, type = 'scatter', mode = "lines")
  # })
  output$detail_normal_plot <- renderPlot({
    plot(Tavg ~ Year, data = SydHistObs, type = 'n')
    lines(Tavg ~ Year, data = SydHistObs)
  })
  # plotPNG(func = function() {
  #   plot(Tavg ~ Year, data = SydHistObs, type = 'n')
  #   lines(Tavg ~ Year, data = SydHistObs)},
  #   filename = "www/assets/detail_normal_plot.png")
}

shinyApp(ui = htmlTemplate("www/index.html"), server)
