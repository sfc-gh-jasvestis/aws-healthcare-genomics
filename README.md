# Genomics & Research Data Platform

A Snowflake-powered genomics research platform demonstrating variant analysis, cohort comparison, biobank management, and Iceberg-based data lake export for interoperability with AWS Glue and Athena.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Snowflake                                     │
│  ┌───────┐   ┌─────────┐   ┌────────┐   ┌──────────┐   ┌───────┐ │
│  │  RAW  │──▶│ CURATED │──▶│   AI   │   │  SEARCH  │   │  ML   │ │
│  │       │   │  (DTs)  │   │(Agent) │   │(Cortex)  │   │(Anom) │ │
│  └───────┘   └─────────┘   └────────┘   └──────────┘   └───────┘ │
│       │                                                      │      │
│       ▼                                                      ▼      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    LAKE (Iceberg Export)                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
        │                                              │
        ▼                                              ▼
┌──────────────┐                              ┌──────────────────┐
│  AWS Glue    │                              │  Amazon Athena   │
│  Catalog     │◀────────────────────────────▶│  (Federated SQL) │
└──────────────┘                              └──────────────────┘
        │
        ▼
┌──────────────┐
│  QuickSight  │
│  (BI / Q)    │
└──────────────┘
```

## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Dr. Sarah Chen** | Principal Investigator | "Which variants are enriched in responders?" "Show me BRCA1 co-occurrence patterns" |
| **Dr. James Park** | Research Director | "What's our biobank utilization?" "How does our cohort compare to published literature?" |

## Data Scale

| Table | Rows | Notes |
|-------|------|-------|
| PATIENTS | 5,000 | 2 cohorts: Responders / Non-Responders |
| VARIANTS | 100,000 | 20 genes, deliberate BRCA1 pathogenic skew in responders |
| BIOSPECIMENS | 20,000 | Blood, tissue, plasma, DNA |
| PHENOTYPES | 30,000 | Clinical phenotype observations |
| PUBLICATIONS | 200 | Research papers with abstracts |
| COHORT_DEFINITIONS | 50 | Reusable cohort criteria |

## Key Discovery

> **BRCA1 pathogenic variants are 2.8x enriched in the responder cohort** compared to non-responders, suggesting BRCA1 status as a predictive biomarker for treatment response.

## Capabilities

1. **Variant Analysis** — Gene-level aggregation with clinical significance filtering
2. **Cohort Comparison** — Side-by-side demographics and variant burden across cohorts
3. **Biobank Management** — Specimen inventory, utilization tracking, quality metrics
4. **Publication Search** — Cortex Search over 200 research abstracts with gene-level filtering
5. **Iceberg Export** — BRCA1+TP53 co-occurrence cohort exported to Iceberg format for Glue/Athena

## Build

```bash
# Execute SQL scripts in order
for f in snowflake/0*.sql; do
  snow sql -f "$f" -c <YOUR_CONNECTION>
done

# Deploy QuickSight resources (requires AWS credentials)
chmod +x quicksight/deploy.sh
./quicksight/deploy.sh
```

## Tear Down

```bash
# Remove Snowflake objects
snow sql -q "DROP DATABASE IF EXISTS HEALTHCARE_GENOMICS" -c <YOUR_CONNECTION>

# Remove AWS resources
chmod +x aws/teardown.sh
./aws/teardown.sh
```

## License

Apache 2.0
