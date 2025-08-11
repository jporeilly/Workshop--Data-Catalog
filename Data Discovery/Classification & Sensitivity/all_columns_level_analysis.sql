-- ============================================================================
-- COMPLETE DATABASE COLUMN ANALYSIS - ALL COLUMNS
-- ============================================================================
-- PURPOSE: This script performs comprehensive analysis of EVERY column in EVERY table
--          across ALL schemas in the database. Unlike the PII-focused script,
--          this analyzes all columns regardless of whether they contain PII.
--
-- METHODOLOGY:
--   - Uses multiple CTEs to break down complex analysis into logical components
--   - Applies universal scoring algorithms to all columns (no filtering)
--   - Combines technical, business, and governance perspectives
--   - Provides actionable recommendations for every column
--
-- SCOPE: 
--   - All user tables in all schemas (excludes system tables and views)
--   - Every column regardless of data type or naming convention
--   - Complete technical metadata analysis
--   - Universal quality and trust scoring (0-100 scale)
--   - Comprehensive governance recommendations
--
-- SCORING METHODOLOGY:
--   - Overall Score: Weighted combination of naming (20%) + data type (25%) + constraints (25%) + business value (30%)
--   - Technical Score: Data type appropriateness + implementation quality
--   - Structural Score: Constraints, keys, and relationships
--   - Naming Score: Convention adherence and descriptiveness
--   - Business Score: Inferred importance and domain relevance
--
-- OUTPUTS: 
--   1. #CompleteColumnAnalysis - Every column with full analysis (main results table)
--   2. Executive Summary - High-level statistics and KPIs
--   3. Schema-level Breakdown - Analysis grouped by schema
--   4. Top Priority Report - Urgent items requiring immediate attention
--   5. Data type Distribution - Technical metadata summary
-- ============================================================================

-- ============================================================================
-- CREATE COMPREHENSIVE RESULTS TABLE
-- ============================================================================
-- This table will store the complete analysis results for every column in the database
-- Each column gets a comprehensive evaluation across multiple dimensions
CREATE TABLE #CompleteColumnAnalysis (
    -- Primary Key and Identification
    analysis_id INT IDENTITY(1,1) PRIMARY KEY,          -- Unique identifier for each analysis record
    
    -- ========================================================================
    -- COLUMN IDENTIFICATION SECTION
    -- ========================================================================
    -- Basic information to uniquely identify each column in the database
    database_name NVARCHAR(128) NOT NULL,               -- Database name (for multi-DB scenarios)
    schema_name NVARCHAR(128) NOT NULL,                 -- Schema containing the table
    table_name NVARCHAR(128) NOT NULL,                  -- Table containing the column
    column_name NVARCHAR(128) NOT NULL,                 -- Column name within the table
    ordinal_position INT NOT NULL,                      -- Column position in table (1, 2, 3, etc.)
    full_column_name NVARCHAR(400) NOT NULL,            -- Fully qualified name (DB.Schema.Table.Column)
    
    -- ========================================================================
    -- COMPLETE TECHNICAL METADATA SECTION
    -- ========================================================================
    -- Comprehensive technical details about each column's data type and properties
    data_type_category VARCHAR(50) NOT NULL,            -- Categorized data type (TEXT, INTEGER, NUMERIC, etc.)
    base_data_type NVARCHAR(128) NOT NULL,              -- Raw SQL Server data type (varchar, int, datetime, etc.)
    formatted_data_type NVARCHAR(200) NOT NULL,         -- Type with length/precision (varchar(50), decimal(10,2))
    max_length INT,                                     -- Maximum length for string/binary types
    precision_value TINYINT,                            -- Numeric precision (total digits)
    scale_value TINYINT,                                -- Numeric scale (decimal places)
    character_set_name NVARCHAR(128),                   -- Character set for text types (ASCII/UNICODE)
    collation_name NVARCHAR(128),                       -- Collation for text types (sorting rules)
    
    -- ========================================================================
    -- COLUMN PROPERTIES SECTION
    -- ========================================================================
    -- Binary flags indicating various column characteristics and constraints
    -- Every column gets analyzed for these properties regardless of type or purpose
    is_nullable BIT NOT NULL,                           -- 1 = allows NULL values, 0 = NOT NULL constraint
    is_identity BIT NOT NULL,                           -- 1 = identity/auto-increment column
    is_computed BIT NOT NULL,                           -- 1 = computed column (formula-based)
    is_primary_key BIT NOT NULL,                        -- 1 = part of primary key constraint
    is_foreign_key BIT NOT NULL,                        -- 1 = part of foreign key constraint
    is_unique_key BIT NOT NULL,                         -- 1 = part of unique constraint (non-PK)
    is_indexed BIT NOT NULL,                            -- 1 = has index (any type) for performance
    has_default_constraint BIT NOT NULL,                -- 1 = has default value constraint
    has_check_constraint BIT NOT NULL,                  -- 1 = has check constraint (business rules)
    
    -- ========================================================================
    -- UNIVERSAL QUALITY SCORING SECTION (0-100 scale for ALL columns)
    -- ========================================================================
    -- Multi-dimensional quality assessment applied to every column
    overall_column_score DECIMAL(5,2) NOT NULL,         -- Composite quality score (weighted average of all factors)
    technical_quality_score DECIMAL(5,2) NOT NULL,      -- Technical implementation quality (data types, structure)
    structural_integrity_score DECIMAL(5,2) NOT NULL,   -- Constraints and relationships quality
    naming_quality_score DECIMAL(5,2) NOT NULL,         -- Naming convention adherence and clarity
    business_value_score DECIMAL(5,2) NOT NULL,         -- Inferred business importance and relevance
    
    -- ========================================================================
    -- QUALITY LEVEL CLASSIFICATIONS
    -- ========================================================================
    -- Categorical interpretations of the numeric scores for easier understanding
    overall_quality_level VARCHAR(20) NOT NULL,         -- EXCELLENT(90+)/GOOD(75-89)/FAIR(60-74)/POOR(<60)
    technical_quality_level VARCHAR(20) NOT NULL,       -- Technical implementation assessment
    structural_quality_level VARCHAR(20) NOT NULL,      -- Constraint and relationship assessment
    naming_quality_level VARCHAR(20) NOT NULL,          -- Naming convention assessment
    
    -- ========================================================================
    -- UNIVERSAL SENSITIVITY ANALYSIS SECTION
    -- ========================================================================
    -- Security and privacy assessment applied to ALL columns (not just obvious PII)
    data_sensitivity_category VARCHAR(30) NOT NULL,     -- HIGHLY_SENSITIVE/SENSITIVE/MODERATELY_SENSITIVE/LOW_SENSITIVITY/PUBLIC
    potential_pii_indicator VARCHAR(50),                -- Detected PII category (if any pattern matches)
    pii_risk_assessment VARCHAR(30) NOT NULL,           -- CRITICAL_RISK/HIGH_RISK/MEDIUM_RISK/LOW_RISK/MINIMAL_RISK
    business_criticality VARCHAR(20) NOT NULL,          -- CRITICAL/HIGH/MEDIUM/STANDARD (business importance)
    
    -- ========================================================================
    -- COMPLETE GOVERNANCE ANALYSIS
    -- ========================================================================
    -- Data governance recommendations and requirements for every column
    data_classification VARCHAR(50) NOT NULL,           -- RESTRICTED/CONFIDENTIAL/SENSITIVE/BUSINESS_CRITICAL/INTERNAL
    access_control_recommendation VARCHAR(30) NOT NULL, -- HIGHLY_RESTRICTED/RESTRICTED/CONTROLLED/MANAGED/STANDARD
    encryption_recommendation VARCHAR(30) NOT NULL,     -- MANDATORY/REQUIRED/RECOMMENDED/NOT_REQUIRED
    masking_recommendation VARCHAR(30) NOT NULL,        -- REQUIRED/RECOMMENDED/NOT_REQUIRED (for non-prod environments)
    monitoring_priority VARCHAR(20) NOT NULL,           -- CONTINUOUS/HIGH/MEDIUM/STANDARD (access monitoring level)
    
    -- ========================================================================
    -- BUSINESS CONTEXT ANALYSIS
    -- ========================================================================
    -- Inferred business purpose and domain classification for each column
    inferred_purpose VARCHAR(200) NOT NULL,             -- Likely business purpose based on naming and context
    domain_category VARCHAR(50) NOT NULL,               -- Business domain (SALES_REVENUE, CUSTOMER_DATA, etc.)
    data_lifecycle_stage VARCHAR(30) NOT NULL,          -- ACTIVE_TRANSACTIONAL/ACTIVE_REFERENCE/HISTORICAL_ARCHIVE/TEMPORARY
    
    -- ========================================================================
    -- COMPLIANCE AND REGULATORY SECTION
    -- ========================================================================
    -- Legal and regulatory considerations for each column
    regulatory_scope NVARCHAR(500) NOT NULL,            -- Applicable regulations (GDPR, CCPA, HIPAA, etc.)
    retention_category VARCHAR(50) NOT NULL,            -- Data retention classification and requirements
    compliance_risk_level VARCHAR(20) NOT NULL,         -- Regulatory compliance risk assessment
    
    -- ========================================================================
    -- ACTIONABLE RECOMMENDATIONS SECTION
    -- ========================================================================
    -- Specific, actionable guidance for data stewards and administrators
    immediate_actions VARCHAR(300),                      -- Urgent actions needed (if any) - NULL if none required
    recommended_improvements VARCHAR(300),               -- Suggested improvements for better governance/quality
    governance_priority VARCHAR(20) NOT NULL,           -- URGENT/HIGH/MEDIUM/LOW (priority for governance attention)
    steward_assignment VARCHAR(50) NOT NULL,            -- Suggested data steward type/role for ownership
    
    -- ========================================================================
    -- ANALYSIS METADATA
    -- ========================================================================
    -- Information about when and how the analysis was performed
    analysis_timestamp DATETIME DEFAULT GETDATE(),      -- When this analysis was run
    analysis_version VARCHAR(10) DEFAULT '1.0'          -- Version of the analysis methodology
);

-- ============================================================================
-- COMPREHENSIVE COLUMN ANALYSIS - MAIN QUERY WITH MULTIPLE CTEs
-- ============================================================================
-- Using Common Table Expressions (CTEs) to break down the complex analysis
-- into manageable, logical components. Each CTE focuses on a specific aspect
-- of the analysis, making the code more readable and maintainable.

WITH 
-- ============================================================================
-- CTE 1: COMPLETE COLUMN INVENTORY
-- ============================================================================
-- PURPOSE: Catalog EVERY column in EVERY user table across ALL schemas
-- SCOPE: Universal - no filtering, every column included regardless of purpose
-- METHOD: Joins system catalog views to extract complete technical metadata
-- OUTPUT: Base dataset with all columns and their technical characteristics
AllColumnsInventory AS (
    SELECT 
        -- Core identifiers for joining with other CTEs
        c.object_id,                                     -- Table object ID (internal SQL Server identifier)
        c.column_id,                                     -- Column ID within the table (internal identifier)
        
        -- Human-readable identifiers
        DB_NAME() as database_name,                      -- Current database name
        s.name AS schema_name,                           -- Schema name (dbo, Sales, Person, etc.)
        t.name AS table_name,                            -- Table name
        c.name AS column_name,                           -- Column name
        c.column_id AS ordinal_position,                 -- Position of column in table definition
        
        -- Fully qualified name for unique identification across database
        DB_NAME() + '.' + s.name + '.' + t.name + '.' + c.name AS full_column_name,
        
        -- ====================================================================
        -- COMPLETE TECHNICAL DETAILS FOR EVERY COLUMN
        -- ====================================================================
        ty.name AS base_data_type,                       -- Base SQL Server data type name
        c.max_length,                                    -- Maximum length (relevant for strings/binary)
        c.precision AS precision_value,                  -- Numeric precision (total significant digits)
        c.scale AS scale_value,                          -- Numeric scale (digits after decimal point)
        c.is_nullable,                                   -- NULL constraint indicator
        c.is_identity,                                   -- Identity column indicator
        c.is_computed,                                   -- Computed column indicator
        c.collation_name,                                -- Text collation (sorting/comparison rules)
        
        -- ====================================================================
        -- ENHANCED DATA TYPE CATEGORIZATION FOR ALL TYPES
        -- ====================================================================
        -- Groups SQL Server's many data types into logical categories
        -- This helps with standardized analysis across different specific types
        CASE 
            -- Text/String data types - for names, descriptions, codes
            WHEN ty.name IN ('char', 'varchar', 'text', 'nchar', 'nvarchar', 'ntext') THEN 'TEXT'
            
            -- Integer data types - for counts, IDs, flags
            WHEN ty.name IN ('int', 'bigint', 'smallint', 'tinyint') THEN 'INTEGER'
            
            -- Decimal/Floating point data types - for money, measurements, calculations
            WHEN ty.name IN ('decimal', 'numeric', 'money', 'smallmoney', 'float', 'real') THEN 'NUMERIC'
            
            -- Date/Time data types - for timestamps, dates, durations
            WHEN ty.name IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'time', 'datetimeoffset') THEN 'TEMPORAL'
            
            -- Boolean data types - for true/false, yes/no flags
            WHEN ty.name = 'bit' THEN 'BOOLEAN'
            
            -- Unique identifier data types - for GUIDs, unique keys
            WHEN ty.name = 'uniqueidentifier' THEN 'IDENTIFIER'
            
            -- Binary data types - for images, documents, encrypted data
            WHEN ty.name IN ('binary', 'varbinary', 'image') THEN 'BINARY'
            
            -- Structured data types - for XML documents
            WHEN ty.name = 'xml' THEN 'STRUCTURED'
            
            -- Spatial data types - for geographic/geometric data
            WHEN ty.name IN ('geography', 'geometry') THEN 'SPATIAL'
            
            -- Hierarchical data types - for organizational structures
            WHEN ty.name = 'hierarchyid' THEN 'HIERARCHICAL'
            
            -- System data types - for internal SQL Server use
            WHEN ty.name IN ('sql_variant', 'timestamp', 'rowversion') THEN 'SYSTEM'
            
            -- Catch-all for any other data types
            ELSE 'OTHER'
        END AS data_type_category,
        
        -- ====================================================================
        -- FORMATTED DATA TYPE WITH FULL SPECIFICATIONS
        -- ====================================================================
        -- Creates human-readable data type strings with length/precision info
        -- Examples: varchar(50), decimal(10,2), datetime2(7)
        ty.name + 
        CASE
            -- String types: show length or MAX
            WHEN ty.name IN ('varchar', 'nvarchar', 'char', 'nchar') THEN
                '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(10)) END + ')'
            
            -- Numeric types: show precision and scale
            WHEN ty.name IN ('decimal', 'numeric') THEN
                '(' + CAST(c.precision AS VARCHAR(10)) + ',' + CAST(c.scale AS VARCHAR(10)) + ')'
            
            -- Float: show precision if not default
            WHEN ty.name IN ('float') THEN
                CASE WHEN c.precision != 53 THEN '(' + CAST(c.precision AS VARCHAR(10)) + ')' ELSE '' END
            
            -- DateTime types: show scale (fractional seconds precision)
            WHEN ty.name IN ('datetime2', 'time', 'datetimeoffset') THEN
                '(' + CAST(c.scale AS VARCHAR(10)) + ')'
            
            -- Other types: no additional formatting needed
            ELSE ''
        END AS formatted_data_type,
        
        -- ====================================================================
        -- CHARACTER SET INFORMATION FOR TEXT COLUMNS
        -- ====================================================================
        -- Identifies whether text columns use ASCII or Unicode encoding
        CASE 
            WHEN ty.name IN ('char', 'varchar', 'text') THEN 'ASCII'      -- Single-byte character sets
            WHEN ty.name IN ('nchar', 'nvarchar', 'ntext') THEN 'UNICODE' -- Multi-byte Unicode support
            ELSE NULL                                                      -- Not applicable to non-text types
        END AS character_set_name
        
    FROM sys.schemas s
    JOIN sys.tables t ON s.schema_id = t.schema_id       -- Join schemas to tables
    JOIN sys.columns c ON t.object_id = c.object_id      -- Join tables to columns
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id -- Join to get data type information
    WHERE t.type = 'U'                                   -- Only user tables (excludes system tables, views, etc.)
),

-- ============================================================================
-- CTE 2: COMPREHENSIVE CONSTRAINT ANALYSIS
-- ============================================================================
-- PURPOSE: Analyze ALL types of constraints for EVERY column
-- SCOPE: Primary keys, foreign keys, unique constraints, indexes, defaults, checks
-- METHOD: Multiple LEFT JOINs to constraint system views to detect all constraint types
-- OUTPUT: Binary flags and scoring for constraint coverage per column
CompleteConstraintAnalysis AS (
    SELECT 
        c.object_id,                                     -- Table identifier for joining
        c.column_id,                                     -- Column identifier for joining
        
        -- ====================================================================
        -- CONSTRAINT DETECTION FLAGS
        -- ====================================================================
        -- Each flag indicates whether the column participates in that constraint type
        
        -- Primary Key Detection
        -- Checks if column is part of the table's primary key constraint
        CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_primary_key,
        
        -- Foreign Key Detection  
        -- Checks if column references another table (referential integrity)
        CASE WHEN fk.parent_column_id IS NOT NULL THEN 1 ELSE 0 END AS is_foreign_key,
        
        -- Unique Constraint Detection (excluding primary key)
        -- Checks for unique constraints that aren't the primary key
        CASE WHEN uk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_unique_key,
        
        -- Index Detection (any type of index)
        -- Checks if column has any index for performance optimization
        CASE WHEN idx.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_indexed,
        
        -- Default Constraint Detection
        -- Checks if column has a default value specified
        CASE WHEN dc.parent_column_id IS NOT NULL THEN 1 ELSE 0 END AS has_default_constraint,
        
        -- Check Constraint Detection (table-level, conservative approach)
        -- Checks if table has check constraints (business rule validation)
        CASE WHEN cc.parent_object_id IS NOT NULL THEN 1 ELSE 0 END AS has_check_constraint,
        
        -- ====================================================================
        -- CONSTRAINT SCORE CALCULATION (0-100+ points possible)
        -- ====================================================================
        -- Weighted scoring system that rewards different types of constraints
        -- Higher scores indicate better data integrity and reliability
        (
            -- Primary Key: 25 points (highest value - uniqueness + not null guaranteed)
            CASE WHEN pk.column_id IS NOT NULL THEN 25 ELSE 0 END +
            
            -- Foreign Key: 20 points (referential integrity, relationships)
            CASE WHEN fk.parent_column_id IS NOT NULL THEN 20 ELSE 0 END +
            
            -- Unique Constraint: 15 points (data uniqueness without being PK)
            CASE WHEN uk.column_id IS NOT NULL THEN 15 ELSE 0 END +
            
            -- Default Constraint: 10 points (prevents null insertion issues)
            CASE WHEN dc.parent_column_id IS NOT NULL THEN 10 ELSE 0 END +
            
            -- Check Constraint: 10 points (business rule enforcement)
            CASE WHEN cc.parent_object_id IS NOT NULL THEN 10 ELSE 0 END +
            
            -- Index: 10 points (performance optimization, indicates importance)
            CASE WHEN idx.column_id IS NOT NULL THEN 10 ELSE 0 END +
            
            -- Identity: 15 points (system-managed, guaranteed uniqueness)
            CASE WHEN c.is_identity = 1 THEN 15 ELSE 0 END +
            
            -- NOT NULL: 5 points (basic data quality requirement)
            CASE WHEN c.is_nullable = 0 THEN 5 ELSE 0 END
        ) AS total_constraint_score
        
    FROM sys.columns c
    
    -- ====================================================================
    -- PRIMARY KEY DETECTION SUBQUERY
    -- ====================================================================
    -- Identifies columns that are part of primary key constraints
    LEFT JOIN (
        SELECT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.is_primary_key = 1                       -- Only primary key indexes
    ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
    
    -- ====================================================================
    -- FOREIGN KEY DETECTION
    -- ====================================================================
    -- Identifies columns that reference other tables (parent side of FK relationship)
    LEFT JOIN sys.foreign_key_columns fk ON c.object_id = fk.parent_object_id 
                                         AND c.column_id = fk.parent_column_id
    
    -- ====================================================================
    -- UNIQUE CONSTRAINT DETECTION SUBQUERY
    -- ====================================================================
    -- Identifies columns with unique constraints (excluding primary keys)
    LEFT JOIN (
        SELECT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.is_unique = 1 AND i.is_primary_key = 0   -- Unique but not primary key
    ) uk ON c.object_id = uk.object_id AND c.column_id = uk.column_id
    
    -- ====================================================================
    -- INDEX DETECTION SUBQUERY
    -- ====================================================================
    -- Identifies columns that have any type of index (for performance)
    LEFT JOIN (
        SELECT DISTINCT ic.object_id, ic.column_id
        FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        -- Includes all index types: clustered, nonclustered, unique, etc.
    ) idx ON c.object_id = idx.object_id AND c.column_id = idx.column_id
    
    -- ====================================================================
    -- DEFAULT CONSTRAINT DETECTION
    -- ====================================================================
    -- Identifies columns that have default value constraints
    LEFT JOIN sys.default_constraints dc ON c.object_id = dc.parent_object_id 
                                         AND c.column_id = dc.parent_column_id
    
    -- ====================================================================
    -- CHECK CONSTRAINT DETECTION (TABLE LEVEL)
    -- ====================================================================
    -- Conservative approach: if table has check constraints, gives credit to all columns
    -- More sophisticated column-specific detection would require parsing constraint definitions
    LEFT JOIN (
        SELECT DISTINCT parent_object_id
        FROM sys.check_constraints
    ) cc ON c.object_id = cc.parent_object_id
),

-- ============================================================================
-- CTE 3: UNIVERSAL NAMING AND PATTERN ANALYSIS
-- ============================================================================
-- PURPOSE: Analyze naming patterns and conventions for ALL columns
-- SCOPE: Every column gets naming quality assessment and pattern detection
-- METHOD: Pattern matching, length analysis, convention checking, PII detection
-- OUTPUT: Naming quality scores, PII risk assessment, data type appropriateness
UniversalNamingAnalysis AS (
    SELECT 
        aci.object_id,
        aci.column_id,
        aci.column_name,
        aci.schema_name,
        aci.table_name,
        aci.data_type_category,
        
        -- ====================================================================
        -- COMPREHENSIVE NAMING QUALITY ANALYSIS
        -- ====================================================================
        -- Evaluates naming conventions, length, clarity, and best practices
        
        -- Column Name Length Assessment (useful for quality evaluation)
        LEN(aci.column_name) AS name_length,
        
        -- ====================================================================
        -- NAMING CONVENTION SCORE (0-100 SCALE)
        -- ====================================================================
        -- Multi-factor assessment of naming quality based on industry best practices
        CASE
            -- EXCELLENT NAMING (95 points): Meets all best practice criteria
            -- - Appropriate length (not too short, not too long)
            -- - Avoids temporary/test naming patterns
            -- - Descriptive and meaningful
            -- - Follows standard conventions
            WHEN LEN(aci.column_name) BETWEEN 3 AND 50 AND 
                 aci.column_name NOT LIKE '%temp%' AND        -- Avoids temporary naming
                 aci.column_name NOT LIKE '%old%' AND         -- Avoids legacy naming
                 aci.column_name NOT LIKE '%bak%' AND         -- Avoids backup naming
                 aci.column_name NOT LIKE '%test%' AND        -- Avoids test naming
                 aci.column_name NOT LIKE '%1' AND            -- Avoids numbered suffixes
                 aci.column_name NOT LIKE '%2' AND            -- Avoids numbered suffixes
                 aci.column_name NOT LIKE 'col%' AND          -- Avoids generic "column" names
                 aci.column_name NOT LIKE 'field%' AND        -- Avoids generic "field" names
                 aci.column_name <> 'id' AND                  -- Avoids non-descriptive "id"
                 aci.column_name NOT LIKE '%_%_%_%'           -- Not overly complex with underscores
            THEN 95
            
            -- GOOD NAMING (80 points): Meets most standards, minor issues
            -- - Reasonable length and avoids obvious bad patterns
            WHEN LEN(aci.column_name) BETWEEN 2 AND 75 AND 
                 aci.column_name NOT LIKE '%temp%' AND 
                 aci.column_name NOT LIKE '%old%' AND
                 aci.column_name NOT LIKE '%test%'
            THEN 80
            
            -- FAIR NAMING (65 points): Acceptable but could improve
            -- - Basic length requirements met, some issues present
            WHEN LEN(aci.column_name) BETWEEN 2 AND 100 AND
                 aci.column_name NOT LIKE '%temp%'
            THEN 65
            
            -- POOR NAMING (40 points): Below standards, needs improvement
            -- - Too short/long, or contains problematic patterns
            WHEN LEN(aci.column_name) < 2 OR LEN(aci.column_name) > 100 OR
                 aci.column_name LIKE '%temp%' OR aci.column_name LIKE '%old%'
            THEN 40
            
            -- VERY POOR NAMING (20 points): Major issues requiring attention
            ELSE 20
        END AS naming_quality_score,
        
        -- ====================================================================
        -- UNIVERSAL PII PATTERN DETECTION
        -- ====================================================================
        -- Apply PII detection to ALL columns, not just suspected ones
        -- Uses broader pattern matching to catch potential PII across all naming styles
        
        -- ====================================================================
        -- POTENTIAL PII CATEGORY (COMPREHENSIVE DETECTION)
        -- ====================================================================
        -- Analyzes column names for patterns indicating different types of personal data
        CASE
            -- GOVERNMENT AND LEGAL IDENTIFIERS
            -- Highest risk category - legal penalties for misuse
            WHEN aci.column_name LIKE '%ssn%' OR aci.column_name LIKE '%social%security%' OR
                 aci.column_name LIKE '%tax%id%' OR aci.column_name LIKE '%ein%' OR
                 aci.column_name LIKE '%passport%' OR aci.column_name LIKE '%license%'
            THEN 'GOVERNMENT_LEGAL_ID'
            
            -- FINANCIAL INFORMATION
            -- Protected by financial regulations (PCI-DSS, banking laws)
            WHEN aci.column_name LIKE '%credit%card%' OR aci.column_name LIKE '%account%number%' OR
                 aci.column_name LIKE '%salary%' OR aci.column_name LIKE '%wage%' OR
                 aci.column_name LIKE '%income%' OR aci.column_name LIKE '%pay%'
            THEN 'FINANCIAL_DATA'
            
            -- PERSONAL NAMES
            -- Can enable identity theft when combined with other data
            WHEN aci.column_name LIKE '%name%' OR aci.column_name LIKE '%first%' OR
                 aci.column_name LIKE '%last%' OR aci.column_name LIKE '%middle%' OR
                 aci.column_name LIKE '%display%'
            THEN 'PERSONAL_NAME'
            
            -- CONTACT INFORMATION
            -- Used for communication but also phishing/social engineering
            WHEN aci.column_name LIKE '%email%' OR aci.column_name LIKE '%mail%' OR
                 aci.column_name LIKE '%phone%' OR aci.column_name LIKE '%mobile%' OR
                 aci.column_name LIKE '%telephone%'
            THEN 'CONTACT_INFO'
            
            -- ADDRESS INFORMATION
            -- Location data, delivery information, can reveal patterns
            WHEN aci.column_name LIKE '%address%' OR aci.column_name LIKE '%street%' OR
                 aci.column_name LIKE '%city%' OR aci.column_name LIKE '%state%' OR
                 aci.column_name LIKE '%zip%' OR aci.column_name LIKE '%postal%' OR
                 aci.column_name LIKE '%country%'
            THEN 'ADDRESS_INFO'
            
            -- DEMOGRAPHIC DATA
            -- Protected classes, potential discrimination risks
            WHEN aci.column_name LIKE '%birth%' OR aci.column_name LIKE '%dob%' OR
                 aci.column_name LIKE '%age%' OR aci.column_name LIKE '%gender%' OR
                 aci.column_name LIKE '%sex%' OR aci.column_name LIKE '%race%' OR
                 aci.column_name LIKE '%ethnicity%'
            THEN 'DEMOGRAPHIC_DATA'
            
            -- AUTHENTICATION/SECURITY
            -- System access credentials and security tokens
            WHEN aci.column_name LIKE '%password%' OR aci.column_name LIKE '%secret%' OR
                 aci.column_name LIKE '%token%' OR aci.column_name LIKE '%hash%' OR
                 aci.column_name LIKE '%key%'
            THEN 'AUTHENTICATION_SECURITY'
            
            -- HEALTH INFORMATION
            -- Protected by health privacy laws (HIPAA, etc.)
            WHEN aci.column_name LIKE '%medical%' OR aci.column_name LIKE '%health%' OR
                 aci.column_name LIKE '%diagnosis%' OR aci.column_name LIKE '%treatment%'
            THEN 'HEALTH_DATA'
            
            -- SYSTEM/TECHNICAL FIELDS
            -- Usually safe but important for system integrity
            WHEN aci.column_name LIKE '%id' OR aci.column_name LIKE '%key' OR
                 aci.column_name LIKE '%guid%' OR aci.column_name LIKE '%uuid%'
            THEN 'SYSTEM_IDENTIFIER'
            
            -- TEMPORAL FIELDS
            -- Time-based data for auditing and analysis
            WHEN aci.column_name LIKE '%date%' OR aci.column_name LIKE '%time%' OR
                 aci.column_name LIKE '%created%' OR aci.column_name LIKE '%modified%' OR
                 aci.column_name LIKE '%updated%'
            THEN 'TEMPORAL_DATA'
            
            -- FINANCIAL/BUSINESS METRICS
            -- Business-sensitive numerical data
            WHEN aci.column_name LIKE '%amount%' OR aci.column_name LIKE '%price%' OR
                 aci.column_name LIKE '%cost%' OR aci.column_name LIKE '%value%' OR
                 aci.column_name LIKE '%total%'
            THEN 'BUSINESS_METRIC'
            
            -- STATUS/CONTROL FIELDS
            -- Workflow and process control indicators
            WHEN aci.column_name LIKE '%status%' OR aci.column_name LIKE '%flag%' OR
                 aci.column_name LIKE '%active%' OR aci.column_name LIKE '%enabled%'
            THEN 'STATUS_CONTROL'
            
            -- DEFAULT CATEGORY
            -- Columns that don't match specific patterns
            ELSE 'GENERAL_DATA'
        END AS potential_pii_category,
        
        -- ====================================================================
        -- PII RISK ASSESSMENT FOR ALL COLUMNS
        -- ====================================================================
        -- Risk level assessment based on potential impact of data exposure
        CASE
            -- CRITICAL RISK: Immediate identity theft or system compromise possible
            -- Legal violations, financial fraud, system breaches
            WHEN aci.column_name LIKE '%ssn%' OR aci.column_name LIKE '%social%security%' OR
                 aci.column_name LIKE '%passport%' OR aci.column_name LIKE '%credit%card%' OR
                 aci.column_name LIKE '%password%'
            THEN 'CRITICAL_RISK'
            
            -- HIGH RISK: Significant personal or financial harm possible
            -- Identity reconstruction, financial loss, privacy violations
            WHEN aci.column_name LIKE '%name%' OR aci.column_name LIKE '%email%' OR
                 aci.column_name LIKE '%phone%' OR aci.column_name LIKE '%address%' OR
                 aci.column_name LIKE '%salary%' OR aci.column_name LIKE '%birth%'
            THEN 'HIGH_RISK'
            
            -- MEDIUM RISK: Moderate privacy concerns, partial identity exposure
            -- Can be problematic in combination with other data
            WHEN aci.column_name LIKE '%age%' OR aci.column_name LIKE '%gender%' OR
                 aci.column_name LIKE '%city%' OR aci.column_name LIKE '%state%'
            THEN 'MEDIUM_RISK'
            
            -- LOW RISK: Limited privacy impact, usually safe when isolated
            -- System fields, non-personal identifiers
            WHEN aci.column_name LIKE '%id%' OR aci.column_name LIKE '%date%' OR
                 aci.column_name LIKE '%flag%' OR aci.column_name LIKE '%status%'
            THEN 'LOW_RISK'
            
            -- MINIMAL RISK: Generally safe, public or non-sensitive data
            ELSE 'MINIMAL_RISK'
        END AS pii_risk_assessment,
        
        -- ====================================================================
        -- DATA TYPE APPROPRIATENESS FOR ALL COLUMNS
        -- ====================================================================
        -- Evaluates whether data type choice is appropriate for column name/purpose
        -- Higher scores indicate better alignment between name and data type
        CASE
            -- PERFECT MATCHES (95-100 points): Ideal data type for the purpose
            WHEN aci.column_name LIKE '%date%' AND aci.data_type_category = 'TEMPORAL' THEN 100
            WHEN aci.column_name LIKE '%time%' AND aci.data_type_category = 'TEMPORAL' THEN 100
            WHEN aci.column_name LIKE '%amount%' AND aci.data_type_category = 'NUMERIC' THEN 100
            WHEN aci.column_name LIKE '%price%' AND aci.data_type_category = 'NUMERIC' THEN 100
            WHEN aci.column_name LIKE '%count%' AND aci.data_type_category = 'INTEGER' THEN 100
            WHEN aci.column_name LIKE '%flag%' AND aci.data_type_category = 'BOOLEAN' THEN 100
            WHEN aci.column_name LIKE '%id' AND aci.data_type_category IN ('INTEGER', 'IDENTIFIER') THEN 95
            WHEN aci.column_name LIKE '%name%' AND aci.data_type_category = 'TEXT' THEN 90
            WHEN aci.column_name LIKE '%description%' AND aci.data_type_category = 'TEXT' THEN 90
            
            -- GOOD MATCHES (75-89 points): Appropriate but not perfect
            WHEN aci.data_type_category = 'TEXT' AND aci.column_name LIKE '%code%' THEN 85
            WHEN aci.data_type_category = 'TEXT' AND aci.column_name LIKE '%address%' THEN 85
            WHEN aci.data_type_category = 'NUMERIC' AND aci.column_name LIKE '%rate%' THEN 80
            WHEN aci.data_type_category = 'INTEGER' AND aci.column_name LIKE '%number%' THEN 80
            
            -- REASONABLE MATCHES (60-74 points): Generally acceptable
            WHEN aci.data_type_category = 'TEXT' THEN 70
            WHEN aci.data_type_category = 'INTEGER' THEN 65
            WHEN aci.data_type_category = 'NUMERIC' THEN 65
            WHEN aci.data_type_category = 'TEMPORAL' THEN 70
            WHEN aci.data_type_category = 'BOOLEAN' THEN 65
            
            -- BELOW AVERAGE MATCHES (40-59 points): Questionable choices
            WHEN aci.data_type_category = 'BINARY' THEN 50
            WHEN aci.data_type_category = 'SYSTEM' THEN 45
            
            -- POOR MATCHES (0-39 points): Likely inappropriate data type choices
            ELSE 40
        END AS data_type_appropriateness_score
        
    FROM AllColumnsInventory aci
),

-- ============================================================================
-- CTE 4: BUSINESS CONTEXT AND VALUE ASSESSMENT
-- ============================================================================
-- PURPOSE: Assess business value and context for ALL columns
-- METHOD: Schema-based and naming-based business value inference
-- SCOPE: Every column gets business importance scoring and domain classification
-- OUTPUT: Business value scores, criticality assessment, domain categorization
BusinessContextAnalysis AS (
    SELECT 
        una.object_id,
        una.column_id,
        una.schema_name,
        una.table_name,
        una.column_name,
        
        -- ====================================================================
        -- BUSINESS VALUE SCORING (0-100 SCALE)
        -- ====================================================================
        -- Determines business importance based on schema, naming, and patterns
        -- Higher scores indicate greater business importance and value
        
        -- Three-component scoring system with weighted contributions:
        
        -- COMPONENT 1: SCHEMA-BASED BUSINESS VALUE (40% OF TOTAL SCORE)
        -- Different schemas typically have different business importance levels
        CASE una.schema_name
            WHEN 'Sales' THEN 40           -- Revenue generating activities - highest priority
            WHEN 'Person' THEN 35          -- Customer data - critical for business
            WHEN 'HumanResources' THEN 35  -- Employee data - legal and operational importance
            WHEN 'Production' THEN 30      -- Operations data - important for manufacturing
            WHEN 'Purchasing' THEN 25      -- Procurement data - cost management
            WHEN 'dbo' THEN 20              -- Default schema - variable importance
            ELSE 15                         -- Other schemas - standard importance
        END +
        
        -- COMPONENT 2: COLUMN NAME BUSINESS VALUE INDICATORS (35% OF TOTAL SCORE)
        -- Column names that suggest high business value or critical operations
        CASE 
            -- Revenue/Financial keywords - highest business impact
            WHEN una.column_name LIKE '%revenue%' OR una.column_name LIKE '%sales%' OR 
                 una.column_name LIKE '%profit%' OR una.column_name LIKE '%income%' THEN 35
            
            -- Customer/Client keywords - critical for customer relationships
            WHEN una.column_name LIKE '%customer%' OR una.column_name LIKE '%client%' OR
                 una.column_name LIKE '%name%' THEN 30
            
            -- Product/Order keywords - core business operations
            WHEN una.column_name LIKE '%product%' OR una.column_name LIKE '%order%' OR
                 una.column_name LIKE '%price%' OR una.column_name LIKE '%amount%' THEN 25
            
            -- Temporal/Status keywords - tracking and workflow
            WHEN una.column_name LIKE '%date%' OR una.column_name LIKE '%time%' OR
                 una.column_name LIKE '%status%' THEN 20
            
            -- Identifier keywords - system integrity
            WHEN una.column_name LIKE '%id%' OR una.column_name LIKE '%key%' THEN 15
            
            -- Descriptive keywords - supporting information
            WHEN una.column_name LIKE '%description%' OR una.column_name LIKE '%note%' THEN 10
            
            -- Other columns - basic value
            ELSE 5
        END +
        
        -- COMPONENT 3: DATA TYPE BUSINESS VALUE (25% OF TOTAL SCORE)
        -- Different data types typically have different business analysis value
        CASE una.data_type_category
            WHEN 'NUMERIC' THEN 25          -- Financial calculations, measurements, KPIs
            WHEN 'TEXT' THEN 20             -- Descriptive information, names, codes
            WHEN 'TEMPORAL' THEN 20         -- Time-based analysis, trends, auditing
            WHEN 'IDENTIFIER' THEN 15       -- Relationships, unique identification
            WHEN 'INTEGER' THEN 15          -- Counts, references, flags
            WHEN 'BOOLEAN' THEN 10          -- Status indicators, flags
            ELSE 5                          -- Other types - limited business analysis value
        END AS business_value_score,
        
        -- ====================================================================
        -- BUSINESS CRITICALITY ASSESSMENT
        -- ====================================================================
        -- Categorical assessment of how critical this column is to business operations
        CASE
            -- CRITICAL: Revenue-generating or financial data in key schemas
            WHEN (una.schema_name IN ('Sales', 'Person') AND una.column_name LIKE '%amount%') OR
                 (una.column_name LIKE '%revenue%' OR una.column_name LIKE '%profit%') THEN 'CRITICAL'
            
            -- HIGH: Data in business-critical schemas
            WHEN una.schema_name IN ('Sales', 'Person', 'HumanResources') THEN 'HIGH'
            
            -- MEDIUM: Operational data supporting business processes
            WHEN una.schema_name IN ('Production', 'Purchasing') THEN 'MEDIUM'
            
            -- STANDARD: General business data with normal importance
            ELSE 'STANDARD'
        END AS business_criticality,
        
        -- ====================================================================
        -- DOMAIN CLASSIFICATION
        -- ====================================================================
        -- Assigns each column to a business domain for governance and stewardship
        CASE 
            WHEN una.schema_name = 'Sales' THEN 'SALES_REVENUE'
            WHEN una.schema_name = 'Person' THEN 'CUSTOMER_DATA'
            WHEN una.schema_name = 'HumanResources' THEN 'EMPLOYEE_DATA'
            WHEN una.schema_name = 'Production' THEN 'OPERATIONS'
            WHEN una.schema_name = 'Purchasing' THEN 'PROCUREMENT'
            WHEN una.column_name LIKE '%financial%' OR una.column_name LIKE '%money%' THEN 'FINANCIAL'
            WHEN una.column_name LIKE '%audit%' OR una.column_name LIKE '%log%' THEN 'AUDIT_COMPLIANCE'
            WHEN una.column_name LIKE '%config%' OR una.column_name LIKE '%setting%' THEN 'CONFIGURATION'
            ELSE 'GENERAL_BUSINESS'
        END AS domain_category,
        
        -- ====================================================================
        -- DATA LIFECYCLE ASSESSMENT
        -- ====================================================================
        -- Determines the lifecycle stage and usage pattern of the data
        CASE 
            -- Active transactional data - frequently updated, current operations
            WHEN una.column_name LIKE '%created%' OR una.column_name LIKE '%modified%' OR
                 una.column_name LIKE '%updated%' OR una.column_name LIKE '%date%' THEN 'ACTIVE_TRANSACTIONAL'
            
            -- Historical/archived data - preserved for compliance or analysis
            WHEN una.column_name LIKE '%archived%' OR una.column_name LIKE '%deleted%' OR
                 una.column_name LIKE '%historical%' THEN 'HISTORICAL_ARCHIVE'
            
            -- Temporary/staging data - processing intermediate results
            WHEN una.column_name LIKE '%temp%' OR una.column_name LIKE '%staging%' THEN 'TEMPORARY_PROCESSING'
            
            -- Active reference data - stable, frequently read
            ELSE 'ACTIVE_REFERENCE'
        END AS data_lifecycle_stage
        
    FROM UniversalNamingAnalysis una
)

-- ============================================================================
-- MAIN INSERT STATEMENT - COMPLETE ANALYSIS OF ALL COLUMNS
-- ============================================================================
-- Combines all the CTE results and calculates final scores and classifications
-- This INSERT processes every column and generates comprehensive governance analysis

INSERT INTO #CompleteColumnAnalysis (
    -- Column identification fields
    database_name, schema_name, table_name, column_name, ordinal_position, full_column_name,
    
    -- Technical metadata fields
    data_type_category, base_data_type, formatted_data_type, max_length, precision_value, scale_value,
    character_set_name, collation_name,
    
    -- Column properties (constraint and structure flags)
    is_nullable, is_identity, is_computed, is_primary_key, is_foreign_key, is_unique_key, 
    is_indexed, has_default_constraint, has_check_constraint,
    
    -- Quality scoring fields
    overall_column_score, technical_quality_score, structural_integrity_score, 
    naming_quality_score, business_value_score,
    
    -- Quality level classifications
    overall_quality_level, technical_quality_level, structural_quality_level, naming_quality_level,
    
    -- Sensitivity and risk fields
    data_sensitivity_category, potential_pii_indicator, pii_risk_assessment, business_criticality,
    
    -- Governance recommendation fields
    data_classification, access_control_recommendation, encryption_recommendation, 
    masking_recommendation, monitoring_priority,
    
    -- Business context fields
    inferred_purpose, domain_category, data_lifecycle_stage,
    
    -- Compliance and regulatory fields
    regulatory_scope, retention_category, compliance_risk_level,
    
    -- Actionable recommendation fields
    immediate_actions, recommended_improvements, governance_priority, steward_assignment
)
SELECT 
    -- ====================================================================
    -- BASIC COLUMN IDENTIFICATION
    -- ====================================================================
    aci.database_name,
    aci.schema_name,
    aci.table_name,
    aci.column_name,
    aci.ordinal_position,
    aci.full_column_name,
    
    -- ====================================================================
    -- TECHNICAL METADATA SECTION
    -- ====================================================================
    aci.data_type_category,
    aci.base_data_type,
    aci.formatted_data_type,
    aci.max_length,
    aci.precision_value,
    aci.scale_value,
    aci.character_set_name,
    aci.collation_name,
    
    -- ====================================================================
    -- COLUMN PROPERTIES (CONSTRAINTS AND STRUCTURE)
    -- ====================================================================
    aci.is_nullable,
    aci.is_identity,
    aci.is_computed,
    cca.is_primary_key,
    cca.is_foreign_key,
    cca.is_unique_key,
    cca.is_indexed,
    cca.has_default_constraint,
    cca.has_check_constraint,
    
    -- ====================================================================
    -- COMPREHENSIVE SCORING FOR ALL COLUMNS
    -- ====================================================================
    
    -- OVERALL COLUMN SCORE (0-100) - WEIGHTED COMPOSITE OF ALL FACTORS
    -- This is the primary quality indicator combining multiple dimensions
    -- Weighting rationale:
    --   - Business Value (30%): Most important - drives governance priorities
    --   - Data Type Appropriateness (25%): Technical quality foundation
    --   - Constraints (25%): Data integrity and reliability
    --   - Naming Quality (20%): Maintainability and understanding
    CAST(
        (una.naming_quality_score * 0.20 +                    -- 20% naming quality
         una.data_type_appropriateness_score * 0.25 +         -- 25% data type appropriateness  
         LEAST(cca.total_constraint_score, 100) * 0.25 +      -- 25% constraints (capped at 100)
         bca.business_value_score * 0.30                      -- 30% business value
        ) AS DECIMAL(5,2)
    ) AS overall_column_score,
    
    -- TECHNICAL QUALITY SCORE (data type appropriateness + technical implementation)
    -- Focuses on technical implementation quality and appropriateness
    CAST((una.data_type_appropriateness_score * 0.6 +         -- 60% data type fit
          CASE WHEN aci.is_computed = 1 THEN 90                -- Computed columns: sophisticated
               WHEN aci.is_identity = 1 THEN 85                -- Identity columns: system-managed
               ELSE 70 END * 0.4                              -- Regular columns: standard baseline
         ) AS DECIMAL(5,2)) AS technical_quality_score,
    
    -- STRUCTURAL INTEGRITY SCORE (constraints and relationships)
    -- Measures data integrity controls and relationship management
    CAST(LEAST(cca.total_constraint_score, 100) AS DECIMAL(5,2)) AS structural_integrity_score,
    
    -- NAMING QUALITY SCORE (from naming analysis)
    CAST(una.naming_quality_score AS DECIMAL(5,2)) AS naming_quality_score,
    
    -- BUSINESS VALUE SCORE (from business context analysis)
    CAST(bca.business_value_score AS DECIMAL(5,2)) AS business_value_score,
    
    -- ====================================================================
    -- QUALITY LEVEL CLASSIFICATIONS
    -- ====================================================================
    -- Convert numeric scores to categorical levels for easier interpretation
    
    -- OVERALL QUALITY LEVEL
    -- Based on the weighted composite score calculated above
    CASE 
        WHEN (una.naming_quality_score * 0.20 + una.data_type_appropriateness_score * 0.25 + 
              LEAST(cca.total_constraint_score, 100) * 0.25 + bca.business_value_score * 0.30) >= 90 THEN 'EXCELLENT'
        WHEN (una.naming_quality_score * 0.20 + una.data_type_appropriateness_score * 0.25 + 
              LEAST(cca.total_constraint_score, 100) * 0.25 + bca.business_value_score * 0.30) >= 75 THEN 'GOOD'
        WHEN (una.naming_quality_score * 0.20 + una.data_type_appropriateness_score * 0.25 + 
              LEAST(cca.total_constraint_score, 100) * 0.25 + bca.business_value_score * 0.30) >= 60 THEN 'FAIR'
        ELSE 'POOR'
    END AS overall_quality_level,
    
    -- TECHNICAL QUALITY LEVEL
    -- Based on data type appropriateness score
    CASE 
        WHEN una.data_type_appropriateness_score >= 90 THEN 'EXCELLENT'
        WHEN una.data_type_appropriateness_score >= 75 THEN 'GOOD'
        WHEN una.data_type_appropriateness_score >= 60 THEN 'FAIR'
        ELSE 'POOR'
    END AS technical_quality_level,
    
    -- STRUCTURAL QUALITY LEVEL
    -- Based on constraint coverage score
    CASE 
        WHEN cca.total_constraint_score >= 75 THEN 'EXCELLENT'
        WHEN cca.total_constraint_score >= 50 THEN 'GOOD'
        WHEN cca.total_constraint_score >= 25 THEN 'FAIR'
        ELSE 'POOR'
    END AS structural_quality_level,
    
    -- NAMING QUALITY LEVEL
    -- Based on naming convention score
    CASE 
        WHEN una.naming_quality_score >= 90 THEN 'EXCELLENT'
        WHEN una.naming_quality_score >= 75 THEN 'GOOD'
        WHEN una.naming_quality_score >= 60 THEN 'FAIR'
        ELSE 'POOR'
    END AS naming_quality_level,
    
    -- ====================================================================
    -- SENSITIVITY AND RISK ANALYSIS
    -- ====================================================================
    
    -- DATA SENSITIVITY CATEGORY
    -- Maps PII risk assessment to sensitivity categories for governance
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'HIGHLY_SENSITIVE'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'SENSITIVE'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' THEN 'MODERATELY_SENSITIVE'
        WHEN una.pii_risk_assessment = 'LOW_RISK' THEN 'LOW_SENSITIVITY'
        ELSE 'PUBLIC'
    END AS data_sensitivity_category,
    
    -- POTENTIAL PII INDICATOR (from naming analysis)
    una.potential_pii_category AS potential_pii_indicator,
    
    -- PII RISK ASSESSMENT (from naming analysis)
    una.pii_risk_assessment,
    
    -- BUSINESS CRITICALITY (from business context analysis)
    bca.business_criticality,
    
    -- ====================================================================
    -- GOVERNANCE RECOMMENDATIONS
    -- ====================================================================
    -- Specific governance controls and requirements based on risk and sensitivity
    
    -- DATA CLASSIFICATION
    -- Formal data classification level for access control and handling procedures
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'RESTRICTED'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'CONFIDENTIAL'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' THEN 'SENSITIVE'
        WHEN bca.business_criticality = 'CRITICAL' THEN 'BUSINESS_CRITICAL'
        WHEN bca.business_criticality = 'HIGH' THEN 'BUSINESS_SENSITIVE'
        ELSE 'INTERNAL'
    END AS data_classification,
    
    -- ACCESS CONTROL RECOMMENDATION
    -- Recommended access control level based on sensitivity and risk
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'HIGHLY_RESTRICTED'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'RESTRICTED'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' THEN 'CONTROLLED'
        WHEN bca.business_criticality IN ('CRITICAL', 'HIGH') THEN 'MANAGED'
        ELSE 'STANDARD'
    END AS access_control_recommendation,
    
    -- ENCRYPTION RECOMMENDATION
    -- Encryption requirements based on sensitivity and regulatory needs
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'MANDATORY'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'REQUIRED'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' THEN 'RECOMMENDED'
        WHEN bca.business_criticality = 'CRITICAL' THEN 'RECOMMENDED'
        ELSE 'NOT_REQUIRED'
    END AS encryption_recommendation,
    
    -- MASKING RECOMMENDATION
    -- Data masking requirements for non-production environments
    CASE 
        WHEN una.pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK', 'MEDIUM_RISK') THEN 'REQUIRED'
        WHEN bca.business_criticality = 'CRITICAL' THEN 'RECOMMENDED'
        ELSE 'NOT_REQUIRED'
    END AS masking_recommendation,
    
    -- MONITORING PRIORITY
    -- Access monitoring and audit logging requirements
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'CONTINUOUS'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'HIGH'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' OR bca.business_criticality = 'CRITICAL' THEN 'MEDIUM'
        ELSE 'STANDARD'
    END AS monitoring_priority,
    
    -- ====================================================================
    -- BUSINESS CONTEXT
    -- ====================================================================
    
    -- INFERRED PURPOSE
    -- Likely business purpose based on naming patterns and context
    CASE 
        WHEN una.potential_pii_category = 'SYSTEM_IDENTIFIER' THEN 'System identification and relationships'
        WHEN una.potential_pii_category = 'PERSONAL_NAME' THEN 'Individual identification and communication'
        WHEN una.potential_pii_category = 'CONTACT_INFO' THEN 'Communication and customer service'
        WHEN una.potential_pii_category = 'ADDRESS_INFO' THEN 'Location services and delivery'
        WHEN una.potential_pii_category = 'FINANCIAL_DATA' THEN 'Financial transactions and analysis'
        WHEN una.potential_pii_category = 'TEMPORAL_DATA' THEN 'Time tracking and audit trails'
        WHEN una.potential_pii_category = 'BUSINESS_METRIC' THEN 'Business analytics and reporting'
        WHEN una.potential_pii_category = 'STATUS_CONTROL' THEN 'Process control and workflow management'
        ELSE 'General business operations and data storage'
    END AS inferred_purpose,
    
    -- DOMAIN CATEGORY (from business context analysis)
    bca.domain_category,
    
    -- DATA LIFECYCLE STAGE (from business context analysis)
    bca.data_lifecycle_stage,
    
    -- ====================================================================
    -- COMPLIANCE AND REGULATORY
    -- ====================================================================
    
    -- REGULATORY SCOPE
    -- Applicable legal and regulatory frameworks based on data type and schema
    CASE 
        WHEN una.potential_pii_category = 'GOVERNMENT_LEGAL_ID' THEN 'GDPR Art.9, CCPA Sensitive PI, Government ID Laws'
        WHEN una.potential_pii_category = 'FINANCIAL_DATA' THEN 'PCI-DSS, SOX, GDPR, CCPA, Financial Regulations'
        WHEN una.potential_pii_category IN ('PERSONAL_NAME', 'CONTACT_INFO', 'ADDRESS_INFO') THEN 'GDPR, CCPA, Privacy Laws'
        WHEN una.potential_pii_category = 'HEALTH_DATA' THEN 'HIPAA, GDPR Art.9, Health Privacy Laws'
        WHEN aci.schema_name = 'HumanResources' THEN 'Employment Laws, GDPR, CCPA'
        WHEN aci.schema_name = 'Sales' THEN 'Consumer Protection, GDPR, CCPA'
        ELSE 'Standard Data Protection Laws'
    END AS regulatory_scope,
    
    -- RETENTION CATEGORY
    -- Data retention classification based on type and business context
    CASE 
        WHEN una.potential_pii_category = 'GOVERNMENT_LEGAL_ID' THEN 'LEGAL_RETENTION'
        WHEN una.potential_pii_category = 'FINANCIAL_DATA' THEN 'FINANCIAL_RETENTION'
        WHEN una.potential_pii_category IN ('PERSONAL_NAME', 'CONTACT_INFO') THEN 'CUSTOMER_RETENTION'
        WHEN aci.schema_name = 'HumanResources' THEN 'EMPLOYEE_RETENTION'
        WHEN aci.schema_name = 'Sales' THEN 'BUSINESS_RETENTION'
        ELSE 'STANDARD_RETENTION'
    END AS retention_category,
    
    -- COMPLIANCE RISK LEVEL
    -- Overall regulatory compliance risk assessment
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' THEN 'VERY_HIGH'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' THEN 'HIGH'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' THEN 'MEDIUM'
        ELSE 'LOW'
    END AS compliance_risk_level,
    
    -- ====================================================================
    -- ACTIONABLE RECOMMENDATIONS
    -- ====================================================================
    
    -- IMMEDIATE ACTIONS
    -- Urgent actions required based on risk level and quality issues
    CASE 
        WHEN una.pii_risk_assessment = 'CRITICAL_RISK' 
        THEN 'URGENT: Implement encryption, restrict access, enable audit logging'
        WHEN una.pii_risk_assessment = 'HIGH_RISK' 
        THEN 'HIGH PRIORITY: Apply data masking, implement access controls'
        WHEN una.naming_quality_score < 40 
        THEN 'IMPROVE: Review and improve column naming standards'
        WHEN cca.total_constraint_score < 20 
        THEN 'ENHANCE: Add appropriate constraints for data integrity'
        ELSE NULL  -- No immediate actions required
    END AS immediate_actions,
    
    -- RECOMMENDED IMPROVEMENTS
    -- Suggested improvements for better governance, quality, or performance
    CASE 
        WHEN una.data_type_appropriateness_score < 60 
        THEN 'Consider reviewing data type choice for better alignment with data content'
        WHEN cca.total_constraint_score < 40 
        THEN 'Add constraints (NOT NULL, CHECK, FK) to improve data quality'
        WHEN una.naming_quality_score < 70 
        THEN 'Improve naming convention adherence for better maintainability'
        WHEN cca.is_indexed = 0 AND (cca.is_foreign_key = 1 OR una.column_name LIKE '%id%')
        THEN 'Consider adding index for performance optimization'
        ELSE 'No immediate improvements required'
    END AS recommended_improvements,
    
    -- GOVERNANCE PRIORITY
    -- Priority level for data governance attention and resource allocation
    CASE 
        WHEN una.pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 'URGENT'
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' OR bca.business_criticality = 'CRITICAL' THEN 'HIGH'
        WHEN bca.business_criticality = 'HIGH' OR 
             (una.naming_quality_score < 50 AND cca.total_constraint_score < 30) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS governance_priority,
    
    -- STEWARD ASSIGNMENT
    -- Suggested data steward type/role based on domain and sensitivity
    CASE 
        WHEN aci.schema_name = 'Sales' THEN 'SALES_DATA_STEWARD'
        WHEN aci.schema_name = 'Person' THEN 'CUSTOMER_DATA_STEWARD'
        WHEN aci.schema_name = 'HumanResources' THEN 'HR_DATA_STEWARD'
        WHEN aci.schema_name = 'Production' THEN 'OPERATIONS_DATA_STEWARD'
        WHEN una.pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 'PRIVACY_OFFICER'
        ELSE 'GENERAL_DATA_STEWARD'
    END AS steward_assignment

-- ====================================================================
-- JOIN ALL CTEs TO GET COMPLETE ANALYSIS
-- ====================================================================
FROM AllColumnsInventory aci
JOIN CompleteConstraintAnalysis cca ON aci.object_id = cca.object_id AND aci.column_id = cca.column_id
JOIN UniversalNamingAnalysis una ON aci.object_id = una.object_id AND aci.column_id = una.column_id
JOIN BusinessContextAnalysis bca ON aci.object_id = bca.object_id AND aci.column_id = bca.column_id

-- ====================================================================
-- ORDERING RESULTS BY GOVERNANCE PRIORITY
-- ====================================================================
-- Order by governance priority (most critical first), then by schema/table/column
-- This ensures the most important items appear first in the results
ORDER BY 
    -- Primary sort: Governance priority (most urgent first)
    CASE 
        WHEN una.pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1
        WHEN una.pii_risk_assessment = 'MEDIUM_RISK' OR bca.business_criticality = 'CRITICAL' THEN 2
        WHEN bca.business_criticality = 'HIGH' THEN 3
        ELSE 4
    END,
    -- Secondary sort: Schema name (alphabetical)
    aci.schema_name,
    -- Tertiary sort: Table name (alphabetical)
    aci.table_name,
    -- Final sort: Column position in table (logical order)
    aci.ordinal_position;

-- ============================================================================
-- COMPLETION MESSAGES AND SUMMARY STATISTICS
-- ============================================================================

PRINT '============================================================================';
PRINT 'COMPLETE DATABASE COLUMN ANALYSIS - FINISHED';
PRINT '============================================================================';

-- Calculate and display summary statistics
-- This provides immediate feedback on analysis results without using variables
SELECT 
    'ANALYSIS SUMMARY' AS summary_type,
    COUNT(*) AS total_columns_analyzed,
    SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) AS high_risk_columns,
    SUM(CASE WHEN overall_quality_level = 'POOR' THEN 1 ELSE 0 END) AS poor_quality_columns,
    SUM(CASE WHEN governance_priority IN ('URGENT', 'HIGH') THEN 1 ELSE 0 END) AS priority_attention_needed
FROM #CompleteColumnAnalysis;

PRINT '============================================================================';

-- ============================================================================
-- EXECUTIVE SUMMARY DASHBOARD
-- ============================================================================
-- Comprehensive high-level view of all columns analyzed
-- Provides key metrics and distributions for executive reporting
SELECT 
    '=== EXECUTIVE SUMMARY - ALL COLUMNS ANALYSIS ===' AS summary_section,
    
    -- ====================================================================
    -- COVERAGE METRICS
    -- ====================================================================
    COUNT(*) AS total_columns_analyzed,                  -- Total number of columns processed
    COUNT(DISTINCT schema_name) AS schemas_analyzed,     -- Number of different schemas covered
    COUNT(DISTINCT schema_name + '.' + table_name) AS tables_analyzed, -- Number of tables covered
    
    -- ====================================================================
    -- QUALITY DISTRIBUTION ANALYSIS
    -- ====================================================================
    -- Shows how columns are distributed across quality levels
    SUM(CASE WHEN overall_quality_level = 'EXCELLENT' THEN 1 ELSE 0 END) AS excellent_quality_columns,
    SUM(CASE WHEN overall_quality_level = 'GOOD' THEN 1 ELSE 0 END) AS good_quality_columns,
    SUM(CASE WHEN overall_quality_level = 'FAIR' THEN 1 ELSE 0 END) AS fair_quality_columns,
    SUM(CASE WHEN overall_quality_level = 'POOR' THEN 1 ELSE 0 END) AS poor_quality_columns,
    
    -- Calculate quality percentages for better understanding
    CAST(SUM(CASE WHEN overall_quality_level = 'EXCELLENT' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS excellent_quality_percentage,
    CAST(SUM(CASE WHEN overall_quality_level = 'POOR' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS poor_quality_percentage,
    
    -- ====================================================================
    -- RISK DISTRIBUTION ANALYSIS
    -- ====================================================================
    -- Shows distribution of columns across risk levels for security planning
    SUM(CASE WHEN pii_risk_assessment = 'CRITICAL_RISK' THEN 1 ELSE 0 END) AS critical_risk_columns,
    SUM(CASE WHEN pii_risk_assessment = 'HIGH_RISK' THEN 1 ELSE 0 END) AS high_risk_columns,
    SUM(CASE WHEN pii_risk_assessment = 'MEDIUM_RISK' THEN 1 ELSE 0 END) AS medium_risk_columns,
    SUM(CASE WHEN pii_risk_assessment = 'LOW_RISK' THEN 1 ELSE 0 END) AS low_risk_columns,
    
    -- Calculate risk percentages
    CAST(SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS high_risk_percentage,
    
    -- ====================================================================
    -- GOVERNANCE PRIORITY DISTRIBUTION
    -- ====================================================================
    -- Shows workload distribution for governance teams
    SUM(CASE WHEN governance_priority = 'URGENT' THEN 1 ELSE 0 END) AS urgent_priority_columns,
    SUM(CASE WHEN governance_priority = 'HIGH' THEN 1 ELSE 0 END) AS high_priority_columns,
    SUM(CASE WHEN governance_priority = 'MEDIUM' THEN 1 ELSE 0 END) AS medium_priority_columns,
    SUM(CASE WHEN governance_priority = 'LOW' THEN 1 ELSE 0 END) AS low_priority_columns,
    
    -- ====================================================================
    -- AVERAGE QUALITY SCORES
    -- ====================================================================
    -- Provides baseline metrics for quality assessment
    CAST(AVG(overall_column_score) AS DECIMAL(5,2)) AS avg_overall_score,
    CAST(AVG(technical_quality_score) AS DECIMAL(5,2)) AS avg_technical_score,
    CAST(AVG(structural_integrity_score) AS DECIMAL(5,2)) AS avg_structural_score,
    CAST(AVG(naming_quality_score) AS DECIMAL(5,2)) AS avg_naming_score,
    CAST(AVG(business_value_score) AS DECIMAL(5,2)) AS avg_business_value_score,
    
    -- ====================================================================
    -- CONSTRAINT COVERAGE ANALYSIS
    -- ====================================================================
    -- Shows how well columns are protected by constraints
    SUM(CASE WHEN is_primary_key = 1 THEN 1 ELSE 0 END) AS primary_key_columns,
    SUM(CASE WHEN is_foreign_key = 1 THEN 1 ELSE 0 END) AS foreign_key_columns,
    SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) AS not_null_columns,
    SUM(CASE WHEN is_indexed = 1 THEN 1 ELSE 0 END) AS indexed_columns,
    
    -- Calculate constraint coverage percentages
    CAST(SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS not_null_coverage_percentage
    
FROM #CompleteColumnAnalysis;

-- ============================================================================
-- SCHEMA-LEVEL BREAKDOWN ANALYSIS
-- ============================================================================
-- Detailed analysis grouped by schema for targeted governance efforts
SELECT 
    '=== SCHEMA-LEVEL ANALYSIS BREAKDOWN ===' AS breakdown_section,
    schema_name,
    
    -- ====================================================================
    -- BASIC COVERAGE METRICS
    -- ====================================================================
    COUNT(*) AS total_columns,                           -- Total columns in this schema
    COUNT(DISTINCT table_name) AS total_tables,          -- Total tables in this schema
    
    -- ====================================================================
    -- QUALITY METRICS BY SCHEMA
    -- ====================================================================
    CAST(AVG(overall_column_score) AS DECIMAL(5,2)) AS avg_quality_score,
    CAST(AVG(technical_quality_score) AS DECIMAL(5,2)) AS avg_technical_score,
    CAST(AVG(structural_integrity_score) AS DECIMAL(5,2)) AS avg_structural_score,
    CAST(AVG(naming_quality_score) AS DECIMAL(5,2)) AS avg_naming_score,
    
    -- Quality level distribution by schema
    SUM(CASE WHEN overall_quality_level = 'EXCELLENT' THEN 1 ELSE 0 END) AS excellent_quality_count,
    SUM(CASE WHEN overall_quality_level = 'GOOD' THEN 1 ELSE 0 END) AS good_quality_count,
    SUM(CASE WHEN overall_quality_level = 'FAIR' THEN 1 ELSE 0 END) AS fair_quality_count,
    SUM(CASE WHEN overall_quality_level = 'POOR' THEN 1 ELSE 0 END) AS poor_quality_count,
    
    -- ====================================================================
    -- RISK METRICS BY SCHEMA
    -- ====================================================================
    SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) AS high_risk_count,
    SUM(CASE WHEN pii_risk_assessment = 'CRITICAL_RISK' THEN 1 ELSE 0 END) AS critical_risk_count,
    SUM(CASE WHEN governance_priority IN ('URGENT', 'HIGH') THEN 1 ELSE 0 END) AS priority_attention_needed,
    
    -- Risk percentage within schema
    CAST(SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS high_risk_percentage,
    
    -- ====================================================================
    -- DATA TYPE DISTRIBUTION BY SCHEMA
    -- ====================================================================
    -- Shows what types of data each schema contains
    SUM(CASE WHEN data_type_category = 'TEXT' THEN 1 ELSE 0 END) AS text_columns,
    SUM(CASE WHEN data_type_category = 'INTEGER' THEN 1 ELSE 0 END) AS integer_columns,
    SUM(CASE WHEN data_type_category = 'NUMERIC' THEN 1 ELSE 0 END) AS numeric_columns,
    SUM(CASE WHEN data_type_category = 'TEMPORAL' THEN 1 ELSE 0 END) AS temporal_columns,
    SUM(CASE WHEN data_type_category = 'BOOLEAN' THEN 1 ELSE 0 END) AS boolean_columns,
    SUM(CASE WHEN data_type_category = 'IDENTIFIER' THEN 1 ELSE 0 END) AS identifier_columns,
    
    -- ====================================================================
    -- CONSTRAINT ANALYSIS BY SCHEMA
    -- ====================================================================
    -- Shows data integrity controls per schema
    SUM(CASE WHEN is_primary_key = 1 THEN 1 ELSE 0 END) AS primary_key_columns,
    SUM(CASE WHEN is_foreign_key = 1 THEN 1 ELSE 0 END) AS foreign_key_columns,
    SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) AS not_null_columns,
    SUM(CASE WHEN is_indexed = 1 THEN 1 ELSE 0 END) AS indexed_columns,
    SUM(CASE WHEN has_default_constraint = 1 THEN 1 ELSE 0 END) AS default_constraint_columns,
    
    -- Constraint coverage percentage for this schema
    CAST(SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS not_null_coverage_pct,
    
    -- ====================================================================
    -- BUSINESS CRITICALITY BY SCHEMA
    -- ====================================================================
    SUM(CASE WHEN business_criticality = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_business_columns,
    SUM(CASE WHEN business_criticality = 'HIGH' THEN 1 ELSE 0 END) AS high_business_columns,
    CAST(AVG(business_value_score) AS DECIMAL(5,2)) AS avg_business_value_score
    
FROM #CompleteColumnAnalysis
GROUP BY schema_name
-- Order by schemas needing most attention first
ORDER BY 
    high_risk_count DESC,                                -- Schemas with most high-risk columns first
    avg_quality_score ASC,                               -- Then by lowest quality scores
    schema_name;                                         -- Finally alphabetical

-- ============================================================================
-- DATA TYPE ANALYSIS DASHBOARD
-- ============================================================================
-- Analysis of data type usage patterns and appropriateness
SELECT 
    '=== DATA TYPE DISTRIBUTION AND QUALITY ANALYSIS ===' AS data_type_section,
    data_type_category,
    
    -- ====================================================================
    -- DATA TYPE USAGE STATISTICS
    -- ====================================================================
    COUNT(*) AS total_columns,                           -- How many columns use this data type category
    COUNT(DISTINCT schema_name) AS schemas_using,        -- How many schemas use this type
    COUNT(DISTINCT schema_name + '.' + table_name) AS tables_using, -- How many tables use this type
    
    -- ====================================================================
    -- QUALITY METRICS BY DATA TYPE
    -- ====================================================================
    CAST(AVG(overall_column_score) AS DECIMAL(5,2)) AS avg_overall_score,
    CAST(AVG(technical_quality_score) AS DECIMAL(5,2)) AS avg_technical_score,
    CAST(AVG(structural_integrity_score) AS DECIMAL(5,2)) AS avg_structural_score,
    CAST(AVG(naming_quality_score) AS DECIMAL(5,2)) AS avg_naming_score,
    
    -- ====================================================================
    -- DATA TYPE APPROPRIATENESS
    -- ====================================================================
    -- Shows how well data types are chosen for their purpose
    CAST(AVG(CASE WHEN technical_quality_level = 'EXCELLENT' THEN 100
                  WHEN technical_quality_level = 'GOOD' THEN 85
                  WHEN technical_quality_level = 'FAIR' THEN 70
                  ELSE 40 END) AS DECIMAL(5,2)) AS avg_appropriateness_score,
    
    -- ====================================================================
    -- RISK ANALYSIS BY DATA TYPE
    -- ====================================================================
    SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) AS high_risk_columns,
    CAST(SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS high_risk_percentage,
    
    -- ====================================================================
    -- CONSTRAINT COVERAGE BY DATA TYPE
    -- ====================================================================
    SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) AS not_null_columns,
    SUM(CASE WHEN is_primary_key = 1 THEN 1 ELSE 0 END) AS primary_key_columns,
    SUM(CASE WHEN is_foreign_key = 1 THEN 1 ELSE 0 END) AS foreign_key_columns,
    SUM(CASE WHEN is_indexed = 1 THEN 1 ELSE 0 END) AS indexed_columns,
    
    -- Constraint coverage percentage for this data type
    CAST(SUM(CASE WHEN is_nullable = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS not_null_coverage_pct
    
FROM #CompleteColumnAnalysis
GROUP BY data_type_category
-- Order by most common data types first, then by risk level
ORDER BY 
    COUNT(*) DESC,                                       -- Most common data types first
    high_risk_percentage DESC;                           -- Then by risk level

-- ============================================================================
-- TOP PRIORITY COLUMNS REQUIRING IMMEDIATE ATTENTION
-- ============================================================================
-- Focused report on columns that need urgent governance attention
-- This is the action-oriented report for data stewards and administrators
SELECT 
    '=== TOP PRIORITY COLUMNS - IMMEDIATE ATTENTION REQUIRED ===' AS priority_section,
    
    -- ====================================================================
    -- COLUMN IDENTIFICATION
    -- ====================================================================
    schema_name,
    table_name,
    column_name,
    data_type_category,
    formatted_data_type,
    ordinal_position,                                    -- Position in table for context
    
    -- ====================================================================
    -- KEY QUALITY AND RISK METRICS
    -- ====================================================================
    overall_column_score,
    overall_quality_level,
    pii_risk_assessment,
    governance_priority,
    business_criticality,
    
    -- ====================================================================
    -- DETAILED RISK INDICATORS
    -- ====================================================================
    potential_pii_indicator,                             -- What type of PII detected
    data_sensitivity_category,                           -- Sensitivity classification
    compliance_risk_level,                               -- Regulatory risk level
    
    -- ====================================================================
    -- TECHNICAL QUALITY INDICATORS
    -- ====================================================================
    technical_quality_level,
    structural_quality_level,
    naming_quality_level,
    
    -- ====================================================================
    -- CONSTRAINT AND STRUCTURE ANALYSIS
    -- ====================================================================
    CASE WHEN is_nullable = 1 THEN 'YES' ELSE 'NO' END AS allows_nulls,
    CASE WHEN is_primary_key = 1 THEN 'YES' ELSE 'NO' END AS is_primary_key,
    CASE WHEN is_foreign_key = 1 THEN 'YES' ELSE 'NO' END AS is_foreign_key,
    CASE WHEN is_indexed = 1 THEN 'YES' ELSE 'NO' END AS has_index,
    CASE WHEN has_default_constraint = 1 THEN 'YES' ELSE 'NO' END AS has_default,
    
    -- ====================================================================
    -- GOVERNANCE RECOMMENDATIONS
    -- ====================================================================
    data_classification,                                 -- Required data classification level
    access_control_recommendation,                       -- Access control requirements
    encryption_recommendation,                           -- Encryption requirements
    masking_recommendation,                              -- Data masking requirements
    monitoring_priority,                                 -- Monitoring requirements
    
    -- ====================================================================
    -- BUSINESS CONTEXT
    -- ====================================================================
    domain_category,                                     -- Business domain
    inferred_purpose,                                    -- Likely business purpose
    steward_assignment,                                  -- Suggested data steward
    
    -- ====================================================================
    -- ACTIONABLE RECOMMENDATIONS
    -- ====================================================================
    immediate_actions,                                   -- Urgent actions needed
    recommended_improvements,                            -- Suggested improvements
    regulatory_scope                                     -- Applicable regulations
    
FROM #CompleteColumnAnalysis

-- ====================================================================
-- FILTERING CRITERIA FOR HIGH PRIORITY ITEMS
-- ====================================================================
-- Only show columns that require governance attention or have quality issues
WHERE 
    governance_priority IN ('URGENT', 'HIGH')           -- High governance priority items
    OR overall_quality_level = 'POOR'                   -- Poor quality columns
    OR pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') -- High-risk PII columns
    OR business_criticality = 'CRITICAL'                -- Business-critical columns
    OR immediate_actions IS NOT NULL                     -- Columns needing immediate action

-- ====================================================================
-- ORDERING FOR MAXIMUM IMPACT
-- ====================================================================
-- Order by priority so most urgent items appear first
ORDER BY 
    -- Primary sort: Governance priority (most urgent first)
    CASE governance_priority 
        WHEN 'URGENT' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3
        ELSE 4 
    END,
    -- Secondary sort: PII risk level (most risky first)
    CASE pii_risk_assessment
        WHEN 'CRITICAL_RISK' THEN 1
        WHEN 'HIGH_RISK' THEN 2
        WHEN 'MEDIUM_RISK' THEN 3
        ELSE 4
    END,
    -- Tertiary sort: Overall quality (worst first)
    overall_column_score ASC,
    -- Final sorts: Schema, table, column for consistency
    schema_name,
    table_name,
    ordinal_position;

-- ============================================================================
-- STEWARD ASSIGNMENT SUMMARY
-- ============================================================================
-- Workload distribution for data steward teams
SELECT 
    '=== DATA STEWARD WORKLOAD DISTRIBUTION ===' AS steward_section,
    steward_assignment,
    
    -- Workload metrics
    COUNT(*) AS total_columns_assigned,
    SUM(CASE WHEN governance_priority IN ('URGENT', 'HIGH') THEN 1 ELSE 0 END) AS high_priority_items,
    SUM(CASE WHEN pii_risk_assessment IN ('CRITICAL_RISK', 'HIGH_RISK') THEN 1 ELSE 0 END) AS high_risk_items,
    SUM(CASE WHEN overall_quality_level = 'POOR' THEN 1 ELSE 0 END) AS poor_quality_items,
    
    -- Schema distribution for each steward type
    COUNT(DISTINCT schema_name) AS schemas_involved,
    COUNT(DISTINCT schema_name + '.' + table_name) AS tables_involved,
    
    -- Average quality scores for steward areas
    CAST(AVG(overall_column_score) AS DECIMAL(5,2)) AS avg_quality_score,
    CAST(AVG(business_value_score) AS DECIMAL(5,2)) AS avg_business_value_score
    
FROM #CompleteColumnAnalysis
GROUP BY steward_assignment
ORDER BY 
    high_priority_items DESC,                            -- Stewards with most urgent work first
    total_columns_assigned DESC;                         -- Then by total workload

PRINT '============================================================================';
PRINT 'COMPLETE ANALYSIS AVAILABLE IN #CompleteColumnAnalysis TABLE';
PRINT 'Use SELECT * FROM #CompleteColumnAnalysis for full details';
PRINT 'Use WHERE clauses to filter by specific criteria (schema, quality, risk, etc.)';
PRINT '============================================================================';