#!/bin/bash
# EC2 user data — runs once as root on first boot (Amazon Linux 2023)
set -euxo pipefail
dnf -y install nginx
WEB=/usr/share/nginx/html
rm -f "$WEB/index.html"
echo "__PAYLOAD__" | base64 -d | tar -xz -C "$WEB"

# Read instance facts from IMDSv2 (token-based metadata service)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
AZ=$(md placement/availability-zone)
sed -i \
  -e "s|{{INSTANCE_ID}}|$(md instance-id)|g" \
  -e "s|{{INSTANCE_TYPE}}|$(md instance-type)|g" \
  -e "s|{{AZ}}|$AZ|g" \
  -e "s|{{REGION}}|$(md placement/region)|g" \
  -e "s|{{AMI_ID}}|$(md ami-id)|g" \
  -e "s|{{PRIVATE_IP}}|$(md local-ipv4)|g" \
  -e "s|{{NGINX}}|$(nginx -v 2>&1 | cut -d/ -f2 | sed 's/^/nginx /')|g" \
  -e "s|{{BOOT_TIME}}|$(date -u '+%Y-%m-%d %H:%M')|g" \
  "$WEB/index.html"

systemctl enable --now nginx
