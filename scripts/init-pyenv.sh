#!/bin/bash
set -e

# Install pipenv as a system app, so it doesn't end up in the prod image
env -u VIRTUAL_ENV PATH="$BASEPATH" pip install --no-cache-dir --upgrade pip==20.0.2 pipenv==2018.11.26 
# Create the venv
python -m venv /venv
mkdir -p /venv/src
# Upgrade pip inside the venv
pip install --no-cache-dir --upgrade pip==20.0.2
pipenv sync
