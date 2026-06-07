# SOC AI — On-Premises Security Operations Assistant

This project is a fully on-premises AI pipeline for a Security Operations Centre (SOC). It ingests raw alerts from a SIEM (LogRhythm), enriches and triages them with a locally-hosted large language model, stores embeddings and vector context in Qdrant, and surfaces analyst feedback through a lightweight web UI. No data leaves the network: all AI inference runs on-site via Ollama (dev) or vLLM on a GPU server (staging/production). The system is composed of Docker containers orchestrated with Compose and communicates internally through Redpanda (Kafka-compatible) message queues.

---

## Environments

| Setting | Dev (Windows laptop) | Staging (Linux server) | Production (Linux server + GPU) |
|---|---|---|---|
| `VLLM_BASE_URL` | `http://localhost:11434/v1` (Ollama) | `http://staging-gpu:8000/v1` (vLLM) | `http://prod-gpu:8000/v1` (vLLM) |
| `MODEL_NAME` | `llama3.2:8b-instruct-q4_K_M` | `phi-4-triage` | `phi-4-triage` |
| `REDPANDA_BROKERS` | `redpanda:9092` | `redpanda:9092` | `redpanda:9092` |
| `OPENSEARCH_HOST` | `http://opensearch:9200` | `http://opensearch:9200` | `http://opensearch:9200` |
| Passwords | defaults from `.env.example` | **must be changed** | **must be changed** |
| `FEEDBACK_UI_PORT` | `8888` | `8888` | `443` (behind reverse proxy) |

All other variables stay the same across environments unless infrastructure hostnames differ.

---

## Running Locally (dev)

**Prerequisites:** Docker Desktop, Ollama installed and running on the host.

```bash
# 1. Pull the model you'll use
ollama pull llama3.2:8b-instruct-q4_K_M

# 2. Copy the example env file and leave the defaults for local use
cp .env.example .env

# 3. Start all services
docker compose -f docker/compose/docker-compose.yml up -d

# 4. Tail logs
docker compose -f docker/compose/docker-compose.yml logs -f
```

The feedback UI will be available at `http://localhost:8888`.

> On Windows, Ollama on the host is reachable from containers via `host.docker.internal`.
> Update `VLLM_BASE_URL=http://host.docker.internal:11434/v1` in your `.env` if needed.

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

# Update env if any new variables were added
diff .env .env.example

# Rebuild and restart changed containers only
docker compose -f docker/compose/docker-compose.yml up -d --build
```

For production, follow the same steps on the production server and ensure credentials in `.env` are rotated from the defaults. Verify `VLLM_BASE_URL` points to the GPU inference server before restarting.
