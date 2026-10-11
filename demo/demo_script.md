# Genomic Sequencing Lab Operations

**Singapore - Healthcare and Life Sciences**
Use case: Research sequencing lab operations and run QC triage

> Sequencing operations analytics for Harbourline Genomics, a fictional Singapore research sequencing network with 40 sequencers across 8 lab sites and 5 assays: dynamic tables, a holdout-evaluated failed-run classifier, a sample volume forecast and grounded AI answers. Data is synthetic and aggregate per instrument and day; there are no patient or genomic records, and nothing is for clinical use.

## Why Snowflake

- **Dynamic tables** reconcile samples, yield attainment, QC flags, confirmed failed runs and PM compliance from RAW instrument data, with checks in `run_core.py`
- **Failed-run classification** gives a holdout-evaluated next-7-day probability per sequencer
- **Sample volume forecast** projects 14 days of network-wide volume with prediction intervals, for lab staffing and reagent planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live runs**: a native run-summary simulator (Snowflake only) or S3 uploads and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.SEQUENCERS` (40 rows) |
| Fact table | `RAW.SEQUENCER_DAILY` (3,600 instrument-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `FAILURE_MODE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.QC_FAIL_SCORES`, `ML.QC_FAIL_HOLDOUT_METRICS`, `ML.SAMPLE_FORECAST`, `ML.PHASING_ANOMALIES` |

Lab sites (Singapore planning areas): Queenstown, Novena, Outram, Jurong East, Tampines, Woodlands, Seletar, Changi.
Assays: Whole Genome, Whole Exome, Targeted Panel, RNA-Seq, Pathogen Surveillance.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Yield Attainment | 94.8% |
| Samples Sequenced | 203,279 |
| Data Output (TB) | 2,500 |
| QC Flags | 711 |
| Confirmed Failed Runs | 224 |
| QC Flag Precision | 31.5% |
| Failed Runs Re-queued | 114 |
| PM Compliance | 79.1% |
| Sequencers Monitored | 40 |
| Reagent Kit Coverage | 65.3% |
| Kits On Order | 20 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily samples against QC flags, flags and confirmed failed runs by failure mode, sequencer table
2. Predictive: holdout metrics, risk bands, 14-day sample volume forecast, phasing anomalies
3. Lab Readiness: PM compliance, reagent kit coverage and kits on order, PM compliance against confirmed failed runs, then generate the action memo
4. Live Runs: run `CALL APP.SIMULATE_RUNS(20)` (Snowflake only) or `python aws/publish_runs.py --account <AWS_ACCOUNT_ID> --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_RUN_ALERT` and show the QC flag log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About one run QC flag in three is a confirmed failed run (31.5%). Most flags pass on review, which is where QC scientist time goes.
- Low cluster density on the Whole Genome line produces the most confirmed failed runs. Novena trails the network on yield; reagent lot hold flags (Novena and Seletar) hit every sequencer at a site at once and are never confirmed.
- The risk model is evaluated on a time-based holdout: precision 0.41 and recall 0.35 at 0.5, against a 0.25 base rate. The top-risk sequencer is SQ-0031 Changi RNA-Seq. Present it as triage, not a verdict.
- Reagent lot hold days are excluded from model training, because they are not instrument-driven.
- The data is operational and aggregate. Do not present any figure as a clinical, diagnostic or medical-efficacy result.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
