#!/bin/bash
# Module 02 — AWS IAM & EC2 : builds everything with the AWS CLI (run in AWS CloudShell)
set -euo pipefail
cd "$(dirname "$0")"
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
TAG='Key=Project,Value=Codomax'
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "▶ Account $ACCOUNT · Region $AWS_DEFAULT_REGION"

echo "▶ 1/5 IAM: least-privilege policy, group and operator user"
POLICY_ARN="arn:aws:iam::$ACCOUNT:policy/EC2-Operate-Lab-Only"
aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1 || \
  aws iam create-policy --policy-name EC2-Operate-Lab-Only \
    --description "View EC2; start/stop/reboot only instances tagged Project=Codomax" \
    --policy-document file://iam/ec2-operator-policy.json --tags $TAG >/dev/null
aws iam get-user --user-name risny-ec2-operator >/dev/null 2>&1 || aws iam create-user --user-name risny-ec2-operator --tags $TAG >/dev/null
# Best practice is to attach policies to a group (EC2-Operators). This Free-plan account's
# service control policy denies iam:CreateGroup, so the group step is tried first and the
# policy falls back to the user if groups are blocked.
if aws iam create-group --group-name EC2-Operators >/dev/null 2>&1 || aws iam get-group --group-name EC2-Operators >/dev/null 2>&1; then
  aws iam attach-group-policy --group-name EC2-Operators --policy-arn "$POLICY_ARN"
  aws iam add-user-to-group --group-name EC2-Operators --user-name risny-ec2-operator
  echo "  policy attached to group EC2-Operators"
else
  aws iam attach-user-policy --user-name risny-ec2-operator --policy-arn "$POLICY_ARN"
  echo "  groups blocked by SCP -> policy attached directly to risny-ec2-operator"
fi

echo "▶ 2/5 IAM role + instance profile for the web server (Session Manager)"
aws iam get-role --role-name EC2-WebServer-Role >/dev/null 2>&1 || \
  aws iam create-role --role-name EC2-WebServer-Role --assume-role-policy-document file://iam/ec2-trust-policy.json --tags $TAG >/dev/null
aws iam attach-role-policy --role-name EC2-WebServer-Role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
if ! aws iam get-instance-profile --instance-profile-name EC2-WebServer-Profile >/dev/null 2>&1; then
  aws iam create-instance-profile --instance-profile-name EC2-WebServer-Profile >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name EC2-WebServer-Profile --role-name EC2-WebServer-Role
  echo "  waiting for the instance profile to propagate…"; sleep 15
fi

echo "▶ 3/5 Security Group: HTTP only, no SSH"
VPC=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=WebServer-SG Name=vpc-id,Values=$VPC --query 'SecurityGroups[0].GroupId' --output text)
if [ "$SG" = "None" ]; then
  SG=$(aws ec2 create-security-group --group-name WebServer-SG --description "HTTP only - Codomax Module 02" --vpc-id "$VPC" \
       --tag-specifications "ResourceType=security-group,Tags=[{$TAG}]" --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG" \
    --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description="Public website"}]' >/dev/null
fi
echo "  $SG in $VPC"

echo "▶ 4/5 Build user data (NGINX + website + IMDSv2 facts)"
PAYLOAD=$(tar -czf - -C website index.html -C ../../assets theme.css | base64 -w0)
sed "s|__PAYLOAD__|$PAYLOAD|" user-data.tpl.sh > /tmp/user-data.sh
echo "  user data size: $(wc -c < /tmp/user-data.sh) bytes (limit 16384)"

echo "▶ 5/5 Launch Amazon Linux 2023 instance"
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
TYPE=$(aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true Name=processor-info.supported-architecture,Values=x86_64 \
       --query 'InstanceTypes[].InstanceType' --output text | tr '\t' '\n' | grep -E '^t3\.micro$|^t2\.micro$' | head -1)
TYPE=${TYPE:-t3.micro}
IID=$(aws ec2 run-instances --image-id "$AMI" --instance-type "$TYPE" --security-group-ids "$SG" \
      --iam-instance-profile Name=EC2-WebServer-Profile --user-data file:///tmp/user-data.sh \
      --metadata-options HttpTokens=required,HttpEndpoint=enabled \
      --associate-public-ip-address \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Codomax-WebServer},{$TAG}]" \
      --query 'Instances[0].InstanceId' --output text)
echo "  launched $IID ($TYPE, $AMI) — waiting until running…"
aws ec2 wait instance-running --instance-ids "$IID"
IP=$(aws ec2 describe-instances --instance-ids "$IID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
DNS=$(aws ec2 describe-instances --instance-ids "$IID" --query 'Reservations[0].Instances[0].PublicDnsName' --output text)
echo
echo "✅ Done. NGINX finishes installing in ~1 minute, then open:"
echo "   http://$IP"
echo "   http://$DNS"
