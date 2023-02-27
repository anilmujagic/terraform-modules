#!/bin/bash

set -eo pipefail

aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
echo "AWS Account ID: $aws_account_id"

aws_region=$([ -n "$AWS_REGION" ] && echo $AWS_REGION || echo $(aws configure get region))
echo "AWS Region: $aws_region"

read -rp $'Continue? (Y/N): ' key
[[ "$key" =~ [Yy] ]] || (echo 'Aborted'; exit 1)

state_bucket="terraform-state-$aws_account_id"
lock_table="terraform-state"

echo "Creating state bucket..."
aws s3 mb "s3://$state_bucket"

echo "Creating lock table..."
aws dynamodb create-table \
   --table-name "$lock_table" \
   --attribute-definitions AttributeName=LockID,AttributeType=S \
   --key-schema AttributeName=LockID,KeyType=HASH \
   --billing-mode PAY_PER_REQUEST

echo "Waiting for the DynamoDB table to be created..."
while true; do
    sleep 5
    table_status="$(aws dynamodb describe-table --table-name "$lock_table" --query 'Table.TableStatus' --output text)"
    [ "$table_status" == "ACTIVE" ] && break
    echo "Table status: $table_status"
done;

echo "DONE"
