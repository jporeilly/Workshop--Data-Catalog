-- ============================================================================
-- SECTION 2: TABLE-LEVEL ANALYSIS  
-- ============================================================================

-- Create Table-Level Analysis Table
CREATE TABLE #TableLevelAnalysis (
    table_id INT IDENTITY(1,1) PRIMARY KEY,
    schema_name NVARCHAR(128) NOT NULL,
    table_name NVARCHAR(128) NOT NULL,
    full_table_name NVARCHAR(257) NOT NULL,
    
    -- Table Metrics
    column_count INT NOT NULL,
    estimated_rows BIGINT,
    table_size_mb DECIMAL(10,2),
    
    -- Table-Level Trust Score (0-100)
    table_trust_score DECIMAL(5,2) NOT NULL,
    table_trust_level VARCHAR(20) NOT NULL,
    
    -- Table-Level Sensitivity
    table_sensitivity_level VARCHAR(10) NOT NULL,
    table_sensitivity_score INT NOT NULL,
    
    -- Quality Metrics
    completeness_percentage DECIMAL(5,2),
    consistency_score DECIMAL(5,2),
    freshness_score DECIMAL(5,2),
    
    -- Usage Metrics
    total_reads BIGINT,
    total_writes BIGINT,
    days_since_last_access INT,
    usage_frequency VARCHAR(20),
    
    -- PII Analysis
    high_risk_pii_columns INT,
    medium_risk_pii_columns INT,
    low_risk_pii_columns INT,
    pii_risk_assessment VARCHAR(20),
    
    -- Business Context
    business_criticality VARCHAR(20),
    data_classification VARCHAR(50),
    
    -- Governance
    encryption_required BIT DEFAULT 0,
    audit_logging_required BIT DEFAULT 0,
    access_control_level VARCHAR(20),
    governance_recommendation NVARCHAR(500),
    
    analysis_timestamp DATETIME DEFAULT GETDATE()
);

-- Populate Table-Level Analysis
WITH TableMetrics AS (
    SELECT 
        t.object_id,
        s.name AS schema_name,
        t.name AS table_name,
        COUNT(c.column_id) AS column_count,
        COALESCE(p.rows, 0) AS estimated_rows,
        COALESCE(
            (SELECT SUM(a.total_pages) * 8 / 1024.0 
             FROM sys.partitions p2 
             JOIN sys.allocation_units a ON p2.partition_id = a.container_id 
             WHERE p2.object_id = t.object_id AND p2.index_id IN (0,1))
        , 0) AS table_size_mb,
        t.create_date,
        t.modify_date
    FROM sys.schemas s
    JOIN sys.tables t ON s.schema_id = t.schema_id
    JOIN sys.columns c ON t.object_id = c.object_id
    LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    WHERE t.type = 'U'
    GROUP BY t.object_id, s.name, t.name, p.rows, t.create_date, t.modify_date
),

TablePIIAnalysis AS (
    SELECT 
        t.object_id,
        -- High-risk PII columns
        COUNT(CASE 
            WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social%security%' OR 
                 c.name LIKE '%password%' OR c.name LIKE '%secret%' OR
                 c.name LIKE '%credit%card%' OR c.name LIKE '%account%number%' OR
                 c.name LIKE '%license%' OR c.name LIKE '%passport%' OR
                 c.name LIKE '%tax%id%'
            THEN 1 
        END) AS high_pii_columns,
        
        -- Medium-risk PII columns
        COUNT(CASE 
            WHEN c.name LIKE '%first%name%' OR c.name LIKE '%last%name%' OR
                 c.name LIKE '%full%name%' OR c.name LIKE '%display%name%' OR
                 c.name LIKE '%email%' OR c.name LIKE '%phone%' OR
                 c.name LIKE '%address%' OR c.name LIKE '%street%' OR
                 c.name LIKE '%city%' OR c.name LIKE '%zip%' OR c.name LIKE '%postal%' OR
                 c.name LIKE '%birth%' OR c.name LIKE '%dob%' OR
                 c.name LIKE '%salary%' OR c.name LIKE '%wage%' OR c.name LIKE '%income%'
            THEN 1 
        END) AS medium_pii_columns,
        
        -- Low-risk PII columns  
        COUNT(CASE 
            WHEN c.name LIKE '%gender%' OR c.name LIKE '%sex%' OR
                 c.name LIKE '%age%' OR c.name LIKE '%title%' OR
                 c.name LIKE '%nationality%' OR c.name LIKE '%ethnicity%' OR
                 c.name LIKE '%marital%' OR c.name LIKE '%suffix%' OR c.name LIKE '%prefix%'
            THEN 1 
        END) AS low_pii_columns,
        
        COUNT(c.column_id) AS total_columns
        
    FROM sys.tables t
    JOIN sys.columns c ON t.object_id = c.object_id
    WHERE t.type = 'U'
    GROUP BY t.object_id
),

TableUsageStats AS (
    SELECT 
        t.object_id,
        COALESCE(us.user_seeks + us.user_scans + us.user_lookups, 0) AS total_reads,
        COALESCE(us.user_updates, 0) AS total_writes,
        us.last_user_seek,
        us.last_user_scan, 
        us.last_user_lookup,
        CASE
            WHEN us.last_user_seek IS NOT NULL OR us.last_user_scan IS NOT NULL OR us.last_user_lookup IS NOT NULL
            THEN DATEDIFF(day, COALESCE(us.last_user_seek, us.last_user_scan, us.last_user_lookup), GETDATE())
            ELSE NULL
        END AS days_since_access
    FROM sys.tables t
    LEFT JOIN sys.dm_db_index_usage_stats us ON t.object_id = us.object_id AND us.index_id IN (0,1)
    WHERE t.type = 'U'
),

TableQualityMetrics AS (
    SELECT 
        t.object_id,
        -- Completeness: percentage of NOT NULL columns
        CAST(COUNT(CASE WHEN c.is_nullable = 0 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS completeness_pct,
        
        -- Consistency: percentage of columns with constraints or foreign keys
        CAST(
            (COUNT(CASE WHEN c.is_identity = 1 THEN 1 END) + 
             COUNT(CASE WHEN fk.constraint_id IS NOT NULL THEN 1 END) +
             COUNT(CASE WHEN cc.constraint_id IS NOT NULL THEN 1 END)
            ) * 100.0 / COUNT(*) 
        AS DECIMAL(5,2)) AS consistency_score,
        
        -- Freshness: based on table modification date
        CASE 
            WHEN DATEDIFF(day, t.modify_date, GETDATE()) <= 7 THEN 100.0
            WHEN DATEDIFF(day, t.modify_date, GETDATE()) <= 30 THEN 80.0
            WHEN DATEDIFF(day, t.modify_date, GETDATE()) <= 90 THEN 60.0
            WHEN DATEDIFF(day, t.modify_date, GETDATE()) <= 365 THEN 40.0
            WHEN DATEDIFF(day, t.modify_date, GETDATE()) <= 730 THEN 20.0
            ELSE 10.0
        END AS freshness_score
        
    FROM sys.tables t
    JOIN sys.columns c ON t.object_id = c.object_id
    LEFT JOIN sys.foreign_key_columns fkc ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
    LEFT JOIN sys.foreign_keys fk ON fkc.constraint_object_id = fk.object_id
    LEFT JOIN sys.check_constraints cc ON t.object_id = cc.parent_object_id
    GROUP BY t.object_id, t.modify_date
)

INSERT INTO #TableLevelAnalysis (
    schema_name, table_name, full_table_name, column_count, estimated_rows, table_size_mb,
    table_trust_score, table_trust_level, table_sensitivity_level, table_sensitivity_score,
    completeness_percentage, consistency_score, freshness_score,
    total_reads, total_writes, days_since_last_access, usage_frequency,
    high_risk_pii_columns, medium_risk_pii_columns, low_risk_pii_columns, pii_risk_assessment,
    business_criticality, data_classification, encryption_required, audit_logging_required,
    access_control_level, governance_recommendation
)
SELECT 
    tm.schema_name,
    tm.table_name,
    tm.schema_name + '.' + tm.table_name AS full_table_name,
    tm.column_count,
    tm.estimated_rows,
    tm.table_size_mb,
    
    -- TABLE-LEVEL TRUST SCORE CALCULATION (0-100)
    CAST(
        -- Data Quality Component (40%)
        (
            (tqm.completeness_pct * 0.4) +           -- 40% of quality score
            (tqm.consistency_score * 0.35) +         -- 35% of quality score  
            (tqm.freshness_score * 0.25)             -- 25% of quality score
        ) * 0.4 +
        
        -- Usage Patterns Component (30%)
        (CASE
            WHEN tus.total_reads > 10000 AND ISNULL(tus.days_since_access, 999) <= 7 THEN 30.0
            WHEN tus.total_reads > 1000 AND ISNULL(tus.days_since_access, 999) <= 30 THEN 25.0
            WHEN tus.total_reads > 100 AND ISNULL(tus.days_since_access, 999) <= 90 THEN 20.0
            WHEN tus.total_reads > 10 AND ISNULL(tus.days_since_access, 999) <= 180 THEN 15.0
            WHEN tus.total_reads > 0 THEN 10.0
            ELSE 5.0
        END) +
        
        -- Technical Health Component (20%)
        (CASE
            -- Size and structure appropriateness
            WHEN tm.estimated_rows BETWEEN 100 AND 10000000 AND tm.table_size_mb < 5000 THEN 20.0
            WHEN tm.estimated_rows BETWEEN 10 AND 100000000 AND tm.table_size_mb < 10000 THEN 16.0
            WHEN tm.estimated_rows > 0 THEN 12.0
            ELSE 8.0
        END) +
        
        -- Business Context Component (10%)
        (CASE tm.schema_name
            WHEN 'Sales' THEN 10.0      -- Critical business data
            WHEN 'Person' THEN 9.0      -- Customer data importance
            WHEN 'HumanResources' THEN 9.0  -- HR data importance
            WHEN 'Production' THEN 8.0  -- Operational data
            WHEN 'Purchasing' THEN 7.0  -- Procurement data
            ELSE 6.0                     -- Other data
        END)
    AS DECIMAL(5,2)) AS table_trust_score,
    
    -- Table Trust Level Classification
    CASE
        WHEN (
            (
                (tqm.completeness_pct * 0.4) +
                (tqm.consistency_score * 0.35) +
                (tqm.freshness_score * 0.25)
            ) * 0.4 +
            (CASE
                WHEN tus.total_reads > 10000 AND ISNULL(tus.days_since_access, 999) <= 7 THEN 30.0
                WHEN tus.total_reads > 1000 AND ISNULL(tus.days_since_access, 999) <= 30 THEN 25.0
                WHEN tus.total_reads > 100 AND ISNULL(tus.days_since_access, 999) <= 90 THEN 20.0
                WHEN tus.total_reads > 10 AND ISNULL(tus.days_since_access, 999) <= 180 THEN 15.0
                WHEN tus.total_reads > 0 THEN 10.0
                ELSE 5.0
            END) +
            (CASE
                    WHEN tm.estimated_rows BETWEEN 100 AND 10000000 AND tm.table_size_mb < 5000 THEN 20.0
                    WHEN tm.estimated_rows BETWEEN 10 AND 100000000 AND tm.table_size_mb < 10000 THEN 16.0
                    WHEN tm.estimated_rows > 0 THEN 12.0
                    ELSE 8.0
                END) +
                (CASE tm.schema_name
                    WHEN 'Sales' THEN 10.0
                    WHEN 'Person' THEN 9.0
                    WHEN 'HumanResources' THEN 9.0
                    WHEN 'Production' THEN 8.0
                    WHEN 'Purchasing' THEN 7.0
                    ELSE 6.0
                END)
             ) < 50 THEN 1
        
        -- Second priority: High sensitivity + Medium trust
        WHEN (tpia.high_pii_columns > 0 OR (tm.schema_name IN ('Person', 'HumanResources') AND tpia.medium_pii_columns > 1)) THEN 2
        
        -- Third priority: Medium sensitivity + Low trust
        WHEN tpia.medium_pii_columns > 0 THEN 3
        
        ELSE 4
    END,
    tm.table_size_mb DESC,
    tm.estimated_rows DESC;

PRINT 'Table-level analysis completed successfully!';

-- Display Table-Level Results Summary
SELECT
    'TABLE-LEVEL KPI DASHBOARD' AS report_section,
    schema_name,
    table_name,
    
    -- Key Metrics
    column_count,
    FORMAT(estimated_rows, 'N0') AS estimated_rows,
    FORMAT(table_size_mb, 'N2') + ' MB' AS table_size,
    
    -- Trust Score KPIs
    table_trust_score,
    table_trust_level,
    
    -- Sensitivity KPIs
    table_sensitivity_level,
    table_sensitivity_score,
    pii_risk_assessment,
    
    -- Quality KPIs
    FORMAT(completeness_percentage, 'N1') + '%' AS completeness,
    FORMAT(consistency_score, 'N1') + '%' AS consistency,
    FORMAT(freshness_score, 'N1') + '%' AS freshness,
    
    -- Usage KPIs
    FORMAT(total_reads, 'N0') AS total_reads,
    FORMAT(total_writes, 'N0') AS total_writes,
    ISNULL(CAST(days_since_last_access AS VARCHAR), 'Never') + ' days' AS last_access,
    usage_frequency,
    
    -- PII Analysis
    high_risk_pii_columns,
    medium_risk_pii_columns,
    low_risk_pii_columns,
    
    -- Governance
    business_criticality,
    CASE WHEN encryption_required = 1 THEN 'YES' ELSE 'NO' END AS encryption_required,
    CASE WHEN audit_logging_required = 1 THEN 'YES' ELSE 'NO' END AS audit_logging_required,
    access_control_level,
    
    -- Actions
    governance_recommendation

FROM #TableLevelAnalysis
ORDER BY 
    CASE table_sensitivity_level WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
    table_trust_score ASC,
    table_size_mb DESC;