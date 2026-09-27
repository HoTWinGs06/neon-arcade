#!/bin/bash
# AWS S3 Static Website Deployment Script for Neon Pulse Arcade
set -e

BUCKET_NAME="neon-pulse-arcade-$(date +%s)"
REGION="us-east-1"

echo "=== Deploying Neon Pulse Arcade to AWS S3 ==="
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS credentials not found or invalid."
    echo "Please run 'aws login' or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
    exit 1
fi

# 1. Create S3 Bucket
echo "Creating S3 bucket..."
if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi

# 2. Disable Block Public Access
echo "Configuring public access settings..."
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# 3. Enable Static Website Hosting
echo "Enabling static website hosting..."
aws s3 website "s3://$BUCKET_NAME" \
    --index-document index.html \
    --error-document index.html

# 4. Set Bucket Policy for Public Read
echo "Setting public read bucket policy..."
cat <<EOF > /tmp/bucket-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/bucket-policy.json
rm /tmp/bucket-policy.json

# 5. Upload index.html
echo "Uploading game file to S3..."
aws s3 cp index.html "s3://$BUCKET_NAME/index.html" --content-type "text/html"

WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
echo ""
echo "============================================"
echo "Deployment Complete!"
echo "Your game is now live at:"
echo "$WEBSITE_URL"
echo "============================================"
