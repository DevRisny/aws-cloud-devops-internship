#!/bin/bash
# Removes everything deploy.sh created (to stay inside free credits)
set -uo pipefail
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
IDS=$(aws ec2 describe-instances --filters Name=tag:Name,Values=Codomax-WebServer Name=instance-state-name,Values=pending,running,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
[ -n "$IDS" ] && aws ec2 terminate-instances --instance-ids $IDS >/dev/null && aws ec2 wait instance-terminated --instance-ids $IDS
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=WebServer-SG --query 'SecurityGroups[0].GroupId' --output text)
[ "$SG" != "None" ] && aws ec2 delete-security-group --group-id "$SG"
aws iam remove-role-from-instance-profile --instance-profile-name EC2-WebServer-Profile --role-name EC2-WebServer-Role
aws iam delete-instance-profile --instance-profile-name EC2-WebServer-Profile
aws iam detach-role-policy --role-name EC2-WebServer-Role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name EC2-WebServer-Role
aws iam remove-user-from-group --group-name EC2-Operators --user-name risny-ec2-operator
aws iam delete-user --user-name risny-ec2-operator
aws iam detach-group-policy --group-name EC2-Operators --policy-arn "arn:aws:iam::$ACCOUNT:policy/EC2-Operate-Lab-Only"
aws iam delete-group --group-name EC2-Operators
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT:policy/EC2-Operate-Lab-Only"
echo "🧹 Module 02 resources removed"
