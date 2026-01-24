#!/bin/bash
# teleport-enum.sh - comprehensive teleport enumeration

echo "=== TELEPORT SERVER INFO ==="
teleport version 2>/dev/null
tctl status 2>/dev/null

echo -e "\n=== TELEPORT CONFIG ==="
cat /etc/teleport.yaml 2>/dev/null

echo -e "\n=== TELEPORT DATA DIR ==="
ls -la /var/lib/teleport/ 2>/dev/null

echo -e "\n=== CERTIFICATES ==="
ls -la /var/lib/teleport/*.crt /var/lib/teleport/*.key /var/lib/teleport/*.pem 2>/dev/null
# Check cert expiry
for cert in /var/lib/teleport/*.crt; do
    [ -f "$cert" ] && echo "--- $cert ---" && openssl x509 -in "$cert" -noout -subject -dates 2>/dev/null
done

echo -e "\n=== CLUSTER NAME & PUBLIC ADDR ==="
grep -E "cluster_name|public_addr|web_listen" /etc/teleport.yaml 2>/dev/null

echo -e "\n=== AUTH SETTINGS ==="
grep -A10 "auth_service:" /etc/teleport.yaml 2>/dev/null
grep -A5 "authentication:" /etc/teleport.yaml 2>/dev/null

#--------------------------------------------------
# USERS & ROLES (the good stuff)
#--------------------------------------------------

echo -e "\n=== TELEPORT USERS ==="
tctl users ls 2>/dev/null

echo -e "\n=== TELEPORT ROLES ==="
tctl get roles --format=yaml 2>/dev/null

echo -e "\n=== ROLE DETAILS (permissions) ==="
for role in $(tctl get roles --format=json 2>/dev/null | jq -r '.[].metadata.name'); do
    echo "--- $role ---"
    tctl get role/$role --format=yaml 2>/dev/null | grep -A20 "spec:"
done

echo -e "\n=== ROLE FILES (if stored locally) ==="
ls -la /teleport/roles/ 2>/dev/null
cat /teleport/roles/*.yaml 2>/dev/null

#--------------------------------------------------
# REGISTERED NODES & APPS
#--------------------------------------------------

echo -e "\n=== REGISTERED NODES (SSH targets) ==="
tctl nodes ls 2>/dev/null

echo -e "\n=== REGISTERED APPS ==="
tctl apps ls 2>/dev/null

echo -e "\n=== APP DETAILS ==="
tctl get apps --format=yaml 2>/dev/null

echo -e "\n=== REGISTERED DATABASES ==="
tctl db ls 2>/dev/null

echo -e "\n=== REGISTERED WINDOWS DESKTOPS ==="
tctl desktop ls 2>/dev/null

#--------------------------------------------------
# TOKENS (for joining new nodes)
#--------------------------------------------------

echo -e "\n=== JOIN TOKENS ==="
tctl tokens ls 2>/dev/null

echo -e "\n=== TOKEN DETAILS ==="
tctl get tokens --format=yaml 2>/dev/null

#--------------------------------------------------
# SESSIONS & AUDIT
#--------------------------------------------------

echo -e "\n=== ACTIVE SESSIONS ==="
tctl sessions ls 2>/dev/null

echo -e "\n=== RECENT AUTH EVENTS (last 50) ==="
tctl get events --last 50 2>/dev/null | head -100

#--------------------------------------------------
# SERVICE STATUS
#--------------------------------------------------

echo -e "\n=== TELEPORT SERVICE STATUS ==="
systemctl status teleport 2>/dev/null | head -20

echo -e "\n=== LISTENING PORTS ==="
ss -tlnp | grep -E "teleport|:443|:3025|:3024|:3080|:3000"

echo -e "\n=== TELEPORT PROCESSES ==="
ps aux | grep teleport | grep -v grep

#--------------------------------------------------
# CONNECTED AGENTS (on other machines)
#--------------------------------------------------

echo -e "\n=== AGENT CONFIG (if this is a node, not auth server) ==="
cat /etc/teleport.yaml 2>/dev/null | grep -A20 "teleport:" | head -25
grep -E "auth_server|proxy_server|token" /etc/teleport.yaml 2>/dev/null

#--------------------------------------------------
# DUMP FOR REBUILD
#--------------------------------------------------

echo -e "\n=== EXPORT FOR BACKUP ==="
mkdir -p /tmp/teleport-backup
tctl get roles --format=yaml > /tmp/teleport-backup/roles.yaml 2>/dev/null
tctl get users --format=yaml > /tmp/teleport-backup/users.yaml 2>/dev/null
tctl get tokens --format=yaml > /tmp/teleport-backup/tokens.yaml 2>/dev/null
tctl get apps --format=yaml > /tmp/teleport-backup/apps.yaml 2>/dev/null
cp /etc/teleport.yaml /tmp/teleport-backup/ 2>/dev/null
echo "Backup saved to /tmp/teleport-backup/"
ls -la /tmp/teleport-backup/