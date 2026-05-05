#!/bin/bash
# QuickSight Deployment for Genomics Research Platform
# Prerequisites: Data source 'genomics-snowflake' must be created manually in QuickSight Console
# (Host: __SNOWFLAKE_ACCOUNT__.snowflakecomputing.com, DB: HEALTHCARE_GENOMICS, WH: CORTEX, User: QUICKSIGHT_HEALTHCARE_SVC)
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
DATA_SOURCE_ID="genomics-snowflake"
DS_ARN="arn:aws:quicksight:$REGION:$ACCOUNT_ID:datasource/bbe8b0eb-3e0a-4888-a38d-12c7bbbc79e7"
PRINCIPAL="arn:aws:quicksight:$REGION:$ACCOUNT_ID:user/default/$ACCOUNT_ID"

echo "=== Deploying QuickSight for Genomics Research Platform ==="

# Dataset: Variant Summary
echo "Creating dataset: hc-genomics-variants..."
aws quicksight create-data-set \
    --aws-account-id "$ACCOUNT_ID" \
    --data-set-id "hc-genomics-variants" \
    --name "HC Genomics: Variant Summary" \
    --physical-table-map '{"t1": {"CustomSql": {"DataSourceArn": "'"$DS_ARN"'", "Name": "GenomicsVariants", "SqlQuery": "SELECT GENE, COHORT_ID, VARIANT_COUNT, PATHOGENIC_COUNT, AVG_ALLELE_FREQUENCY FROM HEALTHCARE_GENOMICS.CURATED.VARIANT_SUMMARY", "Columns": [{"Name": "GENE", "Type": "STRING"}, {"Name": "COHORT_ID", "Type": "STRING"}, {"Name": "VARIANT_COUNT", "Type": "INTEGER"}, {"Name": "PATHOGENIC_COUNT", "Type": "INTEGER"}, {"Name": "AVG_ALLELE_FREQUENCY", "Type": "DECIMAL"}]}}}' \
    --import-mode DIRECT_QUERY \
    --permissions '[{"Principal": "'"$PRINCIPAL"'", "Actions": ["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
    --region "$REGION" || echo "Dataset may already exist"

echo "Created dataset: hc-genomics-variants"
sleep 5

# Dashboard: Genomics Variant Analysis (6 visuals)
echo "Creating dashboard: hc-genomics-dashboard..."
DASHBOARD_PERMS='[{"Principal": "'"$PRINCIPAL"'", "Actions": ["quicksight:DescribeDashboard","quicksight:ListDashboardVersions","quicksight:UpdateDashboardPermissions","quicksight:QueryDashboard","quicksight:UpdateDashboard","quicksight:DeleteDashboard","quicksight:UpdateDashboardPublishedVersion","quicksight:DescribeDashboardPermissions"]}]'

DATASET_ARN="arn:aws:quicksight:$REGION:$ACCOUNT_ID:dataset/hc-genomics-variants"

python3 -c "
import subprocess, json, time

acct = '$ACCOUNT_ID'
region = '$REGION'
dataset_arn = '$DATASET_ARN'
perms = json.loads('$DASHBOARD_PERMS')

definition = {
    'DataSetIdentifierDeclarations': [{'Identifier': 'variants', 'DataSetArn': dataset_arn}],
    'Sheets': [{'SheetId': 's1', 'Name': 'Genomics Research Portfolio', 'Visuals': [
        {'KPIVisual': {'VisualId': 'kpi-total', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Total Variants Analyzed'}}, 'ChartConfiguration': {'FieldWells': {'Values': [{'NumericalMeasureField': {'FieldId': 'f_total', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}}}},
        {'KPIVisual': {'VisualId': 'kpi-pathogenic', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Variants'}}, 'ChartConfiguration': {'FieldWells': {'Values': [{'NumericalMeasureField': {'FieldId': 'f_path', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}}}},
        {'BarChartVisual': {'VisualId': 'bar-pathogenic-gene', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Count by Gene'}}, 'ChartConfiguration': {'FieldWells': {'BarChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f1', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f2', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}}, 'SortConfiguration': {'CategorySort': [{'FieldSort': {'FieldId': 'f2', 'Direction': 'DESC'}}]}, 'Orientation': 'HORIZONTAL'}}},
        {'BarChartVisual': {'VisualId': 'bar-cohort', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Variants: Responders vs Non-Responders'}}, 'ChartConfiguration': {'FieldWells': {'BarChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f3', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f4', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}], 'Colors': [{'CategoricalDimensionField': {'FieldId': 'f5', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}]}}}}},
        {'PieChartVisual': {'VisualId': 'pie-cohort-split', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Variant Distribution by Cohort'}}, 'ChartConfiguration': {'FieldWells': {'PieChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f6', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f7', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}}}}},
        {'TableVisual': {'VisualId': 'table-detail', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Gene Detail'}}, 'ChartConfiguration': {'FieldWells': {'TableAggregatedFieldWells': {'GroupBy': [{'CategoricalDimensionField': {'FieldId': 'f8', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}}, {'CategoricalDimensionField': {'FieldId': 'f9', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f10', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}, {'NumericalMeasureField': {'FieldId': 'f11', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}, {'NumericalMeasureField': {'FieldId': 'f12', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'AVG_ALLELE_FREQUENCY'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}]}}, 'SortConfiguration': {'RowSort': [{'FieldSort': {'FieldId': 'f11', 'Direction': 'DESC'}}]}}}}
    ], 'Layouts': [{'Configuration': {'GridLayout': {'Elements': [
        {'ElementId': 'kpi-total', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 4},
        {'ElementId': 'kpi-pathogenic', 'ElementType': 'VISUAL', 'ColumnIndex': 18, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 4},
        {'ElementId': 'bar-pathogenic-gene', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 18, 'RowIndex': 4, 'RowSpan': 12},
        {'ElementId': 'bar-cohort', 'ElementType': 'VISUAL', 'ColumnIndex': 18, 'ColumnSpan': 18, 'RowIndex': 4, 'RowSpan': 12},
        {'ElementId': 'pie-cohort-split', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 12, 'RowIndex': 16, 'RowSpan': 8},
        {'ElementId': 'table-detail', 'ElementType': 'VISUAL', 'ColumnIndex': 12, 'ColumnSpan': 24, 'RowIndex': 16, 'RowSpan': 8}
    ]}}}]}]
}

cmd = ['aws', 'quicksight', 'create-dashboard', '--aws-account-id', acct, '--region', region,
       '--dashboard-id', 'hc-genomics-dashboard', '--name', 'Genomics: Variant Analysis',
       '--permissions', json.dumps(perms), '--definition', json.dumps(definition)]
r = subprocess.run(cmd, capture_output=True, text=True)
try:
    result = json.loads(r.stdout)
    print(f\"Dashboard: {result.get('CreationStatus')}\")
except:
    print(f\"Dashboard may already exist: {r.stderr[:100]}\")

time.sleep(8)
subprocess.run(['aws', 'quicksight', 'update-dashboard-published-version', '--aws-account-id', acct,
                '--dashboard-id', 'hc-genomics-dashboard', '--version-number', '1', '--region', region],
               capture_output=True)
print('Published dashboard')
"

echo "Created dashboard: hc-genomics-dashboard"

# Q Topic
echo "Creating Q topic: hc-genomics-q..."
aws quicksight create-topic \
    --aws-account-id "$ACCOUNT_ID" \
    --topic-id "hc-genomics-q" \
    --topic '{
        "Name": "Genomics Research",
        "Description": "Natural language queries over genomic variants, cohort comparison, and biobank inventory",
        "DataSets": [
            {
                "DatasetArn": "'"$DATASET_ARN"'",
                "DatasetName": "HC Genomics: Variant Summary"
            }
        ]
    }' \
    --region "$REGION" || echo "Q topic may already exist"

echo "Created Q topic: hc-genomics-q"
echo ""
echo "=== QuickSight deployment complete ==="
echo "Dashboard URL: https://$REGION.quicksight.aws.amazon.com/sn/dashboards/hc-genomics-dashboard"
