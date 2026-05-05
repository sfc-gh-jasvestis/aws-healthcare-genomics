import subprocess, json, time

acct = '__AWS_ACCOUNT_ID__'
region = 'us-west-2'
perms = [{'Principal': f'arn:aws:quicksight:{region}:{acct}:user/default/{acct}', 'Actions': ['quicksight:DescribeDashboard','quicksight:ListDashboardVersions','quicksight:UpdateDashboardPermissions','quicksight:QueryDashboard','quicksight:UpdateDashboard','quicksight:DeleteDashboard','quicksight:UpdateDashboardPublishedVersion','quicksight:DescribeDashboardPermissions']}]

ds_arn = f'arn:aws:quicksight:{region}:{acct}:dataset/hc-genomics-variants'

definition = {
    'DataSetIdentifierDeclarations': [
        {'Identifier': 'variants', 'DataSetArn': ds_arn}
    ],
    'Sheets': [{
        'SheetId': 's1',
        'Name': 'Genomics Research Portfolio',
        'Visuals': [
            {
                'KPIVisual': {
                    'VisualId': 'kpi-total',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Total Variants Analyzed'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'Values': [{'NumericalMeasureField': {'FieldId': 'f_total', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]
                        }
                    }
                }
            },
            {
                'KPIVisual': {
                    'VisualId': 'kpi-pathogenic',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Variants'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'Values': [{'NumericalMeasureField': {'FieldId': 'f_path', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]
                        }
                    }
                }
            },
            {
                'BarChartVisual': {
                    'VisualId': 'bar-pathogenic-gene',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Count by Gene'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'BarChartAggregatedFieldWells': {
                                'Category': [{'CategoricalDimensionField': {'FieldId': 'f1', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}}],
                                'Values': [{'NumericalMeasureField': {'FieldId': 'f2', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]
                            }
                        },
                        'SortConfiguration': {'CategorySort': [{'FieldSort': {'FieldId': 'f2', 'Direction': 'DESC'}}]},
                        'Orientation': 'HORIZONTAL'
                    }
                }
            },
            {
                'BarChartVisual': {
                    'VisualId': 'bar-cohort',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Pathogenic Variants: Responders vs Non-Responders'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'BarChartAggregatedFieldWells': {
                                'Category': [{'CategoricalDimensionField': {'FieldId': 'f3', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}}],
                                'Values': [{'NumericalMeasureField': {'FieldId': 'f4', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}],
                                'Colors': [{'CategoricalDimensionField': {'FieldId': 'f5', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}]
                            }
                        }
                    }
                }
            },
            {
                'PieChartVisual': {
                    'VisualId': 'pie-cohort-split',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Variant Distribution by Cohort'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'PieChartAggregatedFieldWells': {
                                'Category': [{'CategoricalDimensionField': {'FieldId': 'f6', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}],
                                'Values': [{'NumericalMeasureField': {'FieldId': 'f7', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]
                            }
                        }
                    }
                }
            },
            {
                'TableVisual': {
                    'VisualId': 'table-detail',
                    'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Gene Detail'}},
                    'ChartConfiguration': {
                        'FieldWells': {
                            'TableAggregatedFieldWells': {
                                'GroupBy': [
                                    {'CategoricalDimensionField': {'FieldId': 'f8', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'GENE'}}},
                                    {'CategoricalDimensionField': {'FieldId': 'f9', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'COHORT_ID'}}}
                                ],
                                'Values': [
                                    {'NumericalMeasureField': {'FieldId': 'f10', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'VARIANT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}},
                                    {'NumericalMeasureField': {'FieldId': 'f11', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'PATHOGENIC_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}},
                                    {'NumericalMeasureField': {'FieldId': 'f12', 'Column': {'DataSetIdentifier': 'variants', 'ColumnName': 'AVG_ALLELE_FREQUENCY'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}
                                ]
                            }
                        },
                        'SortConfiguration': {'RowSort': [{'FieldSort': {'FieldId': 'f11', 'Direction': 'DESC'}}]}
                    }
                }
            }
        ],
        'Layouts': [{
            'Configuration': {
                'GridLayout': {
                    'Elements': [
                        {'ElementId': 'kpi-total', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 4},
                        {'ElementId': 'kpi-pathogenic', 'ElementType': 'VISUAL', 'ColumnIndex': 18, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 4},
                        {'ElementId': 'bar-pathogenic-gene', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 18, 'RowIndex': 4, 'RowSpan': 12},
                        {'ElementId': 'bar-cohort', 'ElementType': 'VISUAL', 'ColumnIndex': 18, 'ColumnSpan': 18, 'RowIndex': 4, 'RowSpan': 12},
                        {'ElementId': 'pie-cohort-split', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 12, 'RowIndex': 16, 'RowSpan': 8},
                        {'ElementId': 'table-detail', 'ElementType': 'VISUAL', 'ColumnIndex': 12, 'ColumnSpan': 24, 'RowIndex': 16, 'RowSpan': 8}
                    ]
                }
            }
        }]
    }]
}

# Delete and recreate
subprocess.run(['aws', 'quicksight', 'delete-dashboard', '--aws-account-id', acct, '--dashboard-id', 'hc-genomics-dashboard', '--region', region], capture_output=True)
time.sleep(8)

cmd = ['aws', 'quicksight', 'create-dashboard', '--aws-account-id', acct, '--region', region,
       '--dashboard-id', 'hc-genomics-dashboard', '--name', 'Genomics: Variant Analysis',
       '--permissions', json.dumps(perms), '--definition', json.dumps(definition)]
r = subprocess.run(cmd, capture_output=True, text=True)
try:
    result = json.loads(r.stdout)
    print(f"Status: {result.get('CreationStatus')}")
except:
    print(f"Error: {r.stderr[:200]}")

time.sleep(8)
r = subprocess.run(['aws', 'quicksight', 'update-dashboard-published-version', '--aws-account-id', acct,
                    '--dashboard-id', 'hc-genomics-dashboard', '--version-number', '1', '--region', region],
                   capture_output=True, text=True)
print(f"Published: {json.loads(r.stdout).get('Status') if r.stdout else r.stderr[:100]}")
