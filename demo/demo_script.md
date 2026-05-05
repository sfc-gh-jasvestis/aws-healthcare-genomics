# Demo Script: Genomics Research Data Platform
## 3-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: AWS Summit booth / research audience

---

## The Story

A Principal Investigator discovers that BRCA1 pathogenic variants are 2.8x more frequent in treatment responders — a potential biomarker for precision medicine. Using the platform, they compare cohorts, search publications, query the biobank, and export a cohort to the research data lake for further analysis.

---

## Two Personas

| Persona | Tool | What they care about |
|---|---|---|
| **Principal Investigator** | Streamlit in Snowflake | Variant analysis, cohort comparison, publication search |
| **Research Director** | Amazon QuickSight + Amazon Q | Portfolio view, gene-level statistics, resource planning |

---

## Narrative Arc: Discovery → Validation → Literature → Export → Collaboration

---

## Script

### [0:00–0:15] THE DISCOVERY (Show: App header + KPIs)

> "5,000 patients. 100,000 genetic variants across 20 cancer-relevant genes. Two cohorts: responders and non-responders to a targeted therapy. The question: is there a genomic signature that predicts who will respond?"

### [0:15–0:40] VARIANT FREQUENCY (Show: Strip plot)

> "Allele frequency by gene. Each dot is a variant — colored by clinical significance. You can immediately see the red clusters — pathogenic variants — are not evenly distributed. BRCA1 has a visible concentration of pathogenic variants compared to other genes."

### [0:40–1:10] COHORT COMPARISON (Show: Grouped bar chart)

> "Here's the answer. Pathogenic BRCA1 variants in responders: 45.6%. In non-responders: 16.4%. That's a 2.8x enrichment. This isn't noise — it's a potential predictive biomarker. The grouped bar chart makes it instantly visual. TP53 shows a similar but weaker signal. All powered by a Dynamic Table that aggregates 100K variants in real-time."

### [1:10–1:30] BIOBANK (Show: Biobank inventory section)

> "Can we validate this finding? The biobank shows 2,814 FFPE specimens available — enough for a validation cohort. Blood samples: 2,822 available. The quality scores are above 69 across all types. We have the biological material to confirm the discovery."

### [1:30–1:55] PUBLICATION SEARCH (Show: Search for "BRCA1 pathogenic")

> "Search 'BRCA1 pathogenic variants breast cancer' — Cortex Search across 200 research publications. Instantly surfaces relevant papers with abstracts. The PI can validate their finding against existing literature without leaving the platform."

### [1:55–2:20] ASK THE DATA (Show: Ask the Data section)

> "'Which genes have the most pathogenic variants in responders?' — Cortex Analyst generates the SQL and returns a ranked table. The PI gets programmatic answers without writing code."

### [2:20–2:40] AMAZON Q (Show: Switch to QuickSight)

> "The Research Director asks Amazon Q: 'Which gene has the highest pathogenic count?' — BRCA1. Confirmed across both analytics tools. The data is consistent because it's one governed source."

### [2:40–3:00] CLOSE

> "From discovery to validation plan in under 3 minutes. 100,000 variants analyzed. Cohorts compared. Literature searched. Biobank confirmed. Cohort exported to the data lake. That's precision medicine research — powered by Snowflake and AWS."

---

## Pre-Recording Checklist

- [ ] Open Streamlit: HEALTHCARE_GENOMICS.APP.GENOMICS_RESEARCH_APP
- [ ] Verify variant strip plot renders
- [ ] Verify cohort comparison shows BRCA1 difference
- [ ] Verify biobank shows ~2,814 FFPE available
- [ ] Test publication search: "BRCA1 pathogenic"
- [ ] Test Q: "Which gene has the most pathogenic variants?"
