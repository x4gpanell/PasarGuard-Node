#!/bin/sh
set -e

DATA_DIR=/var/lib/pg-node
CERT_DIR=$DATA_DIR/certs
CERT=$CERT_DIR/ssl_cert.pem
KEY=$CERT_DIR/ssl_key.pem
KEY_FILE=$DATA_DIR/api_key.txt

mkdir -p "$CERT_DIR"

# Railway خودش این متغیر رو به هر سرویس تزریق می‌کنه؛ همون آدرس داخلیه که پنل باهاش وصل میشه
HOSTNAME_FOR_CERT="${RAILWAY_PRIVATE_DOMAIN:-node}"

if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
  echo ">> در حال ساخت گواهی SSL برای نود (CN/SAN = $HOSTNAME_FOR_CERT)..."
  cat > /tmp/node_ext.cnf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${HOSTNAME_FOR_CERT}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HOSTNAME_FOR_CERT}
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$KEY" -out "$CERT" \
    -config /tmp/node_ext.cnf -extensions v3_req 2>/dev/null
  rm -f /tmp/node_ext.cnf
fi

# اگه API_KEY رو خودت دستی توی Variables ست کرده باشی همون استفاده میشه.
# در غیر این صورت، یه بار می‌سازه و توی Volume نگه می‌داره تا با هر ری‌استارت عوض نشه.
if [ -z "$API_KEY" ]; then
  if [ -f "$KEY_FILE" ]; then
    API_KEY=$(cat "$KEY_FILE")
  else
    API_KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
    echo "$API_KEY" > "$KEY_FILE"
  fi
  export API_KEY
fi

echo "================================================================"
echo "این اطلاعات رو برای اضافه‌کردن این نود توی پنل لازم داری:"
echo "  Address : $HOSTNAME_FOR_CERT"
echo "  Port    : $SERVICE_PORT"
echo "  API Key : $API_KEY"
echo ""
echo "و این متن رو توی فیلد Certificate پنل پیست کن:"
cat "$CERT"
echo "================================================================"

exec ./main
