#!/bin/bash
#   sudo ./enum_concise.sh
#   VERBOSE=1 sudo ./enum_concise.sh
#   AD_BIND="teleport-bind@placebo-pharma3.local" AD_PASS='StrongPassword123!' sudo ./enum_concise.sh
#

set -euo pipefail

VERBOSE="${VERBOSE:-0}"

AD_HOST="${AD_HOST:-10.37.33.39}"   # change Domain Controller IP / hostname
AD_PORT="${AD_PORT:-389}" # teleport listening port
AD_URL="ldap://${AD_HOST}:${AD_PORT}"

# Bind defaults (override via env)
AD_REALM="${AD_REALM:-placebo-pharma3.local}" #change domain name
AD_BIND="${AD_BIND:-teleport-bind@${AD_REALM}}" #change teleport user
AD_PASS="${AD_PASS:-}" #change teleport password

TCTL="sudo tctl"
TPBIN="teleport"

# Teleport config path varies by install.
# Common paths:
#  - /etc/teleport.yaml
#  - /etc/teleport/teleport.yaml
TELEPORT_CONFIG_PRIMARY="/etc/teleport.yaml"
TELEPORT_CONFIG_FALLBACK="/etc/teleport/teleport.yaml"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

REPORT_FILE="teleport_enum_$(date +%Y%m%d_%H%M%S).json" #change to txt if needed

log() { echo -e "$1" >> "$REPORT_FILE"; }

say() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo -e "$1"
  else
    # strip ANSI
    echo -e "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
  fi
}

run_cmd() {
  local cmd="$1"
  local description="$2"

  log "\n${BLUE}[*]${NC} $description"
  if eval "$cmd" >> "$REPORT_FILE" 2>&1; then
    log "${GREEN}[✓]${NC} Command completed"
    say "[OK] $description"
  else
    log "${RED}[!]${NC} Command failed or not available"
    say "[WARN] $description (failed/unavailable)"
  fi
}


echo "Report: $REPORT_FILE"
echo "(Set VERBOSE=1 for more terminal output.)"
echo ""

log "=== TELEPORT ENUMERATION REPORT ==="
log "Date: $(date)"
log "Hostname: $(hostname)"
log "Mode: local (non-docker)"
log ""

if ! command -v teleport >/dev/null 2>&1; then
  say "[WARN] teleport binary not found on PATH (Teleport not installed locally?)"
  log "${YELLOW}[!]${NC} teleport binary not found on PATH"
fi

if ! command -v tctl >/dev/null 2>&1; then
  say "[WARN] tctl binary not found on PATH (Teleport not installed locally?)"
  log "${YELLOW}[!]${NC} tctl binary not found on PATH"
fi

# AD base DN discovery (optional). Do not fail the whole script if AD is unreachable.
BASE_DN=""
if command -v ldapsearch >/dev/null 2>&1; then
  # RootDSE discovery (works on AD). Some environments block anonymous rootdse; if so, we try authenticated.
  # Prefer the namingContexts output to match common AD behavior.
  BASE_DN=$(ldapsearch -x -H "$AD_URL" -s base -b "" namingContexts 2>/dev/null \
    | awk -F': ' '/^namingContexts: DC=/{print $2; exit}' || true)

  if [[ -z "$BASE_DN" && -n "$AD_PASS" ]]; then
    BASE_DN=$(ldapsearch -x -H "$AD_URL" -s base -b "" -D "$AD_BIND" -w "$AD_PASS" namingContexts 2>/dev/null \
      | awk -F': ' '/^namingContexts: DC=/{print $2; exit}' || true)
  fi

  if [[ -n "$BASE_DN" ]]; then
    echo "AD base DN discovered: $BASE_DN"
    log "AD base DN discovered: $BASE_DN"
  else
    say "[WARN] AD base DN discovery failed (AD checks will be skipped unless BASE_DN is set)"
    log "${YELLOW}[!]${NC} AD base DN discovery failed for $AD_URL"
  fi
else
  say "[WARN] ldapsearch not found (install: sudo apt install -y ldap-utils). AD checks will be skipped."
  log "${YELLOW}[!]${NC} ldapsearch not found; skipping AD checks"
fi

# ==========================================================================
# 1. TELEPORT SERVICE STATUS & VERSION
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}1. TELEPORT SERVICE STATUS & VERSION${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TPBIN version" "Teleport version (local)"
run_cmd "systemctl is-active teleport && systemctl status teleport --no-pager -l" "Teleport systemd service status"
run_cmd "journalctl -u teleport -n 80 --no-pager" "Recent Teleport service logs (tail)"
run_cmd "$TCTL status" "Teleport cluster status"
run_cmd "$TCTL get cluster" "Cluster configuration"

# ==========================================================================
# 2. USER ENUMERATION
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}2. USER ENUMERATION${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL users ls" "List all Teleport users"
run_cmd "$TCTL get users --format=yaml" "Detailed user information (YAML)"

log "\n${BLUE}[*]${NC} Checking for users with admin/root privileges..."
if $TCTL get users --format=yaml 2>/dev/null | grep -E "(roles?:.*admin|roles?:.*root|\\- admin|\\- root)" >> "$REPORT_FILE"; then
  log "${YELLOW}[!]${NC} Found users with elevated privileges - review carefully"
fi

# ==========================================================================
# 3. ROLE ENUMERATION & ANALYSIS
# ==========================================================================

ROLE_JSON="$($TCTL get roles --format=json 2>/dev/null || true)"

if echo "$ROLE_JSON" | jq -e . >/dev/null 2>&1; then
  # Write compact summary to report (always)
  {
    echo "[*] Role privilege summary (compact)"
    echo "$ROLE_JSON" | jq -r '
      .[]? |
      .metadata.name as $name |
      ((.spec.allow.logins // []) | join(",")) as $logins |
      (.spec.allow.node_labels // {}) as $node_labels |
      (
        ($node_labels | has("*")) or
        ($node_labels | to_entries | any(.value == "*"))
      ) as $node_wild |
      (.spec.allow.rules // []) as $rules |
      (
        ($rules | any(((.resources // []) | index("*")) != null)) or
        ($rules | any(((.verbs // []) | index("*")) != null))
      ) as $rule_wild |
      [
        "Role: \($name)",
        (if $logins != "" then "  logins: \($logins)" else "  logins: (none listed)" end),
        (if $node_wild then "wildcard node_labels" else empty end),
        (if $rule_wild then "wildcard rules (* verbs/resources)" else empty end),
        ""
      ] | .[]'
  } >> "$REPORT_FILE"

  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[OK] Role summary written to report (showing top roles):"
    # show only first ~25 lines of the summary in verbose mode
    sed -n '/\[\*\] Role privilege summary (compact)/,$p' "$REPORT_FILE" | head -n 25
  else
    echo "[OK] Roles summarized (see report for details)"
  fi

else
  log "[WARN] Roles JSON not available; falling back to short text list"
  run_cmd "$TCTL get roles" "List all roles (fallback)"
fi

# ==========================================================================
# 4. ACTIVE SESSIONS & NODES
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}4. ACTIVE SESSIONS${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Active sessions are not available via tctl in teleport v18.
# tsh requires an interactive login + proxy content
if command -v tsh >/dev/null 2>&1; then
  if tsh status >/dev/null 2>&1; then
    run_cmd "tsh sessions ls" "List active sessions (tsh)"
  else
    log "[WARN] tsh present but not logged in; skipping active session listing"
    echo "[WARN] Active sessions skipped (no tsh login context)"
  fi
else
  log "[WARN] tsh not available; skipping active session listing"
  echo "[WARN] Active sessions skipped (tsh not available)"
fi

# Nodes
run_cmd "$TCTL nodes ls" "List nodes (admin view)"

# ==========================================================================
# 5. TRUSTED CLUSTERS & FEDERATION
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}5. TRUSTED CLUSTERS & FEDERATION${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL get trusted_cluster" "List trusted clusters"
run_cmd "$TCTL get trusted_cluster --format=yaml" "Detailed trusted cluster config"

log "\n${BLUE}[*]${NC} Checking for unexpected trusted clusters..."
TRUSTED_COUNT=$($TCTL get trusted_cluster 2>/dev/null | wc -l | tr -d ' ')
log "Total trusted clusters (lines): $TRUSTED_COUNT"
if [[ "$TRUSTED_COUNT" -gt 0 ]]; then
  log "${YELLOW}[!]${NC} Review trusted clusters for unauthorized connections"
fi

# ==========================================================================
# 6. AUTHENTICATION CONNECTORS (SSO)
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}6. AUTHENTICATION CONNECTORS (SSO/AD INTEGRATION)${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Auth preference: v18 uses `tctl auth preference`
run_cmd "$TCTL get cluster_auth_preference" "Auth preferences (local vs SSO settings)"

# Connectors: these are resources and SHOULD work with `tctl get`
run_cmd "$TCTL get saml --format=yaml" "SAML connectors"
run_cmd "$TCTL get oidc --format=yaml" "OIDC connectors"
run_cmd "$TCTL get github --format=yaml" "GitHub SSO connectors"

# ==========================================================================
# 7. NODES & RESOURCES
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}7. REGISTERED NODES & RESOURCES${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL nodes ls" "List all nodes"
run_cmd "$TCTL get nodes" "Detailed node information"
run_cmd "$TCTL apps ls" "List application access resources"
run_cmd "$TCTL db ls" "List database access resources"
# run_cmd "$TCTL kube ls" "List Kubernetes clusters"

log "\n${BLUE}[*]${NC} Checking for unauthorized or unknown nodes..."
NODE_COUNT=$($TCTL nodes ls 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
log "Total registered nodes: $NODE_COUNT"

# ==========================================================================
# 8. WINDOWS DESKTOP ACCESS
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}8. WINDOWS DESKTOP ACCESS${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL desktop ls" "List Windows desktops"
run_cmd "$TCTL get windows_desktop --format=yaml" "Windows desktop details"
run_cmd "$TCTL get windows_desktop_service --format=yaml" "Windows desktop service config"

DESKTOP_COUNT=$($TCTL desktop ls 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
log "Total Windows desktops: $DESKTOP_COUNT"

# ==========================================================================
# 9. JOIN TOKENS
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}9. JOIN TOKENS${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL tokens ls" "List join tokens"
run_cmd "$TCTL get tokens --format=yaml" "Token details (types, TTL, labels)"

log "\n${BLUE}[*]${NC} Checking for long-lived tokens..."
if $TCTL get tokens --format=yaml 2>/dev/null | grep -E "ttl.*[0-9]+d|expires.*20[3-9]" >> "$REPORT_FILE"; then
  log "${YELLOW}[!]${NC} Found long-lived tokens - review for security"
fi

# ==========================================================================
# 10. APPLICATION ACCESS DETAILS
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}10. APPLICATION ACCESS DETAILS${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL apps ls" "List apps"
run_cmd "$TCTL get apps --format=yaml" "App config (URIs, labels, public addresses)"

log "\n${BLUE}[*]${NC} Looking for competition-related apps..."
for app in grafana prometheus graylog wordpress falco nginx influxdb database; do
  if $TCTL get apps --format=yaml 2>/dev/null | grep -qi "$app"; then
    log "${GREEN}[+]${NC} Found app matching: $app"
    say "[+] Found app: $app"
  fi
done

# ==========================================================================
# 11. TELEPORT CONFIG FILE ANALYSIS
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}11. TELEPORT CONFIG FILE${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TELEPORT_CONFIG=""
if [[ -f "$TELEPORT_CONFIG_PRIMARY" ]]; then
  TELEPORT_CONFIG="$TELEPORT_CONFIG_PRIMARY"
elif [[ -f "$TELEPORT_CONFIG_FALLBACK" ]]; then
  TELEPORT_CONFIG="$TELEPORT_CONFIG_FALLBACK"
fi

if [[ -n "$TELEPORT_CONFIG" ]]; then
  log "Config file found: $TELEPORT_CONFIG"
  run_cmd "cat $TELEPORT_CONFIG" "Full teleport.yaml"

  log "\n${BLUE}[*]${NC} Security configuration checks..."

  if grep -q "second_factor: off" "$TELEPORT_CONFIG" 2>/dev/null; then
    log "${RED}[!]${NC} MFA is DISABLED (second_factor: off)"
    say "[!] SECURITY: MFA is disabled"
  fi

  if grep -q "permit_user_env: true" "$TELEPORT_CONFIG" 2>/dev/null; then
    log "${YELLOW}[!]${NC} permit_user_env enabled (can be abused for env injection)"
    say "[!] SECURITY: permit_user_env is enabled"
  fi

  if grep -q "proxy_checks_host_keys: no" "$TELEPORT_CONFIG" 2>/dev/null; then
    log "${YELLOW}[!]${NC} Host key checking disabled"
    say "[!] SECURITY: Host key checking disabled"
  fi

  if grep -q "pam:" "$TELEPORT_CONFIG" 2>/dev/null; then
    if grep -A3 "pam:" "$TELEPORT_CONFIG" 2>/dev/null | grep -q "enabled: no"; then
      log "${YELLOW}[!]${NC} PAM is disabled"
    fi
  fi

  log "\n${BLUE}[*]${NC} Key configuration values:"
  grep -E "public_addr|cluster_name|web_listen|auth_server|proxy_server" "$TELEPORT_CONFIG" >> "$REPORT_FILE" 2>/dev/null || true
else
  log "${YELLOW}[!]${NC} Teleport config file not found at expected paths"
  say "[WARN] Teleport config file not found"
fi

# ==========================================================================
# 12. CERTIFICATES
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}12. CERTIFICATES${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "ls -la /var/lib/teleport/*.crt /var/lib/teleport/*.key /var/lib/teleport/*.pem 2>/dev/null || echo 'No certs in /var/lib/teleport/'" "Certificate files"

log "\n${BLUE}[*]${NC} Certificate details:"
for cert in /var/lib/teleport/*.crt /var/lib/teleport/*.pem; do
  if [[ -f "$cert" ]]; then
    log "\n--- $cert ---"
    openssl x509 -in "$cert" -noout -subject -issuer -dates 2>/dev/null >> "$REPORT_FILE" || true
  fi
done 2>/dev/null

# Check for expiring certs
log "\n${BLUE}[*]${NC} Checking for expiring certificates..."
for cert in /var/lib/teleport/*.crt /var/lib/teleport/*.pem; do
  if [[ -f "$cert" ]]; then
    if openssl x509 -in "$cert" -noout -checkend 604800 2>/dev/null; then
      : # cert valid for more than 7 days
    else
      log "${RED}[!]${NC} Certificate expiring soon: $cert"
      say "[!] Certificate expiring soon: $cert"
    fi
  fi
done 2>/dev/null

# ==========================================================================
# 13. AUDIT EVENTS
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}13. AUDIT EVENTS${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_cmd "$TCTL get events --last 100 2>/dev/null | head -200" "Recent audit events (last 100)"

log "\n${BLUE}[*]${NC} Checking for failed authentication attempts..."
FAILED_AUTH=$($TCTL get events --last 500 2>/dev/null | grep -ciE "failed|denied|error" || echo "0")
log "Failed/denied/error events in last 500: $FAILED_AUTH"
if [[ "$FAILED_AUTH" -gt 10 ]]; then
  log "${YELLOW}[!]${NC} High number of failed auth attempts detected"
  say "[!] High number of failed auth attempts: $FAILED_AUTH"
fi

# ==========================================================================
# 14. EXPORT FOR REBUILD
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}14. EXPORT FOR REBUILD${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

BACKUP_DIR="/tmp/teleport-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

log "Exporting Teleport resources to: $BACKUP_DIR"

$TCTL get roles --format=yaml > "$BACKUP_DIR/roles.yaml" 2>/dev/null || true
$TCTL get users --format=yaml > "$BACKUP_DIR/users.yaml" 2>/dev/null || true
$TCTL get tokens --format=yaml > "$BACKUP_DIR/tokens.yaml" 2>/dev/null || true
$TCTL get apps --format=yaml > "$BACKUP_DIR/apps.yaml" 2>/dev/null || true
$TCTL get nodes --format=yaml > "$BACKUP_DIR/nodes.yaml" 2>/dev/null || true
$TCTL get windows_desktop --format=yaml > "$BACKUP_DIR/windows_desktops.yaml" 2>/dev/null || true
$TCTL get trusted_cluster --format=yaml > "$BACKUP_DIR/trusted_clusters.yaml" 2>/dev/null || true
$TCTL get saml --format=yaml > "$BACKUP_DIR/saml_connectors.yaml" 2>/dev/null || true
$TCTL get oidc --format=yaml > "$BACKUP_DIR/oidc_connectors.yaml" 2>/dev/null || true

if [[ -n "$TELEPORT_CONFIG" ]]; then
  cp "$TELEPORT_CONFIG" "$BACKUP_DIR/teleport.yaml" 2>/dev/null || true
fi

run_cmd "ls -la $BACKUP_DIR" "Backup contents"
log "Backup saved to: $BACKUP_DIR"
say "[OK] Backup saved to: $BACKUP_DIR"

# ==========================================================================
# 15. COMPETITION SERVICE MAPPING
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${YELLOW}15. COMPETITION SERVICE MAPPING${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

EXPECTED_SERVICES="grafana prometheus falco graylog wordpress nginx ftp influxdb database teleport"

log "\n${BLUE}[*]${NC} Checking Teleport integration with expected competition services..."

# Check apps
log "\n--- App Access ---"
for svc in $EXPECTED_SERVICES; do
  if $TCTL apps ls 2>/dev/null | grep -qi "$svc"; then
    log "${GREEN}[+]${NC} App access configured for: $svc"
    say "[+] App access: $svc"
  else
    log "${YELLOW}[-]${NC} No app access found for: $svc"
  fi
done

# Check nodes by name/label
log "\n--- Node Access ---"
NODES_OUTPUT=$($TCTL nodes ls 2>/dev/null || true)
for svc in $EXPECTED_SERVICES; do
  if echo "$NODES_OUTPUT" | grep -qi "$svc"; then
    log "${GREEN}[+]${NC} Node registered for: $svc"
    say "[+] Node access: $svc"
  fi
done

# Check roles that grant access to services
log "\n--- Role Coverage ---"
ROLES_OUTPUT=$($TCTL get roles --format=yaml 2>/dev/null || true)
for svc in $EXPECTED_SERVICES; do
  if echo "$ROLES_OUTPUT" | grep -qi "$svc"; then
    log "${GREEN}[+]${NC} Role exists referencing: $svc"
  fi
done

# Windows desktop check
log "\n--- Windows Desktop Access ---"
DESKTOP_OUTPUT=$($TCTL desktop ls 2>/dev/null || true)
if [[ -n "$DESKTOP_OUTPUT" ]]; then
  log "Windows desktops available:"
  echo "$DESKTOP_OUTPUT" >> "$REPORT_FILE"
else
  log "${YELLOW}[-]${NC} No Windows desktops registered"
fi

# ==========================================================================
# COMPLETE
# ==========================================================================
log "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${GREEN}ENUMERATION COMPLETE${NC}"
log "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "Report saved to: $REPORT_FILE"
log "Backup saved to: $BACKUP_DIR"

echo ""
echo "=========================================="
echo "Done. Report: $REPORT_FILE"
echo "Backup: $BACKUP_DIR"
echo "=========================================="
