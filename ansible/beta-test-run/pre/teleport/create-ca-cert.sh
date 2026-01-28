#!/bin/bash
# 1. Create CA key and cert
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.crt -days 3650 -subj "/CN=PlaceboPharma CA"

# 2. Create server key and CSR
openssl genrsa -out private.key 4096
openssl req -new -key private.key -out teleport.csr \
  -subj "/CN=teleport.placebo-pharma.com"

# 3. Create SAN config
cat > san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = DNS:teleport.placebo-pharma.com,DNS:*.teleport.placebo-pharma.com
EOF

# 4. Sign with CA
openssl x509 -req -in teleport.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -extfile san.cnf -extensions v3_req

# 5. Create fullchain (server cert + CA cert)
cat server.crt ca.crt > fullchain.crt