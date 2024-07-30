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

# added  apt-get upgrade -y as after Debian upgrade the container fails to load with malloc issue
# RUN apt-get upgrade -y

RUN pip install mod_wsgi

# Enable SSL module
RUN a2enmod ssl

# Enable Headers module
RUN a2enmod headers

# Install mod_wsgi
RUN mod_wsgi-express install-module > /etc/apache2/mods-available/wsgi.load

# ENV LIBKMSP_DIR="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/"
ENV LIBKMSP_DIR="/usr/lib/x86_64-linux-gnu/engines-1.2/kms11/libkmsp11-1.6-linux-amd64/"
                                                             
## RUN curl -L -o libkmsp11-1.3-linux-amd64.tar.gz https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz
# malloc error after system upgrade 
# RUN wget https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.3/libkmsp11-1.3-linux-amd64.tar.gz && \
#     tar -xzvf libkmsp11-1.3-linux-amd64.tar.gz && \
#     mkdir -p $LIBKMSP_DIR && \
#     mv libkmsp11-1.3-linux-amd64/libkmsp11.so $LIBKMSP_DIR && \
#     rm -rf libkmsp11-1.3-linux-amd64.tar.gz libkmsp11-1.3-linux-amd64

## get and setup the PKCS library for Apache...
RUN wget https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v1.6/libkmsp11-1.6-linux-amd64.tar.gz && \
    tar -xzvf libkmsp11-1.6-linux-amd64.tar.gz && \
    mkdir -p $LIBKMSP_DIR && \
    mv libkmsp11-1.6-linux-amd64/libkmsp11.so $LIBKMSP_DIR && \
    rm -rf libkmsp11-1.6-linux-amd64.tar.gz libkmsp11-1.6-linux-amd64

# RUN chown root:root /usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so
RUN chown root:root /usr/lib/x86_64-linux-gnu/engines-1.2/kms11/libkmsp11-1.6-linux-amd64/libkmsp11.so

# Create directory for ACME challenge (needed for Let's Encrypt)
RUN mkdir -p /var/www/html/.well-known/acme-challenge/

RUN mkdir -p /usr/src/config/apache

COPY ./config/apache/apache.config.templ /usr/src/config/apache/apache.config.templ
COPY ./config/apache/openssl_server_certificate.config ./openssl_server_certificate.config

# COPY ./config/apache/pkcs11-config.yaml ./usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml
COPY ./config/apache/pkcs11-config.yaml ./usr/lib/x86_64-linux-gnu/engines-1.2/pkcs11-config.yaml

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# ENV PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.1/kms11/libkmsp11-1.3-linux-amd64/libkmsp11.so"
ENV PKCS11_MODULE_PATH="/usr/lib/x86_64-linux-gnu/engines-1.2/kms11/libkmsp11-1.6-linux-amd64/libkmsp11.so"

# ENV KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11-config.yaml"
ENV KMS_PKCS11_CONFIG="/usr/lib/x86_64-linux-gnu/engines-1.2/pkcs11-config.yaml"

ENV GRPC_ENABLE_FORK_SUPPORT=1
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/secrets/kms-sa-private-key.json"

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# ENTRYPOINT ["entrypoint.sh"]
## trying to debug the entry point
## -----------------------------------------------------
ENTRYPOINT ["valgrind", "--tool=memcheck", "--leak-check=full", "/usr/local/bin/entrypoint.sh"]
## -----------------------------------------------------



# Start Apache in the foreground
# CMD ["apache2ctl", "-D", "FOREGROUND", "-D", "USE_CHAIN_FILE"]
