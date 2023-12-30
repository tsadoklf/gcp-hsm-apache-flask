#!/bin/sh

# Generate the .env file
# GCP_BUCKET_NAME="tsadok-test"
# STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY="/app/secrets/storage-sa-private-key.json"

# echo "GCP_BUCKET_NAME=$GCP_BUCKET_NAME" > .env
# echo "STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY=$STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY" >> .env
# echo "APP_HOST=0.0.0.0" >> .env
# echo "APP_PORT=5000" >> .env

# cat .env

# Execute the given command from the CMD directive in Dockerfile
exec "$@"
