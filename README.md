# SOC AI — On-Premises Security Operations Assistant

This project is a fully on-premises AI pipeline for a Security Operations Centre (SOC). It ingests raw alerts from a SIEM (LogRhythm), enriches and triages them with a locally-hosted large language model, stores embeddings and vector context in Qdrant, and surfaces analyst feedback through a lightweight web UI. No data leaves the network: all AI inference runs on-site via Ollama (dev) or vLLM on a GPU server (staging/production). The system is composed of Docker containers orchestrated with Compose and communicates internally through Redpanda (Kafka-compatible) message queues.

---

## Environments

| Setting | Dev (Windows laptop) | Staging (Linux server) | Production (GPU server) |
|---|---|---|---|
| `VLLM_BASE_URL` | `http://host.docker.internal:11434/v1` | `http://192.168.1.50:11434/v1` | `http://gpu-server-ip:8000/v1` |
| `MODEL_NAME` | `gemma4` (or `llama3.1:8b`) | `gemma4` | `phi-4-triage` |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | `http://192.168.1.50:11434` | *(not used — vLLM serves both)* |
| `EMBEDDING_MODEL` | `nomic-embed-text` | `nomic-embed-text` | `nomic-embed-text` |
| Passwords | defaults from `.env.example` | **must be changed** | **must be changed** |
| `FEEDBACK_UI_PORT` | `8888` | `8888` | `443` (behind reverse proxy) |

All other variables stay the same across environments unless infrastructure hostnames differ.

The rule for switching environments is simple: **only `VLLM_BASE_URL` and `MODEL_NAME` need to change** to point the stack at a different inference backend.

---

## Running Locally (dev — Windows laptop)

**Prerequisites:** Docker Desktop with WSL2 backend, Ollama installed and running on Windows.

```bash
# 1. Pull the models you'll use (run in Windows terminal or WSL2)
ollama pull gemma4
ollama pull nomic-embed-text

# 2. Copy the example env file — defaults work as-is for dev
cp .env.example .env

# 3. Start all services
docker compose -f docker/compose/docker-compose.yml up -d

# 4. Tail logs
docker compose -f docker/compose/docker-compose.yml logs -f
```

The feedback UI will be available at `http://localhost:8888`.

> Docker containers reach Ollama on the Windows host via `host.docker.internal:11434`.
> This is already set as the default in `.env.example`.

---

## Deploying to Staging

```bash
# On your laptop — push your branch
git push origin main

# SSH into the staging server
ssh user@staging-server

# Pull latest code
cd /opt/soc-ai
git pull origin main

# Update env for staging (point at laptop LAN IP for Ollama, change passwords)
nano .env

# Rebuild and restart only changed containers
docker compose -f docker/compose/docker-compose.yml up -d --build
```

For production, follow the same steps on the GPU server and set `VLLM_BASE_URL` to the vLLM endpoint and `MODEL_NAME` to the served model name. Rotate all credentials from the defaults before starting.
