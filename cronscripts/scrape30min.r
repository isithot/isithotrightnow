#!/usr/bin/Rscript

# File: scrape30min.r
# stefan contractor, mat lipson and james goldie
# Description: 
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with: crontab

library(tidyverse)
library(xml2)
library(jsonlite)

message(Sys.time(), " Looking for new observations...")

if (Sys.info()["user"] == "ubuntu")
{
  # running on the server
  fullpath <- "/srv/isithotrightnow/"
} else {
  # testing locally
  fullpath <- "./"
}
bom_xml_path <- "ftp://ftp.bom.gov.au/anon/gen/fwo/"

# get station id list from locations.json
#and use it to construct a station filter

# get vector of station ids
station_ids <- fromJSON(paste0("data/latest/locations.json")) %>% pull(id)

# filter for querying xml
xpath_filter <-
  paste0("@bom-id = '", station_ids, "'") %>%
  paste(collapse = " or ")


#' Read the BOM XML files for a specified state, locate all weather stations
#' matching our list, extract the latest weather observation for each station
#' and return a dataframe for each station containing the observation
#' @param state 
get_state_obs <- function(state = c("D", "N", "Q", "S", "T", "V", "W")) {

  # validate provided state against argument formals (one only)
  state <- match.arg(state, several.ok = FALSE)

  read_xml(paste0(bom_xml_path, "ID", state, "60920.xml")) %>%
    xml_find_all(paste0("//station[", xpath_filter, "]")) ->
  matching_stations
    # extract the following elements into a dataframe for each of the
    # matching stations...
    
    tibble(
      station_id = xml_attr(matching_stations, "bom-id"),
      tz = xml_attr(matching_stations, "tz"),
      lat = xml_attr(matching_stations, "lat"),
      lon = xml_attr(matching_stations, "lon"),
      tmax =
        xml_find_first(matching_stations,
          ".//element[@type='maximum_air_temperature']") %>%
          xml_text() %>%
          as.numeric(),
      tmax_dt =
        xml_find_first(matching_stations,
          ".//element[@type='maximum_air_temperature']") %>%
          xml_attr("time-local"),
      tmin =
        xml_find_first(matching_stations,
          ".//element[@type='minimum_air_temperature']") %>%
          xml_text() %>%
          as.numeric(),
      tmin_dt =
        xml_find_first(matching_stations,
          ".//element[@type='minimum_air_temperature']") %>%
          xml_attr("time-local")) %>%
    # note we convert to utc here
    mutate(
      tmax_dt = ymd_hms(tmax_dt, tz = "UTC"),
      tmin_dt = ymd_hms(tmin_dt, tz = "UTC"))
}

#' Find the start of today in a specified timezone
find_today_start <- function(tz) {
    today(tz) %>%
      paste("00:00:00") %>%
      ymd_hms(tz = tz) %>%
      with_tz("UTC")
  }

# extract the station detials for each state abd glue them together
# then parse the date-time strings to local date-times
obs_new <-
  map_dfr(c("D", "N", "Q", "S", "T", "V", "W"), get_state_obs)
  
message(Sys.time(), " Downloaded and extracted new observations")

# just use these obs if we don't have existing ones
if (!file.exists(paste0(fullpath, "data/latest/latest-all.csv")))
{
  write_csv(obs_new, paste0(fullpath, "data/latest/latest-all.csv"))
  message(Sys.time(), " Wrote out first station observations")

} else {
  
  # but if we do have existing obs, we want whichever obs are greater
  # (for maxes) or lower (for mins) *within the last 24 hours*

  obs_old <-
    read_csv(
      paste0(fullpath, "data/latest/latest-all.csv"),
      col_types = cols(
        tmax = col_double(),
        tmin = col_double(),
        .default = col_character())) %>%
    rename(tmax_old = tmax, tmin_old = tmin) |>
    mutate(
      tmax_old_dt = ymd_hms(tmax_dt),
      tmin_old_dt = ymd_hms(tmin_dt)) %>%
    select(-tmax_dt, -tmin_dt)
  
  # join the old and new obs together, select the better obs,
  # drop the others and write it out
  joined <-
    full_join(obs_new, obs_old,
      by = join_by(station_id, tz, lat, lon)) %>%
  # get today's local midnight in utc so that we can drop old obs from yesterday
  mutate(today_start = find_today_start(tz)) %>%
  mutate(
    # first, select new obs if they're more extreme than the previous ones
    # *and* within the 24 hour window....
    tmax_selected = if_else(
      tmax >= tmax_old | tmax_old_dt < today_start, tmax, tmax_old),
    tmax_selected_dt = if_else(
      tmax >= tmax_old | tmax_old_dt < today_start, tmax_dt, tmax_old_dt),
    tmin_selected = if_else(
      tmin <= tmin_old | tmin_old_dt < today_start, tmin, tmin_old),
    tmin_selected_dt = if_else(
      tmin <= tmin_old | tmin_old_dt < today_start, tmin_dt, tmin_old_dt),
    # then, backfill any nas 
    tmax_selected = coalesce(tmax_selected, tmax, tmax_old),
    tmax_selected_dt = coalesce(tmax_selected_dt, tmax_dt, tmax_old_dt),
    tmin_selected = coalesce(tmin_selected, tmin, tmin_old),
    tmin_selected_dt = coalesce(tmin_selected_dt, tmin_dt, tmin_old_dt)) %>%
  select(
    station_id, tz, lat, lon,
    tmax = tmax_selected, tmax_dt = tmax_selected_dt,
    tmin = tmin_selected, tmin_dt = tmin_selected_dt) %>%
  write_csv(paste0(fullpath, "data/latest/latest-all.csv"))

  message(Sys.time(), " Wrote out new station observations")
}
