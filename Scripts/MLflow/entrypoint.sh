#!/bin/bash

# ===================================================================================
# MLflow Server Entrypoint Script with Pentaho Data Catalog Integration
# 
# This script orchestrates the startup of MLflow server within a Docker container
# ensuring all dependencies are ready before starting the main service.
#
# Responsibilities:
# - Wait for PostgreSQL database to be ready
# - Wait for MinIO object storage to be ready
# - Initialize Pentaho Data Catalog integration
# - Start MLflow server with full configuration
# - Handle graceful shutdown (via exec)
# ===================================================================================

# ===================================================================================
# Startup Announcement
# Provide clear indication that the container is starting with PDC integration
# ===================================================================================
echo "Starting MLflow server with Pentaho Data Catalog integration..."
# This message appears in container logs and helps identify the custom startup process
# Useful for debugging and monitoring container initialization

# ===================================================================================
# Database Dependency Check
# Wait for PostgreSQL to be ready before proceeding
# ===================================================================================
echo "Waiting for database to be ready..."

# Service availability check using netcat (nc)
while ! nc -z db 5432; do
    sleep 1
done
# Loop breakdown:
# - nc -z db 5432: Check if port 5432 is open on host 'db' (zero I/O mode)
# - db: Docker container hostname for PostgreSQL service
# - 5432: Standard PostgreSQL port (internal container port)
# - while ! [...]: Continue looping while the command fails (port not open)
# - sleep 1: Wait 1 second between checks to avoid overwhelming the network
# 
# Why this is necessary:
# - PostgreSQL needs time to initialize database files
# - MLflow requires database connection immediately on startup
# - Without this check, MLflow would fail with connection errors
# - Docker depends_on only waits for container start, not service readiness

echo "Database is ready!"
# Confirmation message for successful database connectivity
# Appears in logs when PostgreSQL is accepting connections

# ===================================================================================
# MinIO Object Storage Dependency Check  
# Wait for MinIO S3-compatible storage to be ready
# ===================================================================================
echo "Waiting for MinIO to be ready..."

# Service availability check for MinIO API
while ! nc -z s3 9000; do
    sleep 1
done
# Loop breakdown:
# - nc -z s3 9000: Check if port 9000 is open on host 's3' (zero I/O mode)  
# - s3: Docker container hostname for MinIO service
# - 9000: MinIO S3 API port (internal container port)
# - Same loop logic as database check above
#
# Why this is necessary:
# - MinIO needs time to initialize storage backend
# - MLflow artifact logging requires immediate S3 API access
# - Without this check, artifact storage would fail
# - Bucket creation service also depends on MinIO being ready

echo "MinIO is ready!"
# Confirmation message for successful MinIO connectivity
# Appears in logs when MinIO S3 API is accepting requests

# ===================================================================================
# Pentaho Data Catalog Integration Initialization
# Run custom Python script to set up PDC integration
# ===================================================================================
echo "Initializing Pentaho Data Catalog integration..."

# Execute Pentaho integration helper script
python /app/pentaho_integration.py
# Script functions:
# - Log PDC connection information for reference
# - Display configuration instructions for PDC setup
# - Validate integration environment variables
# - Prepare any PDC-specific initialization
#
# Note: This script runs synchronously and must complete before MLflow starts
# If the script fails, the container startup will be interrupted
# The script is non-blocking for MLflow functionality (PDC connects TO MLflow)

# ===================================================================================
# MLflow Server Startup
# Launch MLflow tracking server with complete configuration
# ===================================================================================
echo "Starting MLflow tracking server..."

# Start MLflow server with comprehensive configuration
exec mlflow server \
    --backend-store-uri postgresql://${PG_USER}:${PG_PASSWORD}@db:5432/${PG_DATABASE} \
    --registry-store-uri postgresql://${PG_USER}:${PG_PASSWORD}@db:5432/${PG_DATABASE} \
    --default-artifact-root s3://${MLFLOW_BUCKET_NAME} \
    --host 0.0.0.0 \
    --port 5000 \
    --serve-artifacts \
    --artifacts-destination s3://${MLFLOW_BUCKET_NAME}

# ===================================================================================
# MLflow Server Configuration Breakdown
# ===================================================================================

# Database Configuration:
# --backend-store-uri postgresql://${PG_USER}:${PG_PASSWORD}@db:5432/${PG_DATABASE}
# Purpose: Stores experiment metadata (runs, parameters, metrics, tags)
# Connection details:
# - ${PG_USER}: PostgreSQL username from environment variable
# - ${PG_PASSWORD}: PostgreSQL password from environment variable  
# - db: Docker container hostname for PostgreSQL service
# - 5432: Internal PostgreSQL port (standard)
# - ${PG_DATABASE}: Database name from environment variable
# 
# Data stored: experiments, runs, parameters, metrics, tags, experiment metadata

# Model Registry Configuration:
# --registry-store-uri postgresql://${PG_USER}:${PG_PASSWORD}@db:5432/${PG_DATABASE}  
# Purpose: Stores Model Registry metadata (registered models, versions, stages)
# Connection: Same database as backend store (common configuration)
# Data stored: registered models, model versions, model stages, model tags
# CRITICAL: Required for Pentaho Data Catalog integration

# Artifact Storage Configuration:
# --default-artifact-root s3://${MLFLOW_BUCKET_NAME}
# Purpose: Default location for storing run artifacts
# Format: S3 URI pointing to MinIO bucket
# ${MLFLOW_BUCKET_NAME}: Bucket name from environment variable
# Artifacts stored: models, plots, datasets, logs, any logged files

# Network Configuration:  
# --host 0.0.0.0
# Purpose: Bind MLflow server to all network interfaces
# Effect: Allows connections from outside the container
# Required for: Docker port mapping, external API access, PDC connections

# --port 5000  
# Purpose: MLflow server listening port
# Standard: MLflow default port
# Mapped to: External port via Docker Compose port configuration

# Artifact Serving Configuration:
# --serve-artifacts
# Purpose: Enable MLflow server to serve artifacts directly
# Benefit: Artifacts accessible through MLflow API without direct S3 access
# Required for: Web UI artifact downloads, API artifact retrieval

# --artifacts-destination s3://${MLFLOW_BUCKET_NAME}
# Purpose: Destination for artifact uploads through MLflow server
# Same as default-artifact-root but used for server-mediated uploads
# Enables: Artifact uploads through MLflow API instead of direct S3 access

# ===================================================================================
# Process Management Notes
# ===================================================================================

# exec command usage:
# - exec replaces the shell process with MLflow server process
# - MLflow server becomes PID 1 in the container
# - Ensures proper signal handling (SIGTERM, SIGINT)
# - Enables graceful shutdown when container is stopped
# - Without exec: shell remains as PID 1, MLflow becomes child process

# Signal handling:
# - Docker stop sends SIGTERM to PID 1
# - MLflow server can handle SIGTERM gracefully (close connections, flush data)
# - Container shutdown is clean and doesn't corrupt data

# ===================================================================================
# Integration Architecture Summary
# ===================================================================================

# Service Dependencies (enforced by this script):
# 1. PostgreSQL must be ready (accepting connections on port 5432)
# 2. MinIO must be ready (accepting API requests on port 9000)  
# 3. Pentaho integration initialization must complete
# 4. Then MLflow server starts with full configuration

# External Integration Points:
# - MLflow REST API: Available on port 5000 for PDC connections
# - PostgreSQL: Direct database access available for PDC queries
# - Artifact Storage: Accessible through MLflow API for PDC artifact discovery
# - Model Registry: Available through MLflow API for PDC model governance

# Pentaho Data Catalog Integration:
# - PDC connects to MLflow REST API (http://container:5000)
# - PDC discovers experiments, runs, models through API calls
# - PDC can query Model Registry for governance workflows
# - PDC can access artifact metadata for cataloging
# - No authentication required (internal network deployment)
# ===================================================================================