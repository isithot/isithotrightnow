#!/bin/bash
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with:
# sudo crontab -u shiny -e

# download latest observations

### NEW SOUTH WALES (N) ###
# Sydney Obsevatory
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDN60901.94768.axf http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.axf
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDN60901.94768.json http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json

### VICTORIA (V) ###
# Melbourne (Olympic Park)
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDV60901.95936.axf http://www.bom.gov.au/fwo/IDV60901/IDV60901.95936.axf
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDV60901.95936.json http://www.bom.gov.au/fwo/IDV60901/IDV60901.95936.json

### QUEENSLAND (Q) ###
# Brisbane
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDQ60901.94576.axf http://www.bom.gov.au/fwo/IDQ60901/IDQ60901.94576.axf
curl -o ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDQ60901.94576.json http://www.bom.gov.au/fwo/IDQ60901/IDQ60901.94576.json

# grep last 30min obs (line starting with '0,') into data/hist_ file
grep -o '^0,.*' ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDN60901.94768.axf >> ~/ownCloud/IsItHotRightNow/isithotrightnow/data/hist_IDN60901.94768.csv
grep -o '^0,.*' ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDV60901.95936.axf >> ~/ownCloud/IsItHotRightNow/isithotrightnow/data/hist_IDV60901.95936.csv
grep -o '^0,.*' ~/ownCloud/IsItHotRightNow/isithotrightnow/data/IDQ60901.94576.axf >> ~/ownCloud/IsItHotRightNow/isithotrightnow/data/hist_IDQ60901.94576.csv

echo "latest observations have been scraped"
exit
