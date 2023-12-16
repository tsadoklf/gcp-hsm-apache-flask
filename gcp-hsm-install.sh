#!/bin/bash
set -e

function update_env_var() {
    local env_vars_file="$1"
    local var_name="$2"
    local var_value="$3"

    # Check if the variable definition exists in the file
    if grep -q "export $var_name=" "$env_vars_file"; then
        # Variable exists; update its value using sed
        sudo sed -i "s#export $var_name=.*#export $var_name=\"$var_value\"#" "$env_vars_file"
    else
        # Variable does not exist; add it to the end of the file using tee
        echo "export $var_name=\"$var_value\"" | sudo tee -a "$env_vars_file" >/dev/null
    fi
}

echo PKCS11_MODULE_PATH: $PKCS11_MODULE_PATH
echo KMS_PKCS11_CONFIG: $KMS_PKCS11_CONFIG

export GRPC_ENABLE_FORK_SUPPORT=1

echo GRPC_ENABLE_FORK_SUPPORT: $GRPC_ENABLE_FORK_SUPPORT

ENV_VARS_FILE="/etc/apache2/envvars"

# echo "export PKCS11_MODULE_PATH=\"$PKCS11_MODULE_PATH\"" | sudo tee -a $ENV_VARS_FILE
# echo "export KMS_PKCS11_CONFIG=\"$KMS_PKCS11_CONFIG\"" | sudo tee -a $ENV_VARS_FILE
# echo "export GRPC_ENABLE_FORK_SUPPORT=1" | sudo tee -a $ENV_VARS_FILE
# echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$HOME/website/vm-service-account-private-key.json\"" | sudo tee -a $ENV_VARS_FILE

update_env_var "$ENV_VARS_FILE" PKCS11_MODULE_PATH "$PKCS11_MODULE_PATH"
update_env_var "$ENV_VARS_FILE" KMS_PKCS11_CONFIG "$KMS_PKCS11_CONFIG"
update_env_var "$ENV_VARS_FILE" GRPC_ENABLE_FORK_SUPPORT "1"
# update_env_var "$ENV_VARS_FILE" GOOGLE_APPLICATION_CREDENTIALS "$HOME/website/vm-service-account-private-key.json"


echo 
echo "ENV_VARS_FILE"
cat $ENV_VARS_FILE

KEY_VERSION="4"
LOCATION="us-central1"
KEY_RING="resec-hsm-ring"
KEY="resec-hsm-key"
PUBLIC_KEY_FILE="public-key.pem"

function test_kms(){
        gcloud kms keys versions get-public-key "$KEY_VERSION" --location "$LOCATION" --keyring "$KEY_RING" --key "$KEY" --output-file "$PUBLIC_KEY_FILE"

        INPUT_FILE_NAME="my-plain-text-file.txt"
        echo "TSADOK WAS HERE" > "$INPUT_FILE_NAME"

        # openssl dgst -sha256 -engine pks11 -keyfrom engine -sign pkcs11:object=hsm-sign "$INPUT_FILE_NAME"

        # openssl dgst -sha256 -engine pkcs11 -keyform engine -sign "pkcs11:module=/path/to/pkcs11.so;token-label=my-key" -out signature.bin -in data.txt

        SIGNATURE_FILE="signature.bin"
        gcloud kms asymmetric-sign --location "$LOCATION" --keyring "$KEY_RING" --key "$KEY" --version "$KEY_VERSION" --input-file "$INPUT_FILE_NAME" --signature-file "$SIGNATURE_FILE"

        VERIFICATION_INPUT_FILE=$INPUT_FILE_NAME
        VERIFICATION_SIGNATIRE_FILE=$SIGNATURE_FILE

        openssl dgst -sha256 -verify "$PUBLIC_KEY_FILE" -signature "$SIGNATURE_FILE" -out verified_data.txt "$INPUT_FILE_NAME"


        echo ""
        echo "Creating a signature using openssl ..."
        echo ""
        openssl dgst -sha256 -engine pkcs11 -keyform engine -sign pkcs11:object="$KEY" -out my-signaure.bin "$INPUT_FILE_NAME"
}
function create_certificate_signing_request(){
        echo ""
        echo "Creating a certificate signing request (CSR) ..."
        echo ""

        CERTIFICATE_SIGNING_REQUEST_FILE="my-signing-request.csr"
        SUBJECT="/CN=test/"
        openssl req -new -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key pkcs11:object="$KEY" > "$CERTIFICATE_SIGNING_REQUEST_FILE" 
}

echo ""
echo "Generating self-signed certificate ..."
echo ""

HOST_NAME_OR_IP_ADDRESS="34.122.39.208"

SELF_SIGNED_CERTIFICATE="my-self-signed-certificate.crt"
COMMON_NAME="$HOST_NAME_OR_IP_ADDRESS"
SUBJECT="/CN=$COMMON_NAME/"
openssl req -new -x509 -days 3650 -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key "pkcs11:object=$KEY" -config openssal_server_cert.cnf > "$SELF_SIGNED_CERTIFICATE" 

echo ""
echo "Copying self-signed certificate to ..."
echo ""

APACHE_SSL_DIR="/etc/apache2/ssl"
sudo mkdir -p "$APACHE_SSL_DIR"
sudo cp "$SELF_SIGNED_CERTIFICATE"  "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"

sudo chown root:root "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
sudo chown 600 "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"

echo ""
echo "Updating Apache config ..."

# Replace placeholders in the template with environment variable values
CERT_FILE="$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
KEY_FILE="pkcs11:object=$KEY"

APACHE_CONFIG_TEMPLATE="apache.config.templ"
APACHE_CONFIG="tsadok.conf"
SERVER_NAME="34.122.39.208"
DOCUMENT_ROOT="$HOME/website"

sed -e "s|{{CERT_FILE}}|$CERT_FILE|g" -e "s|{{KEY_FILE}}|$KEY_FILE|g" -e "s|{{SERVER_NAME}}|$SERVER_NAME|g" -e "s|{{DOCUMENT_ROOT}}|$DOCUMENT_ROOT|g" "$APACHE_CONFIG_TEMPLATE" > "$APACHE_CONFIG"

echo ""
echo "Apache config '$APACHE_CONFIG' "
cat "$APACHE_CONFIG"

# Copy the generated configuration to Apache's configuration directory
sudo cp "$APACHE_CONFIG" "/etc/apache2/sites-available/$APACHE_CONFIG"
sudo chmod 644 "/etc/apache2/sites-available/$APACHE_CONFIG"

echo ""
echo "Enabling the SSL module and the virtual host configuration"
sudo a2enmod ssl

echo ""
echo "Enabling the 'mod_proxy' module in Apache ..."
sudo a2enmod proxy
sudo a2enmod proxy_http

echo ""
echo "sudo a2ensite /etc/apache2/sites-available/$APACHE_CONFIG"
sudo a2ensite "$APACHE_CONFIG"

echo "Restarting Apache ..."
sudo systemctl restart apache2

echo "Apache configuration has been updated."


ls -la "$APACHE_SSL_DIR"

echo ""
echo "Checking Apache configuration ..."
echo ""
# sudo systemctl status apache2
sudo apachectl configtest


exit 0

gcloud kms asymmetric-verify \
          --location "$LOCATION" \
          --keyring "$KEY_RING" \
          --key "$KEY" \
          --version "$KEY_VERSION" \
          --input-file "$VERIFICATION_INPUT_FILE" \
          --signature-file "$VERIFICATION_SIGNATURE_FILE"


exit 0
gcloud kms asymmetric-decrypt \
           --location "$LOCATION" \
              --keyring "$KEY_RING" \
                 --key "$KEY" \
                    --version "$KEY_VERSION" \
                       --ciphertext-file encrypted_data.bin \
                          --plaintext-file decrypted_data.txt
