#!/usr/bin/env bash
# Quick dev server for Docker Lab documentation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv venv
fi

# Activate and install
source venv/bin/activate
pip install -q -r requirements.txt

echo "Starting MkDocs dev server..."
echo "Site: http://localhost:8000"
mkdocs serve
