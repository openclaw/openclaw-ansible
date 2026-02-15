#!/bin/bash

# Accepts variables with fallbacks to default values
openclaw_user=${1:-openclaw}
openclaw_home=${2:-/home/openclaw}

# Example of replacing hardcoded references

# Previous hardcoded path and user references replaced
mkdir -p $openclaw_home/some_directory
chown -R $openclaw_user:$openclaw_user $openclaw_home/some_directory

# More script logic
# Utilizes $openclaw_user and $openclaw_home where necessary
