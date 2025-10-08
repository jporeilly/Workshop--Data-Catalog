#!/bin/bash

# MLflow Directory Setup Script
# This script creates the proper directory structure and moves files to correct locations

echo "🚀 Setting up MLflow directory structure..."

# Create MLflow project directory structure
echo "📁 Creating directory structure..."
mkdir -p ~/MLflow/mlflow

# Copy all MLflow files from Workshop--Data-Catalog/MLflow to the new structure
echo "📋 Copying MLflow configuration files..."
cp -r ~/Workshop--Data-Catalog/MLflow/* ~/MLflow/

# Move Docker build context files to mlflow/ subdirectory
echo "🐳 Moving Docker build files to mlflow/ folder..."

# Move Dockerfile to mlflow subfolder
if [ -f ~/MLflow/Dockerfile ]; then
    mv ~/MLflow/Dockerfile ~/MLflow/mlflow/
    echo "✅ Moved Dockerfile to ~/MLflow/mlflow/"
else
    echo "⚠️  Dockerfile not found in ~/MLflow/"
fi

# Move entrypoint.sh to mlflow subfolder
if [ -f ~/MLflow/entrypoint.sh ]; then
    mv ~/MLflow/entrypoint.sh ~/MLflow/mlflow/
    echo "✅ Moved entrypoint.sh to ~/MLflow/mlflow/"
else
    echo "⚠️  entrypoint.sh not found in ~/MLflow/"
fi

# Move pentaho_integration.py to mlflow subfolder
if [ -f ~/MLflow/pentaho_integration.py ]; then
    mv ~/MLflow/pentaho_integration.py ~/MLflow/mlflow/
    echo "✅ Moved pentaho_integration.py to ~/MLflow/mlflow/"
else
    echo "⚠️  pentaho_integration.py not found in ~/MLflow/"
fi

# Make entrypoint.sh executable
if [ -f ~/MLflow/mlflow/entrypoint.sh ]; then
    chmod +x ~/MLflow/mlflow/entrypoint.sh
    echo "✅ Made entrypoint.sh executable"
fi

# Display final directory structure
echo ""
echo "📊 Final directory structure:"
echo "~/MLflow/"
echo "├── .env                           # Environment variables"
echo "├── docker-compose.yml             # Docker services configuration"  
echo "├── init-db.sql                    # PostgreSQL initialization"
echo "└── mlflow/                        # MLflow build context"
echo "    ├── Dockerfile                 # Custom MLflow image"
echo "    ├── entrypoint.sh             # Startup script"
echo "    └── pentaho_integration.py    # Pentaho integration helper"
echo ""

# Verify file locations
echo "🔍 Verifying file locations:"

# Check root directory files
for file in ".env" "docker-compose.yml" "init-db.sql"; do
    if [ -f ~/MLflow/$file ]; then
        echo "✅ ~/MLflow/$file exists"
    else
        echo "❌ ~/MLflow/$file missing"
    fi
done

# Check mlflow subdirectory files
for file in "Dockerfile" "entrypoint.sh" "pentaho_integration.py"; do
    if [ -f ~/MLflow/mlflow/$file ]; then
        echo "✅ ~/MLflow/mlflow/$file exists"
    else
        echo "❌ ~/MLflow/mlflow/$file missing"
    fi
done

echo ""
echo "🎉 MLflow directory setup complete!"
echo ""
echo "Next steps:"
echo "1. cd ~/MLflow"
echo "2. Review and update .env file with your configuration"
echo "3. docker compose build tracking_server"
echo "4. docker compose up -d"
echo ""
echo "Access points after startup:"
echo "- MLflow UI: http://localhost:5000"
echo "- MinIO Console: http://localhost:9001"
echo "- PostgreSQL: localhost:5435"