#!/bin/bash

set -e

OUTPUT_DIR="../../../../documentation/blue_team/regionals/team_2/certificates/"
mkdir -p "$OUTPUT_DIR"

# Create private key
openssl genrsa -out "$OUTPUT_DIR/private.key" 4096

# Create self-signed certificate (valid for 1 year)
openssl req -new -x509 -key "$OUTPUT_DIR/private.key" -out "$OUTPUT_DIR/fullchain.crt" -days 365 \
  -subj "/CN=teleport.placebo-pharma.com" \
  -addext "subjectAltName=DNS:teleport.placebo-pharma.com,DNS:*.teleport.placebo-pharma.com"

echo "certificates created in $OUTPUT_DIR" 
ls -la "$OUTPUT_DIR"