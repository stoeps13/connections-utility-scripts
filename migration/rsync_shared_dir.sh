 #!/usr/bin/env bash

SOURCE_DIR=/mnt/connections-old/data
TARGET_DIR=/mnt/connections/data

DATE=$(date +%Y%m%d_%H%M)

cnx_dir=("activities/content" "blogs/upload" "dogear/favorite" "files/upload" "forums/content" "wikis/upload")

for i in "${cnx_dir[@]}"; do
   APP=$(echo $i | tr / _)
   echo $APP
   rsync --log-file=${DATE}-sync-${APP}.log  -azP ${SOURCE_DIR}/${i}/ ${TARGET_DIR}/${i}
done
