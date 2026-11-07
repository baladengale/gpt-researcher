# research — headless gpt-researcher skill

Vendored copy of the personal `research` skill (ZCode/Claude) that wraps THIS
repo checkout for headless autonomous research. Canonical home:
`~/.claude/skills/research/` (source of truth:
`~/workspace/research/team/autonomous-research-agents/artifacts/research/`);
this copy exists so the tooling travels with the fork.

- `research` — bash runner. RESEARCH-FIRST: `research "<query>"` is a one-shot
  cited markdown report via `cli.py`; `deep` / `multi` run the deep_agents /
  multi_agents stacks; `list` / `view` / `resolve` discover and open past
  reports; `serve` manages the FastAPI.
- `SKILL.md` — full usage, verified override mechanisms, and validation tasks.

Install (macOS):

```
mkdir -p ~/.claude/skills/research
cp research SKILL.md ~/.claude/skills/research/
chmod +x ~/.claude/skills/research/research
ln -sf ~/.claude/skills/research/research /opt/homebrew/bin/research   # optional
```

NOTE: `REPO` is hardcoded to `/Users/bala/workspace/gpt-researcher` at the top
of the runner — edit that line when installing elsewhere. Requires the repo
`.venv` and `.env`, plus `glow` (brew) for previews.

Changelog 2026-11-07: added `list` / `resolve` and selector-based `view`
(index, path, directory, or title substring); fixed `preview_report` crashing
under bash 3.2 + `set -u` ("wargs[@]: unbound variable") by replacing the
empty-array glow flag with a scalar — the crash previously killed the runner
before the final JSON line was emitted.
