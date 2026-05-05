# Genomics & Research Data Platform

A Snowflake-powered precision medicine platform demonstrating variant analysis, cohort comparison, AI-driven variant interpretation, biobank management, and Iceberg-based data lake export for interoperability with AWS Glue and Athena.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         STREAMLIT APPLICATION                            │
│  Variants │ Cohorts │ Biobank │ Forecast │ AI Classify │ Ask Genomics  │
└───────────┬─────────────────┬──────────────────┬────────────────────────┘
            │                 │                  │
┌───────────▼─────────────────▼──────────────────▼────────────────────────┐
│                        CORTEX AGENT (Green)                              │
│         GenomicsAnalyst Tool  +  PublicationSearch Tool                  │
└───────────┬─────────────────┬──────────────────┬────────────────────────┘
            │                 │                  │
┌───────────▼─────┐ ┌────────▼────────┐ ┌──────▼──────────────────────────┐
│  SEMANTIC VIEW  │ │  CORTEX SEARCH  │ │  ML MODELS                      │
│  (3 DTs)        │ │  (Publications) │ │  Anomaly Detection (20 genes)   │
└───────────┬─────┘ └────────┬────────┘ └──────┬──────────────────────────┘
            │                 │                  │
┌───────────▼─────────────────▼──────────────────▼────────────────────────┐
│                      DYNAMIC TABLES (Curated)                           │
│   VARIANT_SUMMARY  │  COHORT_DEMOGRAPHICS  │  BIOBANK_INVENTORY         │
└───────────┬─────────────────┬──────────────────┬────────────────────────┘
            │                 │                  │
┌───────────▼─────────────────▼──────────────────▼────────────────────────┐
│                         RAW SCHEMA                                       │
│  PATIENTS │ VARIANTS │ BIOSPECIMENS │ PHENOTYPES │ PUBLICATIONS │ COHORTS│
└───────────┬─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AWS INTEGRATION                                       │
│   S3 Stage → Iceberg Export → Glue Catalog → Athena (federated query)  │
│   QuickSight + Q (portfolio view, gene statistics)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Dr. Sarah Chen** | Principal Investigator | "Which patients carry the reclassified variant?" "Show me BRCA1 co-occurrence patterns" "Are specimens available for cascade testing?" |
| **Dr. James Park** | Research Director | "What's our biobank utilization?" "How does our cohort compare to published literature?" "Export the affected cohort to the data lake for clinical follow-up" |

## Data Scale

| Table | Rows | Description |
|-------|------|-------------|
| PATIENTS | 5,000 | 2 cohorts: Responders / Non-Responders |
| VARIANTS | 100,000 | 20 genes, deliberate BRCA1 pathogenic skew in responders |
| BIOSPECIMENS | 20,000 | Blood, tissue, plasma, DNA |
| PHENOTYPES | 30,000 | Clinical phenotype observations |
| PUBLICATIONS | 200 | Research papers with abstracts for Cortex Search |
| COHORT_DEFINITIONS | 50 | Reusable cohort criteria |

## Capabilities

1. **Variant Analysis** — Gene-level aggregation with clinical significance filtering and strip-plot visualization
2. **Cohort Comparison** — Side-by-side pathogenic variant burden: Responders vs Non-Responders
3. **Biobank Management** — Specimen inventory, cascade testing readiness, quality metrics
4. **Allele Frequency Anomaly Detection** — ML-based monitoring of 20 gene allele frequency series
5. **AI Variant Interpretation** — Cortex AI generates ACMG-style pathogenicity assessments in real-time
6. **Publication Search** — Cortex Search over 200 research abstracts for literature validation
7. **Data Lake Export** — BRCA1+TP53 co-occurrence cohort exported to S3 → Glue Catalog → Athena
8. **Conversational Agent** — Green-themed Cortex Agent combining analyst + publication search

## Demo Narrative

The demo centers on a **VUS reclassification crisis**: A BRCA1 Variant of Uncertain Significance (rs121913279) has just been reclassified to PATHOGENIC by the ACMG consortium based on new functional evidence. Over 200 patients in our research cohort carry this variant and need immediate clinical re-notification and cascade testing. The PI uses the platform to identify affected patients, confirm biobank specimen availability, validate the reclassification against literature, get AI-powered interpretation, and export the affected cohort to the AWS data lake for the clinical team's follow-up workflow.

## Build Instructions

```bash
# 1. Deploy Snowflake objects (run in order)
for f in snowflake/0*.sql; do
  snow sql -f "$f" -c <YOUR_CONNECTION>
done

# 2. Deploy QuickSight resources
chmod +x quicksight/deploy.sh
./quicksight/deploy.sh

# 3. Deploy Streamlit app
snow streamlit deploy --database HEALTHCARE_GENOMICS --schema APP
```

## Tear Down

```bash
# Remove AWS resources
chmod +x aws/teardown.sh
./aws/teardown.sh

# Remove Snowflake objects
snow sql -q "DROP DATABASE IF EXISTS HEALTHCARE_GENOMICS CASCADE;" -c <YOUR_CONNECTION>
```

## License

Apache 2.0
