#!/bin/bash
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with:
# sudo crontab -u shiny -e

curl -o data/IDN60901.94768.axf http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.axf
curl -o data/IDN60901.94768.json http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json

echo "latest observations have been scraped"
exit
