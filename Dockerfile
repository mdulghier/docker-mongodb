FROM ubuntu:latest
MAINTAINER Markus Dulghier <markus@dulghier.com>

# Add 10gen official apt source to the sources list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | tee /etc/apt/sources.list.d/mongodb.list

# Install MongoDB
RUN apt-get update
RUN apt-get install mongodb-org-server mongodb-org-shell

# Create the MongoDB data directory
RUN mkdir -p /data/db

# Use custom mongod.conf with authentication enabled
ADD ./mongod.conf /etc/mongod.conf
ADD ./run.sh /tmp/run.sh
RUN chmod 755 /tmp/run.sh

EXPOSE 27017
ENTRYPOINT ["/tmp/run.sh"]
