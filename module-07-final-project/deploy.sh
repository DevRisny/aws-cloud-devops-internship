#!/bin/bash
# Module 07 — InternTrack: deploys the whole stack with AWS CloudFormation (run in AWS CloudShell)
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ART=interntrack-artifacts-$ACCOUNT
SITE=interntrack-app-$ACCOUNT
STACK=InternTrack

echo "▶ 1/4 Package Lambda code to S3"
aws s3api head-bucket --bucket "$ART" 2>/dev/null || \
  aws s3api create-bucket --bucket "$ART" --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION >/dev/null
( cd backend && rm -f /tmp/it.zip && zip -q /tmp/it.zip app.py )
KEY="lambda/app-$(date +%Y%m%d%H%M%S).zip"
aws s3 cp /tmp/it.zip "s3://$ART/$KEY" >/dev/null

echo "▶ 2/4 Deploy CloudFormation stack ($STACK) — takes 1–2 minutes"
aws cloudformation deploy --stack-name $STACK --template-file infra/template.yaml \
  --parameter-overrides CodeBucket=$ART CodeKey=$KEY SiteBucketName=$SITE \
  --capabilities CAPABILITY_NAMED_IAM --tags Project=Codomax Module=07 --no-fail-on-empty-changeset
out() { aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
API=$(out ApiUrl); WEB=$(out WebsiteUrl)

echo "▶ 3/4 Publish frontend"
BUILD=$(mktemp -d); cp frontend/index.html ../assets/theme.css "$BUILD/"
sed -i "s|__API_URL__|$API|g" "$BUILD/index.html"
aws s3 sync "$BUILD" "s3://$SITE/" --delete

echo "▶ 4/4 Smoke test"
curl -s "$API/health"; echo
echo
echo "✅ App : $WEB"
echo "✅ API : $API"
echo "✅ Dashboard: https://$AWS_DEFAULT_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_DEFAULT_REGION#dashboards/dashboard/InternTrack"
