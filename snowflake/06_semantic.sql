USE ROLE SYSADMIN;
USE DATABASE HEALTHCARE_GENOMICS;
USE SCHEMA AI;

CREATE OR REPLACE SEMANTIC VIEW GENOMICS_SEMANTIC_VIEW
  AS SEMANTIC MODEL
    NAME = 'Genomics Research Model'
    DESCRIPTION = 'Semantic model over genomics research dynamic tables for variant analysis, cohort comparison, and biobank inventory.'
    ENTITIES = (
        ENTITY variant_summary
            TABLE = CURATED.VARIANT_SUMMARY
            PRIMARY_KEY = (GENE, COHORT, CLINICAL_SIGNIFICANCE)
            COLUMNS = (
                GENE DESCRIPTION 'Gene symbol (e.g., BRCA1, TP53)',
                COHORT DESCRIPTION 'Patient cohort: COHORT_RESPONDERS or COHORT_NON_RESPONDERS',
                CLINICAL_SIGNIFICANCE DESCRIPTION 'Variant classification: Pathogenic, Likely Pathogenic, VUS, Benign',
                VARIANT_COUNT DESCRIPTION 'Number of variants observed',
                PATIENT_COUNT DESCRIPTION 'Number of distinct patients with this variant',
                AVG_ALLELE_FREQUENCY DESCRIPTION 'Average allele frequency across variants',
                COHORT_FRACTION DESCRIPTION 'Fraction of variants in this cohort for the gene'
            ),
        ENTITY cohort_demographics
            TABLE = CURATED.COHORT_DEMOGRAPHICS
            PRIMARY_KEY = (COHORT)
            COLUMNS = (
                COHORT DESCRIPTION 'Cohort identifier',
                TOTAL_PATIENTS DESCRIPTION 'Total enrolled patients',
                AVG_AGE DESCRIPTION 'Average patient age',
                MALE_COUNT DESCRIPTION 'Number of male patients',
                FEMALE_COUNT DESCRIPTION 'Number of female patients',
                MOST_COMMON_DIAGNOSIS DESCRIPTION 'Most frequent cancer diagnosis',
                ACTIVE_COUNT DESCRIPTION 'Currently active patients',
                WITHDRAWN_COUNT DESCRIPTION 'Withdrawn patients'
            ),
        ENTITY biobank_inventory
            TABLE = CURATED.BIOBANK_INVENTORY
            PRIMARY_KEY = (SPECIMEN_TYPE, STATUS)
            COLUMNS = (
                SPECIMEN_TYPE DESCRIPTION 'Type of biospecimen: Blood, Tissue, Plasma, DNA, RNA, etc.',
                STATUS DESCRIPTION 'Specimen availability: Available, In Use, Depleted, Quarantine',
                SPECIMEN_COUNT DESCRIPTION 'Number of specimens',
                TOTAL_VOLUME_ML DESCRIPTION 'Total volume in milliliters',
                AVG_QUALITY_SCORE DESCRIPTION 'Average quality score (0-1)',
                UNIQUE_PATIENTS DESCRIPTION 'Distinct patients contributing specimens'
            )
    );
