# ===================================================================================
# MLflow Server Dockerfile with Pentaho Data Catalog Integration
# 
# This Dockerfile creates a custom MLflow server image that includes:
# - MLflow tracking server with Model Registry support
# - Database connectivity (PostgreSQL)
# - S3-compatible storage support (MinIO/AWS S3)
# - Machine learning libraries for compatibility
# - Pentaho Data Catalog integration helpers
# - Service dependency management (wait for DB/MinIO)
# ===================================================================================

# ===================================================================================
# Base Image Selection
# Using Python 3.10 slim image for optimal balance of features and size
# ===================================================================================
FROM python:3.10-slim
# python:3.10-slim provides:
# - Python 3.10 runtime (compatible with latest MLflow)
# - Debian-based Linux (stable, well-supported)
# - Minimal footprint (excludes unnecessary packages)
# - Good security posture (fewer attack vectors)

# ===================================================================================
# Build Environment Configuration
# Suppress interactive package configuration prompts during build
# ===================================================================================
ENV DEBIAN_FRONTEND=noninteractive
# This prevents package installation from hanging on configuration prompts
# Only affects the Docker build process, not runtime behavior
# Reset to default after package installation to maintain normal behavior

# ===================================================================================
# System Dependencies Installation
# Install essential system packages required for MLflow and integrations
# ===================================================================================
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*
# Package breakdown:
# - curl: HTTP client for health checks and API calls
# - gcc: C compiler for building Python packages with native extensions
# - g++: C++ compiler for building packages like psycopg2
# - netcat-traditional: Network utility for checking service availability
# - rm -rf /var/lib/apt/lists/*: Cleanup to reduce image size

# Reset environment to default for normal runtime behavior
ENV DEBIAN_FRONTEND=

# ===================================================================================
# Python Dependencies Installation  
# Install MLflow and all required Python packages for full functionality
# ===================================================================================
RUN pip install --no-cache-dir \
    mlflow[extras] \
    scikit-learn \
    pandas \
    numpy \
    matplotlib \
    psycopg2-binary \
    boto3 \
    cryptography \
    pymysql \
    requests \
    sqlalchemy \
    alembic
# Package categories and purposes:
#
# Core MLflow:
# - mlflow[extras]: MLflow with additional plugins and integrations
#
# Machine Learning Libraries (for broad model compatibility):
# - scikit-learn: Popular ML library, commonly used with MLflow
# - pandas: Data manipulation and analysis library
# - numpy: Numerical computing library (dependency for most ML packages)
# - matplotlib: Plotting library for generating charts/visualizations
#
# Database Connectivity:
# - psycopg2-binary: PostgreSQL adapter for Python (for Model Registry)
# - pymysql: MySQL adapter for Python (alternative database support)
# - sqlalchemy: SQL toolkit and ORM (used by MLflow for database operations)
# - alembic: Database migration tool (used by MLflow for schema management)
#
# Cloud Storage & Security:
# - boto3: AWS SDK for Python (S3 and MinIO compatibility)
# - cryptography: Cryptographic libraries for secure connections
#
# HTTP & Integration:
# - requests: HTTP library for API calls (Pentaho integration)
#
# Build optimization:
# - --no-cache-dir: Don't cache downloaded packages (reduces image size)

# ===================================================================================
# Application Directory Setup
# Create dedicated directory for MLflow application and scripts
# ===================================================================================
WORKDIR /app
# Sets /app as the working directory for subsequent commands
# All relative paths in COPY, RUN commands will be relative to /app
# MLflow server will run from this directory

# ===================================================================================
# Application Files Integration
# Copy custom integration scripts into the container
# ===================================================================================
COPY pentaho_integration.py /app/
# Pentaho Data Catalog integration helper script
# Contains: PDC connection logging, integration setup functions
# Purpose: Initialize PDC integration and provide connection information

COPY entrypoint.sh /app/
# Custom startup script that orchestrates service initialization
# Functions:
# - Wait for PostgreSQL database to be ready
# - Wait for MinIO object storage to be ready  
# - Initialize Pentaho Data Catalog integration
# - Start MLflow server with proper configuration

# ===================================================================================
# File Permissions Configuration
# Ensure startup script has execute permissions
# ===================================================================================
RUN chmod +x /app/entrypoint.sh
# Makes entrypoint.sh executable so it can be run as the container's main process
# Required for proper container startup

# ===================================================================================
# Network Port Configuration
# Expose MLflow server port for external access
# ===================================================================================
EXPOSE 5000
# Documents that the container listens on port 5000
# MLflow tracking server default port
# Used by:
# - Web UI access (http://host:5000)
# - REST API calls (for logging experiments, querying data)
# - Pentaho Data Catalog connections
# Note: This is documentation only; actual port mapping happens in docker-compose.yml

# ===================================================================================
# Container Startup Configuration
# Set custom entrypoint script as the main container process
# ===================================================================================
ENTRYPOINT ["/app/entrypoint.sh"]
# Starts the custom entrypoint script when container launches
# The entrypoint script will:
# 1. Wait for dependent services (PostgreSQL, MinIO)
# 2. Initialize Pentaho Data Catalog integration
# 3. Start MLflow server with full configuration
# 4. Handle graceful shutdown signals
#
# Alternative approaches not used:
# - CMD ["mlflow", "server", ...]: Would start MLflow directly without dependency checks
# - ENTRYPOINT ["mlflow"] + CMD [...]: Would bypass custom initialization logic

# ===================================================================================
# Runtime Behavior Summary
# 
# When this container starts:
# 1. entrypoint.sh executes as PID 1
# 2. Script waits for database and MinIO to be ready
# 3. Pentaho integration is initialized (logging/setup)
# 4. MLflow server starts with full configuration:
#    - Backend store: PostgreSQL (experiments, runs, Model Registry)
#    - Artifact store: MinIO S3-compatible storage
#    - Model Registry: Enabled (required for Pentaho Data Catalog)
#    - REST API: Available on port 5000
#    - Web UI: Available on port 5000
# 5. Container remains running until stopped
#
# Health checks and monitoring:
# - MLflow provides /health endpoint for monitoring
# - Service dependencies managed through Docker Compose
# - Logs available via docker compose logs tracking_server
# ===================================================================================

# ===================================================================================
# Integration Architecture Summary
#
# This container provides:
# - MLflow Tracking Server (experiments, runs, parameters, metrics)
# - MLflow Model Registry (model versions, stages, tags)
# - REST API endpoints for all MLflow functionality
# - Artifact serving (models, plots, datasets from MinIO)
# - Database connectivity (PostgreSQL for metadata)
# - S3-compatible storage (MinIO for artifacts)
#
# Pentaho Data Catalog Integration:
# - PDC connects to this container's REST API (port 5000)
# - PDC discovers experiments, models, runs through MLflow API
# - PDC can access Model Registry for governance workflows
# - No authentication required (container designed for internal network)
# - All ML metadata available for cataloging and discovery
# ===================================================================================