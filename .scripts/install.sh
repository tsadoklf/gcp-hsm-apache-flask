#!/bin/bash
set -e

APP_GIT_REPOSITORY="https://github.com/tsadoklf/gcp-hsm-apache-flask.git"
APP_GIT_BRANCH="main"

APP_DIR="gcp-hsm-apache-flask"
APP_DATA_DIR="${APP_DIR}/data"

if [ -d "${APP_DIR}" ]; then
    APP_BACKUP_DIR="gcp-hsm-apache-flask-backup-$(date +%Y%m%d%H%M%S)"
    echo "Backing up the current version of the app to ${APP_BACKUP_DIR}..."
    cp -r ${APP_DIR} ${APP_BACKUP_DIR} 

    echo "Removing the current version of the app..."
    rm -r ${APP_DIR} || true
fi

# get the latest version of the app
git clone --branch ${APP_GIT_BRANCH} ${APP_GIT_REPOSITORY} ${APP_DIR}

# populate the certificate folder ???????
# cp -r ssl-certificates-lets-encrypt-prod/ gcp-hsm-apache-flask/.ssl

cp -r gcp-credentials/  ${APP_DIR}/.credentials/

# copy the latest certificates
CERTIFICATES_SRC_DIR="${APP_DIR}/.certificates/latest"
CERTIFICATES_DST_DIR="${APP_DIR}/.ssl"

cp ${CERTIFICATES_SRC_DIR}/hsm_resec_co.crt      ${CERTIFICATES_DST_DIR}/certificate.crt
cp ${CERTIFICATES_SRC_DIR}/ca-bundle-client.crt  ${CERTIFICATES_DST_DIR}/certificates-chain.crt

mkdir -p ${APP_DATA_DIR}

if [[ "$1" == "skip" ]]; then
   echo "Skipping getting the latest data from Resec. Copying the data from the local data folder..."
   cp -r data/* ${APP_DATA_DIR}/
else
    echo "Getting the latest data from Resec..."
    chmod +x get-latest-data.sh && ./get-latest-data.sh
fi

# inside the app folder run the launch bash
cd gcp-hsm-apache-flask && ./exec.sh down && ./exec.sh up-bg

# exit