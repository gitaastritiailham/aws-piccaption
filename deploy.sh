#!/bin/bash
# deploy.sh — Run this AFTER terraform apply
# Usage: bash deploy.sh

set -e
cd "$(dirname "$0")/terraform"

echo "📦 Getting Terraform outputs..."
API_URL=$(terraform output -raw api_url)
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)

echo "  API_URL        = $API_URL"
echo "  USER_POOL_ID   = $USER_POOL_ID"
echo "  CLIENT_ID      = $CLIENT_ID"
echo "  FRONTEND_BUCKET= $FRONTEND_BUCKET"

echo ""
echo "🔧 Injecting config into frontend..."
cd ../frontend
cp index.html index.html.bak
sed -i "s|%%API_URL%%|$API_URL|g" index.html
sed -i "s|%%USER_POOL_ID%%|$USER_POOL_ID|g" index.html
sed -i "s|%%CLIENT_ID%%|$CLIENT_ID|g" index.html

echo "🚀 Uploading frontend to S3..."
aws s3 cp index.html s3://$FRONTEND_BUCKET/index.html \
  --content-type "text/html" \
  --cache-control "no-cache"

# Restore template
mv index.html.bak index.html

echo ""
cd ../terraform
FRONTEND_URL=$(terraform output -raw frontend_url)
echo "✅ Deploy complete!"
echo ""
echo "🌐 App URL: $FRONTEND_URL"
echo ""
echo "⚠️  IMPORTANT: Cek Bedrock model access dulu!"
echo "   AWS Console → Bedrock → Model access → Request access for Claude Haiku"
