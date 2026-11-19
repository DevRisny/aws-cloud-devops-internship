#!/bin/bash
# Module 06 — creates the keyless deploy-hook Lambda (Function URL) used by GitHub Actions.
# Used because this Free-plan account's SCP denies iam:CreateOpenIDConnectProvider (OIDC).
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-risnysuha-portfolio-$ACCOUNT}
FN=codomax-deploy-hook
ROLE=Codomax-DeployHook-Role

echo "▶ 1/3 Least-privilege role: one bucket + one function + logs"
if ! aws iam get-role --role-name $ROLE >/dev/null 2>&1; then
  aws iam create-role --role-name $ROLE --tags Key=Project,Value=Codomax --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
fi
aws iam put-role-policy --role-name $ROLE --policy-name deploy-portfolio-and-skillmatch --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[
 {\"Effect\":\"Allow\",\"Action\":[\"s3:PutObject\"],\"Resource\":\"arn:aws:s3:::$BUCKET/*\"},
 {\"Effect\":\"Allow\",\"Action\":[\"lambda:UpdateFunctionCode\",\"lambda:PublishVersion\"],\"Resource\":\"arn:aws:lambda:$AWS_DEFAULT_REGION:$ACCOUNT:function:skillmatch-api\"}]}"
sleep 10

echo "▶ 2/3 Deploy-hook function"
( cd deployer && rm -f /tmp/dh.zip && zip -q /tmp/dh.zip deployer.py )
ENV="Variables={REPO=DevRisny/aws-cloud-devops-internship,PORTFOLIO_BUCKET=$BUCKET,APP_FUNCTION=skillmatch-api}"
if aws lambda get-function --function-name $FN >/dev/null 2>&1; then
  aws lambda update-function-code --function-name $FN --zip-file fileb:///tmp/dh.zip >/dev/null
  aws lambda wait function-updated-v2 --function-name $FN
  aws lambda update-function-configuration --function-name $FN --timeout 120 >/dev/null
else
  aws lambda create-function --function-name $FN --runtime python3.13 --handler deployer.handler --timeout 120 --memory-size 256 \
    --role "arn:aws:iam::$ACCOUNT:role/$ROLE" --zip-file fileb:///tmp/dh.zip --environment "$ENV" \
    --description "Keyless CD hook for GitHub Actions" --tags Project=Codomax >/dev/null
  aws lambda wait function-active-v2 --function-name $FN
fi

echo "▶ 3/3 Function URL"
URL=$(aws lambda get-function-url-config --function-name $FN --query FunctionUrl --output text 2>/dev/null || true)
if [ -z "$URL" ] || [ "$URL" = "None" ]; then
  URL=$(aws lambda create-function-url-config --function-name $FN --auth-type NONE --query FunctionUrl --output text)
  aws lambda add-permission --function-name $FN --statement-id public-url --action lambda:InvokeFunctionUrl \
    --principal '*' --function-url-auth-type NONE >/dev/null
  aws lambda add-permission --function-name $FN --statement-id public-invoke --action lambda:InvokeFunction \
    --principal '*' --invoked-via-function-url >/dev/null 2>&1 || true
fi
echo
echo "✅ DEPLOY_HOOK_URL = $URL"
echo "   (set it as a GitHub Actions repository variable — it is not a secret: only the head of main can be deployed)"
