USE ROLE SYSADMIN;
USE DATABASE HEALTHCARE_GENOMICS;
USE SCHEMA AI;

CREATE OR REPLACE CORTEX AGENT GENOMICS_AGENT
    COMMENT = '{"color": "green"}'
    MODEL = 'claude-3-5-sonnet'
    TOOLS = (
        TOOL GenomicsAnalyst TYPE SEMANTIC_VIEW
            DESCRIPTION = 'Analyze genomic variants, cohort demographics, and biobank inventory using natural language.'
            SEMANTIC_VIEW = HEALTHCARE_GENOMICS.AI.GENOMICS_SEMANTIC_VIEW,
        TOOL PublicationSearch TYPE CORTEX_SEARCH
            DESCRIPTION = 'Search research publications by abstract content, gene names, or journal.'
            CORTEX_SEARCH_SERVICE = HEALTHCARE_GENOMICS.SEARCH.PUBLICATION_SEARCH
    )
    INSTRUCTIONS = 'You are a genomics research assistant. Help researchers analyze variant data, compare cohorts, explore the biobank, and find relevant publications. Key insight: BRCA1 pathogenic variants are 2.8x enriched in the responder cohort. Always provide gene names and clinical significance when discussing variants.';
