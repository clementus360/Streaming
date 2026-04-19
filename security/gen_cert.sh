#!/bin/bash
# Quick certificate generation for Streaming Platform
# Uses the newer script with SAN support
# Run from: cd /path/to/security && bash gen_cert.sh

if [ ! -f "generate_new.sh" ]; then
    echo "Error: generate_new.sh not found"
    echo "Run this script from the security/ directory"
    exit 1
fi

echo "Generating certificates with SAN support..."
bash generate_new.sh

echo ""
echo "✅ Certificates generated successfully!"
echo "Location: ../certs/"
echo ""
echo "Certificate details:"
openssl x509 -in ../certs/ca-cert.pem -noout -subject -dates 2>/dev/null && echo ""
echo "Service certificates:"
for cert in ../certs/{ingest,processing,distribution,db}-cert.pem; do
    if [ -f "$cert" ]; then
        name=$(basename "$cert" -cert.pem)
        echo "  - $name: $(openssl x509 -in "$cert" -noout -subject -dates 2>/dev/null | head -1)"
    fi
done
