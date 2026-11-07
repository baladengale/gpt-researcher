#!/bin/zsh
# Launch GPT Researcher headless API on port 8000.
# PYTHONPATH needs BOTH the repo root (backend.* imports) and backend/ (server.* imports).
cd /Users/bala/workspace/gpt-researcher
set -a; source .env; set +a
export PYTHONPATH="/Users/bala/workspace/gpt-researcher:/Users/bala/workspace/gpt-researcher/backend${PYTHONPATH:+:$PYTHONPATH}"
.venv/bin/python backend/run_server.py
