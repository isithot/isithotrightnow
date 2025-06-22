# this docker image is designed to work with the {lambdr} package:
# https://github.com/mdneuzerling/lambdr

FROM rocker/r-ver:4.4

# curl needed for {pak}
RUN apt-get update && \
  apt-get -y install --no-install-recommends curl

# options(warn=2) will make the build error out if package doesn't install
RUN Rscript -e "options(warn = 2); install.packages('pak')"

# install r  packages
# (using {pak} means that ubuntu system deps for the r packages are also handled
RUN Rscript -e "pak::pak(c('httr', 'jsonlite', 'logger', 'remotes', 'tidyverse', 'systemfonts', 'aws.s3', 'lambdr', 'ggridges', 'plot3D'))"

# install fonts
COPY Roboto_Condensed/RobotoCondensed*.ttf /usr/share/fonts/

# copy r script(s) into container
RUN mkdir /lambda
COPY runtime.r /lambda
COPY util.r /lambda
RUN chmod 755 -R /lambda

ENTRYPOINT ["Rscript", "R/runtime.r"]

# function to run in this (this should be overridden with the name of another
# function in runtime.r using the "entrypoint" setting when configuring your
# lambda)
CMD ["defaultFunc"]
