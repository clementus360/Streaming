#!/bin/bash

# Check if CA files exist - we need them to sign the new client
if [ ! -f certs/ca-key.pem ] || [ ! -f certs/ca-cert.pem ]; then
    echo "Error: CA files not found in ./certs. Run generate.sh first."
    exit 1
fi

echo "Generating dedicated Client/Postman certificates..."

# 1. Generate Client Key
openssl genrsa -out certs/client-key.pem 4096

# 2. Generate Certificate Signing Request (CSR)
# We use 'developer_client' as the Common Name
openssl req -new -key certs/client-key.pem -out certs/client.csr -subj "/CN=developer_client"

# 3. Sign the Client Cert with our Root CA
openssl x509 -req -in certs/client.csr \
    -CA certs/ca-cert.pem -CAkey certs/ca-key.pem \
    -CAcreateserial -out certs/client-cert.pem \
    -days 365 -sha256

# Cleanup
rm certs/client.csr
rm certs/ca-cert.srl

echo "------------------------------------------------"
echo "Done! Files created in ./certs/:"
echo " - client-cert.pem"
echo " - client-key.pem"
echo "------------------------------------------------"
echo "Next: Add these to Postman along with ca-cert.pem"
