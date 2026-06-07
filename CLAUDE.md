# CLAUDE.md — SOC AI Project Context

Read this at the start of every session. It is the authoritative reference for project conventions.

---

## Project Summary

**Air-gapped, multi-environment SOC AI triage system — Phase 1.**

This system ingests security alerts from a SIEM (LogRhythm), runs LLM-based triage via a LangGraph agent, stores vector embeddings in Qdrant, indexes events in OpenSearch, persists structured data in PostgreSQL, and collects analyst feedback through a web UI. All inference is on-premises — no data leaves the network. Phase 1 covers the ingestion pipeline, triage agent, and feedback loop.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.11 |
| Agent framework | LangGraph |
| Orchestration | Docker Compose |
| Message queue | Redpanda (Kafka-compatible) |
| Search / analytics | OpenSearch 3.6 |
| Vector store | Qdrant |
| Object storage | MinIO |
| Relational DB | PostgreSQL |
| Log pipeline | Vector (vectordotdev) |
| Inference — dev | Ollama (runs on Windows host, reached via `host.docker.internal`) |
| Inference — prod | vLLM (GPU server) |

---

## Environments

| Environment | Host | Inference backend |
|---|---|---|
| **Dev** | Windows laptop (Docker Desktop + WSL2) | Ollama on Windows host |
| **Staging** | Linux server (bare metal or VM) | Ollama on dev laptop via LAN IP |
| **Production** | Linux GPU server | vLLM serving quantised model |

### Model config rule

Switching environments requires changing **exactly two env vars**:

```
VLLM_BASE_URL=<inference endpoint>/v1
MODEL_NAME=<model name as served>
```

No other code changes. The embedding worker also reads `OLLAMA_BASE_URL` and `EMBEDDING_MODEL`, which typically stay the same across all three environments.

---

## Conventions

### Networking
- All services run on a single Docker network named **`socai-net`**.
- Services address each other by **container name**, never `localhost`.
  - Correct: `http://opensearch:9200`
  - Wrong: `http://localhost:9200`

### Compose files
- Every `image:` line in every Compose file must pin an **exact version tag** (e.g. `redpanda:v24.1.7`). Never use `latest`.

### Python services
- All Python services emit **structured JSON logs** — use `structlog` or `python-json-logger`.
- No `print()` statements in service code.
- All services read config exclusively from environment variables (via `pydantic-settings` or `os.environ`).

### Secrets
- **Never commit `.env` files.** Only `.env.example` is committed.
- Default credentials in `.env.example` are placeholders — change all passwords before any non-dev deployment.

### Directory layout
```
agents/          # LangGraph agent code
  triage/        # Alert triage agent
  shared/        # Shared tools, prompts, utilities
docker/
  compose/       # docker-compose.yml and overrides
  configs/       # Service config files (Vector, OpenSearch, etc.)
pipeline/
  vector/        # Vector pipeline config
  schemas/       # JSON/Avro schemas for Redpanda topics
services/
  feedback/      # Analyst feedback web UI
  embedding/     # Embedding worker (reads from Redpanda, writes to Qdrant)
data/
  models/        # Local model weights (gitignored except .gitkeep)
  feedback/      # Feedback exports (gitignored except .gitkeep)
scripts/
  test/          # Integration and smoke test scripts
  deploy/        # Deployment helper scripts
docs/
  runbooks/      # Operational runbooks
```

---

## Common Commands

```bash
# Start the full stack
docker compose -f docker/compose/docker-compose.yml up -d

# Rebuild a single service after code changes
docker compose -f docker/compose/docker-compose.yml up -d --build <service-name>

# Tail logs for all services
docker compose -f docker/compose/docker-compose.yml logs -f

# Tail logs for one service
docker compose -f docker/compose/docker-compose.yml logs -f <service-name>

# Stop everything (preserves volumes)
docker compose -f docker/compose/docker-compose.yml down

# Stop and wipe all volumes (destructive — resets all data)
docker compose -f docker/compose/docker-compose.yml down -v

# Run Python unit tests
pytest agents/ services/ -v

# Run integration / smoke tests
bash scripts/test/smoke.sh
```
