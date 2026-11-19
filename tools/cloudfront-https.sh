#!/bin/bash
# Puts an HTTPS Amazon CloudFront distribution in front of an HTTP-only origin
# (EC2 web server or S3 website endpoint).  Usage: tools/cloudfront-https.sh <origin-domain> "<comment>" [cache|nocache]
set -euo pipefail
ORIGIN=$1; COMMENT=$2; MODE=${3:-cache}
EXISTING=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='$COMMENT'].DomainName | [0]" --output text 2>/dev/null || echo None)
if [ "$EXISTING" != "None" ] && [ -n "$EXISTING" ]; then echo "https://$EXISTING"; exit 0; fi
# AWS managed cache policies
if [ "$MODE" = "nocache" ]; then POLICY=4135ea2d-6df8-44a3-9df3-4b5a84be39ad; else POLICY=658327ea-f89d-4fab-a63d-7e88639e58f6; fi
cat > /tmp/cf.json <<JSON
{
  "CallerReference": "$(date +%s)-$RANDOM",
  "Comment": "$COMMENT",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "PriceClass": "PriceClass_All",
  "HttpVersion": "http2and3",
  "IsIPV6Enabled": true,
  "Origins": { "Quantity": 1, "Items": [ {
      "Id": "origin-1", "DomainName": "$ORIGIN",
      "CustomOriginConfig": { "HTTPPort": 80, "HTTPSPort": 443, "OriginProtocolPolicy": "http-only",
        "OriginSslProtocols": { "Quantity": 1, "Items": ["TLSv1.2"] } } } ] },
  "DefaultCacheBehavior": {
    "TargetOriginId": "origin-1",
    "ViewerProtocolPolicy": "redirect-to-https",
    "Compress": true,
    "CachePolicyId": "$POLICY",
    "AllowedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] } }
  }
}
JSON
DOMAIN=$(aws cloudfront create-distribution --distribution-config file:///tmp/cf.json --query Distribution.DomainName --output text)
echo "https://$DOMAIN"
