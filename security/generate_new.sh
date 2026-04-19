#!/bin/bash
mkdir -p certs

# 1. THE ROOT CA
openssl genrsa -out certs/ca-key.pem 4096
openssl req -x509 -new -nodes -key certs/ca-key.pem -sha256 -days 3650 \
    -out certs/ca-cert.pem -subj "/CN=Streaming-Internal-CA"

# 2. Function to generate service certs with explicit SANs
generate_service_cert() {
    local name=$1
    local dns_name=$2
    local alt_name=$3
    echo "Generating cert for $name..."

    local san_list="DNS:localhost,IP:127.0.0.1,DNS:${dns_name},DNS:${alt_name}"

    # Generate Key
    openssl genrsa -out certs/${name}-key.pem 4096

    # Generate CSR with SANs baked in
    openssl req -new \
        -key certs/${name}-key.pem \
        -out certs/${name}.csr \
        -subj "/CN=${name}_service" \
        -addext "subjectAltName = ${san_list}" \
        -addext "extendedKeyUsage = serverAuth, clientAuth" \
        -addext "keyUsage = critical, digitalSignature, keyEncipherment"

    # Sign the cert and copy CSR extensions into the final certificate
    openssl x509 -req \
        -in certs/${name}.csr \
        -CA certs/ca-cert.pem \
        -CAkey certs/ca-key.pem \
        -CAcreateserial \
        -out certs/${name}-cert.pem \
        -days 365 \
        -sha256 \
        -copy_extensions copy
}

# 3. Generate for all services
generate_service_cert db db-service db_service
generate_service_cert ingest ingest-service ingest_service
generate_service_cert processing processing-service processing_service
generate_service_cert distribution distribution-service distribution_service
generate_service_cert client client-service client_service
generate_service_cert auth auth-service auth_service
generate_service_cert stream stream-service stream_service

# Cleanup
rm certs/*.csr certs/*.srl
echo "Certs generated with SANs successfully."
