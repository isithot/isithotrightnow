#!/bin/bash
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with:
# sudo crontab -u shiny -e

# grep last 30min obs (line starting with '0,') into data/hist_ file
grep -o '^0,.*' data/IDN60901.94768.axf >> data/hist_IDN60901.94768.csv
# download latest observations 
curl -o data/IDN60901.94768.axf http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.axf
curl -o data/IDN60901.94768.json http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json

echo "latest observations have been scraped"
exit
