#!/bin/bash
# QuickSight Deployment for Genomics Research Platform
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
DATA_SOURCE_ID="genomics-snowflake"

echo "=== Deploying QuickSight Datasets for Genomics ==="

# Dataset: Variant Summary
aws quicksight create-data-set \
    --aws-account-id "$ACCOUNT_ID" \
    --data-set-id "hc-genomics-variants" \
    --name "HC Genomics: Variant Summary" \
    --physical-table-map '{
        "GenomicsVariants": {
            "CustomSql": {
                "DataSourceArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':datasource/'$DATA_SOURCE_ID'",
                "Name": "GenomicsVariants",
                "SqlQuery": "SELECT GENE, COHORT_ID, VARIANT_COUNT, PATHOGENIC_COUNT, AVG_ALLELE_FREQUENCY FROM HEALTHCARE_GENOMICS.CURATED.VARIANT_SUMMARY",
                "Columns": [
                    {"Name": "GENE", "Type": "STRING"},
                    {"Name": "COHORT_ID", "Type": "STRING"},
                    {"Name": "VARIANT_COUNT", "Type": "INTEGER"},
                    {"Name": "PATHOGENIC_COUNT", "Type": "INTEGER"},
                    {"Name": "AVG_ALLELE_FREQUENCY", "Type": "DECIMAL"}
                ]
            }
        }
    }' \
    --import-mode DIRECT_QUERY \
    --region "$REGION"

echo "Created dataset: hc-genomics-variants"

# Q Topic
aws quicksight create-topic \
    --aws-account-id "$ACCOUNT_ID" \
    --topic-id "hc-genomics-q" \
    --topic '{
        "Name": "Genomics Research",
        "Description": "Natural language queries over genomic variants, cohort comparison, and biobank inventory",
        "DataSets": [
            {
                "DatasetArn": "arn:aws:quicksight:'$REGION':'$ACCOUNT_ID':dataset/hc-genomics-variants",
                "DatasetName": "HC Genomics: Variant Summary"
            }
        ]
    }' \
    --region "$REGION"

echo "Created Q topic: hc-genomics-q"
echo "=== QuickSight deployment complete ==="
