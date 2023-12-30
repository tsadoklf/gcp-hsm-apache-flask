FROM python:3.8
USER root

RUN apt-get update && apt-get install -y \
    ssl-cert \
    wget \
    curl \
    tar \
    certbot \
    python3-certbot-apache


COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
