#!/bin/bash
# Run Celery beat scheduler for MVP backend

set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
elif [ -d "../venv" ]; then
    echo "Activating virtual environment from parent directory..."
    source ../venv/bin/activate
else
    echo "Warning: No virtual environment found. Make sure dependencies are installed."
fi

# Check if celery is installed
if ! command -v celery &> /dev/null; then
    echo "Error: Celery is not installed. Installing dependencies..."
    pip install -r requirements.txt
fi

# Set PYTHONPATH to include the backend directory
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Run celery beat
echo "Starting Celery beat scheduler..."
celery -A app.celery_app beat --loglevel=info

