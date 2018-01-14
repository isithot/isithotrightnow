# isithotrightnow
Is it hot right now? A Shiny app.

Running locally
===============

~~~~
nginx
nginx -t
nginx -s stop
~~~~
start nginx locally at port as defined in conf.d file
location of nginx conf file
stop nginx locally


BoM product info
================

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
