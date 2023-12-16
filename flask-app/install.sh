#!/bin/bash
set -e

echo ""
echo "Installing required Python libraries ..."
echo ""
sudo apt-get update && sudo apt-get install -y python3-pip
pip install -r requirements.txt
pip install --upgrade flask jinja2

echo ""
echo "Creating required firewall rules in GCP ..."
PROJECT_ID="resec-cloud"
FIREWALL_RULE_NAME="allow-port-5000" # Name for the new firewall rule
PORT="5000"                          # Port to be allowed through the firewall

# Check if the firewall rule already exists
if gcloud compute firewall-rules describe $FIREWALL_RULE_NAME --project $PROJECT_ID &> /dev/null; then
    echo ""
    echo "Firewall rule '$FIREWALL_RULE_NAME' already exists."
else
    # Create a firewall rule that allows inbound traffic on the specified port
    gcloud compute firewall-rules create $FIREWALL_RULE_NAME \
        --project $PROJECT_ID \
        --allow tcp:$PORT \
        --description "Allow incoming traffic on TCP port $PORT" \
        --direction INGRESS \
        --priority 1000

    echo ""
    echo "Firewall rule created to allow traffic on port $PORT"
fi

echo ""
echo "Creating service account ..."

SERVICE_ACCOUNT_NAME="storage-object-viewer" # Name for the new service account
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
KEY_FILE="service-account-keyfile.json"           # Path where the key file will be saved

export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"


# Set the project
gcloud config set project $PROJECT_ID

# Check if the service account already exists
if gcloud iam service-accounts list --filter="email:$SERVICE_ACCOUNT_EMAIL" --format="value(email)" | grep -q "$SERVICE_ACCOUNT_EMAIL"; then
    echo "Service account $SERVICE_ACCOUNT_EMAIL already exists."
else
    # Create the service account
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name "$SERVICE_ACCOUNT_NAME"

    echo "Service account $SERVICE_ACCOUNT_NAME created."

    # Assign roles to the service account (optional, based on your requirement)
    gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member "serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
       --role "roles/storage.objectViewer"

fi

    # Assign roles to the service account (optional, based on your requirement)
    gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member "serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
       --role "roles/storage.objectViewer"

BUCKET_NAME="tsadok-test"
gsutil iam ch "serviceAccount:$SERVICE_ACCOUNT_EMAIL":legacyBucketReader "gs://$BUCKET_NAME"

# Create a key for the service account
gcloud iam service-accounts keys create $KEY_FILE --iam-account $SERVICE_ACCOUNT_EMAIL

echo "Key created for service account $SERVICE_ACCOUNT_EMAIL and saved to $KEY_FILE."

echo "Creating another private key ..."
VM_SERVICE_ACCOUNT_EMAIL="321744876066-compute@developer.gserviceaccount.com"
VM_KEY_FILE="vm-service-account-private-key.json"

gcloud iam service-accounts keys create "$VM_KEY_FILE" --iam-account "$VM_SERVICE_ACCOUNT_EMAIL"
