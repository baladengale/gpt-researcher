# Cluster deployment (local kind infra)

Deploy this repo into the local kind cluster (`~/workspace/kind`, cluster
`kagent`) so the full stack — Next.js UI + FastAPI API behind one nginx —
is served at **https://research.internal** through the cluster's
AgentGateway. No port-forwarding; DNS is the machine-level `*.internal`
dnsmasq zone that the kind infra manages.

## The one command

From the kind infra repo:

```bash
cd ~/workspace/kind
make research-deploy
```

That single target does everything:

1. **Build from source** — `cluster/push-image.sh` runs
   `docker build -f Dockerfile.fullstack` (UI + API + nginx in ONE
   container; supervisord runs all three; port 3000 is the only exposed
   port).
2. **Publish** — pushes to the internal registry:
   `kind-registry.internal/gpt-researcher:local`. The kind nodes pull from
   it directly (containerd `certs.d` bypass wired by the infra's
   `50-registry.sh`). Prefer a side-load instead of the registry?
   `bash cluster/push-image.sh --load`.
3. **Secret** — this repo's `.env` becomes the
   `research/gpt-researcher` Secret (dry-run apply, idempotent). This is
   how your z.ai key reaches the pod: set it HERE, not in the cluster.
4. **Deploy** — applies `cluster/deploy/{namespace,deployment,service}.yaml`
   (namespace `research`) and the HTTPRoute
   (`~/workspace/kind/manifests/research-route.yaml`, host
   `research.internal` -> service :3000).
5. **Rollout + verify** — restarts the rollout (`:local` tag), waits, adds
   the hostname to the gateway TLS cert SAN, probes
   `https://research.internal`.

Idempotent: re-run after ANY change to source code or `.env`. Image layers
are cached — re-runs are fast; the first build is slow (browsers,
node_modules, pip).

## Configuration (this repo's `.env`)

| Var | Role in the pod |
|---|---|
| `OPENAI_API_KEY` | **required for research runs** — z.ai key (the deploy warns if it is still the placeholder) |
| `OPENAI_BASE_URL` | OpenAI-compatible endpoint (coding plan: `https://api.z.ai/api/coding/paas/v4`) |
| `FAST_LLM` / `SMART_LLM` / `STRATEGIC_LLM` | `openai:<model>` — defaults `openai:glm-5.3-flash`; verify ids with `./check_models.sh` |
| `RETRIEVER` | `duckduckgo` (keyless) or `tavily` + `TAVILY_API_KEY` |
| `TYPESAFE_API_KEY` | optional — enables Jev context filtering (upstream default filter; falls back to keyword BM25 without it) |
| `EMBEDDING` | only used if the context filter is set to `embeddings` |

Verify endpoint + model id after changing the key:

```bash
./check_models.sh
```

## Local (non-cluster) usage

The repo root also has standalone launchers that read the same `.env`:

- `./run_cli.sh "<query>"` — one-shot cited report in the terminal
- `./run_api.sh` — headless API on localhost:8000 (fixed `PYTHONPATH` for
  the upstream `backend.*` import quirk)
- `./run_ui_docker.sh` — the upstream docker compose stack (UI :3000 +
  API :8000 as separate containers)

When the cluster deployment is live, prefer it and stop the local compose
stack (`docker compose down`) to avoid running two copies.

## Layout

```
cluster/
  push-image.sh           build + publish (--load = kind side-load fallback)
  deploy/namespace.yaml   ns research
  deploy/deployment.yaml  fullstack pod (envFrom secret, probes, outputs volume)
  deploy/service.yaml     service :3000
  README.md               this file
```

Route lives on the infra side: `~/workspace/kind/manifests/research-route.yaml`
(plain YAML, shared `kind-infra` Gateway — same pattern as the registry
route).
