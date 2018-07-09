# heatmap-tidy.r: take the nested list structure of station_set
# (from heatmap.r) and convert it to a tidy dataframe of all obs and
# all stations. then chop it up by station nand year and export to csv
# so that main_static.r can use it.

library(tidyverse)
library(purrr)
select = dplyr::select
filter = dplyr::filter

# skip this if running directly after heatmap.r!
station_set = readRDS('heatmap-data.rds')

# get the nested list structure into a nested data frame
tidy_data =
  station_set %>%
  {
    data_frame(
    id   = map_chr(., pluck, 'id'),
    # name = map_chr(., pluck, 'name'),
    percentiles =
      map(., pluck, 'percentileHeatmap_array') %>%
      map(as_tibble) %>%
      map(set_names, 1:12) %>%
      map(rownames_to_column, 'day') %>%
      map(gather, key = 'month', value = 'percentile', -day),
    categories =
      map(., pluck, 'categoryHeatmap_array') %>%
      map(as_tibble) %>%
      map(set_names, 1:12) %>%
      map(rownames_to_column, 'day') %>%
      map(gather, key = 'month', value = 'category', -day))
  } %>%
  # now unnest, drop the duplicated columns and then nest by station
  unnest() %>%
  mutate(date = as.Date(paste('2018', month, day, sep = '-'))) %>%
  select(id, date, percentile) %>%
  nest(-id)

# write 'em out to disk  
walk2(tidy_data$data, tidy_data$id,
  ~ write_csv(.x, paste0('databackup/', .y, '-2018.csv')))
  
  
  


