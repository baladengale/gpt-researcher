#!/bin/zsh
# Verify your Z.AI key, endpoint, and the exact model id to use.
set -a; source /Users/bala/workspace/gpt-researcher/.env; set +a

echo "== 1. List models at $OPENAI_BASE_URL =="
curl -s -m 30 "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY" \
  | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    ids=[m.get("id") for m in d.get("data",[])]
    print("\n".join(sorted(filter(None,ids))) if ids else d)
except Exception as e:
    print("(models list not supported or failed:", e, ")")'

echo
echo "== 2. Chat ping with glm-5.3-flash =="
curl -s -m 60 "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"glm-5.3-flash","messages":[{"role":"user","content":"say ok"}],"max_tokens":8}' \
  | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    if "choices" in d: print("OK ->", d["choices"][0]["message"]["content"])
    else: print("ERROR ->", json.dumps(d)[:600])
except Exception as e: print("parse error:", e)'
echo
echo "If step 2 errors with a model-id message, fix FAST_LLM/SMART_LLM/STRATEGIC_LLM in .env and re-run."
