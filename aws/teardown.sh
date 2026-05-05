#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="__AWS_ACCOUNT_ID__"
REGION="us-west-2"

echo "=== Tearing Down AWS Resources for Genomics Demo ==="

# Delete QuickSight Q Topic
echo "Deleting Q topic: hc-genomics-q..."
aws quicksight delete-topic \
  --aws-account-id "$ACCOUNT_ID" \
  --topic-id "hc-genomics-q" 2>/dev/null || echo "  (already deleted or not found)"

# Delete QuickSight Dataset
echo "Deleting dataset: hc-genomics-variants..."
aws quicksight delete-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-genomics-variants" 2>/dev/null || echo "  (already deleted or not found)"

# Delete Glue Database
echo "Deleting Glue database: healthcare_genomics_iceberg..."
aws glue delete-database \
  --name "healthcare_genomics_iceberg" \
  --region "$REGION" 2>/dev/null || echo "  (already deleted or not found)"

# Clear S3 genomics prefix
echo "Clearing S3 genomics prefix..."
aws s3 rm "s3://sg-healthcare-demos-2026/genomics/" --recursive 2>/dev/null || echo "  (already empty or not found)"

# Clear secrets
echo "Clearing secrets..."
aws secretsmanager delete-secret \
  --secret-id "healthcare-genomics/snowflake-credentials" \
  --force-delete-without-recovery \
  --region "$REGION" 2>/dev/null || echo "  (no secret found)"

echo "=== Teardown complete ==="
