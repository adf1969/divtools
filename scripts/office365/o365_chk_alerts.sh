#!/bin/bash
export DIVTOOLS=/opt/divtools

# Define virtual environment path
VENV_PATH="$DIVTOOLS/scripts/venvs/o365_mon"

# Activate the virtual environment
source "$VENV_PATH/bin/activate"

# Ensure we are in the script folder so we can find files
cd $DIVTOOLS/scripts/office365

# Run the Python script
#python3 $DIVTOOLS/scripts/office365/o365_chk_adm_roles.py -compare -m andrew@avcorp.biz
python3 $DIVTOOLS/scripts/office365/o365_chk_alerts.py "$@"

# Deactivate the virtual environment (optional, but good practice)
deactivate