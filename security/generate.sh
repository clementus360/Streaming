#!/bin/bash
# -----------------------------------------------------------------------------
# 1. THE ROOT CA (The source of all trust)
# -----------------------------------------------------------------------------
openssl genrsa -out certs/ca-key.pem 4096
openssl req -x509 -new -nodes -key certs/ca-key.pem -sha256 -days 3650 \
    -out certs/ca-cert.pem -subj "/CN=Streaming-Internal-CA"

# -----------------------------------------------------------------------------
# 2. DATABASE SERVICE (The Server)
# -----------------------------------------------------------------------------
openssl genrsa -out certs/db-key.pem 4096
openssl req -new -key certs/db-key.pem -out certs/db.csr -subj "/CN=go_db_service"
openssl x509 -req -in certs/db.csr -CA certs/ca-cert.pem -CAkey certs/ca-key.pem \
    -CAcreateserial -out certs/db-cert.pem -days 365 -sha256

# -----------------------------------------------------------------------------
# 3. CLIENT SERVICES (Ingest, Processing, Distribution)
# -----------------------------------------------------------------------------
for service in ingest processing distribution; do
    openssl genrsa -out certs/${service}-key.pem 4096
    openssl req -new -key certs/${service}-key.pem -out certs/${service}.csr -subj "/CN=${service}_service"
    openssl x509 -req -in certs/${service}.csr -CA certs/ca-cert.pem -CAkey certs/ca-key.pem \
        -CAcreateserial -out certs/${service}-cert.pem -days 365 -sha256
done

# Cleanup temporary files
rm certs/*.csr certs/*.srl
echo "Certificates generated successfully in ./certs"
