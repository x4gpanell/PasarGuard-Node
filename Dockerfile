# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache make git openssl

WORKDIR /src
RUN git clone --depth 1 https://github.com/PasarGuard/node.git .
RUN go mod download

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make NAME=main build
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make install_xray

# ساخت گواهی خودامضا (self-signed) که هم داخل ایمیج نود می‌ماند (برای TLS)
# و هم محتوایش باید در فیلد "Server CA" پنل کپی شود.
# دامنه TCP Proxy که Railway به این سرویس می‌دهد باید اینجا باشد وگرنه
# پنل هنگام اتصال خطای "Hostname mismatch" می‌دهد.
ARG NODE_DOMAIN=hayabusa.proxy.rlwy.net
RUN mkdir -p /src/certs && \
    openssl req -x509 -newkey ec \
        -pkeyopt ec_paramgen_curve:P-256 \
        -keyout /src/certs/ssl_key.pem \
        -out /src/certs/ssl_cert.pem \
        -days 3650 -nodes \
        -subj "/CN=${NODE_DOMAIN}" \
        -addext "subjectAltName = DNS:${NODE_DOMAIN},DNS:localhost,IP:127.0.0.1"

FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/PasarGuard/node"

RUN apk update && apk add --no-cache wireguard-tools nftables iproute2 procps

WORKDIR /app
COPY --from=builder /src/main /app/main
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY --from=builder /usr/local/share/xray /usr/local/share/xray
COPY --from=builder /src/certs /app/certs

ENV SSL_CERT_FILE=/app/certs/ssl_cert.pem
ENV SSL_KEY_FILE=/app/certs/ssl_key.pem
ENV NODE_HOST=0.0.0.0
ENV SERVICE_PORT=62050

ENTRYPOINT ["./main"]
