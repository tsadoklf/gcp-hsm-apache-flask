#!/bin/bash
set -e

BRANCH="main"
APP_DIR="gcp-hsm-apache-flask"

# backup the current folder
cp -r ${APP_DIR} ${APP_DIR}-$(date +%s)/

# remove the current folder
rm -r ${APP_DIR} || true

# get the latest version of the app
git clone https://github.com/tsadoklf/gcp-hsm-apache-flask.git@${BRANCH} ${APP_DIR}

# populate the certificate folder ???????
# cp -r ssl-certificates-lets-encrypt-prod/ gcp-hsm-apache-flask/.ssl

cp -r gcp-credentials/  ${APP_DIR}/.credentials/

# copy the latest certificates
CERTIFICATES_SRC_DIR="${APP_DIR}/.certificates/latest"
CERTIFICATES_DST_DIR="${APP_DIR}/.ssl"

cp ${CERTIFICATES_SRC_DIR}/hsm_resec_co.crt      ${CERTIFICATES_DST_DIR}/certificate.crt
cp ${CERTIFICATES_SRC_DIR}/ca-bundle-client.crt  ${CERTIFICATES_DST_DIR}/certificates-chain.crt

# Prepare the output folder
mkdir -p gcp-hsm-apache-flask/data 
# cp -r data/* gcp-hsm-apache-flask/data

# inside the app folder run the launch bash
cd gcp-hsm-apache-flask

# run the docker-compose down and up (in background)
./exec.sh down && ./exec.sh up-bg

# populate the update files folder from the remote server
if [[ "$1" == "skip" ]]; then
   echo "skipping file copy from Resec"
else
   cd ..
   ./getupdatelist.sh
fi

exit