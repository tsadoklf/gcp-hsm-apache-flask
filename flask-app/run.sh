#!/bin/bash
set -e

export GOOGLE_APPLICATION_CREDENTIALS="service-account-keyfile.json"


# export GOOGLE_APPLICATION_CREDENTIALS="$HOME/website/vm-service-account-private-key.json"

GCP_BUCKET_NAME="tsadok-test"
STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY="$HOME/website/service-account-keyfile.json"

echo "GCP_BUCKET_NAME=$GCP_BUCKET_NAME" > .env
echo "STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY=$STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY" >> .env
echo "APP_HOST=localhost" >> .env
echo "APP_PORT=5000" >> .env

python3 app.py
