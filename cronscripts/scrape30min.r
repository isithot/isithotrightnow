#!/usr/bin/Rscript

# File: scrape30min.r
# stefan contractor, mat lipson and james goldie
# Description: 
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with: crontab

for (state in c("D", "N", "Q", "S", "T", "V", "W"))
{
  download.file(
    paste0("ftp://ftp.bom.gov.au/anon/gen/fwo/ID", state, "60920.xml"),
    destfile = paste0(
      "/srv/isithotrightnow/data/latest/latest-",
      switch(state, D = "nt", N = "nsw", Q = "qld", S = "sa", T = "tas",
        V = "vic", W = "wa"),
      ".xml"))
}
