---
name: research
description: Run completely autonomous research with the local gpt-researcher checkout — one-shot cited markdown reports, live progress streaming, glow-rendered final report. Use when the user asks to "research X", wants an autonomous deep-research report generated, wants to list or view past research reports, or to run/serve/stop the gpt-researcher API. Not for casual web lookups — each research run spends LLM tokens (tracked ~$0.005-0.01 per research_report run at Z.AI list rates) and takes ~2-5 minutes.
---

# research — headless autonomous research (gpt-researcher)

Wraps the LOCAL repo checkout `/Users/bala/workspace/gpt-researcher` (no pip
install; pyproject.toml ships no console script). The runner `research` is the
single entry point and is RESEARCH-FIRST: the first argument is the query.

Every research path streams child output LIVE to stderr, glow-renders the
final report body (frontmatter stripped) to stderr, then prints EXACTLY ONE
JSON line on stdout — parse stdout, ignore stderr unless the command fails.
Shared flags: `--quiet` (no live stream; output still logged to
${TMPDIR:-/tmp}/gptr-last-run.log) and `--no-preview` (skip the glow render).

## Prerequisites

- Repo at /Users/bala/workspace/gpt-researcher with `.venv/` and `.env`
  containing: OPENAI_API_KEY + OPENAI_BASE_URL (Z.AI OpenAI-compatible
  endpoint), FAST_LLM/SMART_LLM/STRATEGIC_LLM=openai:glm-5.3-flash,
  EMBEDDING=openai:embedding-3, RETRIEVER=duckduckgo (keyless; set
  TAVILY_API_KEY and RETRIEVER=tavily for higher-quality retrieval).
- glow (brew) for the end-of-run preview — auto-detected
  (PATH or /opt/homebrew/bin/glow), skipped with a note if missing.
- macOS curl (used by `serve`).

## Usage

### research "<query>" [--type T] [--domains a.com,b.com] [--tone objective] [--source web] [--quiet] [--no-preview]

One-shot report via `cli.py`. T in: research_report (~2 min, default),
detailed_report (~5 min), resource_report, outline_report, custom_report,
subtopic_report, deep. Report + YAML frontmatter (task_id, title,
sources_count, total_cost_usd) land in `<repo>/outputs/<LLM-title>.md`
(markdown only: --no-pdf --no-docx are always passed to avoid weasyprint
failure modes). NOTE: `--type deep` is cli.py's own deep-research mode,
unrelated to `research deep` below.

Output JSON line:
```
{"path":"/Users/bala/workspace/gpt-researcher/outputs/AVGO_Stock_Decline.md","title":"AVGO Stock Decline","sources_count":15,"total_cost_usd":0.201535}
```
`path` is absolute — open/summarize it after the run. The Nov-7 AVGO run
tracked $0.201535 under the old generic-OpenAI fallback; since the
2026-11-07 Z.AI pricing patch in gpt_researcher/utils/costs.py ($0.15 in /
$0.50 out per MTok), the same run tracks ~$0.006.

### research deep "<query>" [--quiet] [--no-preview]

deep_agents stack: chief editor + parallel researcher subagents (LangChain
deepagents). Writes the query into `<repo>/deep_agents/task.json` (preserving
other fields) and forces model to "openai:glm-5.3-flash" — the shipped
task.json has "openai:gpt-5.4" which the Z.AI endpoint rejects.
deep_agents/main.py has no CLI args, so task.json is the only query channel
(deep_agents/main.py:94-96). Model override is doubly ensured:
deep_agents/agent.py:64 prefers env STRATEGIC_LLM (already
openai:glm-5.3-flash in .env) over task.json model. Output:
`<repo>/deep_agents/outputs/run_<8hex>/report.md` with inline citations +
deduplicated References. Expect 5-15 min.

Output JSON line: `{"path":".../report.md","title":null,"sources_count":null,"total_cost_usd":null}`
(deep_agents does not track cost into frontmatter; the path is the deliverable).

### research multi "<query>" [--quiet] [--no-preview]

multi_agents LangGraph stack: plan -> parallel section research -> review ->
publish. Writes query, include_human_feedback:false (removes the human plan
gate: human.py:18-45 prompts only when true; plan_review.py:8-10 then
auto-accepts), publish_formats markdown-only, model "glm-5.3-flash" into
`<repo>/multi_agents/task.json`. Exports STRATEGIC_LLM=openai:glm-5.3-flash —
VERIFIED override: multi_agents/main.py:59-65 lets this env var beat task.json
model. Files land in `<repo>/outputs/run_<unixtime>_<query-prefix>/<uuid>.md`.
Expect 15-40 min (observed: ~30+ min — the fact-check/review loop makes
several full-draft LLM calls, each minutes long) and 3-5x the cost of a
research_report (~$0.02-0.04 tracked post-patch).

Output JSON line: `{"path":".../outputs/run_.../<uuid>.md","run_dir":".../outputs/run_...","title":null,"sources_count":null,"total_cost_usd":null}`

### research list

List every past report across the three on-disk locations (cli
`outputs/*.md`, multi `outputs/run_*/<uuid>.md`, deep
`deep_agents/outputs/run_*/report.md`) newest first. Human table on
stderr, ONE JSON array line on stdout — each entry has path, kind
(cli|multi|deep), title, date, size_bytes, sources_count,
total_cost_usd (null when the report carries no frontmatter, e.g. multi
runs). Read-only: no lock, no API calls, no .env. The recommended
"list, then view" flow: run `research list`, present the numbered
titles, then open the picked one via index or substring.

### research view [selector] [--term]   /   research resolve <selector>

`view` resolves a selector, then renders the report (frontmatter
stripped) to styled HTML and opens it in the default browser; emits
{"path","html"} on stdout. Selector, all forms tested 2026-11-07:
- omitted — newest report across all three locations
- list index — `research view 3` (same order as `research list`)
- path — absolute, or relative to the repo root
- directory — newest .md inside it (e.g. a multi run dir)
- title/filename substring, case-insensitive — `research view avgo`;
  must match EXACTLY ONE report, else it prints the matching #indices
  to stderr and exits 2
`--term` glow-renders the report to the terminal instead (human mode:
no JSON line). `research resolve <selector>` is the non-opening
variant — prints one JSON line {"path",...} for the selector, for
mapping "view #2" to a path before opening. All three are read-only.

### research serve start|stop|status

Optional FastAPI path (follow-up chat, programmatic POST /report/). start
launches `./run_api.sh` in background (pidfile /tmp/gptr-api.pid, log
/tmp/gptr-api.log) and polls GET localhost:8000 until ready (max 120s). The
sync consumption pattern once up:
```
curl -s localhost:8000/report/ -H 'Content-Type: application/json' \
  -d '{"task":"<query>","report_type":"research_report","report_source":"web","tone":"objective","generate_in_background":false}'
```
returns report + research_information{source_urls, research_costs,
visited_urls} (backend/server/app.py:371-381, 352-365). Do NOT use POST
/api/multi_agents — it is a UI-websocket demo, unusable headless.

## Concurrency and side effects

- Research paths serialize on mkdir lock /tmp/gptr.lock; a second run waits
  (GPTR_LOCK_WAIT seconds, default 900) then fails. This protects keyless
  DuckDuckGo from throttling and the shared task.json files from concurrent
  writes.
- `deep` and `multi` MUTATE the tracked files deep_agents/task.json and
  multi_agents/task.json in place (that is their designed config interface).
  Expect a dirty git diff; `git checkout --` reverts them.
- Last run log: ${TMPDIR:-/tmp}/gptr-last-run.log (inspect on failure).

## Viewing reports in the browser

- LIST THEN VIEW (added 2026-11-07): `research list` -> numbered table +
  JSON array; `research view <index|substring|path|dir>` -> rendered HTML in
  the browser; `research view <sel> --term` -> glow in the terminal;
  `research resolve <sel>` -> just the path as JSON. See the Usage section
  above for the full selector grammar.
- The bundled UI (research serve start + http://localhost:3000, or
  run_ui_docker.sh) lists ONLY reports created through the API/UI (persisted
  in data/reports.json via ReportStore, backend/server/app.py:135) — CLI runs
  bypass that store and will NOT appear in it; use `research list` instead.
- While the server runs, raw markdown is also served UNRENDERED at
  http://localhost:8000/outputs/<file>.md (static mount, app.py:75).

## INSTALL (done 2026-11-07; renamed from gptr per BALA directive)

Installed to `~/.claude/skills/research/` (SKILL.md + executable runner) with
symlink `~/.zcode/skills/research -> ~/.claude/skills/research` — ZCode
mirrors skills from the Claude dir. The old `gptr` skill was removed.
Source of truth for future edits:
`/Users/bala/workspace/research/team/autonomous-research-agents/artifacts/research/`
— after editing, re-copy both files to `~/.claude/skills/research/`; the
symlink picks them up for ZCode. Optional PATH install for bare `research`:
```
ln -sf ~/.claude/skills/research/research /opt/homebrew/bin/research
```

Smoke-check without spending: `research help` and
`research serve status` (should print "not running"). First real run costs
money — see BALA decides.

## Validation tasks (pass/fail)

- V1 CLI smoke (EVIDENCED twice: outputs/AMD_530P_Repair_Plan.md Nov 4 — 15
  sources, $0.202685; outputs/AVGO_Stock_Decline.md Nov 7 — 15 sources,
  $0.201535): fresh query via `research "<q>"`. PASS = one JSON line on
  stdout; md exists; sources_count >= 5; frontmatter parses; wall clock
  <= 10 min; live progress visible; glow preview rendered.
- V2 Format chain: same query with pdf+docx enabled (only via cli.py directly
  or the serve path). PASS = .md/.pdf/.docx share the stem, pdf > 20KB.
- V3 Multi-agent autonomy (SPENDING — needs BALA go): `research multi "<q>"`.
  PASS = zero human interaction; outputs/run_*/<uuid>.md exists; sections >=
  max_sections(3) with hyperlinked sources. Expected cost $0.02-0.04 tracked
  (post-patch Z.AI rates).
- V4 Deep Agents autonomy (SPENDING — needs BALA go): `research deep "<q>"`.
  PASS = deep_agents/outputs/run_*/report.md exists with inline citations +
  dedup References; subagent `task` calls visible in the run log. Expected
  cost $0.02-0.04 tracked (post-patch Z.AI rates).
- V5 Quality gate (optional): evals/ harness (simple_evals quality/
  hallucination evals per evals/README.md) as a regression baseline.

## BALA decides

1. Spending smoke test V3: run `research multi "<your question>"` once —
   ~$0.02-0.04 tracked LLM spend, 5-20 min. Approve or skip.
2. Spending smoke test V4: run `research deep "<your question>"` once —
   ~$0.02-0.04 tracked LLM spend, 5-15 min. Approve or skip.
3. Optional PATH install (see INSTALL) so bare `research "<q>"` works.
4. Optional: set TAVILY_API_KEY in .env (paid search API) if DuckDuckGo
   retrieval quality proves too thin — not required for V1-V4.
