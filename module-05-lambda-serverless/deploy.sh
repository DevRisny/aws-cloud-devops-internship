#!/bin/bash
# Module 05 — AWS Lambda + Amazon API Gateway + S3 frontend (run in AWS CloudShell)
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
FN=skillmatch-api
ROLE=SkillMatch-Lambda-Role
BUCKET=${BUCKET:-risnysuha-skillmatch-$ACCOUNT}

echo "▶ 1/5 Execution role (CloudWatch Logs only)"
if ! aws iam get-role --role-name $ROLE >/dev/null 2>&1; then
  aws iam create-role --role-name $ROLE --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --tags Key=Project,Value=Codomax >/dev/null
  aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  echo "  waiting for role to propagate…"; sleep 12
fi
ROLE_ARN=$(aws iam get-role --role-name $ROLE --query Role.Arn --output text)

echo "▶ 2/5 Package + deploy Lambda ($FN)"
( cd lambda && rm -f /tmp/fn.zip && zip -q /tmp/fn.zip handler.py )
if aws lambda get-function --function-name $FN >/dev/null 2>&1; then
  aws lambda update-function-code --function-name $FN --zip-file fileb:///tmp/fn.zip >/dev/null
else
  aws lambda create-function --function-name $FN --runtime python3.13 --handler handler.lambda_handler \
    --role "$ROLE_ARN" --zip-file fileb:///tmp/fn.zip --memory-size 128 --timeout 5 \
    --description "SkillMatch — resume vs job skill matcher" --tags Project=Codomax >/dev/null
fi
aws lambda wait function-active-v2 --function-name $FN
FN_ARN=$(aws lambda get-function --function-name $FN --query Configuration.FunctionArn --output text)

echo "▶ 3/5 API Gateway HTTP API + CORS"
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='skillmatch-http-api'].ApiId | [0]" --output text)
if [ "$API_ID" = "None" ]; then
  API_ID=$(aws apigatewayv2 create-api --name skillmatch-http-api --protocol-type HTTP --target "$FN_ARN" \
    --cors-configuration AllowOrigins='*',AllowMethods=GET,POST,OPTIONS,AllowHeaders=content-type \
    --tags Project=Codomax --query ApiId --output text)
  aws lambda add-permission --function-name $FN --statement-id apigw-invoke --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:$AWS_DEFAULT_REGION:$ACCOUNT:$API_ID/*" >/dev/null
fi
API_URL=$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)
echo "  $API_URL"

echo "▶ 4/5 Smoke test"
curl -s "$API_URL/health"; echo

echo "▶ 5/5 Frontend on S3 static website"
aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null || \
  aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION >/dev/null
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
aws s3api put-bucket-policy --bucket "$BUCKET" --policy \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/*\"}]}"
aws s3 website "s3://$BUCKET/" --index-document index.html
BUILD=$(mktemp -d); cp frontend/index.html ../assets/theme.css "$BUILD/"
sed -i "s|__API_URL__|$API_URL|g" "$BUILD/index.html"
aws s3 sync "$BUILD" "s3://$BUCKET/" --delete
echo
echo "✅ API : $API_URL  (GET /health, POST /match)"
echo "✅ Site: http://$BUCKET.s3-website.$AWS_DEFAULT_REGION.amazonaws.com"
