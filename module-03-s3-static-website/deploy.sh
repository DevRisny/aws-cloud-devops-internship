#!/bin/bash
# Module 03 — Amazon S3 static website hosting (run in AWS CloudShell)
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-risnysuha-portfolio-$ACCOUNT}
echo "▶ Bucket: $BUCKET"

echo "▶ 1/5 Create bucket + versioning + tags"
aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null || \
  aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION >/dev/null
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Project,Value=Codomax},{Key=Module,Value=03}]'

echo "▶ 2/5 Allow a public-read bucket policy (only this bucket)"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo "▶ 3/5 Bucket policy: anyone can GET objects, nothing else"
sed "s|__BUCKET__|$BUCKET|" bucket-policy.tpl.json > /tmp/policy.json
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file:///tmp/policy.json

echo "▶ 4/5 Enable static website hosting"
aws s3 website "s3://$BUCKET/" --index-document index.html --error-document error.html

echo "▶ 5/5 Upload the site"
BUILD=$(mktemp -d)
cp site/* ../assets/theme.css "$BUILD"/
sed -i -e "s|{{BUCKET}}|$BUCKET|g" -e "s|{{REGION}}|$AWS_DEFAULT_REGION (Sydney)|g" -e "s|{{DEPLOYED}}|$(date -u '+%d %b %Y, %H:%M UTC')|g" "$BUILD/index.html"
aws s3 sync "$BUILD" "s3://$BUCKET/" --delete --cache-control "max-age=300"
echo
echo "✅ Live: http://$BUCKET.s3-website.$AWS_DEFAULT_REGION.amazonaws.com"
