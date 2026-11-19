#!/bin/bash
set -uo pipefail
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-risnysuha-skillmatch-$ACCOUNT}
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='skillmatch-http-api'].ApiId | [0]" --output text)
[ "$API_ID" != "None" ] && aws apigatewayv2 delete-api --api-id "$API_ID"
aws lambda delete-function --function-name skillmatch-api
aws iam detach-role-policy --role-name SkillMatch-Lambda-Role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name SkillMatch-Lambda-Role
aws s3 rb "s3://$BUCKET" --force
echo "🧹 Module 05 removed"
