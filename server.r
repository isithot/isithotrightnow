library(shiny)
library(ggplot2)

# IsItHotRightNow.com
# Algorithm

# Libraries
library(jsonlite)
library(lubridate)
library(plotly)

# server logic: calc output based on inputs
function(input, output) {

  # Get Data
  # Get Climatology data
  # Pre-made BOM statistics available in data/ 
  BOMstats.raw <- read.csv("data/IDCJCM0037_066062.csv", skip = 10, header = T,
                           stringsAsFactors = F)
  
  
  # Get current half hourly data for the past 3 days
  # from http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json
  url = "http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json"
  SydObs.json <- readLines(url)
  SydObs.data <- fromJSON(SydObs.json)
  # Create a dataframe with Date_time in first column and air_temp in second column
  date_time <- ymd_hms(SydObs.data$observations$data$local_date_time_full,
                       tz = "Australia/Sydney")
  air_temp <- SydObs.data$observations$data$air_temp
  # Now create the data frame
  SydObs.df <- data.frame(date_time, air_temp)
  
  # sample plot
  plot_ly(x = ~date_time, y = ~air_temp, type = 'scatter', mode = 'lines') %>%
    layout(xaxis = list(title = "Time"),
           yaxis = list(title = "Temperature (Degrees C)"))
  
  # Now the algorithm
  # --
  # Take the maximum and minimum temperatures of the last 24h
  # and average them to the the avg(Tmax,Tmin)
  # then compare this Tavg with the climatology
  # We use pre-calculated statistics from BOM
  # Climatology value is create by averaging 
  # 90th pc Tmax and 90th pc Tmin from BOM statistics
  # --
  
  # Let's first get the current month and current date_time
  current.date_time <- SydObs.df$date_time[1]
  current.month <- month(current.date_time)
  # Now let's get the air_temp max and min over the past
  # 24h and average them
  Tmax.now <- max(SydObs.df$air_temp[1:48])
  Tmin.now <- min(SydObs.df$air_temp[1:48])
  # Note this is not a true average, just an average of the 
  # max and min values
  Tavg.now <- mean(c(Tmax.now, Tmin.now))
  
  #Now we get the 90th pc Tmax and Tmin from the climatology
  # row 7 is Decile 9 maximum temperature (Degrees C) for years 1859 to 2017
  # row 17 is Decile 9 minimum temperature (Degrees C) for years 1859 to 2017
  Tmax90p.clim <- as.numeric(BOMstats.raw[7, current.month+1])
  Tmin90p.clim <- as.numeric(BOMstats.raw[17, current.month+1])
  Tavg90p.clim <- mean(c(Tmax90p.clim, Tmin90p.clim))
  
  # Now we return 1 if Tavg.now >= Tavg90p.clim and
  #        return 0 otherwise
  if (Tavg.now >= Tavg90p.clim) {
    # answer = 1
    output$isit_answer = renderText({'Yuuuup'})
    output$isit_comment = renderText({"it's super hot"})
  } else {
    # answer = 0
    output$isit_answer = renderText({'Naaaah'})
    output$isit_comment = renderText({"it's not so hot"})
  }
  
}







# use reactive() to ensure that dataset is updated whenever
# inout$sampleSize changes
# dataset <- reactive({
#   diamonds[sample(nrow(diamonds), input$sampleSize), ]
# })

# renderPlot() does the plot rendering. duh.
# output$plot <- renderPlot({

#   p <- ggplot(dataset(), aes_string(x=input$x, y=input$y)) +
#     geom_point()

#   if (input$color != 'None')
#     p <- p + aes_string(color=input$color)

#   facets <- paste(input$facet_row, '~', input$facet_col)
#   if (facets != '. ~ .')
#     p <- p + facet_grid(facets)

#   if (input$jitter)
#     p <- p + geom_jitter()
#   if (input$smooth)
#     p <- p + geom_smooth()

#   print(p)

# }, height = 700)
