import subprocess, json, time

acct = '__AWS_ACCOUNT_ID__'
region = 'us-west-2'
perms = [{'Principal': f'arn:aws:quicksight:{region}:{acct}:user/default/{acct}', 'Actions': ['quicksight:DescribeDashboard','quicksight:ListDashboardVersions','quicksight:UpdateDashboardPermissions','quicksight:QueryDashboard','quicksight:UpdateDashboard','quicksight:DeleteDashboard','quicksight:UpdateDashboardPublishedVersion','quicksight:DescribeDashboardPermissions']}]

dashboards = [
    {
        'id': 'hc-radiology-dashboard',
        'name': 'Radiology: TAT & Critical Findings',
        'definition': {
            'DataSetIdentifierDeclarations': [
                {'Identifier': 'tat', 'DataSetArn': f'arn:aws:quicksight:{region}:{acct}:dataset/hc-radiology-tat'},
                {'Identifier': 'crit', 'DataSetArn': f'arn:aws:quicksight:{region}:{acct}:dataset/hc-radiology-critical'}
            ],
            'Sheets': [{'SheetId': 's1', 'Name': 'TAT & Critical Findings', 'Visuals': [
                {'BarChartVisual': {'VisualId': 'v1', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Average TAT by Modality (Minutes)'}}, 'ChartConfiguration': {'FieldWells': {'BarChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f1', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'MODALITY'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f2', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'AVG_TAT_MINUTES'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}]}}}}},
                {'BarChartVisual': {'VisualId': 'v2', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'SLA Breach % by Modality'}}, 'ChartConfiguration': {'FieldWells': {'BarChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f3', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'MODALITY'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f4', 'Column': {'DataSetIdentifier': 'tat', 'ColumnName': 'SLA_BREACH_PCT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'AVERAGE'}}}]}}}}}
            ], 'Layouts': [{'Configuration': {'GridLayout': {'Elements': [
                {'ElementId': 'v1', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 12},
                {'ElementId': 'v2', 'ElementType': 'VISUAL', 'ColumnIndex': 18, 'ColumnSpan': 18, 'RowIndex': 0, 'RowSpan': 12}
            ]}}}]}]
        }
    },
    {
        'id': 'hc-trials-dashboard',
        'name': 'Clinical Trials: Site Performance',
        'definition': {
            'DataSetIdentifierDeclarations': [
                {'Identifier': 'sites', 'DataSetArn': f'arn:aws:quicksight:{region}:{acct}:dataset/hc-trials-sites'}
            ],
            'Sheets': [{'SheetId': 's1', 'Name': 'Site Performance', 'Visuals': [
                {'BarChartVisual': {'VisualId': 'v1', 'Title': {'Visibility': 'VISIBLE', 'FormatText': {'PlainText': 'Enrollment by Site'}}, 'ChartConfiguration': {'FieldWells': {'BarChartAggregatedFieldWells': {'Category': [{'CategoricalDimensionField': {'FieldId': 'f1', 'Column': {'DataSetIdentifier': 'sites', 'ColumnName': 'SITE_NAME'}}}], 'Values': [{'NumericalMeasureField': {'FieldId': 'f2', 'Column': {'DataSetIdentifier': 'sites', 'ColumnName': 'ENROLLMENT_COUNT'}, 'AggregationFunction': {'SimpleNumericalAggregation': 'SUM'}}}]}}}}}
            ], 'Layouts': [{'Configuration': {'GridLayout': {'Elements': [
                {'ElementId': 'v1', 'ElementType': 'VISUAL', 'ColumnIndex': 0, 'ColumnSpan': 36, 'RowIndex': 0, 'RowSpan': 12}
            ]}}}]}]
        }
    }
]

for db in dashboards:
    cmd = ['aws', 'quicksight', 'create-dashboard', '--aws-account-id', acct, '--region', region,
           '--dashboard-id', db['id'], '--name', db['name'],
           '--permissions', json.dumps(perms), '--definition', json.dumps(db['definition'])]
    r = subprocess.run(cmd, capture_output=True, text=True)
    try:
        result = json.loads(r.stdout)
        print(f"{db['id']}: {result.get('CreationStatus')}")
    except:
        print(f"{db['id']}: {r.stderr[:150]}")
    time.sleep(3)

time.sleep(8)

for db in dashboards:
    r = subprocess.run(['aws', 'quicksight', 'update-dashboard-published-version', '--aws-account-id', acct,
                        '--dashboard-id', db['id'], '--version-number', '1', '--region', region],
                       capture_output=True, text=True)
    print(f"Published {db['id']}")

# Check genomics dashboard status
r = subprocess.run(['aws', 'quicksight', 'describe-dashboard', '--aws-account-id', acct,
                    '--dashboard-id', 'hc-genomics-dashboard', '--region', region],
                   capture_output=True, text=True)
d = json.loads(r.stdout)
print(f"\nGenomics dashboard status: {d['Dashboard']['Version']['Status']}")
