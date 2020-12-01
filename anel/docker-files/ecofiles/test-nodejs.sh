#!/bin/bash

# Start the mysqld
mysqld

# Run the unit tests
FILTER=unit npm test
# Run the integration tests
# mysql -u root -e "CREATE DATABASE IF NOT EXISTS node_mysql_test"
#MYSQL_HOST=localhost MYSQL_PORT=3306 MYSQL_DATABASE=node_mysql_test MYSQL_USER=root MYSQL_PASSWORD= FILTER=integration npm test
