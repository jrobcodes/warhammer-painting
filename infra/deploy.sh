#!/bin/bash
set -euo pipefail

PROFILE="pip"
REGION="us-west-2"
TABLE_NAME="painting-progress"
FUNCTION_NAME="painting-progress-api"
ROLE_NAME="painting-progress-lambda-role"
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)

echo "==> Account: $ACCOUNT_ID, Region: $REGION"

# 1. Create DynamoDB table (if not exists)
echo "==> Creating DynamoDB table..."
aws dynamodb create-table \
  --profile "$PROFILE" \
  --region "$REGION" \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=userId,AttributeType=S \
  --key-schema AttributeName=userId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null && echo "    Table created." || echo "    Table already exists."

# Wait for table to be active
aws dynamodb wait table-exists \
  --profile "$PROFILE" \
  --region "$REGION" \
  --table-name "$TABLE_NAME"

# 2. Create IAM role (if not exists)
echo "==> Creating IAM role..."
TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

aws iam create-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  2>/dev/null && echo "    Role created." || echo "    Role already exists."

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Attach policies
aws iam attach-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

# Inline policy for DynamoDB access
DDB_POLICY="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Action\": [\"dynamodb:GetItem\", \"dynamodb:PutItem\"],
    \"Resource\": \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}\"
  }]
}"

aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "dynamodb-access" \
  --policy-document "$DDB_POLICY"

echo "    Waiting for role to propagate..."
sleep 10

# 3. Package Lambda
echo "==> Packaging Lambda..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/lambda"
zip -j /tmp/painting-lambda.zip index.mjs

# 4. Create or update Lambda function
echo "==> Deploying Lambda..."
aws lambda create-function \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs20.x \
  --handler index.handler \
  --role "$ROLE_ARN" \
  --zip-file fileb:///tmp/painting-lambda.zip \
  --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
  --timeout 10 \
  --memory-size 128 \
  2>/dev/null && echo "    Function created." || {
    echo "    Function exists, updating..."
    aws lambda update-function-code \
      --profile "$PROFILE" \
      --region "$REGION" \
      --function-name "$FUNCTION_NAME" \
      --zip-file fileb:///tmp/painting-lambda.zip
  }

# 5. Create Function URL (if not exists)
echo "==> Creating Function URL..."
FUNC_URL=$(aws lambda create-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --auth-type NONE \
  --cors '{"AllowOrigins":["*"],"AllowMethods":["GET","PUT","OPTIONS"],"AllowHeaders":["Content-Type"]}' \
  --query FunctionUrl --output text 2>/dev/null) || {
    FUNC_URL=$(aws lambda get-function-url-config \
      --profile "$PROFILE" \
      --region "$REGION" \
      --function-name "$FUNCTION_NAME" \
      --query FunctionUrl --output text)
  }

# Allow public invoke
aws lambda add-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id "public-url-access" \
  --action lambda:InvokeFunctionUrl \
  --principal "*" \
  --function-url-auth-type NONE \
  2>/dev/null || true

echo ""
echo "============================================"
echo "  Deployed! Function URL:"
echo "  $FUNC_URL"
echo ""
echo "  Usage:"
echo "    GET  ${FUNC_URL}jrob     — read progress"
echo "    PUT  ${FUNC_URL}jrob     — write progress"
echo "============================================"
