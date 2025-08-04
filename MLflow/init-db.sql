-- ===================================================================================
-- PostgreSQL Database Initialization Script for MLflow with Pentaho Data Catalog
-- 
-- This script is automatically executed when the PostgreSQL container starts
-- for the first time. It prepares the database for MLflow usage including:
-- - Model Registry support (required for Pentaho Data Catalog integration)
-- - Proper user permissions for all MLflow operations
-- - Database extensions needed for advanced features
-- 
-- Execution Context:
-- - Runs as PostgreSQL superuser (postgres) during container initialization
-- - Executed via Docker volume mount: ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
-- - Only runs on first container startup (when database is empty)
-- - Must complete successfully for container to start
-- ===================================================================================

-- ===================================================================================
-- PostgreSQL Extensions Setup
-- Install necessary extensions for MLflow advanced functionality
-- ===================================================================================

-- UUID Extension for unique identifier generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Purpose: Provides functions for generating UUIDs (Universally Unique Identifiers)
-- Used by: MLflow for generating unique IDs for experiments, runs, and models
-- Functions provided:
--   - uuid_generate_v1(): MAC address-based UUIDs
--   - uuid_generate_v4(): Random UUIDs (most commonly used by MLflow)
-- Benefits:
--   - Ensures globally unique identifiers across distributed systems
--   - Required for Model Registry unique model version IDs
--   - Prevents ID collisions in multi-instance deployments
-- Note: IF NOT EXISTS prevents errors if extension is already installed

-- ===================================================================================
-- MLflow Table Creation Strategy
-- MLflow will automatically create its own tables, but we prepare the environment
-- ===================================================================================

-- MLflow Automatic Table Creation:
-- When MLflow server starts, it automatically creates these tables:
--
-- Experiment Tracking Tables:
-- - experiments: Experiment metadata and configuration  
-- - runs: Individual experiment runs with start/end times
-- - metrics: Numeric metrics logged during runs (accuracy, loss, etc.)
-- - params: Parameters/hyperparameters for runs (learning_rate, epochs, etc.)
-- - tags: Key-value metadata tags for experiments and runs
-- - latest_metrics: Optimized view of most recent metric values
--
-- Model Registry Tables (REQUIRED for Pentaho Data Catalog):
-- - registered_models: Model registry entries with names and descriptions
-- - model_versions: Specific versions of registered models
-- - model_version_tags: Tags associated with model versions  
-- - registered_model_tags: Tags associated with registered models
-- - model_version_aliases: Aliases for model versions (e.g., "champion", "challenger")
--
-- Additional Tables:
-- - experiments_tags: Tags associated with experiments
-- - dataset_inputs: Dataset inputs for runs (data lineage)
-- - input_tags: Tags for dataset inputs
-- - trace_info: Tracing information for MLflow deployments
-- - trace_data: Detailed trace data
--
-- Database Migration:
-- MLflow uses Alembic for database schema migrations
-- Schema automatically upgrades when MLflow server starts
-- Migrations are logged during container startup

-- ===================================================================================
-- Database-Level Permissions  
-- Grant comprehensive access to the MLflow database for the mlflow user
-- ===================================================================================

-- Full database access for MLflow operations
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
-- Permissions granted:
-- - CONNECT: Connect to the database
-- - CREATE: Create new schemas and objects
-- - TEMPORARY: Create temporary tables and objects
-- - ALL: Complete database-level access
-- 
-- Why necessary:
-- - MLflow needs to create/modify tables during startup
-- - Database migrations require DDL (Data Definition Language) privileges
-- - Experiment logging requires DML (Data Manipulation Language) privileges
-- - Model Registry operations need full CRUD access

-- ===================================================================================
-- Schema-Level Permissions
-- Grant access to the public schema where MLflow creates its tables
-- ===================================================================================

-- Public schema access for MLflow user
GRANT ALL PRIVILEGES ON SCHEMA public TO mlflow;
-- Permissions granted:
-- - USAGE: Access objects within the schema
-- - CREATE: Create new objects in the schema
-- - ALL: Complete schema-level access
--
-- Public schema context:
-- - Default schema in PostgreSQL databases
-- - MLflow creates all tables in public schema by default
-- - Required for table creation and access

-- ===================================================================================
-- Table-Level Permissions (Existing Objects)
-- Grant access to any tables that already exist in the public schema
-- ===================================================================================

-- Access to all existing tables in public schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mlflow;
-- Permissions granted:
-- - SELECT: Read data from tables
-- - INSERT: Add new rows to tables  
-- - UPDATE: Modify existing rows in tables
-- - DELETE: Remove rows from tables
-- - TRUNCATE: Remove all rows from tables
-- - REFERENCES: Create foreign key constraints
-- - TRIGGER: Create triggers on tables
-- - ALL: Complete table-level access
--
-- Scope: Applies to tables that exist at the time this command runs
-- Note: This mainly covers edge cases since MLflow creates its own tables

-- ===================================================================================
-- Sequence-Level Permissions (Existing Objects)  
-- Grant access to any sequences that already exist in the public schema
-- ===================================================================================

-- Access to all existing sequences in public schema  
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mlflow;
-- Permissions granted:
-- - USAGE: Use NEXTVAL, CURRVAL functions on sequences
-- - SELECT: Read sequence values
-- - UPDATE: Modify sequence values (SETVAL)
-- - ALL: Complete sequence-level access
--
-- Sequences usage:
-- - PostgreSQL uses sequences for auto-incrementing columns (SERIAL, BIGSERIAL)
-- - MLflow tables use sequences for primary key generation
-- - Required for INSERT operations on tables with auto-increment IDs

-- ===================================================================================
-- Default Privileges for Future Objects
-- Ensure MLflow user has access to objects created in the future
-- ===================================================================================

-- Automatic permissions for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mlflow;
-- Purpose: Automatically grant permissions when new tables are created
-- Applies to: Any table created in the public schema after this command
-- Permissions: Same as GRANT ALL PRIVILEGES ON ALL TABLES (see above)
-- 
-- Why critical for MLflow:
-- - MLflow creates tables dynamically during operation
-- - Database migrations add new tables and columns
-- - Without this, newly created tables would be inaccessible to mlflow user
-- - Prevents permission-related failures during MLflow operation

-- Automatic permissions for future sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mlflow;  
-- Purpose: Automatically grant permissions when new sequences are created
-- Applies to: Any sequence created in the public schema after this command
-- Permissions: Same as GRANT ALL PRIVILEGES ON ALL SEQUENCES (see above)
--
-- Why critical for MLflow:
-- - New tables often include auto-incrementing columns with sequences
-- - Database migrations may create new sequences
-- - Ensures INSERT operations work on new tables with SERIAL columns

-- ===================================================================================
-- Pentaho Data Catalog Integration Considerations
-- ===================================================================================

-- Model Registry Requirements:
-- - Pentaho Data Catalog requires MLflow Model Registry to be enabled
-- - Model Registry tables store registered models, versions, and stages  
-- - These permissions ensure PDC can discover and catalog ML models
-- - PDC connects to MLflow via REST API, which queries these tables
--
-- Database Access Patterns:
-- - MLflow REST API: Queries all tables for experiment and model data
-- - Direct PDC Access: PDC may query database directly for enhanced metadata
-- - Model Governance: Model Registry tables support PDC governance workflows
--
-- Performance Considerations:
-- - Full privileges enable MLflow to create indexes for performance
-- - Allows creation of materialized views for complex queries
-- - Supports database-level optimizations for large datasets

-- ===================================================================================
-- Security and Production Considerations
-- ===================================================================================

-- Current Configuration (Development/Internal):
-- - MLflow user has full database privileges (suitable for single-tenant)
-- - No row-level security or column-level restrictions
-- - Appropriate for internal/development environments
--
-- Production Recommendations:
-- - Consider more granular permissions if sharing database with other applications
-- - Implement connection pooling for better resource management
-- - Regular database backups to prevent data loss
-- - Monitor database performance and storage usage
-- - Consider read replicas for analytics workloads (like Pentaho Data Catalog queries)
--
-- Multi-tenant Considerations:
-- - If hosting multiple MLflow instances, consider separate databases or schemas
-- - Implement role-based access control for different user types
-- - Consider audit logging for compliance requirements

-- ===================================================================================
-- Troubleshooting Common Issues
-- ===================================================================================

-- Permission Errors:
-- - If MLflow fails with "permission denied" errors, verify these grants completed
-- - Check MLflow logs for specific permission issues
-- - Ensure database connection string uses correct username/password
--
-- Table Creation Failures:
-- - If MLflow can't create tables, verify GRANT ALL ON DATABASE succeeded
-- - Check disk space on PostgreSQL data volume
-- - Verify PostgreSQL container has sufficient memory
--
-- Model Registry Issues:
-- - If Model Registry features don't work, ensure uuid-ossp extension loaded
-- - Verify registered_models and model_versions tables exist after MLflow startup
-- - Check MLflow server logs for Model Registry initialization messages
-- ===================================================================================