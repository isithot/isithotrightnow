# isithotrightnow
Is it hot right now?

Written in R with scripts to download data, create stats and plots run every 10 minutes.

main_static.R timeseries and distribution plot
heatmap.R daily heatmap (run once per day)


BoM product info
================

Source data from Australian Bureau of Meteorology www.bom.gov.au

Each state is associated with a letter, used in product codes (`IDx`, where `x` is the state letter), and a range of regions, [used in station IDs](http://www.bom.gov.au/climate/cdo/about/site-num.shtml#tabulated) (`XYYnnn`, where `YY` is the region number).

State     | Product letter | Regions
----------|----------------|-------
WA        | W              | 1–13
NT        | D              | 14–15
SA        | S              | 16–26
Qld       | Q              | 27–45
NSW & ACT | N              | 46–75
Vic       | V              | 76–90
Tas       | T              | 91–99
