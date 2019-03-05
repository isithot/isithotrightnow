library(tidyverse)
library(purrr)
library(jsonlite)
library(lubridate)
library(ggmap)
# extrafont also needed on windows
library(extrafont)
library(here)


stations =
  fromJSON(here('www', 'locations.json'), simplifyDataFrame = TRUE) %>%
  select(station = id, name, label, lat, lon)

# code percentile ranges as discrnfete
colours = c(g = '#b2182b', f = '#ef8a62', e = '#fddbc7', d = '#f7f7f7',
  c ='#d1e5f0', b ='#67a9cf', a = '#2166ac')

# heatweave plot function
# data cols: date, percentile, month, day, pct_category
build_hw_plot = function(station, label, data) {
  ggplot(data, aes(x = day, y = fct_rev(month))) +
    geom_tile(aes(fill = pct_category), show.legend = FALSE) +
    # geom_text(aes(label = percentile), show.legend = FALSE) +
    scale_x_discrete(position = 'top', breaks = 1:31,
      expand = expand_scale(0)) +
    scale_y_discrete(expand = expand_scale(0)) +
    scale_fill_manual(values = colours, na.value = 'black') +
    coord_fixed(ratio = 1) +
    theme_void(base_family = 'Oswald Medium') +
    theme(
      plot.title = element_text(
        margin = margin(b = 0.15, unit = 'cm'),
        colour = 'white'),
      plot.background = element_blank(),
      panel.background = element_rect(fill = 'black')) +
    labs(
      x = NULL, y = NULL,
      title = toupper(label)
    )
}

# import and tidy obs, then plot each stations' percentiles

obs = 
  # import and tidy up the csv files
  list.files(here('2018-stats'), pattern = glob2rx('*.csv'), full.names = TRUE) %>%
  set_names(., .) %>%
  map_dfr(read_csv, .id = 'path') %>%
  mutate(fname = basename(path)) %>%
  separate(fname, into = c('station', 'year', 'extension'), sep = '[-.]') %>%
  select(station, date, percentile) %>%
  # delect date range (currently aus. summer 2018-19)
  filter(date %within% interval(ymd('2018-12-01'), ymd('2019-02-28'))) %>%
  # merge station names in
  left_join(stations, by = c('station')) %>%
  mutate(
    # extract month and day of month
    month = factor(month(date),
      levels = c(12, 1:2),
      labels = c(month.abb[12], month.abb[1:2])),
    day = mday(date),
    # categorise the percentiles for the colour scale
    pct_category = cut(percentile,
      breaks = c(0, 5, 20, 40, 60, 80, 95, 100),
      labels = letters[1:7]),
    lat = as.numeric(lat),
    lon = as.numeric(lon)) %>%
  # nest and plot!
  nest(-station, -name, -label, -lat, -lon) %>%
  mutate(
    hw_plot = pmap(select(., station, label, data), build_hw_plot),
    hw_grob = map(hw_plot, ggplotGrob))
  
# get the map tiles and plot them
aus_map = get_stamenmap(
  bbox = c(left = 100, top = -9, right = 165, bottom = -45), zoom = 5,
  maptype = 'toner-background')

summer_map =
  ggmap(aus_map) +
  theme_void()

# not sure how to apply/map this, so stuff it, we're doing a loop
# wdith and height are in degrees or lat/lon
# DOESN'T WORK
# grob_width = 5
# grob_height = 2
# for (row in seq(1:nrow(obs))) {
#   summer_map =
#     summer_map +
#     annotation_custom(
#       obs$hw_grob[row],
#       xmin = obs$lon[row] - (grob_width  / 2),
#       xmax = obs$lon[row] + (grob_width  / 2),
#       ymin = obs$lat[row] - (grob_height / 2),
#       ymax = obs$lat[row] + (grob_height / 2))
# }

# export everything
pwalk(select(obs, hw_plot, station, label),
  function(hw_plot, station, label) {
    ggsave(here('2018-stats', paste('hwplot-', station, '-', label, '.svg')), hw_plot)
  })

ggsave(here('2018-stats', 'hwplot-base.svg'), summer_map, width = 16, height = 9, units = 'in')

# { walk2(.$hw_plot, .$label, ~ ggsave(paste0('hw_summer1819-', .y, '.png'), .x)) }




