FROM python:3.8
USER root

RUN apt-get update --allow-unauthenticated && apt-get install -y \
    apache2 \
    apache2-dev \
    ssl-cert \
    libengine-pkcs11-openssl \
    libpkcs11-helper1 \
    wget \
    curl \
    tar \
    certbot \
    python3-certbot-apache \
    opensc

RUN pip install mod_wsgi

# Enable SSL module
RUN a2enmod ssl

# Enable Headers module
RUN a2enmod headers

# Install mod_wsgi
RUN mod_wsgi-express install-module > /etc/apache2/mods-available/wsgi.load

ENV PKCS11_LIB_VERSION "1.6"
# ENV ENV_PKCS11_LIB_VERSION=$PKCS11_LIB_VERSION
ENV LIBKMSP_DIR="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64"
                                                             
# RUN curl -L -o libkmsp11-1.3-linux-amd64.tar.gz https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz
# RUN wget https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz && \
RUN wget "https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v${PKCS11_LIB_VERSION}/libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64.tar.gz" && \
    tar -xzvf "libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64.tar.gz" && \
    mkdir -p "${LIBKMSP_DIR}/" && \
    mv "libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64/libkmsp11.so" "${LIBKMSP_DIR}/" && \
    rm -rf "libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64.tar.gz" "libkmsp11-${PKCS11_LIB_VERSION}-linux-amd64"

RUN chown root:root ${LIBKMSP_DIR}/libkmsp11.so

# Create directory for ACME challenge (needed for Let's Encrypt)
RUN mkdir -p /var/www/html/.well-known/acme-challenge/

RUN mkdir -p /usr/src/config/apache

COPY ./config/apache/apache.config.templ /usr/src/config/apache/apache.config.templ
COPY ./config/apache/openssl_server_certificate.config ./openssl_server_certificate.config
COPY ./config/apache/pkcs11-config.yaml ./usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml

# Expose HTTP and HTTPS ports
EXPOSE 80 443

ENV PKCS11_MODULE_PATH="${LIBKMSP_DIR}/libkmsp11.so"
ENV KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml"
ENV GRPC_ENABLE_FORK_SUPPORT=1
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/secrets/kms-sa-private-key.json"

# Download and install the Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && apt-get update && apt-get install -y google-cloud-sdk

COPY kms-sa-private-key.json /app/secrets/kms-sa-private-key.json
RUN gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS

# RUN gcloud auth application-default login --quiet


COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Start Apache in the foreground
# CMD ["apache2ctl", "-D", "FOREGROUND", "-D", "USE_CHAIN_FILE"]
