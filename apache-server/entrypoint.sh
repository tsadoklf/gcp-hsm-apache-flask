#!/bin/bash
set -e

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

APACHE_SSL_DIR="/etc/apache2/ssl"

CERTIFICATE_FILE="certificate.crt"
CERTIFICATE_SIGNING_REQUEST_FILE="$APACHE_SSL_DIR/certificate-signing-request.csr"

CERT_FILE="$APACHE_SSL_DIR/$CERTIFICATE_FILE"
CERT_KEY_FILE="pkcs11:object=$KEY_NAME"
# CERT_KEY_FILE="pkcs11:id=$KEY_IDENTIFIER"
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

KEY_IDENTIFIER="projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEY_RING/cryptoKeys/$KEY_NAME/cryptoKeyVersions/$KEY_VERSION"

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

function update_config(){
    local config_file="$1"
    local var_name="$2"
    local var_value="$3"

    # Check if the variable definition exists in the file
    if grep -q "$var_name" "$config_file"; then
        # Variable exists; update its value using sed
        sed -i "s#$var_name .*#$var_name=\"$var_value\"#" "$config_file"
    else
        # Variable does not exist; add it to the end of the file using tee
        echo "$var_name \"$var_value\"" | tee -a "$config_file" >/dev/null
    fi
}

function update_apache_global_config(){
    # commented as it seems to be already defined in the config
    #  update_config "$APACHE_GLOBAL_CONFIG" "ServerName" "$SERVER_NAME"
    update_config "$APACHE_GLOBAL_CONFIG" "LogLevel" "debug"
}

function update_apache_envvars(){
    local ENV_VARS_FILE="/etc/apache2/envvars"

    # local PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.2-linux-amd64/libkmsp11.so"
    local PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so"
    local KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml"
    local GRPC_ENABLE_FORK_SUPPORT=1
    local GOOGLE_APPLICATION_CREDENTIALS="/app/secrets/kms-sa-private-key.json"

    update_env_var "$ENV_VARS_FILE" PKCS11_MODULE_PATH "$PKCS11_MODULE_PATH"
    update_env_var "$ENV_VARS_FILE" KMS_PKCS11_CONFIG "$KMS_PKCS11_CONFIG"
    update_env_var "$ENV_VARS_FILE" GRPC_ENABLE_FORK_SUPPORT "1"
    update_env_var "$ENV_VARS_FILE" GOOGLE_APPLICATION_CREDENTIALS "$GOOGLE_APPLICATION_CREDENTIALS"

    echo ""
    echo "$ENV_VARS_FILE file"
    echo "-------------------------------------------------"
    cat $ENV_VARS_FILE

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

function create_certificate_signing_request(){
    echo ""
    echo "Creating a certificate signing request (CSR) ..."
    echo ""
    openssl req -new -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key pkcs11:object="$KEY_NAME" > "$CERTIFICATE_SIGNING_REQUEST_FILE" 
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

    openssl req -in "$CERTIFICATE_SIGNING_REQUEST_FILE" -noout -pubkey -out "$csr_public_key_file"
    openssl pkey -in "$csr_public_key_file" -pubin -text
}

function create_self_signed_certificate(){

    local OPENSSL_SERVER_CERTIFICATE_CONFIG="openssl_server_certificate.config"
    echo ""
    echo "Generating self-signed certificate ..."
    echo ""    
    local KEY="pkcs11:object=$KEY_NAME"
    # local KEY="pkcs11:id=$KEY_IDENTIFIER"
    
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

function copy_self_signed_certificate(){
    echo ""
    echo "Copying self-signed certificate to $APACHE_SSL_DIR ..."
    echo ""

    mkdir -p "$APACHE_SSL_DIR"
    cp "$CERTIFICATE_FILE"  "$APACHE_SSL_DIR/$CERTIFICATE_FILE"

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
}
function start_apache(){
    # echo "Restarting Apache ..."
    # systemctl restart apache2
    
    echo "Starting Apache in the background (temporarily) ..."
    apachectl start
    
    # echo "Starting Apache in the foreground ..."
    # apachectl -D FOREGROUND

    # echo "Apache configuration has been updated."
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

function create_certificate(){

    case "$CERTIFICATE_AUTHORITY" in
        "letsencrypt-staging"|"letsencrypt-production")
            create_certificate_signing_request
            request_letsencrypt_certificate
            ;;
        "self-signed")
            echo ""
            echo "Using a self-signed certificate ..."
            echo ""
            create_self_signed_certificate
            copy_self_signed_certificate
            ;;
        *)
            echo "Usage: $0 [letsencrypt-staging|letsencrypt-production|self-signed]"
            exit 1
            ;;
    esac
}

validate_env_vars
update_apache_global_config
update_apache_envvars
create_apache_config
enable_apache_modules_and_config

# Check if the certificate (/etc/apache2/ssl/certificate.crt) exists
# If it does not exist, create a self-signed certificate
if [ ! -f "$CERT_FILE" ]; then
    echo "Certificate does not exists. Creating self signed certificate ..."
    create_self_signed_certificate
    copy_self_signed_certificate
    SELF_SIGNED_CERTIFICATE_CREATED="true"

    start_apache
    verify_apache

    # If the certificate is self-signed, exit
    # If the certificate is not self-signed, create a certificate signing request and request a certificate from Let's Encrypt
    create_certificate
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
        exec apachectl -D FOREGROUND -D USE_CHAIN_FILE
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


