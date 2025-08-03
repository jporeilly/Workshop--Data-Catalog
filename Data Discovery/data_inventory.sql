-- Connect to AdventureWorks2022 database
USE AdventureWorks2022;

-- Verify connection and database version
SELECT
    @@SERVERNAME AS server_name,
    DB_NAME() AS database_name,
    @@VERSION AS sql_version,
    GETDATE() AS [current_time];
    
-- Create temporary tables for workshop results
CREATE TABLE #DataInventory (
    schema_name NVARCHAR(128),
    table_name NVARCHAR(128),
    column_count INT,
    required_columns INT,
    estimated_rows BIGINT,
    size_mb DECIMAL(10,2),
    last_modified DATETIME,
    business_purpose NVARCHAR(500),
    data_sensitivity NVARCHAR(50),
    -- Additional governance fields
    data_owner NVARCHAR(100),
    data_steward NVARCHAR(100),
    retention_period INT,
    compliance_tags NVARCHAR(200)
);