-- ============================================================================
-- MULTI-LEVEL DATA GOVERNANCE ANALYSIS FOR ADVENTUREWORKS2022
-- Schema Level | Table Level | Column Level
-- ============================================================================

USE AdventureWorks2022;

-- ============================================================================
-- SECTION 1: SCHEMA-LEVEL ANALYSIS
-- ============================================================================
-- PURPOSE: Calculate Trust Scores and Sensitivity Classifications at the schema level
-- SCOPE: Provides executive-level KPIs for departmental governance oversight
-- OUTPUT: Schema-level metrics for Pentaho Data Catalog domain management
-- ============================================================================

-- Clean up any existing temp tables to ensure fresh analysis
-- This prevents conflicts if the script is run multiple times in the same session
IF OBJECT_ID('tempdb..#SchemaLevelAnalysis') IS NOT NULL DROP TABLE #SchemaLevelAnalysis;
IF OBJECT_ID('tempdb..#TableLevelAnalysis') IS NOT NULL DROP TABLE #TableLevelAnalysis;
IF OBJECT_ID('tempdb..#ColumnLevelAnalysis') IS NOT NULL DROP TABLE #ColumnLevelAnalysis;

PRINT 'Starting Multi-Level Data Governance Analysis...';
PRINT 'Analysis timestamp: ' + CAST(GETDATE() AS VARCHAR(50));

-- ============================================================================
-- SCHEMA-LEVEL RESULTS TABLE DEFINITION
-- ============================================================================
-- This table stores comprehensive schema-level KPIs that provide executive oversight
-- and departmental governance metrics suitable for Pentaho Data Catalog integration

CREATE TABLE #SchemaLevelAnalysis (
    -- ========================================================================
    -- PRIMARY KEY AND IDENTIFICATION
    -- ========================================================================
    schema_id INT IDENTITY(1,1) PRIMARY KEY,        -- Unique identifier for each schema record
    schema_name NVARCHAR(128) NOT NULL,             -- Database schema name (Person, Sales, etc.)
    
    -- ========================================================================
    -- FOUNDATIONAL SCHEMA METRICS
    -- ========================================================================
    -- These metrics provide the basic scale and scope of each schema
    total_tables INT NOT NULL,                      -- Count of user tables in this schema
    total_columns INT NOT NULL,                     -- Count of all columns across schema tables
    total_estimated_rows BIGINT,                    -- Sum of estimated rows across all tables
    total_size_mb DECIMAL(12,2),                    -- Total storage consumption in megabytes
    
    -- ========================================================================
    -- SCHEMA-LEVEL TRUST SCORE (0-100 Scale)
    -- ========================================================================
    -- Trust Score Components:
    -- • Data Volume & Structure Health (30%): Scale and organization quality
    -- • Usage Patterns (40%): How actively the schema is accessed
    -- • Business Context & Organization (20%): Clarity of business purpose
    -- • Data Governance Readiness (10%): Documentation and naming standards
    schema_trust_score DECIMAL(5,2) NOT NULL,       -- Calculated trust score (0-100)
    schema_trust_level VARCHAR(20) NOT NULL,        -- Categorical trust level (VERY_HIGH, HIGH, MEDIUM, LOW, VERY_LOW)
    
    -- ========================================================================
    -- SCHEMA-LEVEL SENSITIVITY CLASSIFICATION
    -- ========================================================================
    -- Sensitivity levels determined by:
    -- • PII content density and risk level
    -- • Business function criticality (HR, Sales, etc.)
    -- • Regulatory compliance requirements
    schema_sensitivity_level VARCHAR(10) NOT NULL,  -- HIGH/MEDIUM/LOW classification
    schema_sensitivity_score INT NOT NULL,          -- Numerical sensitivity score (0-100)
    
    -- ========================================================================
    -- DATA QUALITY AND RISK METRICS
    -- ========================================================================
    -- These metrics help assess data reliability and governance needs
    avg_completeness_pct DECIMAL(5,2),              -- Average completeness across schema tables
    pii_density_pct DECIMAL(5,2),                   -- Percentage of columns containing PII
    high_risk_table_count INT,                      -- Count of tables with critical PII exposure
    
    -- ========================================================================
    -- BUSINESS CONTEXT FOR GOVERNANCE
    -- ========================================================================
    -- Maps technical schemas to business functions for stakeholder communication
    business_domain VARCHAR(100),                   -- Business function description
    data_owner_department VARCHAR(50),              -- Responsible department/team
    governance_priority VARCHAR(20),                -- Priority level for governance attention
    
    -- ========================================================================
    -- COMPLIANCE AND REGULATORY REQUIREMENTS
    -- ========================================================================
    -- Helps legal and compliance teams understand regulatory exposure
    regulatory_frameworks NVARCHAR(500),            -- Applicable regulations (GDPR, CCPA, etc.)
    encryption_required_tables INT,                 -- Count of tables requiring encryption
    
    -- ========================================================================
    -- AUDIT AND TRACKING
    -- ========================================================================
    analysis_timestamp DATETIME DEFAULT GETDATE()  -- When this analysis was performed
);

-- ============================================================================
-- SCHEMA-LEVEL DATA COLLECTION AND CALCULATION
-- ============================================================================
-- This section uses Common Table Expressions (CTEs) to gather and calculate
-- the various components needed for schema-level trust scores and sensitivity
-- ============================================================================

-- CTE 1: FOUNDATIONAL SCHEMA METRICS
-- ============================================================================
-- Collects basic statistical information about each schema's structure and size
-- This forms the foundation for trust score calculations
WITH SchemaMetrics AS (
    SELECT 
        s.schema_id,                                 -- Schema system identifier
        s.name AS schema_name,                       -- Human-readable schema name
        
        -- STRUCTURAL METRICS: Count tables and columns for scope assessment
        COUNT(DISTINCT t.object_id) AS table_count, -- Number of user tables (excludes views, system tables)
        COUNT(c.column_id) AS column_count,         -- Total columns across all tables in schema
        
        -- DATA VOLUME METRICS: Assess scale and business importance
        COALESCE(SUM(p.rows), 0) AS total_rows,     -- Sum of estimated rows across all tables
        
        -- STORAGE METRICS: Calculate total space consumption
        -- This complex subquery calculates actual storage used by summing allocation pages
        COALESCE(SUM(
            (SELECT SUM(a.total_pages) * 8 / 1024.0 -- Convert 8KB pages to MB
             FROM sys.partitions p2 
             JOIN sys.allocation_units a ON p2.partition_id = a.container_id 
             WHERE p2.object_id = t.object_id         -- Match specific table
             AND p2.index_id IN (0,1))                -- Include heap (0) and clustered index (1) data
        ), 0) AS total_size_mb
        
    FROM sys.schemas s                               -- All database schemas
    LEFT JOIN sys.tables t ON s.schema_id = t.schema_id AND t.type = 'U'  -- Only user tables
    LEFT JOIN sys.columns c ON t.object_id = c.object_id                  -- All columns in user tables
    LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)  -- Row count estimates
    GROUP BY s.schema_id, s.name                     -- Group by schema for aggregation
),

-- CTE 2: PII DETECTION AND RISK ASSESSMENT
-- ============================================================================
-- Analyzes column names to detect potential Personally Identifiable Information (PII)
-- Uses pattern matching to classify PII risk levels for compliance assessment
SchemaPIIAnalysis AS (
    SELECT 
        s.schema_id,
        
        -- HIGH-RISK PII DETECTION
        -- These patterns indicate the most sensitive data requiring strongest protection
        COUNT(CASE 
            WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social%' OR     -- Social Security Numbers
                 c.name LIKE '%password%' OR c.name LIKE '%credit%' OR -- Authentication & Financial
                 c.name LIKE '%account%number%' OR c.name LIKE '%license%' OR  -- Account Numbers & IDs
                 c.name LIKE '%passport%'                             -- Government IDs
            THEN 1 
        END) AS high_pii_columns,
        
        -- MEDIUM-RISK PII DETECTION  
        -- Personal identifiers that require significant protection but are less critical than high-risk
        COUNT(CASE 
            WHEN c.name LIKE '%first%name%' OR c.name LIKE '%last%name%' OR  -- Personal names
                 c.name LIKE '%email%' OR c.name LIKE '%phone%' OR           -- Contact information
                 c.name LIKE '%address%' OR c.name LIKE '%birth%' OR         -- Location & demographic
                 c.name LIKE '%salary%' OR c.name LIKE '%wage%'              -- Financial compensation
            THEN 1 
        END) AS medium_pii_columns,
        
        -- LOW-RISK PII DETECTION
        -- Demographic information that may have privacy implications but lower risk
        COUNT(CASE 
            WHEN c.name LIKE '%gender%' OR c.name LIKE '%age%' OR      -- Basic demographics
                 c.name LIKE '%title%' OR c.name LIKE '%nationality%'  -- Professional/cultural info
            THEN 1 
        END) AS low_pii_columns,
        
        -- TOTAL COLUMN COUNT for calculating PII density percentages
        COUNT(c.column_id) AS total_columns
        
    FROM sys.schemas s
    LEFT JOIN sys.tables t ON s.schema_id = t.schema_id AND t.type = 'U'  -- Only user tables
    LEFT JOIN sys.columns c ON t.object_id = c.object_id                  -- All columns
    GROUP BY s.schema_id
),

-- CTE 3: USAGE PATTERN ANALYSIS
-- ============================================================================
-- Analyzes how actively each schema is being used based on SQL Server statistics
-- Usage patterns are a key indicator of data trust and business value
SchemaUsagePatterns AS (
    SELECT 
        s.schema_id,
        
        -- AVERAGE USAGE CALCULATION
        -- Combines seeks (index lookups), scans (table scans), and lookups (key lookups)
        AVG(COALESCE(us.user_seeks + us.user_scans + us.user_lookups, 0)) AS avg_usage,
        
        -- RECENT ACCESS ANALYSIS
        -- Counts tables that have been accessed within the last 30 days
        -- This indicates active vs. dormant data
        COUNT(CASE 
            WHEN DATEDIFF(day, COALESCE(us.last_user_seek, us.last_user_scan, us.last_user_lookup, '1900-01-01'), GETDATE()) <= 30 
            THEN 1 
        END) AS recently_accessed_tables,
        
        -- TOTAL TABLE COUNT for calculating percentage of active tables
        COUNT(t.object_id) AS total_tables
        
    FROM sys.schemas s
    LEFT JOIN sys.tables t ON s.schema_id = t.schema_id AND t.type = 'U'  -- Only user tables
    -- LEFT JOIN to usage stats allows for tables with no recorded usage (new or unused tables)
    LEFT JOIN sys.dm_db_index_usage_stats us ON t.object_id = us.object_id AND us.index_id IN (0,1)
    GROUP BY s.schema_id
)

-- ============================================================================
-- MAIN INSERT STATEMENT: SCHEMA-LEVEL KPI CALCULATION
-- ============================================================================
-- This section combines all the CTE data to calculate final schema-level KPIs
-- The calculations use weighted algorithms to produce meaningful business metrics
INSERT INTO #SchemaLevelAnalysis (
    schema_name, total_tables, total_columns, total_estimated_rows, total_size_mb,
    schema_trust_score, schema_trust_level, schema_sensitivity_level, schema_sensitivity_score,
    avg_completeness_pct, pii_density_pct, high_risk_table_count,
    business_domain, data_owner_department, governance_priority,
    regulatory_frameworks, encryption_required_tables
)
SELECT 
    sm.schema_name,                                  -- Schema identifier for reporting
    sm.table_count AS total_tables,                 -- Count of user tables in schema
    sm.column_count AS total_columns,               -- Total columns across all schema tables
    sm.total_rows AS total_estimated_rows,          -- Sum of estimated rows across tables
    sm.total_size_mb,                               -- Total storage consumption in MB
    
    -- ========================================================================
    -- SCHEMA-LEVEL TRUST SCORE CALCULATION (0-100 Scale)
    -- ========================================================================
    -- Trust Score Algorithm combines four weighted components:
    -- 1. Data Volume & Structure Health (30%): Measures schema scale and organization
    -- 2. Usage Patterns (40%): Indicates business value through access frequency  
    -- 3. Business Context & Organization (20%): Assesses clarity of business purpose
    -- 4. Data Governance Readiness (10%): Evaluates documentation and standards
    CAST(
        -- COMPONENT 1: DATA VOLUME & STRUCTURE HEALTH (30% of total score)
        -- Larger, well-populated schemas typically indicate higher business value
        -- and organizational investment, contributing to trustworthiness
        (CASE
            WHEN sm.table_count > 10 AND sm.total_rows > 50000 THEN 30.0    -- Large, well-populated schema
            WHEN sm.table_count > 5 AND sm.total_rows > 10000 THEN 25.0     -- Medium-sized operational schema
            WHEN sm.table_count > 2 AND sm.total_rows > 1000 THEN 20.0      -- Small but active schema
            WHEN sm.table_count > 0 THEN 15.0                               -- Minimal schema with some data
            ELSE 5.0                                                         -- Empty or nearly empty schema
        END) +
        
        -- COMPONENT 2: USAGE PATTERNS (40% of total score)
        -- High usage frequency and recent access indicate active business reliance
        -- This is the highest weighted component as usage reflects real business value
        (CASE
            -- Excellent usage: High frequency + all tables recently accessed
            WHEN sup.avg_usage > 1000 AND sup.recently_accessed_tables = sup.total_tables THEN 40.0
            -- Good usage: Regular access + most tables active
            WHEN sup.avg_usage > 100 AND sup.recently_accessed_tables >= sup.total_tables * 0.7 THEN 30.0
            -- Fair usage: Some access + half the tables active  
            WHEN sup.avg_usage > 10 AND sup.recently_accessed_tables >= sup.total_tables * 0.5 THEN 20.0
            -- Low usage: Minimal access but some activity
            WHEN sup.recently_accessed_tables > 0 THEN 15.0
            -- No usage: No recorded access (potential dormant data)
            ELSE 5.0
        END) +
        
        -- COMPONENT 3: BUSINESS CONTEXT & ORGANIZATION (20% of total score)  
        -- Well-defined business domains indicate mature data organization
        -- and clear data ownership, improving trust and governance
        (CASE sm.schema_name
            WHEN 'Person' THEN 18.0         -- Customer data: well-organized, critical business function
            WHEN 'Sales' THEN 20.0          -- Revenue operations: highest business priority
            WHEN 'Production' THEN 16.0     -- Manufacturing: clear operational purpose
            WHEN 'HumanResources' THEN 18.0 -- HR data: well-defined domain with clear ownership
            WHEN 'Purchasing' THEN 15.0     -- Procurement: defined business function
            ELSE 10.0                        -- Other schemas: unclear business purpose
        END) +
        
        -- COMPONENT 4: DATA GOVERNANCE READINESS (10% of total score)
        -- Schemas with clear business purpose and established patterns
        -- are more ready for governance frameworks and policy application
        (CASE
            -- High readiness: Known business-critical schemas
            WHEN sm.schema_name IN ('Person', 'Sales', 'HumanResources') THEN 10.0
            -- Medium readiness: Multiple tables suggest established use
            WHEN sm.table_count > 5 THEN 8.0
            -- Basic readiness: Some structure exists
            WHEN sm.table_count > 0 THEN 6.0
            -- Low readiness: Minimal or unclear structure
            ELSE 2.0
        END)
    AS DECIMAL(5,2)) AS schema_trust_score,
    
    -- ========================================================================
    -- SCHEMA TRUST LEVEL CLASSIFICATION
    -- ========================================================================
    -- Converts numerical trust scores into categorical levels for easier interpretation
    -- These categories help executives and managers quickly understand schema reliability
    CASE
        WHEN (
            -- Recalculate the same trust score for comparison against thresholds
            -- This ensures consistent classification based on the calculated score
            (CASE
                WHEN sm.table_count > 10 AND sm.total_rows > 50000 THEN 30.0
                WHEN sm.table_count > 5 AND sm.total_rows > 10000 THEN 25.0
                WHEN sm.table_count > 2 AND sm.total_rows > 1000 THEN 20.0
                WHEN sm.table_count > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE
                WHEN sup.avg_usage > 1000 AND sup.recently_accessed_tables = sup.total_tables THEN 40.0
                WHEN sup.avg_usage > 100 AND sup.recently_accessed_tables >= sup.total_tables * 0.7 THEN 30.0
                WHEN sup.avg_usage > 10 AND sup.recently_accessed_tables >= sup.total_tables * 0.5 THEN 20.0
                WHEN sup.recently_accessed_tables > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE sm.schema_name
                WHEN 'Person' THEN 18.0
                WHEN 'Sales' THEN 20.0
                WHEN 'Production' THEN 16.0
                WHEN 'HumanResources' THEN 18.0
                WHEN 'Purchasing' THEN 15.0
                ELSE 10.0
            END) +
            (CASE
                WHEN sm.schema_name IN ('Person', 'Sales', 'HumanResources') THEN 10.0
                WHEN sm.table_count > 5 THEN 8.0
                WHEN sm.table_count > 0 THEN 6.0
                ELSE 2.0
            END)
        ) >= 80 THEN 'VERY_HIGH'        -- 80-100: Excellent reliability, high business value
        WHEN (
            (CASE
                WHEN sm.table_count > 10 AND sm.total_rows > 50000 THEN 30.0
                WHEN sm.table_count > 5 AND sm.total_rows > 10000 THEN 25.0
                WHEN sm.table_count > 2 AND sm.total_rows > 1000 THEN 20.0
                WHEN sm.table_count > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE
                WHEN sup.avg_usage > 1000 AND sup.recently_accessed_tables = sup.total_tables THEN 40.0
                WHEN sup.avg_usage > 100 AND sup.recently_accessed_tables >= sup.total_tables * 0.7 THEN 30.0
                WHEN sup.avg_usage > 10 AND sup.recently_accessed_tables >= sup.total_tables * 0.5 THEN 20.0
                WHEN sup.recently_accessed_tables > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE sm.schema_name
                WHEN 'Person' THEN 18.0
                WHEN 'Sales' THEN 20.0
                WHEN 'Production' THEN 16.0
                WHEN 'HumanResources' THEN 18.0
                WHEN 'Purchasing' THEN 15.0
                ELSE 10.0
            END) +
            (CASE
                WHEN sm.schema_name IN ('Person', 'Sales', 'HumanResources') THEN 10.0
                WHEN sm.table_count > 5 THEN 8.0
                WHEN sm.table_count > 0 THEN 6.0
                ELSE 2.0
            END)
        ) >= 65 THEN 'HIGH'             -- 65-79: Good reliability, suitable for business use
        WHEN (
            (CASE
                WHEN sm.table_count > 10 AND sm.total_rows > 50000 THEN 30.0
                WHEN sm.table_count > 5 AND sm.total_rows > 10000 THEN 25.0
                WHEN sm.table_count > 2 AND sm.total_rows > 1000 THEN 20.0
                WHEN sm.table_count > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE
                WHEN sup.avg_usage > 1000 AND sup.recently_accessed_tables = sup.total_tables THEN 40.0
                WHEN sup.avg_usage > 100 AND sup.recently_accessed_tables >= sup.total_tables * 0.7 THEN 30.0
                WHEN sup.avg_usage > 10 AND sup.recently_accessed_tables >= sup.total_tables * 0.5 THEN 20.0
                WHEN sup.recently_accessed_tables > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE sm.schema_name
                WHEN 'Person' THEN 18.0
                WHEN 'Sales' THEN 20.0
                WHEN 'Production' THEN 16.0
                WHEN 'HumanResources' THEN 18.0
                WHEN 'Purchasing' THEN 15.0
                ELSE 10.0
            END) +
            (CASE
                WHEN sm.schema_name IN ('Person', 'Sales', 'HumanResources') THEN 10.0
                WHEN sm.table_count > 5 THEN 8.0
                WHEN sm.table_count > 0 THEN 6.0
                ELSE 2.0
            END)
        ) >= 50 THEN 'MEDIUM'           -- 50-64: Moderate reliability, may need improvement
        WHEN (
            (CASE
                WHEN sm.table_count > 10 AND sm.total_rows > 50000 THEN 30.0
                WHEN sm.table_count > 5 AND sm.total_rows > 10000 THEN 25.0
                WHEN sm.table_count > 2 AND sm.total_rows > 1000 THEN 20.0
                WHEN sm.table_count > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE
                WHEN sup.avg_usage > 1000 AND sup.recently_accessed_tables = sup.total_tables THEN 40.0
                WHEN sup.avg_usage > 100 AND sup.recently_accessed_tables >= sup.total_tables * 0.7 THEN 30.0
                WHEN sup.avg_usage > 10 AND sup.recently_accessed_tables >= sup.total_tables * 0.5 THEN 20.0
                WHEN sup.recently_accessed_tables > 0 THEN 15.0
                ELSE 5.0
            END) +
            (CASE sm.schema_name
                WHEN 'Person' THEN 18.0
                WHEN 'Sales' THEN 20.0
                WHEN 'Production' THEN 16.0
                WHEN 'HumanResources' THEN 18.0
                WHEN 'Purchasing' THEN 15.0
                ELSE 10.0
            END) +
            (CASE
                WHEN sm.schema_name IN ('Person', 'Sales', 'HumanResources') THEN 10.0
                WHEN sm.table_count > 5 THEN 8.0
                WHEN sm.table_count > 0 THEN 6.0
                ELSE 2.0
            END)
        ) >= 35 THEN 'LOW'              -- 35-49: Low reliability, significant improvement needed
        ELSE 'VERY_LOW'                 -- 0-34: Very poor reliability, major issues exist
    END AS schema_trust_level,
    
    -- ========================================================================
    -- SCHEMA-LEVEL SENSITIVITY CLASSIFICATION (HIGH/MEDIUM/LOW)
    -- ========================================================================
    -- Determines data sensitivity based on PII content, business function, and regulatory risk
    -- This classification drives security controls, access policies, and compliance requirements
    CASE
        -- HIGH SENSITIVITY: Contains critical PII or operates in highly regulated business areas
        -- Triggers strongest security controls and compliance monitoring
        WHEN spa.high_pii_columns > 0 OR                                    -- Any government IDs, financial data, authentication
             sm.schema_name IN ('Person', 'HumanResources') OR              -- Known sensitive business domains
             (spa.medium_pii_columns > 0 AND spa.medium_pii_columns * 100.0 / NULLIF(spa.total_columns, 0) > 20) -- High PII density (>20%)
        THEN 'HIGH'
        
        -- MEDIUM SENSITIVITY: Contains some PII or handles business-critical operations
        -- Requires standard security controls and regular governance oversight  
        WHEN spa.medium_pii_columns > 0 OR                                  -- Any personal identifiers detected
             sm.schema_name IN ('Sales', 'Production') AND sm.total_rows > 10000 OR  -- Large business-critical datasets
             sm.total_rows > 50000                                          -- Large datasets regardless of domain
        THEN 'MEDIUM'
        
        -- LOW SENSITIVITY: Reference data, system schemas, or minimal business impact
        -- Standard governance controls sufficient
        ELSE 'LOW'
    END AS schema_sensitivity_level,
    
    -- Schema Sensitivity Score (0-100)
    CASE
        -- HIGH sensitivity scoring (70-100)
        WHEN spa.high_pii_columns > 0 THEN 85 + LEAST(spa.high_pii_columns * 3, 15)
        WHEN sm.schema_name = 'Person' THEN 80 + (spa.medium_pii_columns * 2)
        WHEN sm.schema_name = 'HumanResources' THEN 78 + (spa.medium_pii_columns * 2)
        WHEN (spa.medium_pii_columns * 100.0 / NULLIF(spa.total_columns, 0)) > 20 THEN 72 + (spa.medium_pii_columns)
        
        -- MEDIUM sensitivity scoring (40-69)
        WHEN spa.medium_pii_columns > 0 THEN 45 + (spa.medium_pii_columns * 3) + (spa.low_pii_columns)
        WHEN sm.schema_name = 'Sales' AND sm.total_rows > 10000 THEN 55
        WHEN sm.schema_name = 'Sales' THEN 48
        WHEN sm.schema_name IN ('Production', 'Purchasing') AND sm.total_rows > 10000 THEN 50
        WHEN sm.schema_name IN ('Production', 'Purchasing') THEN 42
        WHEN sm.total_rows > 50000 THEN 45
        
        -- LOW sensitivity scoring (5-39)
        WHEN spa.low_pii_columns > 0 THEN 25 + (spa.low_pii_columns * 2)
        WHEN sm.total_rows > 1000 THEN 20
        WHEN sm.table_count > 0 THEN 15
        ELSE 5
    END AS schema_sensitivity_score,
    
    -- Quality Metrics
    CAST(
        CASE 
            WHEN sm.column_count > 0 
            THEN (
                SELECT AVG(CAST(
                    COUNT(CASE WHEN c.is_nullable = 0 THEN 1 END) * 100.0 / COUNT(*)
                AS DECIMAL(5,2)))
                FROM sys.tables t2
                JOIN sys.columns c ON t2.object_id = c.object_id
                WHERE t2.schema_id = sm.schema_id AND t2.type = 'U'
                GROUP BY t2.object_id
            )
            ELSE 0 
        END
    AS DECIMAL(5,2)) AS avg_completeness_pct,
    
    -- PII Density Percentage
    CAST(
        CASE 
            WHEN spa.total_columns > 0 
            THEN (spa.high_pii_columns + spa.medium_pii_columns + spa.low_pii_columns) * 100.0 / spa.total_columns
            ELSE 0 
        END
    AS DECIMAL(5,2)) AS pii_density_pct,
    
    -- High Risk Table Count (tables with high PII + large data volume)
    (SELECT COUNT(*)
     FROM sys.tables t3
     WHERE t3.schema_id = sm.schema_id AND t3.type = 'U'
     AND EXISTS (
         SELECT 1 FROM sys.columns c3 
         WHERE c3.object_id = t3.object_id 
         AND (c3.name LIKE '%ssn%' OR c3.name LIKE '%password%' OR c3.name LIKE '%credit%')
     )
    ) AS high_risk_table_count,
    
    -- Business Context
    CASE sm.schema_name
        WHEN 'Person' THEN 'Customer & Identity Management'
        WHEN 'Sales' THEN 'Revenue Operations & Customer Relations'
        WHEN 'Production' THEN 'Manufacturing & Inventory Operations'
        WHEN 'HumanResources' THEN 'Employee Lifecycle Management'
        WHEN 'Purchasing' THEN 'Vendor Relations & Procurement'
        ELSE 'System & Reference Data'
    END AS business_domain,
    
    CASE sm.schema_name
        WHEN 'Person' THEN 'Customer Service'
        WHEN 'Sales' THEN 'Sales Operations'
        WHEN 'HumanResources' THEN 'Human Resources'
        WHEN 'Production' THEN 'Operations'
        WHEN 'Purchasing' THEN 'Procurement'
        ELSE 'IT Administration'
    END AS data_owner_department,
    
    -- Governance Priority
    CASE
        WHEN spa.high_pii_columns > 0 OR sm.schema_name IN ('Person', 'HumanResources') THEN 'CRITICAL'
        WHEN spa.medium_pii_columns > 0 OR sm.schema_name = 'Sales' THEN 'HIGH'
        WHEN sm.total_rows > 10000 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS governance_priority,
    
    -- Regulatory Frameworks
    CASE
        WHEN spa.high_pii_columns > 0 OR sm.schema_name = 'Person'
        THEN 'GDPR, CCPA, PIPEDA, PII Protection Laws, Data Breach Notification'
        WHEN sm.schema_name = 'HumanResources'
        THEN 'GDPR, CCPA, Employment Law, Wage & Hour Regulations'
        WHEN sm.schema_name = 'Sales' AND spa.medium_pii_columns > 0
        THEN 'GDPR, CCPA, SOX, Financial Privacy Rules'
        WHEN sm.schema_name IN ('Production', 'Purchasing')
        THEN 'SOX, Industry Safety Regulations, Supply Chain Compliance'
        ELSE 'Standard Corporate Data Governance'
    END AS regulatory_frameworks,
    
    -- Encryption Required Tables Count
    (SELECT COUNT(*)
     FROM sys.tables t4
     WHERE t4.schema_id = sm.schema_id AND t4.type = 'U'
     AND (
         sm.schema_name IN ('Person', 'HumanResources') OR
         EXISTS (
             SELECT 1 FROM sys.columns c4 
             WHERE c4.object_id = t4.object_id 
             AND (c4.name LIKE '%ssn%' OR c4.name LIKE '%password%' OR c4.name LIKE '%credit%')
         )
     )
    ) AS encryption_required_tables

FROM SchemaMetrics sm
LEFT JOIN SchemaPIIAnalysis spa ON sm.schema_id = spa.schema_id
LEFT JOIN SchemaUsagePatterns sup ON sm.schema_id = sup.schema_id
WHERE sm.table_count > 0  -- Only include schemas with user tables
ORDER BY schema_trust_score DESC, schema_sensitivity_score DESC;

PRINT 'Schema-level analysis completed successfully!';

-- Display Schema-Level Results
SELECT
    'SCHEMA-LEVEL KPI DASHBOARD' AS report_section,
    schema_name,
    
    -- Key Metrics
    total_tables,
    total_columns,
    FORMAT(total_estimated_rows, 'N0') AS total_estimated_rows,
    FORMAT(total_size_mb, 'N2') + ' MB' AS total_size,
    
    -- Trust Score KPIs
    schema_trust_score,
    schema_trust_level,
    
    -- Sensitivity KPIs  
    schema_sensitivity_level,
    schema_sensitivity_score,
    
    -- Quality KPIs
    FORMAT(avg_completeness_pct, 'N1') + '%' AS avg_completeness,
    FORMAT(pii_density_pct, 'N1') + '%' AS pii_density,
    
    -- Business Context
    business_domain,
    data_owner_department,
    governance_priority,
    
    -- Risk Indicators
    high_risk_table_count,
    encryption_required_tables,
    
    -- Compliance
    regulatory_frameworks

FROM #SchemaLevelAnalysis
ORDER BY schema_trust_score DESC, schema_sensitivity_score DESC;