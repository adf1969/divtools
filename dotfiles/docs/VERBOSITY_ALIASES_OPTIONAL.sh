#!/bin/bash
# DivTools Verbosity Quick Reference
# Add this to your ~/.bash_aliases or ~/.bashrc for quick access

# Quick verbosity level aliases
alias v0='export DT_VERBOSE=0'      # Silent (errors only)
alias v1='export DT_VERBOSE=1'      # Minimal (errors + warnings)
alias v2='export DT_VERBOSE=2'      # Normal (default behavior)
alias v3='export DT_VERBOSE=3'      # Verbose (includes debug)
alias v4='export DT_VERBOSE=4'      # Debug (everything)

# Reload profile with specific verbosity
alias v0s='v0 && sep'               # Silent reload
alias v1s='v1 && sep'               # Minimal reload
alias v2s='v2 && sep'               # Normal reload (default)
alias v3s='v3 && sep'               # Verbose reload
alias v4s='v4 && sep'               # Debug reload

# Show current verbosity settings
alias vshow='echo "DT_VERBOSE=${DT_VERBOSE:-2}"; declare -p DT_VERBOSITY_LEVELS 2>/dev/null || echo "DT_VERBOSITY_LEVELS not set"'

# Common use cases
alias vquiet='v0 && sep'            # One-liner to reload silently
alias verbose='v3 && sep'           # One-liner to reload with debug info

# Usage examples (uncomment and run):
# v0              # Set to silent, but don't reload
# v0s             # Reload in silent mode
# vshow           # Show current verbosity settings
# vquiet          # Reload silently (silent mode + sep)
# verbose         # Reload with verbose output
