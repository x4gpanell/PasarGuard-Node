FROM pasarguard/node:latest

# openssl برای ساخت خودکار گواهی SSL لازمه (ایمیج اصلی نود این ابزار رو نداره)
RUN apk add --no-cache openssl

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_HOST=0.0.0.0 \
    SERVICE_PORT=62050 \
    SSL_CERT_FILE=/var/lib/pg-node/certs/ssl_cert.pem \
    SSL_KEY_FILE=/var/lib/pg-node/certs/ssl_key.pem

ENTRYPOINT ["/entrypoint.sh"]
