# IsItHotRightNow.com
# Algorithm

# Libraries
library(jsonlite)
library(ludridate)

# Get Data
# Get Climatology data
# Pre-made climatology from BOM available in data/ 


# Get current half hourly data for the past 3 days
# from http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json

url = "http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json"
SydObs.json <- readLines(url)
SydObs.data <- fromJSON(SydObs.json)
# Create a dataframe with Date_time in first column and air_temp in second column
date_time.raw <- ymd_hms(SydObs.data$observations$data$local_date_time_full,
                         tz = "Australia/Sydney")
air_temp.raw <- SydObs.data$observations$data$air_temp


