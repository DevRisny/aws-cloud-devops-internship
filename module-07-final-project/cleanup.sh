#!/bin/bash
set -uo pipefail
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm "s3://interntrack-app-$ACCOUNT" --recursive
aws cloudformation delete-stack --stack-name InternTrack && aws cloudformation wait stack-delete-complete --stack-name InternTrack
aws s3 rb "s3://interntrack-artifacts-$ACCOUNT" --force
echo "🧹 InternTrack removed"
