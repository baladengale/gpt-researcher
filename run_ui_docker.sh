#!/bin/zsh
# Full web UI via Docker (builds the Next.js frontend inside the container;
# no local Node needed). UI on http://localhost:3000, API on :8000.
cd /Users/bala/workspace/gpt-researcher
docker compose up --build
