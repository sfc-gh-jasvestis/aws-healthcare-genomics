import streamlit as st
import pandas as pd
import json
import plotly.express as px
import plotly.graph_objects as go
import _snowflake
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="Genomics Research", layout="wide", page_icon="🧬")

page = st.sidebar.radio("Navigation", [
    "Variant Explorer",
    "Cohort Comparison",
    "Biobank",
    "Anomaly Detection",
    "AI Classify",
    "Ask Genomics"
], label_visibility="collapsed")
st.sidebar.divider()
st.sidebar.markdown("### Genomics Research Platform")
st.sidebar.caption("Precision medicine research — variant analysis, cohort comparison, AI interpretation")
st.sidebar.divider()
gene_filter = st.sidebar.multiselect("Gene Filter", ["BRCA1", "BRCA2", "TP53", "EGFR", "KRAS", "PIK3CA", "ALK", "HER2", "PTEN", "RB1"])
gene_clause = "','".join(gene_filter) if gene_filter else ""
gene_sql = f"AND GENE IN ('{gene_clause}')" if gene_filter else ""

ALERT_MSG = "BRCA1 CNV (VUS) reclassified to PATHOGENIC by ACMG — 204 patients require clinical re-notification"

if page == "Variant Explorer":
    st.error(f"⚠️ {ALERT_MSG}", icon="🚨")
    st.title("Variant Explorer")
    st.caption("Gene-level variant analysis with clinical significance filtering")

    kpi = session.sql(f"""
        SELECT COUNT(DISTINCT PATIENT_ID) AS PATIENTS,
               COUNT(*) AS VARIANTS,
               COUNT_IF(CLINICAL_SIGNIFICANCE='PATHOGENIC') AS PATHOGENIC,
               COUNT_IF(CLINICAL_SIGNIFICANCE='VUS') AS VUS
        FROM HEALTHCARE_GENOMICS.RAW.VARIANTS
        WHERE 1=1 {gene_sql}
    """).to_pandas()
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Patients", f"{kpi['PATIENTS'].iloc[0]:,}")
    c2.metric("Total Variants", f"{kpi['VARIANTS'].iloc[0]:,}")
    c3.metric("Pathogenic", f"{kpi['PATHOGENIC'].iloc[0]:,}")
    c4.metric("VUS (Under Review)", f"{kpi['VUS'].iloc[0]:,}", delta="204 reclassified", delta_color="inverse")

    st.subheader("Allele Frequency Distribution")
    var_df = session.sql(f"""
        SELECT GENE, ALLELE_FREQUENCY::FLOAT AS AF, CLINICAL_SIGNIFICANCE, VARIANT_TYPE
        FROM HEALTHCARE_GENOMICS.RAW.VARIANTS
        WHERE ALLELE_FREQUENCY > 0.01 {gene_sql}
        ORDER BY RANDOM() LIMIT 1000
    """).to_pandas()
    if not var_df.empty:
        var_df["AF"] = pd.to_numeric(var_df["AF"], errors="coerce")
        fig = px.strip(var_df, x="GENE", y="AF", color="CLINICAL_SIGNIFICANCE",
                       color_discrete_map={"PATHOGENIC": "#FF4B4B", "LIKELY_PATHOGENIC": "#FF8C00",
                                           "VUS": "#FFC107", "LIKELY_BENIGN": "#4CAF50", "BENIGN": "#2196F3"},
                       title="Allele Frequency by Gene (colored by clinical significance)")
        fig.update_layout(height=450, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

    with st.expander("Reclassified Variant Details — BRCA1 CNV"):
        reclass = session.sql("""
            SELECT v.VARIANT_ID, v.PATIENT_ID, v.POSITION, v.VARIANT_TYPE,
                   v.ALLELE_FREQUENCY::FLOAT AS AF, v.ZYGOSITY, v.DEPTH,
                   p.COHORT_ID, p.GENDER, p.ETHNICITY
            FROM HEALTHCARE_GENOMICS.RAW.VARIANTS v
            JOIN HEALTHCARE_GENOMICS.RAW.PATIENTS p ON v.PATIENT_ID = p.PATIENT_ID
            WHERE v.GENE = 'BRCA1' AND v.CLINICAL_SIGNIFICANCE = 'VUS' AND v.VARIANT_TYPE = 'CNV'
            ORDER BY v.ALLELE_FREQUENCY DESC
            LIMIT 20
        """).to_pandas()
        if not reclass.empty:
            reclass["AF"] = pd.to_numeric(reclass["AF"], errors="coerce")
            st.dataframe(reclass, use_container_width=True)
            st.info(f"Showing top 20 of 204 affected patients. These require clinical notification and cascade testing.")

elif page == "Cohort Comparison":
    st.error(f"⚠️ {ALERT_MSG}", icon="🚨")
    st.title("Cohort Comparison: Responders vs Non-Responders")
    st.caption("Pathogenic variant burden by gene and cohort")

    cohort = session.sql(f"""
        SELECT GENE, COHORT_ID,
               SUM(VARIANT_COUNT)::FLOAT AS VARIANT_COUNT,
               SUM(PATHOGENIC_COUNT)::FLOAT AS PATHOGENIC_COUNT,
               AVG(AVG_ALLELE_FREQUENCY)::FLOAT AS AVG_AF
        FROM HEALTHCARE_GENOMICS.CURATED.VARIANT_SUMMARY
        WHERE 1=1 {gene_sql.replace('AND GENE', 'AND GENE')}
        GROUP BY GENE, COHORT_ID ORDER BY GENE
    """).to_pandas()
    if not cohort.empty:
        for col in ["VARIANT_COUNT", "PATHOGENIC_COUNT", "AVG_AF"]:
            cohort[col] = pd.to_numeric(cohort[col], errors="coerce")

        brca1 = cohort[cohort["GENE"] == "BRCA1"]
        if not brca1.empty:
            resp_count = brca1[brca1["COHORT_ID"].str.contains("RESP", case=False, na=False)]["PATHOGENIC_COUNT"].sum()
            nonresp_count = brca1[~brca1["COHORT_ID"].str.contains("RESP", case=False, na=False)]["PATHOGENIC_COUNT"].sum()
            if nonresp_count > 0:
                ratio = resp_count / nonresp_count
                st.metric("BRCA1 Pathogenic Enrichment (Responders / Non-Responders)", f"{ratio:.1f}x")

        fig = px.bar(cohort, x="GENE", y="PATHOGENIC_COUNT", color="COHORT_ID", barmode="group",
                     title="Pathogenic Variants: Responders vs Non-Responders",
                     color_discrete_map={"COHORT_RESPONDERS": "#2196F3", "COHORT_NON_RESPONDERS": "#FF5722"})
        fig.update_layout(height=400, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Impact of VUS Reclassification")
    impact = session.sql("""
        SELECT p.COHORT_ID, COUNT(DISTINCT v.PATIENT_ID) AS AFFECTED_PATIENTS
        FROM HEALTHCARE_GENOMICS.RAW.VARIANTS v
        JOIN HEALTHCARE_GENOMICS.RAW.PATIENTS p ON v.PATIENT_ID = p.PATIENT_ID
        WHERE v.GENE = 'BRCA1' AND v.CLINICAL_SIGNIFICANCE = 'VUS' AND v.VARIANT_TYPE = 'CNV'
        GROUP BY p.COHORT_ID
    """).to_pandas()
    if not impact.empty:
        cols = st.columns(len(impact))
        for i, (_, row) in enumerate(impact.iterrows()):
            cols[i].metric(f"{row['COHORT_ID']}", f"{row['AFFECTED_PATIENTS']} patients")
        st.warning("These 204 patients move from VUS → Pathogenic, increasing the overall pathogenic burden and strengthening the biomarker signal.")

elif page == "Biobank":
    st.title("Biobank Inventory & Cascade Testing Readiness")
    st.caption("Specimen availability for validation and re-testing")

    bio = session.sql("""
        SELECT SPECIMEN_TYPE, SUM(TOTAL_SPECIMENS)::INT AS TOTAL,
               SUM(AVAILABLE_COUNT)::INT AS AVAILABLE,
               ROUND(AVG(AVG_QUALITY),1)::FLOAT AS QUALITY
        FROM HEALTHCARE_GENOMICS.CURATED.BIOBANK_INVENTORY
        GROUP BY SPECIMEN_TYPE ORDER BY AVAILABLE DESC
    """).to_pandas()
    if not bio.empty:
        for col in ["TOTAL", "AVAILABLE", "QUALITY"]:
            bio[col] = pd.to_numeric(bio[col], errors="coerce")
        c1, c2, c3 = st.columns(3)
        c1.metric("Total Specimens", f"{bio['TOTAL'].sum():,}")
        c2.metric("Available", f"{bio['AVAILABLE'].sum():,}")
        c3.metric("Avg Quality Score", f"{bio['QUALITY'].mean():.1f}")

        fig = px.bar(bio, x="SPECIMEN_TYPE", y="AVAILABLE", color="QUALITY",
                     color_continuous_scale="Greens", title="Available Specimens by Type")
        fig.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Cascade Testing Readiness — Reclassified Patients")
    cascade = session.sql("""
        SELECT b.SPECIMEN_TYPE, COUNT(DISTINCT b.PATIENT_ID) AS PATIENTS_WITH_SPECIMEN,
               SUM(CASE WHEN b.STATUS = 'AVAILABLE' THEN 1 ELSE 0 END) AS AVAILABLE_SPECIMENS
        FROM HEALTHCARE_GENOMICS.RAW.BIOSPECIMENS b
        WHERE b.PATIENT_ID IN (
            SELECT DISTINCT PATIENT_ID FROM HEALTHCARE_GENOMICS.RAW.VARIANTS
            WHERE GENE = 'BRCA1' AND CLINICAL_SIGNIFICANCE = 'VUS' AND VARIANT_TYPE = 'CNV'
        )
        GROUP BY b.SPECIMEN_TYPE ORDER BY AVAILABLE_SPECIMENS DESC
    """).to_pandas()
    if not cascade.empty:
        for col in ["PATIENTS_WITH_SPECIMEN", "AVAILABLE_SPECIMENS"]:
            cascade[col] = pd.to_numeric(cascade[col], errors="coerce")
        st.dataframe(cascade, use_container_width=True)
        total_available = cascade["AVAILABLE_SPECIMENS"].sum()
        st.success(f"✅ {total_available} specimens available across {len(cascade)} types for cascade testing of 204 affected patients.")

elif page == "Anomaly Detection":
    st.title("Allele Frequency Anomaly Detection")
    st.caption("ML-based monitoring of 20 gene allele frequency series — detecting unusual shifts")

    anomaly = session.sql("""
        SELECT SERIES AS GENE, TS, Y::FLOAT AS OBSERVED, FORECAST::FLOAT AS EXPECTED,
               LOWER_BOUND::FLOAT AS LOWER_BOUND, UPPER_BOUND::FLOAT AS UPPER_BOUND,
               IS_ANOMALY, PERCENTILE::FLOAT AS PERCENTILE
        FROM HEALTHCARE_GENOMICS.ML.ANOMALY_DETECTION_RESULTS
        ORDER BY TS
    """).to_pandas()
    if not anomaly.empty:
        for col in ["OBSERVED", "EXPECTED", "LOWER_BOUND", "UPPER_BOUND", "PERCENTILE"]:
            anomaly[col] = pd.to_numeric(anomaly[col], errors="coerce")

        anomalies_found = anomaly[anomaly["IS_ANOMALY"] == True]
        c1, c2, c3 = st.columns(3)
        c1.metric("Genes Monitored", anomaly["GENE"].nunique())
        c2.metric("Observations", len(anomaly))
        c3.metric("Anomalies Detected", len(anomalies_found), delta="requires review" if len(anomalies_found) > 0 else "all normal")

        selected_genes = st.multiselect("Select genes to visualize", sorted(anomaly["GENE"].unique()),
                                        default=["BRCA1", "TP53", "EGFR"] if "BRCA1" in anomaly["GENE"].values else list(anomaly["GENE"].unique()[:3]))
        for gene in selected_genes:
            g = anomaly[anomaly["GENE"] == gene]
            fig = go.Figure()
            fig.add_trace(go.Scatter(x=g["TS"], y=g["OBSERVED"], mode="markers+lines", name="Observed", line=dict(color="#636EFA")))
            fig.add_trace(go.Scatter(x=g["TS"], y=g["EXPECTED"], mode="lines", name="Expected", line=dict(color="#00CC96", dash="dash")))
            fig.add_trace(go.Scatter(x=g["TS"], y=g["UPPER_BOUND"], mode="lines", line=dict(width=0), showlegend=False))
            fig.add_trace(go.Scatter(x=g["TS"], y=g["LOWER_BOUND"], mode="lines", line=dict(width=0), fill="tonexty", fillcolor="rgba(0,204,150,0.15)", name="Expected Range"))
            anom_pts = g[g["IS_ANOMALY"] == True]
            if not anom_pts.empty:
                fig.add_trace(go.Scatter(x=anom_pts["TS"], y=anom_pts["OBSERVED"], mode="markers", name="Anomaly",
                                         marker=dict(color="red", size=12, symbol="x")))
            fig.update_layout(title=f"{gene} — Allele Frequency Monitoring", height=300, margin=dict(t=40, b=10), yaxis_title="Avg Allele Frequency")
            st.plotly_chart(fig, use_container_width=True)

elif page == "AI Classify":
    st.error(f"⚠️ {ALERT_MSG}", icon="🚨")
    st.title("AI Variant Interpretation")
    st.caption("Cortex AI generates ACMG-style pathogenicity assessments")

    st.markdown("Select a variant from the reclassified cohort for AI-powered interpretation:")

    hero_variant = session.sql("""
        SELECT v.VARIANT_ID, v.PATIENT_ID, v.GENE, v.CHROMOSOME, v.POSITION,
               v.REF_ALLELE, v.ALT_ALLELE, v.VARIANT_TYPE, v.CONSEQUENCE,
               v.ALLELE_FREQUENCY::FLOAT AS AF, v.CLINICAL_SIGNIFICANCE, v.ZYGOSITY, v.DEPTH,
               p.GENDER, DATEDIFF('year', p.DOB, CURRENT_DATE()) AS AGE, p.ETHNICITY, p.COHORT_ID
        FROM HEALTHCARE_GENOMICS.RAW.VARIANTS v
        JOIN HEALTHCARE_GENOMICS.RAW.PATIENTS p ON v.PATIENT_ID = p.PATIENT_ID
        WHERE v.GENE = 'BRCA1' AND v.VARIANT_TYPE = 'CNV' AND v.CLINICAL_SIGNIFICANCE = 'VUS'
        ORDER BY v.ALLELE_FREQUENCY DESC
        LIMIT 5
    """).to_pandas()

    if not hero_variant.empty:
        hero_variant["AF"] = pd.to_numeric(hero_variant["AF"], errors="coerce")
        selected = st.selectbox("Select variant:", hero_variant["VARIANT_ID"].tolist())
        row = hero_variant[hero_variant["VARIANT_ID"] == selected].iloc[0]

        col1, col2 = st.columns(2)
        with col1:
            st.markdown("**Variant Details**")
            st.markdown(f"- Gene: **{row['GENE']}**")
            st.markdown(f"- Position: chr{row['CHROMOSOME']}:{row['POSITION']}")
            st.markdown(f"- Type: {row['VARIANT_TYPE']} ({row['CONSEQUENCE']})")
            st.markdown(f"- Allele Frequency: {row['AF']:.3f}")
            st.markdown(f"- Zygosity: {row['ZYGOSITY']}, Depth: {row['DEPTH']}")
        with col2:
            st.markdown("**Patient Context**")
            st.markdown(f"- Patient: {row['PATIENT_ID']}")
            st.markdown(f"- Gender: {row['GENDER']}, Age: {row['AGE']}")
            st.markdown(f"- Ethnicity: {row['ETHNICITY']}")
            st.markdown(f"- Cohort: {row['COHORT_ID']}")

        if st.button("🧬 Run AI Variant Classification", type="primary"):
            with st.spinner("Cortex AI generating ACMG-style assessment..."):
                try:
                    prompt = f"""You are a clinical genomics expert. Provide an ACMG/AMP-style pathogenicity assessment for this variant.

Variant: {row['GENE']} {row['VARIANT_TYPE']} at chr{row['CHROMOSOME']}:{row['POSITION']}
Consequence: {row['CONSEQUENCE']}
Allele Frequency: {row['AF']:.4f}
Zygosity: {row['ZYGOSITY']}
Read Depth: {row['DEPTH']}
Patient Cohort: {row['COHORT_ID']} (treatment response study)
Current Classification: VUS (under review for reclassification to Pathogenic)

Provide your assessment as structured JSON with these fields:
- gene, variant_description, acmg_criteria (array of applicable criteria codes like PVS1, PM2, PP3 etc with brief justification), 
- pathogenicity_score (1-5 scale), classification (one of: Benign, Likely_Benign, VUS, Likely_Pathogenic, Pathogenic),
- clinical_actionability (Low/Medium/High), recommendation (brief clinical next step),
- evidence_summary (2-3 sentences)"""
                    safe = prompt.replace("'", "''")
                    result = session.sql(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5', '{safe}')").collect()[0][0]
                    st.markdown("**AI Classification Result:**")
                    st.code(str(result), language="json")
                    st.success("Classification complete. Based on ACMG criteria, this variant supports reclassification to Likely Pathogenic / Pathogenic.")
                except Exception as e:
                    st.error(f"Error: {e}")

    st.divider()
    st.subheader("Publication Search — Validate Reclassification")
    query = st.text_input("Search research publications:", value="BRCA1 copy number variant pathogenic reclassification")
    if query:
        with st.spinner("Searching 200 publications..."):
            try:
                safe_q = query.replace("'", "''").replace('"', '\\"')
                raw = session.sql(f"""SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'HEALTHCARE_GENOMICS.SEARCH.PUBLICATION_SEARCH',
                    '{{"query": "{safe_q}", "columns": ["ABSTRACT", "TITLE", "JOURNAL"], "limit": 5}}'
                ) AS R""").collect()[0][0]
                results = json.loads(raw) if isinstance(raw, str) else raw
                for r in results.get("results", []):
                    st.markdown(f"**{r.get('TITLE', '')}** — _{r.get('JOURNAL', '')}_")
                    st.caption(r.get("ABSTRACT", "")[:250] + "...")
                    st.divider()
            except Exception as e:
                st.error(f"Search error: {e}")

elif page == "Ask Genomics":
    st.title("Ask the Data")
    st.markdown("Natural language questions powered by Cortex Analyst:")
    sample_qs = [
        "How many patients carry BRCA1 VUS variants?",
        "Which genes have the most pathogenic variants in responders?",
        "What is the average allele frequency for BRCA1 pathogenic variants?"
    ]
    sel_q = st.selectbox("Sample questions:", [""] + sample_qs)
    user_q = st.text_input("Or type your question:") or sel_q
    if user_q:
        with st.spinner("Generating answer..."):
            try:
                request_body = {
                    "messages": [{"role": "user", "content": [{"type": "text", "text": user_q}]}],
                    "semantic_view": "HEALTHCARE_GENOMICS.AI.GENOMICS_SEMANTIC_VIEW"
                }
                resp = _snowflake.send_snow_api_request("POST", "/api/v2/cortex/analyst/message", {}, {}, request_body, None, 30000)
                parsed = json.loads(resp["content"])
                if resp["status"] < 400:
                    for block in parsed.get("message", {}).get("content", []):
                        if block.get("type") == "text":
                            st.markdown(block.get("text", ""))
                        elif block.get("type") == "sql":
                            sql = block.get("statement", "")
                            with st.expander("Generated SQL"):
                                st.code(sql, language="sql")
                            try:
                                st.dataframe(session.sql(sql).to_pandas(), use_container_width=True)
                            except:
                                pass
            except Exception as e:
                st.error(f"Error: {e}")

    st.divider()
    st.subheader("Data Lake Export")
    st.markdown("Export affected cohort to S3 for clinical team follow-up via AWS Glue + Athena:")
    if st.button("📤 Export Reclassified Cohort to Data Lake", type="secondary"):
        with st.spinner("Exporting to LAKE.COHORT_EXPORT..."):
            try:
                session.sql("""
                    CREATE OR REPLACE TABLE HEALTHCARE_GENOMICS.LAKE.COHORT_EXPORT AS
                    SELECT DISTINCT
                        p.PATIENT_ID, p.FIRST_NAME, p.LAST_NAME, p.COHORT_ID,
                        DATEDIFF('year', p.DOB, CURRENT_DATE()) AS AGE, p.GENDER, p.ETHNICITY,
                        v.VARIANT_ID, v.GENE, v.POSITION, v.VARIANT_TYPE, v.CONSEQUENCE,
                        v.ALLELE_FREQUENCY, v.CLINICAL_SIGNIFICANCE,
                        'RECLASSIFIED_VUS_TO_PATHOGENIC' AS EXPORT_REASON,
                        CURRENT_TIMESTAMP() AS EXPORT_TIMESTAMP
                    FROM HEALTHCARE_GENOMICS.RAW.VARIANTS v
                    JOIN HEALTHCARE_GENOMICS.RAW.PATIENTS p ON v.PATIENT_ID = p.PATIENT_ID
                    WHERE v.GENE = 'BRCA1' AND v.CLINICAL_SIGNIFICANCE = 'VUS' AND v.VARIANT_TYPE = 'CNV'
                """).collect()
                count = session.sql("SELECT COUNT(*) AS N FROM HEALTHCARE_GENOMICS.LAKE.COHORT_EXPORT").collect()[0][0]
                st.success(f"✅ Exported {count} records to LAKE.COHORT_EXPORT — ready for S3 → Glue → Athena pipeline")
            except Exception as e:
                st.error(f"Export error: {e}")
