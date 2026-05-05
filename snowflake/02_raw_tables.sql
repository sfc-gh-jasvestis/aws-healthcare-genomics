USE ROLE SYSADMIN;
USE DATABASE HEALTHCARE_GENOMICS;
USE SCHEMA RAW;

--------------------------------------------------------------------
-- PATIENTS (5,000 rows — 2 cohorts)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE PATIENTS (
    PATIENT_ID       VARCHAR(20),
    COHORT           VARCHAR(30),
    AGE              NUMBER(3,0),
    SEX              VARCHAR(1),
    ETHNICITY        VARCHAR(30),
    DIAGNOSIS        VARCHAR(50),
    ENROLLMENT_DATE  DATE,
    STATUS           VARCHAR(15)
);

INSERT INTO PATIENTS
SELECT
    'PAT-G-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS PATIENT_ID,
    CASE WHEN SEQ4() % 2 = 0 THEN 'COHORT_RESPONDERS' ELSE 'COHORT_NON_RESPONDERS' END AS COHORT,
    25 + UNIFORM(0, 55, RANDOM()) AS AGE,
    CASE WHEN UNIFORM(0, 1, RANDOM()) = 0 THEN 'M' ELSE 'F' END AS SEX,
    ARRAY_CONSTRUCT('Caucasian','African American','Hispanic','Asian','Other')[UNIFORM(0,4,RANDOM())]::VARCHAR AS ETHNICITY,
    ARRAY_CONSTRUCT('Breast Cancer','Ovarian Cancer','Lung Cancer','Prostate Cancer','Colorectal Cancer')[UNIFORM(0,4,RANDOM())]::VARCHAR AS DIAGNOSIS,
    DATEADD('day', -UNIFORM(30, 730, RANDOM()), CURRENT_DATE()) AS ENROLLMENT_DATE,
    CASE WHEN UNIFORM(0, 9, RANDOM()) < 8 THEN 'Active' ELSE 'Withdrawn' END AS STATUS
FROM TABLE(GENERATOR(ROWCOUNT => 5000));

--------------------------------------------------------------------
-- VARIANTS (100,000 rows — 20 genes, BRCA1 pathogenic skew in responders)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE VARIANTS (
    VARIANT_ID           VARCHAR(20),
    PATIENT_ID           VARCHAR(20),
    GENE                 VARCHAR(10),
    CHROMOSOME           VARCHAR(5),
    POSITION             NUMBER(12,0),
    REF_ALLELE           VARCHAR(5),
    ALT_ALLELE           VARCHAR(5),
    CLINICAL_SIGNIFICANCE VARCHAR(20),
    ALLELE_FREQUENCY     FLOAT,
    COHORT               VARCHAR(30),
    DETECTED_DATE        DATE
);

INSERT INTO VARIANTS
WITH GENES AS (
    SELECT COLUMN1 AS GENE, COLUMN2 AS CHROM FROM VALUES
    ('BRCA1','17'),('BRCA2','13'),('TP53','17'),('EGFR','7'),('KRAS','12'),
    ('ALK','2'),('PIK3CA','3'),('PTEN','10'),('APC','5'),('RB1','13'),
    ('MYC','8'),('BRAF','7'),('HER2','17'),('CDH1','16'),('ATM','11'),
    ('PALB2','16'),('CHEK2','22'),('MLH1','3'),('MSH2','2'),('RAD51','15')
),
BASE AS (
    SELECT
        SEQ4() AS RN,
        'VAR-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS VARIANT_ID,
        'PAT-G-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 5, '0') AS PATIENT_ID,
        UNIFORM(0, 19, RANDOM()) AS GENE_IDX,
        CASE WHEN UNIFORM(0, 4999, RANDOM()) % 2 = 0 THEN 'COHORT_RESPONDERS' ELSE 'COHORT_NON_RESPONDERS' END AS COHORT
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
)
SELECT
    b.VARIANT_ID,
    b.PATIENT_ID,
    g.GENE,
    g.CHROM,
    UNIFORM(10000, 250000000, RANDOM()) AS POSITION,
    ARRAY_CONSTRUCT('A','T','C','G')[UNIFORM(0,3,RANDOM())]::VARCHAR AS REF_ALLELE,
    ARRAY_CONSTRUCT('A','T','C','G')[UNIFORM(0,3,RANDOM())]::VARCHAR AS ALT_ALLELE,
    CASE
        WHEN g.GENE = 'BRCA1' AND b.COHORT = 'COHORT_RESPONDERS' AND UNIFORM(0,9,RANDOM()) < 7 THEN 'Pathogenic'
        WHEN g.GENE = 'BRCA1' AND b.COHORT = 'COHORT_NON_RESPONDERS' AND UNIFORM(0,9,RANDOM()) < 2 THEN 'Pathogenic'
        WHEN UNIFORM(0,9,RANDOM()) < 2 THEN 'Pathogenic'
        WHEN UNIFORM(0,9,RANDOM()) < 4 THEN 'Likely Pathogenic'
        WHEN UNIFORM(0,9,RANDOM()) < 3 THEN 'VUS'
        ELSE 'Benign'
    END AS CLINICAL_SIGNIFICANCE,
    ROUND(UNIFORM(1, 500, RANDOM())::FLOAT / 10000, 4) AS ALLELE_FREQUENCY,
    b.COHORT,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS DETECTED_DATE
FROM BASE b
JOIN GENES g ON g.GENE = (
    SELECT GENE FROM GENES ORDER BY GENE LIMIT 1 OFFSET b.GENE_IDX
);

--------------------------------------------------------------------
-- BIOSPECIMENS (20,000 rows)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE BIOSPECIMENS (
    SPECIMEN_ID      VARCHAR(20),
    PATIENT_ID       VARCHAR(20),
    SPECIMEN_TYPE    VARCHAR(20),
    COLLECTION_DATE  DATE,
    STATUS           VARCHAR(15),
    QUANTITY_ML      FLOAT,
    STORAGE_LOCATION VARCHAR(20),
    QUALITY_SCORE    FLOAT
);

INSERT INTO BIOSPECIMENS
SELECT
    'BIO-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS SPECIMEN_ID,
    'PAT-G-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 5, '0') AS PATIENT_ID,
    ARRAY_CONSTRUCT('Blood','Tissue','Plasma','DNA','RNA','Serum','Buffy Coat','FFPE')[UNIFORM(0,7,RANDOM())]::VARCHAR AS SPECIMEN_TYPE,
    DATEADD('day', -UNIFORM(1, 730, RANDOM()), CURRENT_DATE()) AS COLLECTION_DATE,
    ARRAY_CONSTRUCT('Available','In Use','Depleted','Quarantine')[UNIFORM(0,3,RANDOM())]::VARCHAR AS STATUS,
    ROUND(UNIFORM(1, 100, RANDOM())::FLOAT / 10, 1) AS QUANTITY_ML,
    'RACK-' || LPAD(UNIFORM(1, 50, RANDOM())::VARCHAR, 3, '0') AS STORAGE_LOCATION,
    ROUND(UNIFORM(60, 100, RANDOM())::FLOAT / 100, 2) AS QUALITY_SCORE
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

--------------------------------------------------------------------
-- PHENOTYPES (30,000 rows)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE PHENOTYPES (
    PHENOTYPE_ID     VARCHAR(20),
    PATIENT_ID       VARCHAR(20),
    HPO_TERM         VARCHAR(50),
    CATEGORY         VARCHAR(30),
    SEVERITY         VARCHAR(10),
    ONSET_AGE        NUMBER(3,0),
    OBSERVATION_DATE DATE
);

INSERT INTO PHENOTYPES
SELECT
    'PHE-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS PHENOTYPE_ID,
    'PAT-G-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 5, '0') AS PATIENT_ID,
    ARRAY_CONSTRUCT('HP:0000006','HP:0001427','HP:0000007','HP:0003745','HP:0001428',
                    'HP:0002862','HP:0000951','HP:0001250','HP:0001635','HP:0002664')[UNIFORM(0,9,RANDOM())]::VARCHAR AS HPO_TERM,
    ARRAY_CONSTRUCT('Neoplasm','Cardiovascular','Neurological','Immunological','Metabolic','Musculoskeletal')[UNIFORM(0,5,RANDOM())]::VARCHAR AS CATEGORY,
    ARRAY_CONSTRUCT('Mild','Moderate','Severe')[UNIFORM(0,2,RANDOM())]::VARCHAR AS SEVERITY,
    UNIFORM(20, 75, RANDOM()) AS ONSET_AGE,
    DATEADD('day', -UNIFORM(1, 500, RANDOM()), CURRENT_DATE()) AS OBSERVATION_DATE
FROM TABLE(GENERATOR(ROWCOUNT => 30000));

--------------------------------------------------------------------
-- PUBLICATIONS (200 rows)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE PUBLICATIONS (
    PUBLICATION_ID   VARCHAR(20),
    TITLE            VARCHAR(200),
    ABSTRACT         VARCHAR(2000),
    JOURNAL          VARCHAR(100),
    PUBLISH_DATE     DATE,
    GENES_MENTIONED  VARCHAR(100),
    AUTHORS          VARCHAR(200),
    DOI              VARCHAR(50)
);

INSERT INTO PUBLICATIONS
SELECT
    'PUB-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS PUBLICATION_ID,
    ARRAY_CONSTRUCT(
        'BRCA1 Pathogenic Variants and Treatment Response in Breast Cancer',
        'TP53 Mutations as Prognostic Markers in Ovarian Cancer',
        'EGFR-Targeted Therapy Resistance Mechanisms',
        'KRAS G12C Inhibitors: A New Therapeutic Paradigm',
        'PIK3CA Alterations in Endocrine-Resistant Breast Cancer',
        'Genomic Landscape of Hereditary Cancer Syndromes',
        'PTEN Loss and Immune Checkpoint Response',
        'HER2 Amplification in Gastric Cancer Subtypes',
        'ALK Rearrangements in Non-Small Cell Lung Cancer',
        'BRAF V600E and Combination Therapy Outcomes'
    )[UNIFORM(0,9,RANDOM())]::VARCHAR || ' — Study ' || SEQ4()::VARCHAR AS TITLE,
    ARRAY_CONSTRUCT(
        'We investigated the role of BRCA1 pathogenic variants in predicting treatment response across a cohort of 2500 patients. Results demonstrate a significant 2.8-fold enrichment of pathogenic BRCA1 mutations in treatment responders compared to non-responders (p<0.001). These findings suggest BRCA1 status as a robust predictive biomarker for PARP inhibitor therapy selection.',
        'This study examines TP53 mutation patterns across 1800 ovarian cancer patients enrolled in three clinical trials. We identified distinct mutational signatures associated with platinum sensitivity and resistance, enabling refined patient stratification for therapeutic intervention.',
        'Analysis of EGFR mutation profiles in 3200 NSCLC patients reveals novel resistance mechanisms including MET amplification and KRAS co-mutations. Sequential liquid biopsy monitoring detected resistance emergence a median of 4.2 months before radiographic progression.',
        'We report outcomes from a phase III trial of KRAS G12C inhibitors in 950 patients with advanced solid tumors. Overall response rate was 43% with median duration of response of 11.2 months. Biomarker analysis identified co-occurring STK11 loss as a predictor of reduced benefit.',
        'Comprehensive genomic profiling of 4100 breast cancer patients identifies PIK3CA hotspot mutations in 34% of HR+/HER2- tumors. Paired analysis of primary and metastatic samples reveals enrichment of PIK3CA mutations at progression on endocrine therapy.'
    )[UNIFORM(0,4,RANDOM())]::VARCHAR AS ABSTRACT,
    ARRAY_CONSTRUCT('Nature Genetics','Cancer Cell','NEJM','Lancet Oncology','JCO','Nature Medicine','Cell','Science','JAMA Oncology','Genome Research')[UNIFORM(0,9,RANDOM())]::VARCHAR AS JOURNAL,
    DATEADD('day', -UNIFORM(30, 1095, RANDOM()), CURRENT_DATE()) AS PUBLISH_DATE,
    ARRAY_CONSTRUCT('BRCA1,TP53','EGFR,KRAS','PIK3CA,PTEN','ALK,ROS1','BRAF,MEK','HER2,CDH1','BRCA2,PALB2','ATM,CHEK2','MLH1,MSH2','MYC,RB1')[UNIFORM(0,9,RANDOM())]::VARCHAR AS GENES_MENTIONED,
    ARRAY_CONSTRUCT('Chen S, Park J','Smith A, Jones B','Williams R, Brown T','Garcia M, Davis L','Wilson K, Taylor P')[UNIFORM(0,4,RANDOM())]::VARCHAR || ' et al.' AS AUTHORS,
    '10.' || UNIFORM(1000, 9999, RANDOM())::VARCHAR || '/gen.' || UNIFORM(2022, 2026, RANDOM())::VARCHAR || '.' || LPAD(SEQ4()::VARCHAR, 4, '0') AS DOI
FROM TABLE(GENERATOR(ROWCOUNT => 200));

--------------------------------------------------------------------
-- COHORT_DEFINITIONS (50 rows)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE COHORT_DEFINITIONS (
    COHORT_ID        VARCHAR(20),
    COHORT_NAME      VARCHAR(100),
    DESCRIPTION      VARCHAR(500),
    CRITERIA_SQL     VARCHAR(1000),
    CREATED_BY       VARCHAR(50),
    CREATED_DATE     DATE,
    PATIENT_COUNT    NUMBER(6,0),
    STATUS           VARCHAR(10)
);

INSERT INTO COHORT_DEFINITIONS
SELECT
    'COH-' || LPAD(SEQ4()::VARCHAR, 3, '0') AS COHORT_ID,
    ARRAY_CONSTRUCT(
        'BRCA1 Pathogenic Carriers','TP53 Mutant Cohort','Triple Negative Subgroup',
        'HER2+ Amplified','KRAS Wildtype','High TMB (>10 mut/Mb)',
        'MSI-High','Platinum Sensitive','Prior Immunotherapy',
        'Young Onset (<40)'
    )[UNIFORM(0,9,RANDOM())]::VARCHAR || ' v' || (SEQ4()+1)::VARCHAR AS COHORT_NAME,
    'Cohort defined by specific genomic and clinical criteria for research study enrollment and biomarker analysis.' AS DESCRIPTION,
    'SELECT PATIENT_ID FROM RAW.PATIENTS WHERE COHORT = ''COHORT_RESPONDERS'' AND AGE > ' || UNIFORM(30, 60, RANDOM())::VARCHAR AS CRITERIA_SQL,
    ARRAY_CONSTRUCT('Dr. Sarah Chen','Dr. James Park','Dr. Emily Wright','Dr. Michael Torres','Dr. Lisa Huang')[UNIFORM(0,4,RANDOM())]::VARCHAR AS CREATED_BY,
    DATEADD('day', -UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) AS CREATED_DATE,
    UNIFORM(50, 2000, RANDOM()) AS PATIENT_COUNT,
    CASE WHEN UNIFORM(0, 4, RANDOM()) < 4 THEN 'Active' ELSE 'Archived' END AS STATUS
FROM TABLE(GENERATOR(ROWCOUNT => 50));
