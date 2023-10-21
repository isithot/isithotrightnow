# start from the public.ecr.aws/lambda/provided parent image,
# which provides the basic components necessary to serve a Lambda
FROM public.ecr.aws/lambda/provided

# set r version to install
ENV R_VERSION=4.2.2

# install r + system dependencies
RUN yum -y install wget git tar
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm

# set r installation destination
ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

# install system requirements for r packages
RUN yum -y install openssl-devel

# install r  packages
RUN Rscript -e "install.packages(c('httr', 'jsonlite', 'logger', 'remotes', 'tidyverse', 'systemfonts', 'aws.s3', 'lambdr', 'ggridges', 'plot3D'), repos = 'https://packagemanager.rstudio.com/all/__linux__/centos7/latest')"

# install fonts
COPY Roboto_Condensed/RobotoCondensed*.ttf /usr/share/fonts/

# copy r script(s) into container
RUN mkdir /lambda
COPY runtime.r /lambda
COPY util.r /lambda
RUN chmod 755 -R /lambda

# run lambdr + source functions
RUN printf '#!/bin/sh\ncd /lambda\nRscript runtime.r' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap

# function to run in this (this should be overridden with the name of another
# function in runtime.r using the "entrypoint" setting when configuring your
# lambda)
CMD ["defaultFunc"]
