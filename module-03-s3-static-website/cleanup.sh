#!/bin/bash
set -uo pipefail
export AWS_DEFAULT_REGION=${AWS_REGION:-ap-southeast-2}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-risnysuha-portfolio-$ACCOUNT}
# delete all object versions, then the bucket
aws s3api list-object-versions --bucket "$BUCKET" --output json --query '{Objects: [Versions[], DeleteMarkers[]][] | [].{Key:Key,VersionId:VersionId}}' > /tmp/v.json
python3 -c "import json;d=json.load(open('/tmp/v.json'));exit(0 if d.get('Objects') else 1)" && aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/v.json >/dev/null
aws s3api delete-bucket --bucket "$BUCKET" && echo "🧹 $BUCKET removed"
