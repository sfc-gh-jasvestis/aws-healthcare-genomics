# Demo Script: Genomics Research Data Platform
## 4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: AWS Summit booth / research audience

---

## The Story

A BRCA1 Copy Number Variant (CNV) previously classified as "Variant of Uncertain Significance" (VUS) has just been reclassified to PATHOGENIC by the ACMG consortium. 204 patients in our research cohort carry this variant. They need immediate clinical re-notification, specimen availability confirmation for cascade testing, AI-powered interpretation validation, and data lake export for the clinical team's follow-up workflow.

---

## Two Personas

| Persona | Tool | What they care about |
|---|---|---|
| **Principal Investigator (Dr. Sarah Chen)** | Streamlit in Snowflake | Variant impact, cohort analysis, AI classification, cascade testing |
| **Research Director (Dr. James Park)** | Amazon QuickSight + Amazon Q | Portfolio view, gene-level statistics, resource planning |

---

## Narrative Arc: Architecture → Crisis Alert → Impact Assessment → Biobank Check → AI Interpretation → Literature Validation → Data Lake Export → Executive View

---

## Script

### [0:00–0:10] OPEN — ARCHITECTURE (Show: README.md in VS Code, scroll to architecture diagram)

> "Let's look at what we've built. This is a precision medicine research platform — end-to-end on Snowflake with AWS integration. At the bottom, S3 ingestion feeds into the Glue catalog and Athena for federated query. Raw genomic data flows through Dynamic Tables into three curated views: variant summary, cohort demographics, and biobank inventory. ML anomaly detection monitors allele frequencies across 20 genes. Cortex Search indexes 200 research publications. A Semantic View powers natural language analytics. All unified by a Cortex Agent and consumed through the Streamlit app."

### [0:10–0:20] PERSONAS (Show: Scroll to Personas table)

> "Two personas. The PI — Dr. Chen — manages the research cohort, interprets variants, and coordinates clinical follow-up. The Research Director — Dr. Park — tracks the overall portfolio and allocates resources. Same governed data, different consumption — Streamlit for research, QuickSight for executive."

### [0:20–0:30] DATA SCALE (Show: Scroll to Data Scale section)

> "5,000 patients across two cohorts — responders and non-responders to a targeted therapy. 100,000 genetic variants across 20 cancer-relevant genes. 20,000 biospecimens. 200 publications indexed for search. Eight capabilities from real-time variant analysis to AI classification to data lake export."

### [0:30–0:40] DEMO NARRATIVE (Show: Scroll to Demo Narrative section)

> "The story: A BRCA1 CNV — previously uncertain — just got reclassified to Pathogenic. 204 patients need action. Let's see how the platform responds."

### [0:40–0:55] THE CRISIS (Show: Switch to Streamlit — Variant Explorer page)

> "Here's the alert banner — immediate visual signal. 204 patients affected. The KPIs update: VUS count now shows '204 reclassified' in red. The strip plot below shows allele frequency by gene — you can see the red pathogenic clusters in BRCA1 are denser than other genes. Expanding the reclassified variant details shows the specific patients, their allele frequencies, and cohort assignments."

### [0:55–1:20] COHORT IMPACT (Show: Cohort Comparison page)

> "Now the research question: does this reclassification strengthen our biomarker signal? BRCA1 pathogenic enrichment: 2.8x in responders. The grouped bar chart makes it immediately visual — responders carry far more BRCA1 pathogenic variants. The impact panel shows: of the 204 reclassified patients, how many fall in each cohort. This moves them from VUS to Pathogenic, strengthening the treatment response signal."

### [1:20–1:45] BIOBANK (Show: Biobank page)

> "Can we actually re-test these patients? The biobank shows total specimen inventory — thousands available across blood, tissue, plasma, DNA. But the critical table is 'Cascade Testing Readiness' — filtered to just the 204 affected patients. Multiple specimen types available. We have the biological material to confirm the reclassification."

### [1:45–2:10] ANOMALY DETECTION (Show: Anomaly Detection page, BRCA1 selected)

> "The ML anomaly detection has been monitoring allele frequencies weekly across all 20 genes. BRCA1 — the observed frequency tracks the expected range, but watch for any data points that break the confidence interval. Those red X markers would indicate an anomalous shift — exactly what you'd investigate after a reclassification event. This model runs continuously through Snowflake ML."

### [2:10–2:40] AI CLASSIFICATION (Show: AI Classify page, select a variant, click button)

> "Here's where AI accelerates the workflow. I select one of the reclassified variants — a BRCA1 CNV from patient PAT-G with allele frequency 0.49. Click 'Run AI Variant Classification' — Cortex AI generates a full ACMG-style assessment. Gene, position, applicable ACMG criteria — PVS1 for loss-of-function, PM2 for rare frequency — pathogenicity score, classification recommendation, clinical actionability. What used to take a genetics counselor hours is done in seconds."

### [2:40–3:00] LITERATURE (Show: Publication search below AI section)

> "'BRCA1 copy number variant pathogenic reclassification' — Cortex Search surfaces relevant publications instantly. The PI validates the reclassification against published evidence without leaving the platform. 200 papers indexed and searchable."

### [3:00–3:15] DATA LAKE EXPORT (Show: Ask Genomics page, click export button)

> "Now the clinical handoff. Click 'Export Reclassified Cohort to Data Lake' — 208 records flow to LAKE.COHORT_EXPORT, tagged with the reclassification reason and timestamp. This triggers a COPY INTO the S3 stage as Parquet."

### [3:15–3:30] GLUE CATALOG (Show: Switch to AWS Console → Glue → Data Catalog → Databases → healthcare_genomics_iceberg → Tables → cohort_export)

> "In the AWS Glue Data Catalog — same region, Oregon — the database 'healthcare_genomics_iceberg' already has the table registered. 16 columns: patient ID, cohort, gene, variant type, allele frequency, export reason. The schema is automatically inferred from the Parquet metadata. No ETL jobs, no crawlers — the table definition is pre-registered and Snowflake writes directly to the S3 location."

### [3:30–3:50] ATHENA QUERY (Show: Switch to Athena Console → Query editor → Run query)

> "Now the clinical team's view. In Amazon Athena — select the 'healthcare_genomics_iceberg' database — and run: 'SELECT cohort_id, COUNT star, AVG allele_frequency FROM cohort_export GROUP BY cohort_id.' Results in under a second: 130 non-responders, 78 responders. Same governed data that was in Snowflake 30 seconds ago, now queryable by any AWS service. The clinical team uses their existing Athena workflows — zero friction."

**Athena query to run:**
```sql
SELECT cohort_id, COUNT(*) AS patient_count, ROUND(AVG(allele_frequency), 4) AS avg_af
FROM healthcare_genomics_iceberg.cohort_export
GROUP BY cohort_id
```

### [3:50–4:10] AMAZON Q (Show: Switch to QuickSight)

> "The Research Director opens QuickSight. Amazon Q: 'Which gene has the highest pathogenic count?' — BRCA1. Confirmed across all three access patterns: Streamlit for research, Athena for clinical ops, QuickSight for executive. One governed source, three consumption layers."

### [4:10–4:30] CLOSE

> "We started with an ACMG reclassification — a real-world crisis that hits genomics labs regularly. In under 4 minutes: 208 affected patients identified, biobank confirmed for cascade testing, AI classification validated the pathogenicity, literature corroborated the evidence, data exported to S3, visible in Glue, and queryable in Athena — all from one governed Snowflake platform. That's precision medicine research — Snowflake and AWS turning a multi-week crisis response into a 4-minute workflow."

---

## Pre-Recording Checklist

- [ ] Open README.md in VS Code — verify architecture diagram renders
- [ ] Scroll: Architecture → Personas → Data Scale → Capabilities → Demo Narrative
- [ ] Open Streamlit: HEALTHCARE_GENOMICS.APP.GENOMICS_RESEARCH_APP
- [ ] Verify alert banner shows on Variant Explorer page
- [ ] Verify VUS metric shows "204 reclassified"
- [ ] Switch to Cohort Comparison — verify 2.8x enrichment metric
- [ ] Switch to Biobank — verify cascade testing readiness table populates
- [ ] Switch to Anomaly Detection — select BRCA1, verify chart renders
- [ ] Switch to AI Classify — select a variant, click classify button, verify JSON output
- [ ] Test publication search: "BRCA1 copy number variant pathogenic"
- [ ] Test data lake export button — verify "208 records" success message
- [ ] Open AWS Glue Console (us-west-2): Databases → healthcare_genomics_iceberg → Tables → cohort_export
- [ ] Open Athena Console (us-west-2): Select database healthcare_genomics_iceberg, run: `SELECT cohort_id, COUNT(*) AS patient_count, ROUND(AVG(allele_frequency), 4) AS avg_af FROM cohort_export GROUP BY cohort_id`
- [ ] Verify Athena returns 2 rows (COHORT_RESPONDERS: 78, COHORT_NON_RESPONDERS: 130)
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/sn/dashboards/hc-genomics-dashboard
- [ ] Test Q topic question: "Which gene has the highest pathogenic count?"
