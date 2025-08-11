-- ============================================================================
-- SECTION 3: COLUMN-LEVEL ANALYSIS (FIXED WITH DETAILED COMMENTS)
-- ============================================================================
-- PURPOSE: This script performs comprehensive column-level analysis for data governance,
--          including PII detection, trust scoring, sensitivity classification, and 
--          governance recommendations for each column in the database.
--
-- OUTPUTS: 
--   1. #ColumnLevelAnalysis temporary table with detailed metrics
--   2. High-priority summary report focusing on sensitive/risky columns
--
-- SCORING METHODOLOGY:
--   - Trust Score (0-100): Based on data quality, constraints, and business context
--   - Sensitivity Score (0-100): Based on PII risk level and schema context
--   - PII Confidence (0-100): Confidence level in PII classification accuracy
-- ============================================================================

-- ============================================================================
-- CREATE RESULTS TABLE
-- ============================================================================
-- Create temporary table to store comprehensive column-level analysis results
CREATE TABLE #ColumnLevelAnalysis (
    column_id INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Basic Column Identification
    schema_name NVARCHAR(128) NOT NULL,          -- Schema containing the table
    table_name NVARCHAR(128) NOT NULL,           -- Table containing the column
    column_name NVARCHAR(128) NOT NULL,          -- Column name
    full_column_name NVARCHAR(393) NOT NULL,     -- Fully qualified column name (schema.table.column)
    
    -- Column Technical Details
    data_type NVARCHAR(128) NOT NULL,            -- Data type with length/precision info
    max_length INT,                              -- Maximum length for string types
    precision_scale VARCHAR(20),                 -- Precision and scale for numeric types
    is_nullable BIT NOT NULL,                    -- Whether column allows NULL values
    is_identity BIT NOT NULL,                    -- Whether column is an identity column
    is_computed BIT NOT NULL,                    -- Whether column is computed
    is_primary_key BIT DEFAULT 0,                -- Whether column is part of primary key
    is_foreign_key BIT DEFAULT 0,                -- Whether column is part of foreign key
    
    -- Column-Level Trust Score (0-100)
    -- Higher scores indicate more trustworthy/reliable data
    column_trust_score DECIMAL(5,2) NOT NULL,    -- Calculated trust score
    column_trust_level VARCHAR(20) NOT NULL,     -- Categorical trust level (VERY_HIGH, HIGH, MEDIUM, LOW, VERY_LOW)
    
    -- Column-Level Sensitivity Classification
    -- Used to determine access controls and protection requirements
    column_sensitivity_level VARCHAR(10) NOT NULL,   -- HIGH/MEDIUM/LOW sensitivity classification
    column_sensitivity_score INT NOT NULL,           -- Numeric sensitivity score (0-100)
    
    -- PII (Personally Identifiable Information) Classification
    pii_category VARCHAR(50),                    -- Type of PII (GOVERNMENT_ID, FINANCIAL, etc.)
    pii_risk_level VARCHAR(20) NOT NULL,         -- Risk level (CRITICAL_PII_RISK, HIGH_PII_RISK, etc.)
    pii_confidence_score DECIMAL(5,2),           -- Confidence in PII classification (0-100)
    
    -- Data Quality Indicators
    constraint_validation_score DECIMAL(5,2),   -- Score based on constraints (PK, FK, NOT NULL, etc.)
    data_type_appropriateness DECIMAL(5,2),     -- How appropriate the data type is for the column
    naming_convention_score DECIMAL(5,2),       -- Quality of column naming conventions
    
    -- Business Context
    business_purpose VARCHAR(200),               -- Inferred business purpose of the column
    data_element_classification VARCHAR(100),   -- Data classification level
    
    -- Governance Requirements
    encryption_priority VARCHAR(20),            -- Encryption requirement level
    masking_required BIT DEFAULT 0,             -- Whether data masking is required
    audit_logging_priority VARCHAR(20),         -- Audit logging requirement level
    access_restriction_level VARCHAR(20),       -- Access control requirement level
    
    -- Compliance and Legal
    regulatory_classification NVARCHAR(500),    -- Applicable regulations (GDPR, CCPA, etc.)
    data_retention_category VARCHAR(50),        -- Data retention classification
    
    -- Recommendations and Actions
    column_governance_action VARCHAR(200),      -- Recommended governance actions
    data_steward_priority VARCHAR(20),          -- Priority level for data steward attention
    
    analysis_timestamp DATETIME DEFAULT GETDATE()  -- When analysis was performed
);

-- ============================================================================
-- MAIN ANALYSIS QUERY WITH MULTIPLE CTEs
-- ============================================================================
-- Using Common Table Expressions (CTEs) to break down the complex analysis
-- into manageable, logical components for better readability and maintenance

WITH 
-- ============================================================================
-- CTE 1: COLUMN TECHNICAL DETAILS
-- ============================================================================
-- Purpose: Extract basic technical information about all columns
-- Includes: Data types, constraints, structural relationships (PK/FK)
ColumnTechnicalDetails AS (
    SELECT 
        c.object_id,                             -- Table object ID for joining
        c.column_id,                             -- Column ID within the table
        s.name AS schema_name,                   -- Schema name
        t.name AS table_name,                    -- Table name
        c.name AS column_name,                   -- Column name
        ty.name AS data_type_name,               -- Base data type name
        c.max_length,                            -- Maximum length (for string types)
        c.precision,                             -- Numeric precision
        c.scale,                                 -- Numeric scale
        c.is_nullable,                           -- NULL constraint indicator
        c.is_identity,                           -- Identity column indicator
        c.is_computed,                           -- Computed column indicator
        
        -- Determine if column is part of primary key
        -- Uses LEFT JOIN to pk subquery to check PK membership
        CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_primary_key,
        
        -- Determine if column is part of foreign key
        -- Uses LEFT JOIN to foreign key system table
        CASE WHEN fk.parent_column_id IS NOT NULL THEN 1 ELSE 0 END AS is_foreign_key
        
    FROM sys.schemas s
    JOIN sys.tables t ON s.schema_id = t.schema_id          -- Join schemas to tables
    JOIN sys.columns c ON t.object_id = c.object_id         -- Join tables to columns
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id   -- Join to get data type info
    
    -- Subquery to identify primary key columns
    LEFT JOIN (
        SELECT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.is_primary_key = 1               -- Only primary key indexes
    ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
    
    -- Join to identify foreign key columns
    LEFT JOIN sys.foreign_key_columns fk ON c.object_id = fk.parent_object_id 
                                         AND c.column_id = fk.parent_column_id
    
    WHERE t.type = 'U'                           -- Only user tables (exclude system tables, views, etc.)
),

-- ============================================================================
-- CTE 2: PII CLASSIFICATION ENGINE
-- ============================================================================
-- Purpose: Analyze column names to detect potential Personally Identifiable Information (PII)
-- Method: Pattern matching against known PII naming conventions
-- Output: PII category, risk level, and confidence score for each column
ColumnPIIClassification AS (
    SELECT 
        c.object_id,
        c.column_id,
        c.name AS column_name,
        
        -- ========================================================================
        -- DETAILED PII CATEGORY CLASSIFICATION
        -- ========================================================================
        -- Uses pattern matching on column names to categorize potential PII
        -- Categories ordered by typical risk level (highest to lowest)
        CASE
            -- GOVERNMENT & LEGAL IDENTIFIERS (Highest Risk)
            -- These are typically protected by law and have severe penalties for misuse
            WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social%security%' THEN 'GOVERNMENT_ID'
            WHEN c.name LIKE '%tax%id%' OR c.name LIKE '%ein%' OR c.name LIKE '%tin%' THEN 'GOVERNMENT_ID'
            WHEN c.name LIKE '%passport%' OR c.name LIKE '%license%' OR c.name LIKE '%permit%' THEN 'LEGAL_ID'
            
            -- AUTHENTICATION & SECURITY (Critical Risk)
            -- Compromise of these can lead to system breaches
            WHEN c.name LIKE '%password%' OR c.name LIKE '%secret%' OR c.name LIKE '%token%' THEN 'AUTHENTICATION'
            WHEN c.name LIKE '%hash%' OR c.name LIKE '%salt%' OR c.name LIKE '%key%' THEN 'AUTHENTICATION'
            
            -- FINANCIAL DATA (High Risk)
            -- Protected by financial regulations (PCI-DSS, etc.)
            WHEN c.name LIKE '%credit%card%' OR c.name LIKE '%ccn%' OR c.name LIKE '%card%number%' THEN 'FINANCIAL'
            WHEN c.name LIKE '%account%number%' OR c.name LIKE '%routing%' OR c.name LIKE '%iban%' THEN 'FINANCIAL'
            WHEN c.name LIKE '%salary%' OR c.name LIKE '%wage%' OR c.name LIKE '%income%' OR c.name LIKE '%pay%' THEN 'FINANCIAL'
            
            -- PERSONAL NAMES (Medium-High Risk)
            -- Can be used for identity theft when combined with other data
            WHEN c.name LIKE '%first%name%' OR c.name LIKE '%given%name%' OR c.name LIKE '%fname%' THEN 'PERSONAL_NAME'
            WHEN c.name LIKE '%last%name%' OR c.name LIKE '%surname%' OR c.name LIKE '%family%name%' OR c.name LIKE '%lname%' THEN 'PERSONAL_NAME'
            WHEN c.name LIKE '%middle%name%' OR c.name LIKE '%full%name%' OR c.name LIKE '%display%name%' THEN 'PERSONAL_NAME'
            WHEN c.name LIKE '%maiden%name%' OR c.name LIKE '%title%' AND c.name NOT LIKE '%job%title%' THEN 'PERSONAL_NAME'
            
            -- CONTACT INFORMATION (Medium Risk)
            -- Can be used for phishing, social engineering
            WHEN c.name LIKE '%email%' OR c.name LIKE '%mail%' THEN 'CONTACT_INFO'
            WHEN c.name LIKE '%phone%' OR c.name LIKE '%mobile%' OR c.name LIKE '%telephone%' OR c.name LIKE '%fax%' THEN 'CONTACT_INFO'
            
            -- ADDRESS INFORMATION (Medium Risk)
            -- Can reveal location patterns, enable stalking/targeting
            WHEN c.name LIKE '%address%' OR c.name LIKE '%street%' OR c.name LIKE '%addr%' THEN 'ADDRESS_INFO'
            WHEN c.name LIKE '%city%' OR c.name LIKE '%state%' OR c.name LIKE '%province%' THEN 'ADDRESS_INFO'
            WHEN c.name LIKE '%zip%' OR c.name LIKE '%postal%' OR c.name LIKE '%country%' THEN 'ADDRESS_INFO'
            
            -- DEMOGRAPHIC DATA (Medium Risk)
            -- Protected classes, potential discrimination risks
            WHEN c.name LIKE '%birth%' OR c.name LIKE '%dob%' OR c.name LIKE '%age%' THEN 'DEMOGRAPHIC'
            WHEN c.name LIKE '%gender%' OR c.name LIKE '%sex%' THEN 'DEMOGRAPHIC'
            WHEN c.name LIKE '%nationality%' OR c.name LIKE '%ethnicity%' OR c.name LIKE '%race%' THEN 'DEMOGRAPHIC'
            WHEN c.name LIKE '%marital%' OR c.name LIKE '%religion%' THEN 'DEMOGRAPHIC'
            
            -- HEALTH INFORMATION (High Risk - if present)
            -- Protected by HIPAA and similar health privacy laws
            WHEN c.name LIKE '%medical%' OR c.name LIKE '%health%' OR c.name LIKE '%diagnosis%' THEN 'HEALTH'
            WHEN c.name LIKE '%disability%' OR c.name LIKE '%condition%' OR c.name LIKE '%treatment%' THEN 'HEALTH'
            
            -- BIOMETRIC DATA (Very High Risk)
            -- Permanent identifiers that cannot be changed if compromised
            WHEN c.name LIKE '%biometric%' OR c.name LIKE '%fingerprint%' OR c.name LIKE '%photo%' THEN 'BIOMETRIC'
            WHEN c.name LIKE '%image%' OR c.name LIKE '%picture%' THEN 'BIOMETRIC'
            
            ELSE NULL                            -- No PII pattern detected
        END AS pii_category,
        
        -- ========================================================================
        -- PII RISK LEVEL ASSESSMENT
        -- ========================================================================
        -- Assigns risk levels based on potential impact of data breach
        -- Risk levels: CRITICAL > HIGH > MEDIUM > LOW > NO_PII_DETECTED
        CASE
            -- CRITICAL RISK: Government IDs, Authentication, Biometrics
            -- Data breach could result in identity theft, system compromise, legal violations
            WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social%security%' OR
                 c.name LIKE '%tax%id%' OR c.name LIKE '%passport%' OR
                 c.name LIKE '%password%' OR c.name LIKE '%secret%' OR
                 c.name LIKE '%biometric%' OR c.name LIKE '%fingerprint%'
            THEN 'CRITICAL_PII_RISK'
            
            -- HIGH RISK: Financial data, Full names, Health data
            -- Significant financial or personal harm possible
            WHEN c.name LIKE '%credit%card%' OR c.name LIKE '%account%number%' OR
                 c.name LIKE '%salary%' OR c.name LIKE '%wage%' OR
                 c.name LIKE '%full%name%' OR c.name LIKE '%display%name%' OR
                 c.name LIKE '%medical%' OR c.name LIKE '%health%'
            THEN 'HIGH_PII_RISK'
            
            -- MEDIUM RISK: Personal identifiers, Contact info, Demographics with birth info
            -- Could enable social engineering or partial identity reconstruction
            WHEN c.name LIKE '%first%name%' OR c.name LIKE '%last%name%' OR
                 c.name LIKE '%email%' OR c.name LIKE '%phone%' OR
                 c.name LIKE '%address%' OR c.name LIKE '%birth%' OR c.name LIKE '%dob%'
            THEN 'MEDIUM_PII_RISK'
            
            -- LOW RISK: General demographics, Titles
            -- Limited risk when isolated, but can be problematic in aggregate
            WHEN c.name LIKE '%gender%' OR c.name LIKE '%age%' OR
                 c.name LIKE '%title%' OR c.name LIKE '%nationality%' OR
                 c.name LIKE '%city%' OR c.name LIKE '%state%'
            THEN 'LOW_PII_RISK'
            
            ELSE 'NO_PII_DETECTED'              -- No PII patterns found
        END AS pii_risk_level,
        
        -- ========================================================================
        -- PII CONFIDENCE SCORE (0-100)
        -- ========================================================================
        -- Indicates how confident we are in the PII classification
        -- Higher scores = more confident in the classification
        CASE
            -- Very high confidence (95%): Exact matches for well-known PII patterns
            -- These are standard, widely-recognized PII field names
            WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social%security%number%' OR
                 c.name LIKE '%email%address%' OR c.name LIKE '%phone%number%' OR
                 c.name LIKE '%credit%card%number%' OR c.name LIKE '%date%of%birth%'
            THEN 95.0
            
            -- High confidence (85%): Strong pattern matches
            -- Common naming patterns with high PII probability
            WHEN c.name LIKE '%first%name%' OR c.name LIKE '%last%name%' OR
                 c.name LIKE '%password%' OR c.name LIKE '%address%' OR
                 c.name LIKE '%salary%'
            THEN 85.0
            
            -- Medium confidence (70%): Partial matches or context-dependent
            -- Could be PII but might also be other types of data
            WHEN c.name LIKE '%name%' OR c.name LIKE '%phone%' OR
                 c.name LIKE '%email%' OR c.name LIKE '%birth%' OR
                 c.name LIKE '%gender%'
            THEN 70.0
            
            -- Lower confidence (60%): Ambiguous or general patterns
            -- Might be PII in some contexts but not others
            WHEN c.name LIKE '%title%' OR c.name LIKE '%age%' OR
                 c.name LIKE '%city%' OR c.name LIKE '%country%'
            THEN 60.0
            
            ELSE 0.0                             -- No PII indicators found
        END AS pii_confidence_score
        
    FROM sys.tables t
    JOIN sys.columns c ON t.object_id = c.object_id
    WHERE t.type = 'U'                           -- Only user tables
),

-- ============================================================================
-- CTE 3: COLUMN QUALITY METRICS
-- ============================================================================
-- Purpose: Assess data quality indicators for each column
-- Includes: Constraint analysis, data type appropriateness, naming conventions
ColumnQualityMetrics AS (
    SELECT 
        c.object_id,
        c.column_id,
        
        -- ========================================================================
        -- CONSTRAINT VALIDATION SCORE (0-25 points)
        -- ========================================================================
        -- Higher scores indicate better data integrity controls
        -- Constraints help ensure data quality and reliability
        CASE
            WHEN c.is_identity = 1 THEN 25.0     -- Identity columns: System-managed, highly reliable
            WHEN pk.column_id IS NOT NULL THEN 25.0  -- Primary keys: Strong uniqueness constraint
            WHEN fk.parent_column_id IS NOT NULL THEN 20.0  -- Foreign keys: Referential integrity
            WHEN cc.parent_object_id IS NOT NULL THEN 15.0  -- Check constraints: Business rule validation
            WHEN c.is_nullable = 0 THEN 10.0     -- NOT NULL: Prevents missing data
            ELSE 5.0                             -- No constraints: Basic score
        END AS constraint_validation_score,
        
        -- ========================================================================
        -- DATA TYPE APPROPRIATENESS SCORE (0-25 points)
        -- ========================================================================
        -- Evaluates whether the chosen data type makes sense for the column's likely content
        -- Appropriate data types improve performance and prevent data quality issues
        CASE
            -- Perfect matches: Column name suggests specific data type, and it matches
            WHEN c.name LIKE '%date%' AND ty.name LIKE '%date%' THEN 25.0
            WHEN c.name LIKE '%time%' AND ty.name LIKE '%time%' THEN 25.0
            WHEN c.name LIKE '%amount%' AND ty.name IN ('decimal', 'money', 'numeric') THEN 25.0
            WHEN c.name LIKE '%count%' AND ty.name IN ('int', 'bigint', 'smallint') THEN 25.0
            WHEN c.name LIKE '%flag%' AND ty.name = 'bit' THEN 25.0
            WHEN c.name LIKE '%id%' AND ty.name IN ('int', 'bigint', 'uniqueidentifier') THEN 25.0
            WHEN c.name LIKE '%name%' AND ty.name IN ('varchar', 'nvarchar', 'char', 'nchar') THEN 20.0
            
            -- Good matches: Generally appropriate data types
            WHEN ty.name IN ('varchar', 'nvarchar', 'char', 'nchar') THEN 15.0  -- Text fields
            WHEN ty.name IN ('int', 'bigint', 'decimal', 'numeric') THEN 15.0   -- Numeric fields
            WHEN ty.name LIKE '%date%' THEN 15.0                                -- Date fields
            
            ELSE 10.0                            -- Default score for other types
        END AS data_type_appropriateness,
        
        -- ========================================================================
        -- NAMING CONVENTION SCORE (0-25 points)
        -- ========================================================================
        -- Evaluates the quality of column naming based on length and content
        -- Good naming conventions improve maintainability and understanding
        CASE
            -- Excellent naming (25 points): Descriptive, appropriate length, clean
            WHEN LEN(c.name) BETWEEN 4 AND 50 AND 
                 c.name NOT LIKE '%temp%' AND c.name NOT LIKE '%old%' AND 
                 c.name NOT LIKE '%bak%' AND c.name NOT LIKE '%1%' AND c.name NOT LIKE '%2%'
            THEN 25.0
            
            -- Good naming (20 points): Reasonable but could be better
            WHEN LEN(c.name) BETWEEN 3 AND 75 AND 
                 c.name NOT LIKE '%temp%' AND c.name NOT LIKE '%old%'
            THEN 20.0
            
            -- Fair naming (15 points): Acceptable minimum standards
            WHEN LEN(c.name) BETWEEN 2 AND 100 THEN 15.0
            
            -- Poor naming (10 points): Too short, too long, or poor conventions
            ELSE 10.0
        END AS naming_convention_score
        
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    JOIN sys.tables t ON c.object_id = t.object_id
    
    -- Join to identify primary key columns
    LEFT JOIN (
        SELECT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.is_primary_key = 1
    ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
    
    -- Join to identify foreign key columns
    LEFT JOIN sys.foreign_key_columns fk ON c.object_id = fk.parent_object_id 
                                         AND c.column_id = fk.parent_column_id
    
    -- Simplified check constraint detection (table-level)
    -- Note: Check constraints are complex to map to specific columns, so we use table-level detection
    LEFT JOIN (
        SELECT DISTINCT parent_object_id, parent_column_id
        FROM sys.check_constraints cc
        CROSS APPLY STRING_SPLIT(cc.definition, ',') 
        WHERE cc.parent_column_id IS NOT NULL
    ) cc ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
    
    WHERE t.type = 'U'                           -- Only user tables
)

-- ============================================================================
-- MAIN INSERT STATEMENT
-- ============================================================================
-- Combines all the CTE results and calculates final scores and classifications
INSERT INTO #ColumnLevelAnalysis (
    schema_name, table_name, column_name, full_column_name,
    data_type, max_length, precision_scale, is_nullable, is_identity, is_computed, is_primary_key, is_foreign_key,
    column_trust_score, column_trust_level, column_sensitivity_level, column_sensitivity_score,
    pii_category, pii_risk_level, pii_confidence_score,
    constraint_validation_score, data_type_appropriateness, naming_convention_score,
    business_purpose, data_element_classification, encryption_priority, masking_required,
    audit_logging_priority, access_restriction_level, regulatory_classification,
    data_retention_category, column_governance_action, data_steward_priority
)
SELECT 
    ctd.schema_name,
    ctd.table_name,
    ctd.column_name,
    ctd.schema_name + '.' + ctd.table_name + '.' + ctd.column_name AS full_column_name,
    
    -- ========================================================================
    -- TECHNICAL DETAILS FORMATTING
    -- ========================================================================
    -- Format data type with appropriate length/precision information
    ctd.data_type_name + 
    CASE
        WHEN ctd.data_type_name IN ('varchar', 'nvarchar', 'char', 'nchar')
        THEN '(' + CAST(ctd.max_length AS VARCHAR(10)) + ')'
        WHEN ctd.data_type_name IN ('decimal', 'numeric')
        THEN '(' + CAST(ctd.precision AS VARCHAR(10)) + ',' + CAST(ctd.scale AS VARCHAR(10)) + ')'
        ELSE ''
    END AS data_type,
    
    ctd.max_length,
    
    -- Format precision and scale for numeric types
    CASE
        WHEN ctd.data_type_name IN ('decimal', 'numeric')
        THEN CAST(ctd.precision AS VARCHAR(10)) + ',' + CAST(ctd.scale AS VARCHAR(10))
        ELSE NULL
    END AS precision_scale,
    
    ctd.is_nullable,
    ctd.is_identity,
    ctd.is_computed,
    ctd.is_primary_key,
    ctd.is_foreign_key,
    
    -- ========================================================================
    -- COLUMN-LEVEL TRUST SCORE CALCULATION (0-100)
    -- ========================================================================
    -- Composite score combining multiple quality and reliability factors
    -- Weighting: Data Quality (60%) + Structure/Relationships (25%) + Business Context (15%)
    CAST(
        -- Data Quality Component (60% of total score)
        (cqm.constraint_validation_score * 0.35 +      -- 35% of data quality (21% of total)
         cqm.data_type_appropriateness * 0.4 +         -- 40% of data quality (24% of total)
         cqm.naming_convention_score * 0.25) * 0.6 +   -- 25% of data quality (15% of total)
        
        -- Structure & Relationships Component (25% of total score)
        -- Higher trust for columns with structural integrity constraints
        (CASE
            WHEN ctd.is_primary_key = 1 THEN 25.0       -- Primary keys: Highest structural trust
            WHEN ctd.is_foreign_key = 1 THEN 20.0       -- Foreign keys: High referential integrity
            WHEN ctd.is_identity = 1 THEN 18.0          -- Identity: System-managed reliability
            WHEN ctd.is_nullable = 0 THEN 15.0          -- NOT NULL: Prevents missing data
            ELSE 10.0                                    -- No special constraints
        END) +
        
        -- Business Context Component (15% of total score)
        -- Different schemas have different typical data quality standards
        (CASE ctd.schema_name
            WHEN 'Sales' THEN 15.0          -- Sales: Business-critical, usually well-maintained
            WHEN 'Person' THEN 14.0         -- Person: Customer data, important for business
            WHEN 'HumanResources' THEN 14.0 -- HR: Legal requirements, usually well-governed
            WHEN 'Production' THEN 12.0     -- Production: Operational data, good quality
            WHEN 'Purchasing' THEN 11.0     -- Purchasing: Important but less critical
            ELSE 10.0                        -- Other schemas: Standard quality assumptions
        END)
    AS DECIMAL(5,2)) AS column_trust_score,
    
    -- ========================================================================
    -- COLUMN TRUST LEVEL CLASSIFICATION
    -- ========================================================================
    -- Convert numeric trust score to categorical levels for easier interpretation
    CASE
        WHEN (
            (cqm.constraint_validation_score * 0.35 +
             cqm.data_type_appropriateness * 0.4 +
             cqm.naming_convention_score * 0.25) * 0.6 +
            (CASE
                WHEN ctd.is_primary_key = 1 THEN 25.0
                WHEN ctd.is_foreign_key = 1 THEN 20.0
                WHEN ctd.is_identity = 1 THEN 18.0
                WHEN ctd.is_nullable = 0 THEN 15.0
                ELSE 10.0
            END) +
            (CASE ctd.schema_name
                WHEN 'Sales' THEN 15.0
                WHEN 'Person' THEN 14.0
                WHEN 'HumanResources' THEN 14.0
                WHEN 'Production' THEN 12.0
                WHEN 'Purchasing' THEN 11.0
                ELSE 10.0
            END)
        ) >= 80 THEN 'VERY_HIGH'    -- 80-100: Exceptional trust level
        WHEN (
            (cqm.constraint_validation_score * 0.35 +
             cqm.data_type_appropriateness * 0.4 +
             cqm.naming_convention_score * 0.25) * 0.6 +
            (CASE
                WHEN ctd.is_primary_key = 1 THEN 25.0
                WHEN ctd.is_foreign_key = 1 THEN 20.0
                WHEN ctd.is_identity = 1 THEN 18.0
                WHEN ctd.is_nullable = 0 THEN 15.0
                ELSE 10.0
            END) +
            (CASE ctd.schema_name
                WHEN 'Sales' THEN 15.0
                WHEN 'Person' THEN 14.0
                WHEN 'HumanResources' THEN 14.0
                WHEN 'Production' THEN 12.0
                WHEN 'Purchasing' THEN 11.0
                ELSE 10.0
            END)
        ) >= 65 THEN 'HIGH'          -- 65-79: High trust level
        WHEN (
            (cqm.constraint_validation_score * 0.35 +
             cqm.data_type_appropriateness * 0.4 +
             cqm.naming_convention_score * 0.25) * 0.6 +
            (CASE
                WHEN ctd.is_primary_key = 1 THEN 25.0
                WHEN ctd.is_foreign_key = 1 THEN 20.0
                WHEN ctd.is_identity = 1 THEN 18.0
                WHEN ctd.is_nullable = 0 THEN 15.0
                ELSE 10.0
            END) +
            (CASE ctd.schema_name
                WHEN 'Sales' THEN 15.0
                WHEN 'Person' THEN 14.0
                WHEN 'HumanResources' THEN 14.0
                WHEN 'Production' THEN 12.0
                WHEN 'Purchasing' THEN 11.0
                ELSE 10.0
            END)
        ) >= 50 THEN 'MEDIUM'        -- 50-64: Medium trust level
        WHEN (
            (cqm.constraint_validation_score * 0.35 +
             cqm.data_type_appropriateness * 0.4 +
             cqm.naming_convention_score * 0.25) * 0.6 +
            (CASE
                WHEN ctd.is_primary_key = 1 THEN 25.0
                WHEN ctd.is_foreign_key = 1 THEN 20.0
                WHEN ctd.is_identity = 1 THEN 18.0
                WHEN ctd.is_nullable = 0 THEN 15.0
                ELSE 10.0
            END) +
            (CASE ctd.schema_name
                WHEN 'Sales' THEN 15.0
                WHEN 'Person' THEN 14.0
                WHEN 'HumanResources' THEN 14.0
                WHEN 'Production' THEN 12.0
                WHEN 'Purchasing' THEN 11.0
                ELSE 10.0
            END)
        ) >= 35 THEN 'LOW'           -- 35-49: Low trust level
        ELSE 'VERY_LOW'              -- 0-34: Very low trust level
    END AS column_trust_level,
    
    -- ========================================================================
    -- COLUMN-LEVEL SENSITIVITY CLASSIFICATION
    -- ========================================================================
    -- Determines access control and protection requirements
    -- Based on PII risk level and business context
    CASE
        -- HIGH: Critical PII or high-risk data requiring maximum protection
        WHEN cpi.pii_risk_level IN ('CRITICAL_PII_RISK', 'HIGH_PII_RISK') OR
             (ctd.schema_name IN ('Person', 'HumanResources') AND cpi.pii_risk_level = 'MEDIUM_PII_RISK')
        THEN 'HIGH'
        
        -- MEDIUM: Moderate PII risk or business-sensitive data
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' OR
             (ctd.schema_name = 'Sales' AND ctd.column_name NOT LIKE '%id%') OR
             cpi.pii_risk_level = 'LOW_PII_RISK'
        THEN 'MEDIUM'
        
        -- LOW: System fields, IDs, or non-sensitive data
        ELSE 'LOW'
    END AS column_sensitivity_level,
    
    -- ========================================================================
    -- COLUMN SENSITIVITY SCORE (0-100)
    -- ========================================================================
    -- Numeric score for sensitivity level, used for prioritization
    CASE
        -- CRITICAL sensitivity (95-100): Government IDs, passwords, biometrics
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 95 + CAST(cpi.pii_confidence_score / 20 AS INT)
        
        -- HIGH sensitivity (75-94): Financial data, full names, health info
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 75 + CAST(cpi.pii_confidence_score / 5 AS INT)
        
        -- MEDIUM-HIGH sensitivity (55-74): Personal identifiers in sensitive schemas
        WHEN ctd.schema_name IN ('Person', 'HumanResources') AND cpi.pii_risk_level = 'MEDIUM_PII_RISK' 
        THEN 55 + CAST(cpi.pii_confidence_score / 5 AS INT)
        
        -- MEDIUM sensitivity (35-54): General PII, business data
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 35 + CAST(cpi.pii_confidence_score / 5 AS INT)
        WHEN ctd.schema_name = 'Sales' AND ctd.column_name NOT LIKE '%id%' THEN 40
        WHEN cpi.pii_risk_level = 'LOW_PII_RISK' THEN 30 + CAST(cpi.pii_confidence_score / 10 AS INT)
        
        -- LOW sensitivity (5-34): System fields, IDs, reference data
        WHEN ctd.is_primary_key = 1 OR ctd.is_foreign_key = 1 OR ctd.is_identity = 1 THEN 15
        WHEN ctd.column_name LIKE '%id%' OR ctd.column_name LIKE '%key%' THEN 20
        WHEN ctd.schema_name IN ('Production', 'Purchasing') THEN 25
        ELSE 10
    END AS column_sensitivity_score,
    
    -- PII Analysis Results (from CTE)
    cpi.pii_category,
    cpi.pii_risk_level,
    cpi.pii_confidence_score,
    
    -- Quality Metrics (from CTE)
    cqm.constraint_validation_score,
    cqm.data_type_appropriateness,
    cqm.naming_convention_score,
    
    -- ========================================================================
    -- BUSINESS PURPOSE INFERENCE
    -- ========================================================================
    -- Infer the likely business purpose based on PII category and column characteristics
    CASE
        WHEN cpi.pii_category = 'GOVERNMENT_ID' THEN 'Legal Identification & Compliance'
        WHEN cpi.pii_category = 'AUTHENTICATION' THEN 'System Security & Access Control'
        WHEN cpi.pii_category = 'FINANCIAL' THEN 'Financial Transactions & Compensation'
        WHEN cpi.pii_category = 'PERSONAL_NAME' THEN 'Individual Identification & Communication'
        WHEN cpi.pii_category = 'CONTACT_INFO' THEN 'Communication & Customer Service'
        WHEN cpi.pii_category = 'ADDRESS_INFO' THEN 'Location Services & Delivery'
        WHEN cpi.pii_category = 'DEMOGRAPHIC' THEN 'Analytics & Personalization'
        WHEN cpi.pii_category = 'HEALTH' THEN 'Health Services & Compliance'
        WHEN cpi.pii_category = 'BIOMETRIC' THEN 'Identity Verification & Security'
        WHEN ctd.is_primary_key = 1 THEN 'Primary Record Identification'
        WHEN ctd.is_foreign_key = 1 THEN 'Relational Data Integrity'
        WHEN ctd.column_name LIKE '%date%' THEN 'Temporal Tracking & Auditing'
        WHEN ctd.column_name LIKE '%amount%' OR ctd.column_name LIKE '%price%' THEN 'Financial Calculations'
        WHEN ctd.column_name LIKE '%status%' OR ctd.column_name LIKE '%flag%' THEN 'State Management & Workflow'
        ELSE 'General Business Operations'
    END AS business_purpose,
    
    -- ========================================================================
    -- DATA ELEMENT CLASSIFICATION
    -- ========================================================================
    -- Formal data classification based on sensitivity and regulatory requirements
    CASE
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 'RESTRICTED - Legal/Government Identifier'
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 'CONFIDENTIAL - High-Risk Personal Data'
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 'SENSITIVE - Personal Identifier'
        WHEN cpi.pii_risk_level = 'LOW_PII_RISK' THEN 'CONTROLLED - Demographic Data'
        WHEN ctd.schema_name = 'Sales' THEN 'BUSINESS_SENSITIVE - Commercial Data'
        WHEN ctd.schema_name IN ('Production', 'Purchasing') THEN 'INTERNAL - Operational Data'
        WHEN ctd.is_primary_key = 1 OR ctd.is_foreign_key = 1 THEN 'STRUCTURAL - System Identifier'
        ELSE 'PUBLIC - General Reference Data'
    END AS data_element_classification,
    
    -- ========================================================================
    -- GOVERNANCE REQUIREMENTS
    -- ========================================================================
    
    -- Encryption Priority: Based on data sensitivity and regulatory requirements
    CASE
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 'MANDATORY'      -- Must encrypt
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 'REQUIRED'           -- Should encrypt
        WHEN ctd.schema_name IN ('Person', 'HumanResources') AND cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 'RECOMMENDED'
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 'CONDITIONAL'      -- Consider encryption
        ELSE 'NOT_REQUIRED'                                                  -- Encryption not needed
    END AS encryption_priority,
    
    -- Masking Required: For non-production environments
    CASE 
        WHEN cpi.pii_risk_level IN ('CRITICAL_PII_RISK', 'HIGH_PII_RISK', 'MEDIUM_PII_RISK') THEN 1 
        ELSE 0 
    END AS masking_required,
    
    -- Audit Logging Priority: For compliance and security monitoring
    CASE
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 'MANDATORY'      -- All access logged
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 'REQUIRED'           -- Access monitoring needed
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 'RECOMMENDED'      -- Consider logging
        WHEN ctd.schema_name IN ('Person', 'HumanResources', 'Sales') THEN 'CONDITIONAL'  -- Business decision
        ELSE 'STANDARD'                                                      -- Normal logging
    END AS audit_logging_priority,
    
    -- Access Restriction Level: Controls who can access the data
    CASE
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 'HIGHLY_RESTRICTED'  -- Very limited access
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 'RESTRICTED'             -- Limited access
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' THEN 'CONTROLLED'           -- Managed access
        WHEN ctd.schema_name IN ('Person', 'HumanResources', 'Sales') THEN 'MANAGED'  -- Business controls
        ELSE 'STANDARD'                                                          -- Normal access
    END AS access_restriction_level,
    
    -- ========================================================================
    -- REGULATORY CLASSIFICATION
    -- ========================================================================
    -- Maps to applicable legal and regulatory frameworks
    CASE
        WHEN cpi.pii_category = 'GOVERNMENT_ID' THEN 'GDPR Art.9, CCPA Sensitive PI, Government ID Protection Laws'
        WHEN cpi.pii_category = 'FINANCIAL' THEN 'PCI-DSS, SOX, GDPR, CCPA, Banking Regulations'
        WHEN cpi.pii_category IN ('PERSONAL_NAME', 'CONTACT_INFO', 'ADDRESS_INFO') THEN 'GDPR Art.6, CCPA Personal Information'
        WHEN cpi.pii_category = 'DEMOGRAPHIC' THEN 'GDPR Art.9 Special Categories, Anti-Discrimination Laws'
        WHEN cpi.pii_category = 'HEALTH' THEN 'HIPAA, GDPR Art.9, Health Information Privacy Laws'
        WHEN cpi.pii_category = 'AUTHENTICATION' THEN 'GDPR, Cybersecurity Regulations, Data Protection Laws'
        WHEN ctd.schema_name = 'HumanResources' THEN 'Employment Law, GDPR, CCPA, Wage & Hour Regulations'
        WHEN ctd.schema_name = 'Sales' THEN 'Consumer Protection, GDPR, CCPA, Commercial Data Regulations'
        ELSE 'Standard Data Protection Requirements'
    END AS regulatory_classification,
    
    -- ========================================================================
    -- DATA RETENTION CATEGORY
    -- ========================================================================
    -- Determines how long data should be kept based on type and regulations
    CASE
        WHEN cpi.pii_category = 'GOVERNMENT_ID' THEN 'LEGAL_RETENTION'       -- Legal requirements
        WHEN cpi.pii_category = 'FINANCIAL' THEN 'FINANCIAL_RETENTION'       -- Financial regulations
        WHEN cpi.pii_category IN ('PERSONAL_NAME', 'CONTACT_INFO', 'ADDRESS_INFO') THEN 'CUSTOMER_RETENTION'
        WHEN ctd.schema_name = 'HumanResources' THEN 'EMPLOYEE_RETENTION'    -- Employment records
        WHEN ctd.schema_name = 'Sales' THEN 'BUSINESS_RETENTION'             -- Business records
        WHEN ctd.schema_name IN ('Production', 'Purchasing') THEN 'OPERATIONAL_RETENTION'  -- Operational data
        ELSE 'STANDARD_RETENTION'                                            -- Default retention
    END AS data_retention_category,
    
    -- ========================================================================
    -- COLUMN GOVERNANCE ACTION RECOMMENDATIONS
    -- ========================================================================
    -- Specific actions recommended based on risk level and data quality
    CASE
        -- Critical Actions: Immediate attention required
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK'
        THEN 'IMMEDIATE: Implement field-level encryption, restrict access, enable audit logging, review data handling procedures.'
        
        -- High Priority Actions: Security controls needed
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK'
        THEN 'PRIORITY: Apply data masking for non-production, implement access controls, enable monitoring.'
        
        -- Medium Priority Actions: Governance controls recommended
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK'
        THEN 'RECOMMENDED: Consider data masking, apply appropriate access controls, document data usage.'
        
        -- Low Priority Actions: Standard governance
        WHEN cpi.pii_risk_level = 'LOW_PII_RISK'
        THEN 'STANDARD: Apply standard governance controls, monitor access patterns.'
        
        -- Quality Improvement: Technical debt addressing
        WHEN (
            (cqm.constraint_validation_score * 0.35 +
             cqm.data_type_appropriateness * 0.4 +
             cqm.naming_convention_score * 0.25) * 0.6 +
            (CASE
                WHEN ctd.is_primary_key = 1 THEN 25.0
                WHEN ctd.is_foreign_key = 1 THEN 20.0
                WHEN ctd.is_identity = 1 THEN 18.0
                WHEN ctd.is_nullable = 0 THEN 15.0
                ELSE 10.0
            END) +
            (CASE ctd.schema_name
                WHEN 'Sales' THEN 15.0
                WHEN 'Person' THEN 14.0
                WHEN 'HumanResources' THEN 14.0
                WHEN 'Production' THEN 12.0
                WHEN 'Purchasing' THEN 11.0
                ELSE 10.0
            END)
        ) < 50
        THEN 'IMPROVE: Address data quality issues, review naming conventions, add appropriate constraints.'
        
        ELSE 'MONITOR: Continue standard monitoring and periodic review.'
    END AS column_governance_action,
    
    -- ========================================================================
    -- DATA STEWARD PRIORITY
    -- ========================================================================
    -- Priority level for data steward attention and resource allocation
    CASE
        WHEN cpi.pii_risk_level = 'CRITICAL_PII_RISK' THEN 'URGENT'          -- Immediate attention
        WHEN cpi.pii_risk_level = 'HIGH_PII_RISK' THEN 'HIGH'                -- High priority
        WHEN cpi.pii_risk_level = 'MEDIUM_PII_RISK' OR ctd.schema_name IN ('Person', 'HumanResources') THEN 'MEDIUM'
        WHEN cpi.pii_risk_level = 'LOW_PII_RISK' OR ctd.schema_name = 'Sales' THEN 'LOW'
        ELSE 'ROUTINE'                                                        -- Standard priority
    END AS data_steward_priority

-- ========================================================================
-- JOIN ALL CTEs AND ORDER RESULTS
-- ========================================================================
FROM ColumnTechnicalDetails ctd
JOIN ColumnPIIClassification cpi ON ctd.object_id = cpi.object_id AND ctd.column_id = cpi.column_id
JOIN ColumnQualityMetrics cqm ON ctd.object_id = cqm.object_id AND ctd.column_id = cqm.column_id

-- Order by risk level (highest first), then by schema/table/column for consistency
ORDER BY 
    CASE cpi.pii_risk_level 
        WHEN 'CRITICAL_PII_RISK' THEN 1 
        WHEN 'HIGH_PII_RISK' THEN 2 
        WHEN 'MEDIUM_PII_RISK' THEN 3 
        WHEN 'LOW_PII_RISK' THEN 4 
        ELSE 5 
    END,
    ctd.schema_name, 
    ctd.table_name, 
    ctd.column_name;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================
PRINT 'Column-level analysis completed successfully!';
PRINT 'Results stored in #ColumnLevelAnalysis temporary table.';

-- ============================================================================
-- HIGH-PRIORITY SUMMARY REPORT
-- ============================================================================
-- Display summary of high-priority items requiring immediate attention
-- Filters to show only columns that need governance action or have high sensitivity

SELECT
    'COLUMN-LEVEL KPI DASHBOARD - HIGH PRIORITY ITEMS' AS report_section,
    
    -- Column Identification
    schema_name,
    table_name,
    column_name,
    data_type,
    
    -- Trust & Sensitivity KPIs
    column_trust_score,
    column_trust_level,
    column_sensitivity_level,
    column_sensitivity_score,
    
    -- PII Analysis Results
    pii_category,
    pii_risk_level,
    FORMAT(pii_confidence_score, 'N1') + '%' AS pii_confidence,  -- Format as percentage
    
    -- Quality and Structure Indicators
    CASE WHEN is_nullable = 1 THEN 'YES' ELSE 'NO' END AS nullable,
    CASE WHEN is_primary_key = 1 THEN 'YES' ELSE 'NO' END AS primary_key,
    CASE WHEN is_foreign_key = 1 THEN 'YES' ELSE 'NO' END AS foreign_key,
    
    -- Business Context
    business_purpose,
    data_element_classification,
    
    -- Governance Requirements
    encryption_priority,
    CASE WHEN masking_required = 1 THEN 'YES' ELSE 'NO' END AS masking_required,
    audit_logging_priority,
    access_restriction_level,
    
    -- Priority and Actions
    data_steward_priority,
    column_governance_action

FROM #ColumnLevelAnalysis

-- Filter to show only high-priority items that need attention
WHERE pii_risk_level IN ('CRITICAL_PII_RISK', 'HIGH_PII_RISK', 'MEDIUM_PII_RISK')  -- Any PII detected
   OR column_sensitivity_level = 'HIGH'                                             -- High sensitivity
   OR data_steward_priority IN ('URGENT', 'HIGH')                                   -- Urgent/high priority

-- Order by priority: most critical items first
ORDER BY 
    CASE pii_risk_level 
        WHEN 'CRITICAL_PII_RISK' THEN 1 
        WHEN 'HIGH_PII_RISK' THEN 2 
        WHEN 'MEDIUM_PII_RISK' THEN 3 
        ELSE 4 
    END,
    column_sensitivity_score DESC,  -- Higher sensitivity first
    column_trust_score ASC;         -- Lower trust (more problematic) first

-- ============================================================================
-- ANALYSIS COMPLETE
-- ============================================================================
-- The script has created a comprehensive column-level analysis including:
-- 1. PII detection and classification
-- 2. Trust and quality scoring
-- 3. Sensitivity assessment
-- 4. Governance recommendations
-- 5. Regulatory compliance mapping
-- 6. Prioritized action items
--
-- Use the #ColumnLevelAnalysis table for detailed analysis
-- Review the summary report for immediate action items
-- ============================================================================