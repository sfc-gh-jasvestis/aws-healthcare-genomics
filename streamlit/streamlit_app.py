import streamlit as st
import pandas as pd
import json
import plotly.express as px
import _snowflake
from snowflake.snowpark.context import get_active_session

session = get_active_session()
st.set_page_config(page_title="Genomics Research", layout="wide", page_icon="🧬")
st.title("Genomics Research Data Platform")
st.caption("Variant analysis | Cohort comparison | Biobank inventory | Publication search")

kpi = session.sql("SELECT COUNT(DISTINCT PATIENT_ID) AS PATIENTS, COUNT(*) AS VARIANTS, COUNT_IF(CLINICAL_SIGNIFICANCE='PATHOGENIC') AS PATHOGENIC FROM HEALTHCARE_GENOMICS.RAW.VARIANTS").to_pandas()
c1, c2, c3 = st.columns(3)
c1.metric("Patients", f"{kpi['PATIENTS'].iloc[0]:,}")
c2.metric("Total Variants", f"{kpi['VARIANTS'].iloc[0]:,}")
c3.metric("Pathogenic", f"{kpi['PATHOGENIC'].iloc[0]:,}")

st.divider()
st.subheader("Variant Frequency by Gene")
var_df = session.sql("SELECT GENE, ALLELE_FREQUENCY::FLOAT AS AF, CLINICAL_SIGNIFICANCE, VARIANT_TYPE FROM HEALTHCARE_GENOMICS.RAW.VARIANTS WHERE ALLELE_FREQUENCY > 0.01 ORDER BY RANDOM() LIMIT 800").to_pandas()
if not var_df.empty:
    var_df["AF"] = pd.to_numeric(var_df["AF"], errors="coerce")
    fig = px.strip(var_df, x="GENE", y="AF", color="CLINICAL_SIGNIFICANCE", title="Allele Frequency Distribution by Gene")
    fig.update_layout(height=400, margin=dict(t=40, b=10))
    st.plotly_chart(fig, use_container_width=True)

st.divider()
st.subheader("Cohort Comparison: Responders vs Non-Responders")
cohort = session.sql("""
    SELECT GENE, COHORT_ID,
           SUM(VARIANT_COUNT)::FLOAT AS VARIANT_COUNT,
           SUM(PATHOGENIC_COUNT)::FLOAT AS PATHOGENIC_COUNT,
           AVG(AVG_ALLELE_FREQUENCY)::FLOAT AS AVG_AF
    FROM HEALTHCARE_GENOMICS.CURATED.VARIANT_SUMMARY GROUP BY GENE, COHORT_ID ORDER BY GENE
""").to_pandas()
if not cohort.empty:
    for col in ["VARIANT_COUNT", "PATHOGENIC_COUNT", "AVG_AF"]:
        cohort[col] = pd.to_numeric(cohort[col], errors="coerce")
    fig2 = px.bar(cohort, x="GENE", y="PATHOGENIC_COUNT", color="COHORT_ID", barmode="group", title="Pathogenic Variants: Responders vs Non-Responders")
    fig2.update_layout(height=350, margin=dict(t=40, b=10))
    st.plotly_chart(fig2, use_container_width=True)

st.divider()
st.subheader("Biobank Inventory")
bio = session.sql("SELECT SPECIMEN_TYPE, SUM(TOTAL_SPECIMENS)::INT AS TOTAL, SUM(AVAILABLE_COUNT)::INT AS AVAILABLE, ROUND(AVG(AVG_QUALITY),1)::FLOAT AS QUALITY FROM HEALTHCARE_GENOMICS.CURATED.BIOBANK_INVENTORY GROUP BY SPECIMEN_TYPE ORDER BY TOTAL DESC").to_pandas()
if not bio.empty:
    for col in ["TOTAL", "AVAILABLE", "QUALITY"]:
        bio[col] = pd.to_numeric(bio[col], errors="coerce")
    for _, row in bio.iterrows():
        st.markdown(f"**{row['SPECIMEN_TYPE']}**: {row['AVAILABLE']:,.0f} available / {row['TOTAL']:,.0f} total (quality: {row['QUALITY']:.1f})")
        st.progress(min(float(row['AVAILABLE']) / max(float(row['TOTAL']), 1), 1.0))

st.divider()
st.subheader("Publication Search")
query = st.text_input("Search research publications:", placeholder="e.g., BRCA1 pathogenic variants breast cancer")
if query:
    with st.spinner("Searching..."):
        try:
            safe_q = query.replace("'", "''").replace('"', '\\\\"')
            raw = session.sql(f"SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW('HEALTHCARE_GENOMICS.SEARCH.PUBLICATION_SEARCH', '{{\"query\": \"{safe_q}\", \"columns\": [\"ABSTRACT\", \"TITLE\", \"JOURNAL\"], \"limit\": 5}}') AS R").collect()[0][0]
            results = json.loads(raw) if isinstance(raw, str) else raw
            for r in results.get("results", []):
                st.markdown(f"**{r.get('TITLE', '')}** — {r.get('JOURNAL', '')}")
                st.caption(r.get("ABSTRACT", "")[:200] + "...")
                st.divider()
        except Exception as e:
            st.error(f"Search error: {e}")

st.divider()
st.subheader("Ask the Data")
user_q = st.text_input("Natural language question:", placeholder="Which genes have the most pathogenic variants?")
if user_q:
    with st.spinner("Cortex Analyst..."):
        try:
            request_body = {"messages": [{"role": "user", "content": [{"type": "text", "text": user_q}]}], "semantic_view": "HEALTHCARE_GENOMICS.AI.GENOMICS_SEMANTIC_VIEW"}
            resp = _snowflake.send_snow_api_request("POST", "/api/v2/cortex/analyst/message", {}, {}, request_body, None, 30000)
            parsed = json.loads(resp["content"])
            if resp["status"] < 400:
                for block in parsed.get("message", {}).get("content", []):
                    if block.get("type") == "text": st.markdown(block.get("text", ""))
                    elif block.get("type") == "sql":
                        sql = block.get("statement", "")
                        st.code(sql, language="sql")
                        try: st.dataframe(session.sql(sql).to_pandas(), use_container_width=True)
                        except: pass
        except Exception as e:
            st.error(f"Error: {e}")
