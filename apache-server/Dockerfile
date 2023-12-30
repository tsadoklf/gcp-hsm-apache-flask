FROM python:3.8
USER root

RUN apt-get update && apt-get install -y \
    apache2 \
    apache2-dev \
    ssl-cert \
    libengine-pkcs11-openssl \
    libpkcs11-helper1 \
    wget \
    curl \
    tar \
    certbot \
    python3-certbot-apache

RUN pip install mod_wsgi

# Enable SSL module
RUN a2enmod ssl

# Install mod_wsgi
RUN mod_wsgi-express install-module > /etc/apache2/mods-available/wsgi.load

ENV LIBKMSP_DIR="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/"
                                                             
# RUN curl -L -o libkmsp11-1.3-linux-amd64.tar.gz https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz
RUN wget https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz && \
    tar -xzvf libkmsp11-1.3-linux-amd64.tar.gz && \
    mkdir -p $LIBKMSP_DIR && \
    mv libkmsp11-1.3-linux-amd64/libkmsp11.so $LIBKMSP_DIR && \
    rm -rf libkmsp11-1.3-linux-amd64.tar.gz libkmsp11-1.3-linux-amd64

RUN chown root:root /usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so

# Create directory for ACME challenge (needed for Let's Encrypt)
RUN mkdir -p /var/www/html/.well-known/acme-challenge/

RUN mkdir -p /usr/src/config/apache

COPY ./config/apache/apache.config.templ /usr/src/config/apache/apache.config.templ
COPY ./config/apache/openssl_server_certificate.config ./openssl_server_certificate.config
COPY ./config/apache/pkcs11-config.yaml ./usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml

# Expose HTTP and HTTPS ports
EXPOSE 80 443

ENV PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so"
ENV KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml"
ENV GRPC_ENABLE_FORK_SUPPORT=1
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/secrets/kms-sa-private-key.json"

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Start Apache in the foreground
CMD ["apache2ctl", "-D", "FOREGROUND", "-D", "USE_CHAIN_FILE"]
