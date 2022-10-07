FROM ubuntu/mysql:8.0-20.04_beta
MAINTAINER Ben Wang

ENV TZ=UTC
ENV MYSQL_ROOT_PASSWORD=root

COPY setup_db.sh /
#COPY wait_for_mysql.sh /