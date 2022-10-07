#!/bin/bash

sleep 5

set_up_mysql(){
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'mlflow'@'%' IDENTIFIED BY 'mlflow'"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'mlflow'@'%' WITH GRANT OPTION"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE mlflowruns"
}

while !(set_up_mysql)
do
    sleep 3
    echo "waiting for mysql"
done

echo "Successfully setup database for mlflow"
