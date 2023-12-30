#!/bin/bash
set -e

PROJECT_ID="resec-cloud"

STORAGE_SA_NAME="storage-object-viewer" # Name for the new service account
STORAGE_SA_EMAIL="$STORAGE_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
STORAGE_SA_PRIVATE_KEY_FILE="storage-sa-private-key.json"

KMS_SA_EMAIL="321744876066-compute@developer.gserviceaccount.com"
KMS_SA_PRIVATE_KEY_FILE="kms-sa-private-key.json"

# Set the project
gcloud config set project $PROJECT_ID

function create_firewall_rule(){
    echo ""
    echo "Creating required firewall rules in GCP ..."
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
}
function create_service_account(){
    echo ""
    echo "Creating service account ..."

    # Check if the service account already exists
    if gcloud iam service-accounts list --filter="email:$STORAGE_SA_EMAIL" --format="value(email)" | grep -q "$STORAGE_SA_EMAIL"; then
        echo "Service account $STORAGE_SA_EMAIL already exists."
    else
        # Create the service account
        gcloud iam service-accounts create $STORAGE_SA_NAME --display-name "$STORAGE_SA_NAME"

        echo "Service account $STORAGE_SA_NAME created."

        # Assign roles to the service account (optional, based on your requirement)
        gcloud projects add-iam-policy-binding $PROJECT_ID --member "serviceAccount:$STORAGE_SA_EMAIL" --role "roles/storage.objectViewer"
    fi

    gcloud projects add-iam-policy-binding $PROJECT_ID --member "serviceAccount:$STORAGE_SA_EMAIL" --role "roles/storage.objectViewer"

    # Assign roles to the service account (optional, based on your requirement)
}

function create_bucket(){
    BUCKET_NAME="tsadok-test"
    gsutil iam ch "serviceAccount:$STORAGE_SA_EMAIL":legacyBucketReader "gs://$BUCKET_NAME"
}
    
function create_service_account_private_keys(){

    local credentials_dir="./../.credentials"
    mkdir -p "$credentials_dir"

    echo "Creating private key '$STORAGE_SA_PRIVATE_KEY_FILE' ..."
    gcloud iam service-accounts keys create $STORAGE_SA_PRIVATE_KEY_FILE --iam-account $STORAGE_SA_EMAIL

    mv --force "$STORAGE_SA_PRIVATE_KEY_FILE" "$credentials_dir"

    echo "Creating private key '$KMS_SA_PRIVATE_KEY_FILE' ..."
    gcloud iam service-accounts keys create "$KMS_SA_PRIVATE_KEY_FILE" --iam-account "$KMS_SA_EMAIL"
    mv --force "$KMS_SA_PRIVATE_KEY_FILE" "$credentials_dir"
}

COMMAND=$1
case $COMMAND in
    # "create-firewall-rule")
    #     create_firewall_rule
    #     ;;
    # "create-service-account")
    #     create_service_account
    #     ;;
    # "create-bucket")
    #     create_bucket
    #     ;;
    "create-sa-keys")
        create_service_account_private_keys
        ;;
    *)
        echo "Usage: $0 [create-firewall-rule|create-service-account|create-bucket|create-sa-keys]"
        exit 1
        ;;
esac
