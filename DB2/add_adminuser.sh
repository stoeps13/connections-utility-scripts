#!/bin/bash
#
# Author: Christoph Stoettner
# E-Mail: christoph.stoettner@stoeps.de

# get all databases of db2 instance
databases=$(db2 list database directory | grep alias | awk '{print $4}' | sort)

# Loop through list of databases:
for database in ${databases[@]}
do
 echo $database
 db2 "connect to %%a"
 db2 "GRANT DBADM ON DATABASE TO USER db2admin"
 db2 "commit"
 db2 "connect reset"
done
