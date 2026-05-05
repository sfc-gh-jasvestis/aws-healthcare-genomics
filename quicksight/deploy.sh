#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="__AWS_ACCOUNT_ID__"
REGION="us-west-2"
QS_NAMESPACE="default"
DATA_SOURCE_ID="healthcare-snowflake-ds"

echo "=== Deploying QuickSight Resources for Genomics Demo ==="

# Dataset: Variant Summary
echo "Creating dataset: hc-genomics-variants..."
aws quicksight create-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-genomics-variants" \
  --name "HC Genomics - Variant Summary" \
  --physical-table-map '{
    "variant-summary": {
      "CustomSql": {
        "DataSourceArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':datasource/'$DATA_SOURCE_ID'",
        "Name": "VariantSummary",
        "SqlQuery": "SELECT GENE, COHORT, CLINICAL_SIGNIFICANCE, VARIANT_COUNT, PATIENT_COUNT, AVG_ALLELE_FREQUENCY, COHORT_FRACTION FROM HEALTHCARE_GENOMICS.CURATED.VARIANT_SUMMARY",
        "Columns": [
          {"Name": "GENE", "Type": "STRING"},
          {"Name": "COHORT", "Type": "STRING"},
          {"Name": "CLINICAL_SIGNIFICANCE", "Type": "STRING"},
          {"Name": "VARIANT_COUNT", "Type": "INTEGER"},
          {"Name": "PATIENT_COUNT", "Type": "INTEGER"},
          {"Name": "AVG_ALLELE_FREQUENCY", "Type": "DECIMAL"},
          {"Name": "COHORT_FRACTION", "Type": "DECIMAL"}
        ]
      }
    }
  }' \
  --import-mode SPICE \
  --permissions '[{"Principal": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':user/'$QS_NAMESPACE'/QUICKSIGHT_HEALTHCARE_SVC", "Actions": ["quicksight:DescribeDataSet","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:CreateIngestion"]}]'

# Q Topic
echo "Creating Q topic: hc-genomics-q..."
aws quicksight create-topic \
  --aws-account-id "$ACCOUNT_ID" \
  --topic-id "hc-genomics-q" \
  --topic '{
    "Name": "HC Genomics Q",
    "Description": "Natural language queries over genomics variant data, cohort demographics, and biobank inventory",
    "DataSets": [
      {
        "DatasetArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':dataset/hc-genomics-variants",
        "DatasetName": "HC Genomics - Variant Summary",
        "Columns": [
          {"ColumnName": "GENE", "ColumnFriendlyName": "Gene", "ColumnDescription": "Gene symbol", "ColumnSynonyms": ["gene name","gene symbol"], "IsIncludedInTopic": true, "SemanticType": {"TypeName": "DIMENSION"}},
          {"ColumnName": "COHORT", "ColumnFriendlyName": "Cohort", "ColumnDescription": "Patient cohort", "IsIncludedInTopic": true, "SemanticType": {"TypeName": "DIMENSION"}},
          {"ColumnName": "CLINICAL_SIGNIFICANCE", "ColumnFriendlyName": "Significance", "ColumnDescription": "Clinical significance classification", "IsIncludedInTopic": true, "SemanticType": {"TypeName": "DIMENSION"}},
          {"ColumnName": "VARIANT_COUNT", "ColumnFriendlyName": "Variant Count", "ColumnDescription": "Number of variants", "IsIncludedInTopic": true, "SemanticType": {"TypeName": "MEASURE"}, "Aggregation": "SUM"},
          {"ColumnName": "PATIENT_COUNT", "ColumnFriendlyName": "Patient Count", "ColumnDescription": "Number of patients", "IsIncludedInTopic": true, "SemanticType": {"TypeName": "MEASURE"}, "Aggregation": "SUM"}
        ]
      }
    ]
  }'

echo "=== QuickSight deployment complete ==="
echo "Dataset: hc-genomics-variants"
echo "Q Topic: hc-genomics-q"
