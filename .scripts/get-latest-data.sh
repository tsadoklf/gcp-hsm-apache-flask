#!/bin/bash

APP_DATA_DIR="gcp-hsm-apache-flask/data"

# download the index page
rm index.html
wget https://update.resec.co/ -P /var/www/html/updates/

# Specify the path to the HTML file
html_file="/var/www/html/updates/index.html"

# Use cat to read the HTML content from the file and then use grep and sed to extract all href links
#href_list=$(cat "$html_file" | grep -oi 'href="/[^"]*"' | sed 's/href="\/\([^"]*\)"/\1/g')
file_list=$(cat "$html_file" | grep -oi 'HREF="/[^"]*"' | sed 's/HREF="\/\([^"]*\)"/\1/g')

# Print the list of href links
echo "$file_list"

# Loop through the file list and use wget to download each file
for file in $file_list
do
    # wget "https://update.resec.co/$file" -P /var/www/html/updates/buffer
    wget "https://update.resec.co/$file" -P ${APP_DATA_DIR}
done