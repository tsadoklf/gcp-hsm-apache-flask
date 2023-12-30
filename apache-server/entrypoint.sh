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

SELF_SIGNED_CERTIFICATE="self-signed-certificate.crt"
CERTIFICATE_SIGNING_REQUEST_FILE="$APACHE_SSL_DIR/certificate-signing-request.csr"

CERT_FILE="$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
CERT_KEY_FILE="pkcs11:object=$KEY_NAME"
# CERT_KEY_FILE="pkcs11:id=$KEY_IDENTIFIER"
CERT_CHAIN_FILE="$APACHE_SSL_DIR/certificates-chain.pem"

# certificate information
COUNTRY_CODE="IL"
COMMON_NAME="$SERVER_NAME"
ORGANIZATION_NAME="Tsadok Ltd."
# "/C=US/ST=State/L=City/O=Organization Name/CN=www.example.com"
SUBJECT="/C=$COUNTRY_CODE/CN=$COMMON_NAME/O=$ORGANIZATION_NAME"

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

function create_apache_envvars(){
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
function request_certificate(){

    if [[ "$USE_TEST_CERT" == "true" ]]; then
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
        mv --force 0000_cert.pem "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"

        # The intermediate certificate(s) that help browsers and other clients 
        # trust the certificate by linking it to a trusted root certificate
        mv --force 0000_chain.pem "$APACHE_SSL_DIR/certificates-chain.pem"

        # This may be an alternative or additional chain file. 
        # Sometimes, Let's Encrypt provides different chain options for compatibility reasons
        # 0001_chain.pem
    else
        echo "Certificate issuance failed."
    fi
}

function create_self_signed_certificate(){

    local OPENSSL_SERVER_CERTIFICATE_CONFIG="openssl_server_certificate.config"
    echo ""
    echo "Generating self-signed certificate ..."
    echo ""    
    local KEY="pkcs11:object=$KEY_NAME"
    # local KEY="pkcs11:id=$KEY_IDENTIFIER"
    
    # openssl req -new -x509 -days 3650 -subj "$SUBJECT" -sha256 -engine pkcs11 -keyform engine -key "$KEY" -config "$OPENSSL_SERVER_CERTIFICATE_CONFIG" > "$SELF_SIGNED_CERTIFICATE" 

    # '/CN=localhost'
    # -keyout localhost.key
    openssl req -new -x509 -days 3650 \
        -engine pkcs11 -keyform engine -key "$KEY" \
        -out "$SELF_SIGNED_CERTIFICATE"  \
        -newkey rsa:2048 -nodes -sha256 \
        -subj "$SUBJECT" -extensions EXT \
        -config <( printf "[dn]\nCN=$COMMON_NAME\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$COMMON_NAME\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
}

function copy_self_signed_certificate(){
    echo ""
    echo "Copying self-signed certificate to $APACHE_SSL_DIR ..."
    echo ""

    mkdir -p "$APACHE_SSL_DIR"
    cp "$SELF_SIGNED_CERTIFICATE"  "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"

    chown root:root "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
    # chown 600 "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
    chmod 600 "$APACHE_SSL_DIR/$SELF_SIGNED_CERTIFICATE"
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
    # sudo a2enmod proxy
    # sudo a2enmod proxy_http
    a2enmod proxy
    a2enmod proxy_http

    echo ""
    echo "sudo a2ensite /etc/apache2/sites-available/$APACHE_CONFIG"
    # sudo a2ensite "$APACHE_CONFIG"
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

create_apache_envvars

create_self_signed_certificate
copy_self_signed_certificate

create_apache_config
enable_apache_modules_and_config
start_apache
verify_apache

create_certificate_signing_request
request_certificate

# echo ""
# echo "Restarting Apache with USE_CHAIN_FILE ..."
# apachectl -D USE_CHAIN_FILE -k graceful

# echo "Keeping Apache running in the foreground ..."
# apachectl -D USE_CHAIN_FILE -D FOREGROUND

stop_apache

echo "Starting Apache in the foreground ..."
exec "$@"
