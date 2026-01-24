#!/bin/bash
# service-enum.sh - comprehensive enum for competition services

echo "=== SYSTEM INFO ==="
hostname; cat /etc/os-release | grep PRETTY_NAME
ip -4 addr | grep -oP 'inet \K[\d./]+'

echo -e "\n=== CONTAINERS ==="
docker ps -a 2>/dev/null
podman ps -a 2>/dev/null
docker compose ls 2>/dev/null

echo -e "\n=== LISTENING SERVICES ==="
ss -tlnp | column -t

echo -e "\n=== SYSTEMD SERVICES (enabled) ==="
systemctl list-unit-files --state=enabled --type=service | grep -v '@'

#--------------------------------------------------
# SERVICE-SPECIFIC CHECKS
#--------------------------------------------------

echo -e "\n=== NGINX ==="
which nginx && nginx -v 2>&1
ls -la /etc/nginx/sites-enabled/ 2>/dev/null
cat /etc/nginx/nginx.conf 2>/dev/null | head -50
docker ps | grep -i nginx && docker exec $(docker ps -qf "ancestor=nginx" | head -1) cat /etc/nginx/nginx.conf 2>/dev/null

echo -e "\n=== WORDPRESS ==="
find /var/www /srv /opt -name "wp-config.php" 2>/dev/null -exec cat {} \;
docker ps | grep -iE 'wordpress|wp' && docker inspect $(docker ps -qf name=wordpress 2>/dev/null) 2>/dev/null | grep -A20 '"Env"'

echo -e "\n=== PROMETHEUS ==="
ls -la /etc/prometheus/ 2>/dev/null
cat /etc/prometheus/prometheus.yml 2>/dev/null
docker ps | grep prometheus && docker exec $(docker ps -qf name=prometheus | head -1) cat /etc/prometheus/prometheus.yml 2>/dev/null
curl -s localhost:9090/api/v1/targets 2>/dev/null | head -100

echo -e "\n=== GRAFANA ==="
ls -la /etc/grafana/ 2>/dev/null
cat /etc/grafana/grafana.ini 2>/dev/null | grep -vE '^;|^$' | head -50
docker ps | grep grafana
# default creds: admin/admin
curl -s -u admin:admin localhost:3000/api/datasources 2>/dev/null

echo -e "\n=== FALCO ==="
which falco && falco --version
cat /etc/falco/falco.yaml 2>/dev/null | head -50
ls -la /etc/falco/rules.d/ 2>/dev/null
docker ps | grep -iE 'falco|sidekick'
# check falcosidekick outputs (discord, slack, etc)
docker inspect $(docker ps -qf name=sidekick 2>/dev/null) 2>/dev/null | grep -A30 '"Env"'

echo -e "\n=== TELEPORT ==="
which teleport && teleport version
cat /etc/teleport.yaml 2>/dev/null
ls -la /var/lib/teleport/ 2>/dev/null
tctl status 2>/dev/null
tctl users ls 2>/dev/null
tctl get roles 2>/dev/null

echo -e "\n=== CENTRALIZED LOGGING (graylog/loki/elastic) ==="
docker ps | grep -iE 'graylog|elastic|loki|fluentd|filebeat|logstash'
cat /etc/filebeat/filebeat.yml 2>/dev/null
cat /etc/rsyslog.conf 2>/dev/null | grep -v '^#' | grep -v '^$'
# check where logs are being shipped
grep -r "forward\|remote\|@" /etc/rsyslog.d/ 2>/dev/null

echo -e "\n=== FTP SERVER ==="
which vsftpd proftpd pure-ftpd 2>/dev/null
cat /etc/vsftpd.conf 2>/dev/null
cat /etc/proftpd/proftpd.conf 2>/dev/null
ls -la /srv/ftp/ /home/*/ftp 2>/dev/null

echo -e "\n=== ADFS (linux side - check SAML/LDAP integration) ==="
cat /etc/sssd/sssd.conf 2>/dev/null
cat /etc/krb5.conf 2>/dev/null | head -30
realm list 2>/dev/null
# check PAM for AD integration
grep -r "pam_sss\|pam_krb5\|pam_winbind" /etc/pam.d/ 2>/dev/null

echo -e "\n=== IMPORTANT CONFIG FILES ==="
for f in \
    /etc/nginx/nginx.conf \
    /etc/prometheus/prometheus.yml \
    /etc/grafana/grafana.ini \
    /etc/teleport.yaml \
    /etc/falco/falco.yaml \
    /etc/filebeat/filebeat.yml \
    /etc/graylog/server/server.conf
do
    [ -f "$f" ] && echo "FOUND: $f"
done

echo -e "\n=== DOCKER ENV VARS (credentials) ==="
for cid in $(docker ps -q 2>/dev/null); do
    name=$(docker inspect --format '{{.Name}}' $cid | tr -d '/')
    echo "--- $name ---"
    docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' $cid | grep -iE 'pass|token|secret|key|user|db_|mysql|postgres|admin'
done

echo -e "\n=== CRON JOBS ==="
cat /etc/crontab 2>/dev/null
ls -la /etc/cron.d/ 2>/dev/null
for u in $(cut -f1 -d: /etc/passwd); do crontab -u $u -l 2>/dev/null | grep -v '^#' && echo "^ $u"; done
