#!/bin/bash
# Module 06 — lets GitHub Actions deploy to AWS with short-lived OIDC credentials (no access keys)
set -euo pipefail
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
REPO=${REPO:-DevRisny/aws-cloud-devops-internship}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-risnysuha-portfolio-$ACCOUNT}
ROLE=GitHubActions-Deploy-Role
PROVIDER_ARN="arn:aws:iam::$ACCOUNT:oidc-provider/token.actions.githubusercontent.com"

echo "▶ 1/3 GitHub OIDC identity provider"
aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null 2>&1 || \
  aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com --tags Key=Project,Value=Codomax >/dev/null

echo "▶ 2/3 Deploy role — trusted only by $REPO on main"
cat > /tmp/trust.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"$PROVIDER_ARN"},
 "Action":"sts:AssumeRoleWithWebIdentity",
 "Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},
   "StringLike":{"token.actions.githubusercontent.com:sub":["repo:$REPO:ref:refs/heads/main","repo:$REPO:environment:production"]}}}]}
JSON
aws iam get-role --role-name $ROLE >/dev/null 2>&1 || \
  aws iam create-role --role-name $ROLE --assume-role-policy-document file:///tmp/trust.json --tags Key=Project,Value=Codomax >/dev/null
aws iam update-assume-role-policy --role-name $ROLE --policy-document file:///tmp/trust.json

echo "▶ 3/3 Least-privilege permissions: one bucket + one function"
cat > /tmp/perm.json <<JSON
{"Version":"2012-10-17","Statement":[
 {"Sid":"SyncPortfolio","Effect":"Allow","Action":["s3:ListBucket"],"Resource":"arn:aws:s3:::$BUCKET"},
 {"Sid":"WriteObjects","Effect":"Allow","Action":["s3:PutObject","s3:DeleteObject","s3:GetObject"],"Resource":"arn:aws:s3:::$BUCKET/*"},
 {"Sid":"UpdateSkillMatch","Effect":"Allow","Action":["lambda:UpdateFunctionCode","lambda:GetFunction","lambda:PublishVersion"],
  "Resource":"arn:aws:lambda:$AWS_DEFAULT_REGION:$ACCOUNT:function:skillmatch-api"}]}
JSON
aws iam put-role-policy --role-name $ROLE --policy-name deploy-portfolio-and-lambda --policy-document file:///tmp/perm.json
echo
echo "✅ Add these as GitHub repository variables (Settings → Secrets and variables → Actions → Variables):"
echo "   AWS_ROLE_ARN     = $(aws iam get-role --role-name $ROLE --query Role.Arn --output text)"
echo "   PORTFOLIO_BUCKET = $BUCKET"
