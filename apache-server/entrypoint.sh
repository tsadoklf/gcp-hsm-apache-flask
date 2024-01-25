#!/bin/bash
set -e

echo ""
echo "---------------------------------------------"
echo "apache-server entrypoint.sh script"
echo "---------------------------------------------"

echo ""
echo "Checking the installed software versions ..."
echo "---------------------------------------------"
apache2 -v
openssl version

echo "PKCS11_LIB_VERSION: $PKCS11_LIB_VERSION"
cat /usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml



# gcloud kms keys versions describe 4 \
#     --location us-central1 \
#     --keyring resec-hsm-ring \
#     --key resec-hsm-key \
#     --project resec-cloud


echo ""
echo "---------------------------------------------"
echo "Testing the PKCS#11 engine initialization ..."
echo "---------------------------------------------"
# First, create a SHA256 digest of the message you want to sign.
# echo -n "your-message" | sha256sum | awk '{print $1}' > digest.txt
DIGEST=$(echo -n "your-message" | sha256sum | awk '{print $1}')
echo "$DIGEST" | while read -r hex; do printf "%b" "\\x${hex:0:2}\\x${hex:2:2}\\x${hex:4:2}\\x${hex:6:2}\\x${hex:8:2}\\x${hex:10:2}\\x${hex:12:2}\\x${hex:14:2}\\x${hex:16:2}\\x${hex:18:2}\\x${hex:20:2}\\x${hex:22:2}\\x${hex:24:2}\\x${hex:26:2}\\x${hex:28:2}\\x${hex:30:2}" > digest.bin; done

# Now, use the digest file in the gcloud command.
gcloud kms asymmetric-sign \
    --location us-central1 \
    --keyring resec-hsm-ring \
    --key resec-hsm-key \
    --version 4 \
    --digest-algorithm sha256 \
    --input-file=digest.bin \
    --signature-file=signature.bin \
    --project resec-cloud


echo ""
echo "---------------------------------------------"
echo "Testing the PKCS#11 engine initialization ..."
echo "Attempt to extract the public key from the specified PKCS#11 private key object"
echo "---------------------------------------------"
openssl pkey -engine pkcs11 -inform engine -in "pkcs11:object=resec-hsm-key;type=private" -pubout

echo ""


# SERVER_NAME="34.122.39.208"

# KEY_IDENTIFIER: an identifier for the key. 
# If you're using pkcs11:object, use the key's name—for example, KEY_NAME. 
# If you're using pkcs11:id, use the full resource ID of the key or key version—
# for example, projects/PROJECT_ID/locations/LOCATION/keyRings/KEY_RING/cryptoKeys/KEY_NAME/cryptoKeyVersions/KEY_VERSION.

[[ -z "$SERVER_NAME" ]] && "SERVER_NAME is empty" && exit 1

PROJECT_ID="resec-cloud"
LOCATION="us-central1"
KEY_RING="resec-hsm-ring"
KEY_NAME="resec-hsm-key"
KEY_VERSION="4"

KEY_IDENTIFIER="projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEY_RING/cryptoKeys/$KEY_NAME/cryptoKeyVersions/$KEY_VERSION"

echo ""
echo "---------------------------------------------"
echo "PROJECT_ID: $PROJECT_ID"
echo "LOCATION: $LOCATION"
echo "KEY_RING: $KEY_RING"
echo "KEY_NAME: $KEY_NAME"
echo "KEY_VERSION: $KEY_VERSION"
echo "KEY_IDENTIFIER: $KEY_IDENTIFIER"
echo "---------------------------------------------"

APACHE_SSL_DIR="/etc/apache2/ssl"

CERTIFICATE_FILE="certificate.crt"
CERTIFICATE_SIGNING_REQUEST_FILE="$APACHE_SSL_DIR/certificate-signing-request.csr"

CERT_FILE="$APACHE_SSL_DIR/$CERTIFICATE_FILE"

PRIVATE_KEY_FILE="private_key.pem"

# CERT_KEY_FILE="pkcs11:id=$KEY_IDENTIFIER"
CERT_KEY_FILE="pkcs11:object=$KEY_NAME"
# CERT_KEY_FILE="pkcs11:slot-id=0;object=resec-hsm-key;type=private"
# CERT_KEY_FILE="pkcs11:slot-id=0;id=70726f6a656374732f72657365632d636c6f75642f6c6f636174696f6e732f75732d63656e7472616c312f6b657952696e67732f72657365632d68736d2d72696e672f63727970746f4b6579732f72657365632d68736d2d6b65792f63727970746f4b657956657273696f6e732f34;type=private"


# CERT_KEY_FILE="pkcs11:object=$KEY_NAME;type=private"
# CERT_KEY_FILE="$PRIVATE_KEY_FILE"
# CERT_KEY_FILE="pkcs11:object=resec-hsm-key;type=private"



CERT_CHAIN_FILE="$APACHE_SSL_DIR/certificates-chain.crt"

# certificate information
COUNTRY_CODE="IL"
COMMON_NAME="$SERVER_NAME"
ORGANIZATION_NAME="Resec Technologies"
# "/C=US/ST=State/L=City/O=Organization Name/CN=www.example.com"
SUBJECT="/C=$COUNTRY_CODE/CN=$COMMON_NAME/O=$ORGANIZATION_NAME"

APACHE_GLOBAL_CONFIG="/etc/apache2/apache2.conf"

APACHE_CONFIG_TEMPLATE="/usr/src/config/apache/apache.config.templ"
APACHE_CONFIG="000-default.conf"
DOCUMENT_ROOT="$HOME/website"


function update_env_var() {
    local env_vars_file="$1"
    local var_name="$2"
    local var_value="$3"

    # Check if the variable definition exists in the file
    if grep -q "export $var_name=" "$env_vars_file"; then
        # Variable exists; update its value using sed
        sed -i "s#export $var_name=.*#export $var_name=\"$var_value\"#" "$env_vars_file"
    else
        # Variable does not exist; add it to the end of the file using tee
        echo "export $var_name=\"$var_value\"" | tee -a "$env_vars_file" >/dev/null
    fi
}

# function update_config(){
#     local config_file="$1"
#     local var_name="$2"
#     local var_value="$3"

#     # Check if the variable definition exists in the file
#     if grep -q "$var_name" "$config_file"; then
#         # Variable exists; update its value using sed
#         sed -i "s#$var_name .*#$var_name=\"$var_value\"#" "$config_file"
#     else
#         # Variable does not exist; add it to the end of the file using tee
#         echo "$var_name \"$var_value\"" | tee -a "$config_file" >/dev/null
#     fi
# }

function update_config(){
    local config_file="$1"
    local var_name="$2"
    local var_value="$3"

    if grep -q "^$var_name" "$config_file"; then
        sed -i "s#^$var_name .*#$var_name $var_value#" "$config_file"
    else
        echo "$var_name $var_value" | tee -a "$config_file" >/dev/null
    fi
}

function update_apache_global_config(){
    update_config "$APACHE_GLOBAL_CONFIG" "ServerName" "$SERVER_NAME"
    update_config "$APACHE_GLOBAL_CONFIG" "LogLevel" "ssl:trace5"

    echo ""
    echo "$APACHE_GLOBAL_CONFIG file"
    echo "-------------------------------------------------"
    cat $APACHE_GLOBAL_CONFIG
    echo "-------------------------------------------------"
}

# Without 
# PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so"

mkdir -p /var/log/kmsp11
chmod 777 /var/log/kmsp11


# With pkcs11-spy
export PKCS11_MODULE_PATH=/usr/lib/x86_64-linux-gnu/pkcs11-spy.so
export PKCS11SPY="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64/libkmsp11.so"
export PKCS11SPY_OUTPUT="/var/log/kmsp11/pkcs11-spy.log"

# export PKCS11_PROVIDER_DEBUG="/var/log/kmsp11/pkcs11-spy.debug,level=5"
export PKCS11_PROVIDER_DEBUG="file:/var/log/kmsp11/pkcs11-spy.debug,level=5"

echo "---------------------------------------------"
echo "Exdecuting pkcs11-tool --module $PKCS11_MODULE_PATH --list-slots"
echo "---------------------------------------------"
echo ""
echo "Listing the slots in the PKCS#11 token ..."
echo ""
pkcs11-tool --module $PKCS11_MODULE_PATH --list-slots

echo ""
echo "Listing the token slots in the PKCS#11 token ..."
echo ""
pkcs11-tool --module $PKCS11_MODULE_PATH --list-token-slots 

echo ""
echo "Listing the objects in the PKCS#11 token ..."
echo ""
pkcs11-tool --module $PKCS11_MODULE_PATH --list-objects 

# echo ""
# pkcs11-tool --module /usr/lib/x86_64-linux-gnu/pkcs11-spy.so --list-objects --id 70726f6a656374732f72657365632d636c6f75642f6c6f636174696f6e732f75732d63656e7472616c312f6b657952696e67732f72657365632d68736d2d72696e672f63727970746f4b6579732f72657365632d68736d2d6b65792f63727970746f4b657956657273696f6e732f34 --login

echo ""
echo "-------------------------------------------------------------"




# echo ""
# echo "-------------------------------------------------------------"
# echo "Testing the PKCS#11 engine initialization ..."
# echo "-------------------------------------------------------------"
# openssl engine -t -c -pre MODULE_PATH:$PKCS11_MODULE_PATH pkcs11

# echo ""
# echo "-------------------------------------------------------------"
# echo "Checking the full capabilities of the PKCS#11 engine ..."
# echo "-------------------------------------------------------------"
# openssl engine -c -pre MODULE_PATH:$PKCS11_MODULE_PATH pkcs11

# echo ""
# echo "-------------------------------------------------------------"
# echo "Listing the objects in the PKCS#11 token ..."
# echo "-------------------------------------------------------------"
# pkcs11-tool --module $PKCS11_MODULE_PATH --list-objects 

function update_apache_envvars(){
    local ENV_VARS_FILE="/etc/apache2/envvars"

    # local PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.2-linux-amd64/libkmsp11.so"
    # local PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so"
    
    local PKCS11_MODULE_PATH=/usr/lib/x86_64-linux-gnu/pkcs11-spy.so
    local PKCS11SPY="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64/libkmsp11.so"

    # export PKCS11SPY_OUTPUT="/path/to/pkcs11-spy.log"
    local PKCS11SPY_OUTPUT="/var/log/kmsp11/pkcs11-spy.log"
    # local PKCS11_PROVIDER_DEBUG="/var/log/kmsp11/pkcs11-spy.debug,level=5"
    local PKCS11_PROVIDER_DEBUG="file:/var/log/kmsp11/pkcs11-spy.debug,level=5"

    local KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml"

    local GRPC_ENABLE_FORK_SUPPORT=1
    local GOOGLE_APPLICATION_CREDENTIALS="/app/secrets/kms-sa-private-key.json"

    update_env_var "$ENV_VARS_FILE" PKCS11_MODULE_PATH "$PKCS11_MODULE_PATH"
    update_env_var "$ENV_VARS_FILE" PKCS11SPY "$PKCS11SPY"
    
    update_env_var "$ENV_VARS_FILE" PKCS11SPY_OUTPUT "$PKCS11SPY_OUTPUT"
    update_env_var "$ENV_VARS_FILE" PKCS11_PROVIDER_DEBUG "$PKCS11_PROVIDER_DEBUG"

    update_env_var "$ENV_VARS_FILE" KMS_PKCS11_CONFIG "$KMS_PKCS11_CONFIG"
    update_env_var "$ENV_VARS_FILE" GRPC_ENABLE_FORK_SUPPORT "1"
    update_env_var "$ENV_VARS_FILE" GOOGLE_APPLICATION_CREDENTIALS "$GOOGLE_APPLICATION_CREDENTIALS"

    echo ""
    echo "$ENV_VARS_FILE file"
    echo "-------------------------------------------------"
    cat $ENV_VARS_FILE
    echo "-------------------------------------------------"

    # echo ""
    # echo "Updating /etc/profile ..."
    # echo "-------------------------------------------------"
    # # echo "source $ENV_VARS_FILE" | tee -a /etc/profile >/dev/null
    # echo "export PKCS11_MODULE_PATH=$PKCS11_MODULE_PATH" | tee -a /etc/profile >/dev/null
    # echo "export KMS_PKCS11_CONFIG=$KMS_PKCS11_CONFIG" | tee -a /etc/profile >/dev/null
    # echo "export GRPC_ENABLE_FORK_SUPPORT=$GRPC_ENABLE_FORK_SUPPORT" | tee -a /etc/profile >/dev/null
    # echo "export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS" | tee -a /etc/profile >/dev/null
    
    # echo ""
    # echo "/etc/profile file"
    # echo "-------------------------------------------------"
    # cat /etc/profile

    # source /etc/profile
}

function verify_private_key() {
    local key_name="$1"

    echo ""
    echo "-------------------------------------------------------------"
    echo "Verifying the private key ..."
    echo "-------------------------------------------------------------"
    echo ""
    
    local data_file="data.txt"
    local hash_file="hash.bin"
    local signature_file="signature.bin"
    local public_key_file="/usr/local/bin/public-key.pem"

    # Create a simple file with some data to sign
    echo "Test data for signing" > "$data_file"

    # Hash the data using OpenSSL
    openssl dgst -sha256 -binary "$data_file" > "$hash_file"

    # Sign the hashed data using OpenSSL and the PKCS#11 engine (note the -rawin option to prevent padding the input data)
    # openssl pkeyutl -sign -engine pkcs11 -keyform engine -inkey "pkcs11:object=$key_name;type=private" -in "$hash_file" -out "$signature_file" -rawin
    openssl pkeyutl -sign -engine pkcs11 -keyform engine -inkey "$CERT_KEY_FILE" -in "$hash_file" -out "$signature_file" -rawin

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        if [ -s "$signature_file" ]; then
            echo "Private key '$key_name' is accessible and the data was signed successfully."         
            
            # Check public key and signature
            # echo "Public key:"
            # cat "$public_key_file"
            # echo "-------------------------------------------------------------"
            # openssl pkey -pubin -in "$public_key_file" -text -noout
            # echo "-------------------------------------------------------------"
            # hexdump "$signature_file"
            # echo "-------------------------------------------------------------"
            # hexdump "$hash_file"
            # echo "-------------------------------------------------------------"

            # Temporarily disable 'exit on error' for verification
            set +e

            echo ""
            echo "-------------------------------------------------------------"
            echo "Verifying the signature using the public key ..."
            echo "-------------------------------------------------------------"
            # pass the error and output to /dev/null
            # note the -rawin option to prevent padding the input data
            openssl pkeyutl -verify -pubin -inkey "$public_key_file" -sigfile "$signature_file" -in "$hash_file" -rawin > /dev/null 2>&1
            local exit_code=$?
            set -e

            if [ $exit_code -eq 0 ]; then
                echo "Signature verified successfully."
            else
                echo "Signature verification failed. Command failed with exit code $exit_code."
            fi

        else
            echo "Failed to sign the data. The private key may not be accessible."
        fi
    else
        echo "OpenSSL command failed with exit code $exit_code. Ensure the PKCS#11 engine, key URI, and digest algorithm are correct."
    fi

    # Clean up
    # rm -f "$data_file" "$hash_file" "$signature_file" "$public_key_file"
    rm -f "$data_file" "$hash_file" "$signature_file"
}

function create_certificate_signing_request(){
    echo ""
    echo "Creating a certificate signing request (CSR) ..."
    echo ""
    openssl req -new -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key pkcs11:object="$KEY_NAME" > "$CERTIFICATE_SIGNING_REQUEST_FILE" 
}

function create_certificate_signing_request_no_pkcs11(){
    echo ""
    echo "Creating a certificate signing request (CSR) without pkcs11..."
    echo ""
    openssl req -new -subj "$SUBJECT" -sha256 -key "$PRIVATE_KEY_FILE" > "$CERTIFICATE_SIGNING_REQUEST_FILE"
}

# https://hsm.resec.co/
function request_letsencrypt_certificate(){

    if [[ "$CERTIFICATE_AUTHORITY" == "letsencrypt-staging" ]]; then
        echo ""
        echo "Requesting a certificate from Let's Encrypt (staging) ..."
        echo ""
        certbot certonly --apache --test-cert \
            --preferred-challenges http \
            --csr "$CERTIFICATE_SIGNING_REQUEST_FILE" \
            --register-unsafely-without-email \
            --agree-tos 
    else
        echo ""
        echo "Requesting a certificate from Let's Encrypt (production) ..."
        echo ""
        certbot certonly --apache \
            --preferred-challenges http \
            --csr "$CERTIFICATE_SIGNING_REQUEST_FILE" \
            --register-unsafely-without-email \
            --agree-tos 
    fi
  
    if [[ $? -eq 0 ]]; then
        echo ""
        echo "Certificate successfully issued."

        ls -l

        echo""
        echo "Moving certificate files to $APACHE_SSL_DIR ..."

        # The primary certificate file for the domain
        mv --force 0000_cert.pem "$APACHE_SSL_DIR/$CERTIFICATE_FILE"

        # The intermediate certificate(s) that help browsers and other clients 
        # trust the certificate by linking it to a trusted root certificate
        mv --force 0000_chain.pem "$APACHE_SSL_DIR/certificates-chain.crt"

        # This may be an alternative or additional chain file. 
        # Sometimes, Let's Encrypt provides different chain options for compatibility reasons
        # 0001_chain.pem
    else
        echo "Certificate issuance failed."
    fi
}

function verify_certificate_signing_request(){

    local hsm_public_key_file="$APACHE_SSL_DIR/hsm-public-key.pem"
    local csr_public_key_file="$APACHE_SSL_DIR/csr-public-key.pem"
    
    # gcloud kms keys versions get-public-key "$KEY_VERSION" \
    #     --location "$LOCATION" \
    #     --keyring "$KEY_RING" \
    #     --key "$KEY_NAME" \
    #     --output-file "$hsm_public_key_file"

    # openssl pkey -in "$hsm_public_key_file" -pubin -text

    echo ""
    echo "Creating a public key from the certificate signing request ..."
    openssl req -in "$CERTIFICATE_SIGNING_REQUEST_FILE" -noout -pubkey -out "$csr_public_key_file"

    echo ""
    echo "Public key from the certificate signing request:"
    cat "$csr_public_key_file"

    echo ""
    echo "Verifying the public key from the certificate signing request ..."
    openssl pkey -in "$csr_public_key_file" -pubin -text
}

function create_self_signed_certificate(){

    echo ""
    echo "Generating self-signed certificate ..."
    echo "" 

    # local KEY="pkcs11:object=$KEY_NAME"
    # local KEY="pkcs11:id=$KEY_IDENTIFIER"
    local KEY="$CERT_KEY_FILE"
    
    # local OPENSSL_SERVER_CERTIFICATE_CONFIG="openssl_server_certificate.config"
    # openssl req -new -x509 -days 3650 -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key "$KEY" -config "$OPENSSL_SERVER_CERTIFICATE_CONFIG" > "$CERTIFICATE_FILE" 

    # '/CN=localhost'
    # -keyout localhost.key
    openssl req -new -x509 -days 3650 \
        -engine pkcs11 -keyform engine -key "$KEY" \
        -out "$CERTIFICATE_FILE"  \
        -newkey rsa:2048 -nodes -sha256 \
        -subj "$SUBJECT" -extensions EXT \
        -config <( printf "[dn]\nCN=$COMMON_NAME\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$COMMON_NAME\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
}

function create_private_key(){
    echo ""
    echo "Generating a new private key ..."
    echo ""
    
    openssl genpkey -algorithm RSA -out "$PRIVATE_KEY_FILE" -pkeyopt rsa_keygen_bits:2048
}

function create_self_signed_certificate_no_pkcs11(){

    echo ""
    echo "Generating self-signed certificate with private key ..."
    echo ""
    
    openssl req -new -x509 -days 3650 \
        -key "$PRIVATE_KEY_FILE" \
        -out "$CERTIFICATE_FILE" \
        -sha256 \
        -subj "$SUBJECT" -extensions EXT \
        -config <( printf "[dn]\nCN=$COMMON_NAME\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$COMMON_NAME\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")

}

function copy_self_signed_certificate(){
    echo ""
    echo "-------------------------------------------------------------"
    echo "Copying self-signed certificate to $APACHE_SSL_DIR ..."
    echo "-------------------------------------------------------------"

    mkdir -p "$APACHE_SSL_DIR"

    echo "Copying '$CERTIFICATE_FILE' to '$APACHE_SSL_DIR/$CERTIFICATE_FILE' ..."
    cp "$CERTIFICATE_FILE"  "$APACHE_SSL_DIR/$CERTIFICATE_FILE"

    # Copy the private key to the Apache SSL directory (if it's not pkcs11 object)
    # if [[ "$CERT_KEY_FILE" == "private_key.pem" ]]; then
    if [[ "$USE_PRIVATE_KEY" == "true" ]]; then
        echo "Copying '$PRIVATE_KEY_FILE' to '$APACHE_SSL_DIR/$PRIVATE_KEY_FILE' ..."
        cp "$PRIVATE_KEY_FILE" "$APACHE_SSL_DIR/$PRIVATE_KEY_FILE"
        chown root:root "$APACHE_SSL_DIR/$PRIVATE_KEY_FILE"
    fi

    # if [[ -f "$CERT_CHAIN_FILE" ]]; then
    #     cp "$CERT_CHAIN_FILE" "$APACHE_SSL_DIR/$CERT_CHAIN_FILE"
    # fi

    chown root:root "$APACHE_SSL_DIR/$CERTIFICATE_FILE"
    # chown 600 "$APACHE_SSL_DIR/$CERTIFICATE_FILE"
    chmod 600 "$APACHE_SSL_DIR/$CERTIFICATE_FILE"
}

function create_apache_config(){
    echo ""
    echo "Updating Apache config ..."

    local FLASK_APP="http://flask-app:5000/"

    sed  -e "s|{{CERT_FILE}}|$CERT_FILE|g" \
         -e "s|{{CERT_KEY_FILE}}|$CERT_KEY_FILE|g" \
         -e "s|{{CERT_CHAIN_FILE}}|$CERT_CHAIN_FILE|g" \
         -e "s|{{SERVER_NAME}}|$SERVER_NAME|g" \
         -e "s|{{DOCUMENT_ROOT}}|$DOCUMENT_ROOT|g" \
         -e "s|{{FLASK_APP}}|$FLASK_APP|g" \
         "$APACHE_CONFIG_TEMPLATE" > "$APACHE_CONFIG"

    echo ""
    echo "Apache config '$APACHE_CONFIG' "
    cat "$APACHE_CONFIG"

    # Copy the generated configuration to Apache's configuration directory
    cp "$APACHE_CONFIG" "/etc/apache2/sites-available/$APACHE_CONFIG"
    chmod 644 "/etc/apache2/sites-available/$APACHE_CONFIG"
}

function enable_apache_modules_and_config(){
    echo ""
    echo "Enabling the SSL module and the virtual host configuration"
    # sudo a2enmod ssl
    a2enmod ssl

    echo ""
    echo "Enabling the 'mod_proxy' module in Apache ..."
    a2enmod proxy
    a2enmod proxy_http

    echo ""
    echo "a2ensite $APACHE_CONFIG"
    a2ensite "$APACHE_CONFIG"

    echo ""
    echo "---------------------------------------------"
    echo "Checking the installed Apache modules ..."
    echo "---------------------------------------------"
    # apachectl -M
    apachectl -M | grep ssl
}
function start_apache(){
    # echo "Restarting Apache ..."
    # systemctl restart apache2
    # service apache2 restart
    
    echo "Starting Apache in the background (temporarily) ..."
    apachectl start
    
    # echo "Starting Apache in the foreground ..."
    # apachectl -D FOREGROUND
}
function stop_apache(){
    echo "Stopping Apache  ..."
    apachectl stop
}
function verify_apache(){
    # ls -la "$APACHE_SSL_DIR"

    echo ""
    echo "Checking Apache configuration ..."
    echo ""
    # sudo systemctl status apache2
    apachectl configtest
}

function validate_env_vars(){
    if [[ -z "$SERVER_NAME" ]]; then
        echo ""
        echo "ERROR: SERVER_NAME is empty."
        echo ""
        exit 1
    fi

    if [[ -z "$CERTIFICATE_AUTHORITY" ]]; then
        echo ""
        echo "ERROR: CERTIFICATE_AUTHORITY is empty."
        echo ""
        exit 1
    fi

    if [[ "$CERTIFICATE_AUTHORITY" != "self-signed" && "$CERTIFICATE_AUTHORITY" != "letsencrypt-staging" && "$CERTIFICATE_AUTHORITY" != "letsencrypt-production" && "$CERTIFICATE_AUTHORITY" != "comodo-production" ]]; then
        echo ""
        echo "ERROR: CERTIFICATE_AUTHORITY must be one of the following: 'self-signed', 'letsencrypt-staging', 'letsencrypt-production' or 'comodo-production'."
        echo ""
        exit 1
    fi

    if [[ "$SERVER_NAME" == "localhost" && "$CERTIFICATE_AUTHORITY" != "self-signed" ]]; then
        echo ""
        echo "ERROR: SERVER_NAME cannot be 'localhost' when using a certificate authority other than 'self-signed'."
        echo ""
        exit 1
    fi
}

# function create_certificate(){

#     case "$CERTIFICATE_AUTHORITY" in
#         "letsencrypt-staging"|"letsencrypt-production")
#             # create_certificate_signing_request
#             create_certificate_signing_request_no_pkcs11
#             request_letsencrypt_certificate
#             ;;
#         "self-signed")
#             echo ""
#             echo "Using a self-signed certificate ..."
#             echo ""
#             # create_self_signed_certificate
#             create_self_signed_certificate_no_pkcs11
#             copy_self_signed_certificate
#             ;;
#         *)
#             echo "Usage: $0 [letsencrypt-staging|letsencrypt-production|self-signed]"
#             exit 1
#             ;;
#     esac
# }

verify_private_key "$KEY_NAME"

# create_certificate_signing_request
# verify_certificate_signing_request

# exit 0

validate_env_vars
update_apache_global_config
update_apache_envvars

if [[ "$USE_PRIVATE_KEY" == "true" ]]; then
    create_private_key
    CERT_KEY_FILE="$APACHE_SSL_DIR/$PRIVATE_KEY_FILE"
fi

# create_apache_config


enable_apache_modules_and_config

create_certificate_signing_request
verify_certificate_signing_request




# Check if the certificate (/etc/apache2/ssl/certificate.crt) exists
# If it does not exist, create a self-signed certificate
if [[ "$FORCE_RECREATE_CERTIFICATE" == "true" || ! -f "$CERT_FILE" ]]; then

    if [ ! -f "$CERT_FILE" ]; then
        echo "-------------------------------------------------------------"
        echo "Certificate does not exists. Creating self signed certificate ..."
        echo "-------------------------------------------------------------"
    else 
        echo "-------------------------------------------------------------"
        echo "FORCE_RECREATE_CERTIFICATE is set to 'true'. Recreating self signed certificate ..."
        echo "-------------------------------------------------------------"
    fi

    if [[ "$USE_PKCS11_ENGINE" == "true" ]]; then
        echo "Creating a self-signed certificate with PKCS#11 engine ..."
        create_self_signed_certificate
    else
        echo "Creating a self-signed certificate without PKCS#11 engine ..."
        create_self_signed_certificate_no_pkcs11
    fi
    copy_self_signed_certificate
    # SELF_SIGNED_CERTIFICATE_CREATED="true"

    create_apache_config

    start_apache
    verify_apache

    # If the certificate is self-signed, exit
    # If the certificate is not self-signed, create a certificate signing request and request a certificate from Let's Encrypt
    
    #  case "$CERTIFICATE_AUTHORITY" in
    # "letsencrypt-staging"|"letsencrypt-production")
    if [[ "$CERTIFICATE_AUTHORITY" == "letsencrypt-staging" || "$CERTIFICATE_AUTHORITY" == "letsencrypt-production" ]]; then

        if [[ "$USE_PKCS11_ENGINE" == "true" ]]; then
            create_certificate_signing_request
        else
            create_certificate_signing_request_no_pkcs11
        fi
        request_letsencrypt_certificate
        
    fi
    stop_apache
fi

if [[ ! -z "$CERTIFICATE_SIGNING_REQUEST_FILE" && -f "$CERTIFICATE_SIGNING_REQUEST_FILE" ]]; then
    echo ""
    echo "Verifying certificate signing request ..."
    verify_certificate_signing_request
fi

verify_apache

case "$CERTIFICATE_AUTHORITY" in 
    "letsencrypt-staging"|"letsencrypt-production")
        echo -e "\nStarting Apache in the foreground with a certificate from Let's Encrypt."
        # exec apachectl -D FOREGROUND -D USE_CHAIN_FILE
        exec apachectl -D FOREGROUND 
        ;;
    "comodo-production" )
        echo -e "\nStarting Apache in the foreground with a certificate from Comodo."
        exec apachectl -D FOREGROUND -D USE_CHAIN_FILE
        ;;
    "self-signed")
        echo -e "\nStarting Apache in the foreground with a self-signed certificate."
        exec apachectl -D FOREGROUND 
        ;;
    *)
        echo "Usage: $0 [letsencrypt-staging|letsencrypt-production|self-signed|comodo-production]"
        exit 1
        ;;
esac


