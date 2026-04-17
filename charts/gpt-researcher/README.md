# gpt-researcher Helm chart

Deploy [GPT Researcher](https://gptr.dev) on Kubernetes.

## Install

### From OCI (recommended — Helm 3.8+)

```bash
helm install gptr oci://ghcr.io/budecosystem/charts/gpt-researcher \
  --version 0.1.0 \
  --namespace gptr --create-namespace \
  --set secrets.data.OPENAI_API_KEY=sk-... \
  --set secrets.data.TAVILY_API_KEY=tvly-... \
  --set frontend.env.NEXT_PUBLIC_GPTR_API_URL=https://gptr.example.com/api
```

### From Helm repo (gh-pages)

```bash
helm repo add budecosystem https://budecosystem.github.io/gpt-researcher
helm repo update
helm install gptr budecosystem/gpt-researcher -n gptr --create-namespace -f my-values.yaml
```

### From source

```bash
git clone https://github.com/BudEcosystem/gpt-researcher
helm install gptr ./gpt-researcher/charts/gpt-researcher -f my-values.yaml
```

## Requirements

- Helm 3.11+
- Kubernetes 1.25+
- A StorageClass for `my-docs` / `outputs` / `logs` PVCs (or set `persistence.*.enabled=false`)
- An Ingress controller if you want browser access via a hostname

## Images

Published to Docker Hub under `budstudio/`:

| Image | Contents | Size |
|---|---|---|
| `budstudio/gpt-researcher-backend:X.Y.Z` | Minimal backend — OpenAI provider only | ~1 GB |
| `budstudio/gpt-researcher-backend:X.Y.Z-full` | Adds `langchain-huggingface`, `sentence-transformers`, `duckduckgo-search`, Cohere, Google GenAI, Ollama | ~2.5 GB |
| `budstudio/gpt-researcher-frontend:X.Y.Z` | Next.js production build | ~200 MB |

The chart defaults to the `-full` backend variant via `backend.image.tagSuffix: "-full"`. Switch to minimal with:

```yaml
backend:
  image:
    tagSuffix: ""
```

## Deployment modes

### Split (default)

Backend and frontend run as separate Deployments / Services. Recommended for production — scale each independently, rolling restarts don't take down the whole stack.

### Fullstack

A single Deployment runs the `Dockerfile.fullstack` image (nginx + supervisord + backend + frontend).

```yaml
fullstack:
  enabled: true
```

## Secrets

Three modes, in precedence order:

1. **External Secrets Operator** (`secrets.externalSecrets.enabled: true`) — renders an `ExternalSecret` CR.
2. **Existing secret** (`secrets.existingSecret: my-secret`) — uses a pre-provisioned k8s Secret via `envFrom`.
3. **Rendered from values** (`secrets.create: true`, default) — dev only.

Required: `OPENAI_API_KEY`, `TAVILY_API_KEY`. Optional: `LANGCHAIN_API_KEY`, `GOOGLE_API_KEY`, `GOOGLE_CX_KEY`, `OPENAI_BASE_URL`, `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`.

## Persistence

Three PVCs mirror the docker-compose volumes:

| PVC       | Mount                         | Default size | Notes |
|-----------|-------------------------------|--------------|-------|
| `my-docs` | `/usr/src/app/my-docs`        | 5Gi          | User-uploaded source docs |
| `outputs` | `/usr/src/app/outputs`        | 10Gi         | Generated reports — set RWX to share with frontend |
| `logs`    | `/usr/src/app/logs`           | 2Gi          | App logs |

For `backend.replicaCount > 1`, change `accessModes` to `ReadWriteMany`, or set `persistence.*.enabled: false`.

## Ingress

`ingress.enabled: true` renders a single Ingress with path routing matching the nginx config in `Dockerfile.fullstack`:

- `/ws`, `/outputs`, `/reports`, `/files`, `/getConfig`, `/setConfig` → backend
- `/` → frontend

Websocket tip for ingress-nginx:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

## Frontend API URL

`NEXT_PUBLIC_GPTR_API_URL` is consumed by client-side JavaScript — the browser must resolve it. Set it to the externally reachable backend URL (Ingress hostname, or the same Ingress host + `/api`). In-cluster Service DNS will not work.

## Using an OpenAI-compatible gateway

Any OpenAI-compatible endpoint (LocalAI, vLLM, LiteLLM proxy, custom gateways) works via `OPENAI_BASE_URL`:

```yaml
secrets:
  data:
    OPENAI_API_KEY: your-gateway-key
    OPENAI_BASE_URL: https://your-gateway/v1

config:
  FAST_LLM: "openai:your-model"
  SMART_LLM: "openai:your-model"
  STRATEGIC_LLM: "openai:your-model"
  # If your gateway has no embeddings endpoint, use a local HF model:
  EMBEDDING: "huggingface:sentence-transformers/all-MiniLM-L6-v2"
  # Keyless web search:
  RETRIEVER: "duckduckgo"
```

Avoid reasoning models (Kimi-K2, Qwen with `<think>`) — they return empty `content`, which breaks gpt-researcher's JSON agent classifier with `TypeError: expected string or bytes-like object, got 'NoneType'`.

## Probes

Default liveness is a TCP probe on 8000, readiness is `GET /` (returns HTML 200). Override via `backend.probes.*` if you add a `/health` route.

## Values reference

Key knobs (see `values.yaml` for the full surface):

| Key                                     | Default                                  |
|-----------------------------------------|------------------------------------------|
| `fullstack.enabled`                     | `false`                                  |
| `backend.enabled`                       | `true`                                   |
| `backend.image.tagSuffix`               | `"-full"`                                |
| `backend.replicaCount`                  | `1`                                      |
| `backend.autoscaling.enabled`           | `false`                                  |
| `backend.persistence.{myDocs,outputs,logs}.enabled` | `true`                       |
| `frontend.enabled`                      | `true`                                   |
| `frontend.env.NEXT_PUBLIC_GPTR_API_URL` | `""` (required for browser access)       |
| `frontend.mountOutputs`                 | `false`                                  |
| `discordBot.enabled`                    | `false`                                  |
| `secrets.create` / `existingSecret` / `externalSecrets.enabled` | — pick one |
| `ingress.enabled`                       | `false`                                  |
| `networkPolicy.enabled`                 | `false`                                  |

## Examples

See `examples/` for ready-to-use values:

- `examples/minimal.yaml` — single-node dev
- `examples/production.yaml` — Ingress + External Secrets + HPA
- `examples/fullstack.yaml` — single-pod deployment

## Development

```bash
helm lint charts/gpt-researcher
for f in charts/gpt-researcher/ci/*.yaml; do helm template t charts/gpt-researcher -f "$f" > /dev/null; done
helm test gptr --namespace gptr   # after install
```
