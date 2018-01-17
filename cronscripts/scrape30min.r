#!/usr/bin/Rscript

# File: scrape30min.r
# stefan contractor, mat lipson and james goldie
# Description: 
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with: crontab

library(dplyr)
library(readr)
library(purrr)
library(lubridate)
library(xml2)
library(RJSONIO)

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
station_ids <-
  fromJSON(paste0(fullpath, "www/locations.json")) %>%
  map(~ pluck(., "id")) %>%
  unlist()
xpath_filter <-
  paste0("@bom-id = '", station_ids, "'") %>%
  paste(collapse = " or ")

obs_new <-
  map_dfr(
    # for each state, we're going to...
    c("D", "N", "Q", "S", "T", "V", "W"),
    # download the file and select the matching stations
    ~ read_xml(paste0(bom_xml_path, "ID", ., "60920.xml")) %>%
    xml_find_all(paste0("//station[", xpath_filter, "]")) %>%
    # build a data frame with the info we want...
    data_frame(
      # TODO - not sure why this also returns a column with the nodeset!
      # if . is used in a pipe, the piped-in thing shouldn't automatically be
      # the first argument. ahh well, i'll just drop it for now...
      station_id = xml_attr(., "bom-id"),
      tz = xml_attr(., "tz"),
      lat = xml_attr(., "lat"),
      lon = xml_attr(., "lon"),
      tmax =
        xml_find_first(., ".//element[@type='maximum_air_temperature']") %>%
        xml_text(),
      tmax_dt =
        xml_find_first(., ".//element[@type='maximum_air_temperature']") %>%
        xml_attr("time-local"),
      tmin =
        xml_find_first(., ".//element[@type='minimum_air_temperature']") %>%
        xml_text(),
      tmin_dt =
        xml_find_first(., ".//element[@type='minimum_air_temperature']") %>%
        xml_attr("time-local")) %>%
    select(-1) %>%
    # convert the date-time strings
    rowwise() %>%
    mutate(
      tmax_dt = ymd_hms(tmax_dt, tz = tz),
      tmin_dt = ymd_hms(tmin_dt, tz = tz)) %>%
    ungroup())
  
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
      col_types = cols(.default = col_character())) %>%
    rowwise() %>%
    # note that datetimes are written out in utc. we can leave them this way
    # for the time checking maths :)
    mutate(
      tmax_dt = ymd_hms(tmax_dt),
      tmin_dt = ymd_hms(tmin_dt)) %>%
    ungroup() %>%
    rename(
      tmax_old = tmax,
      tmax_old_dt = tmax_dt,
      tmin_old = tmin,
      tmin_old_dt = tmin_dt)
  
  # join the old and new obs together, select the better obs,
  # drop the others and write it out
  inner_join(obs_new, obs_old) %>%
  mutate(
    tmax_selected = if_else(
      tmax > tmax_old | tmax_old_dt %--% Sys.time() %/% hours(1) >= 24,
        true = tmax, false = tmax_old),
    tmax_selected_dt = if_else(
      tmax > tmax_old | tmax_old_dt %--% Sys.time() %/% hours(1) >= 24,
        true = tmax_dt, false = tmax_old_dt),
    tmin_selected = if_else(
      tmin > tmin_old | tmin_old_dt %--% Sys.time() %/% hours(1) >= 24,
        true = tmin, false = tmin_old),
    tmin_selected_dt = if_else(
      tmin > tmin_old | tmin_old_dt %--% Sys.time() %/% hours(1) >= 24,
        true = tmin_dt, false = tmin_old_dt)) %>%
  print() %>% # for debugging!
  select(
    station_id, tz, lat, lon,
    tmax = tmax_selected, tmax_dt = tmax_selected_dt,
    tmin = tmin_selected, tmin_dt = tmin_selected_dt) %>%
  write_csv(paste0(fullpath, "data/latest/latest-all.csv"))

  message(Sys.time(), " Wrote out new station observations")
}
