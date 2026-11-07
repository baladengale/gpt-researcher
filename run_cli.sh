#!/bin/zsh
# Headless one-shot report, no UI needed:
#   ./run_cli.sh "Should I repair my short AMD 530P Dec-18 after the Nov-3 guide?"
cd /Users/bala/workspace/gpt-researcher
set -a; source .env; set +a
.venv/bin/python cli.py "$1" --report_type research_report --tone objective --no-pdf --no-docx
