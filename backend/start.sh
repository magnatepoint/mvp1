#!/bin/bash

# Start the FastAPI backend server
# Binds to 0.0.0.0 to allow connections from network devices (Android/iOS)

cd "$(dirname "$0")"
source .venv/bin/activate 2>/dev/null || source venv/bin/activate 2>/dev/null

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

