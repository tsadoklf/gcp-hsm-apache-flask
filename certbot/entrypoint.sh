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

function request_certificate(){
    echo ""
    echo "Requesting a certificate from Let's Encrypt ..."
    echo ""

    # Check if the USE_TEST_CERT environment variable is set to "true"
    if [[ "$USE_TEST_CERT" == "true" ]]; then
        CERTBOT_FLAGS="--test-cert"
    else
        CERTBOT_FLAGS=""
    fi

    # Path to the file you are waiting for
    file_path="$CERTIFICATE_SIGNING_REQUEST_FILE"

    # Loop until the file exists
    while [[ ! -f "$file_path" ]]; do
        echo "Waiting for file $file_path to exist..."
        sleep 5  # Number of seconds to wait before checking again
    done

    certbot certonly --apache "$CERTBOT_FLAGS" \
        --preferred-challenges http \
        --csr "$CERTIFICATE_SIGNING_REQUEST_FILE" \
        --register-unsafely-without-email \
        --agree-tos 
  
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

        # echo ""
        # echo "Restarting Apache with USE_CHAIN_FILE ..."
        # apachectl -D USE_CHAIN_FILE -k graceful

        # echo "Keeping Apache running in the foreground ..."
        # apachectl -D USE_CHAIN_FILE -D FOREGROUND
    else
        echo "Certificate issuance failed."
    fi
}

# function restart_apache(){
#     # echo "Restarting Apache ..."
#     # systemctl restart apache2
#     # apachectl start
#     echo "Starting Apache in the foreground ..."
#     apachectl -D FOREGROUND

#     echo "Apache configuration has been updated."
# }

request_certificate
