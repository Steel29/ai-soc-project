#!/usr/bin/env bash
# Smoke test for the SOC AI infrastructure stack.
# Run from the project root after the stack is up:
#   docker compose -f docker/compose/infrastructure.yml up -d
#   bash scripts/test/test-infrastructure.sh

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
header() { echo -e "\n${YELLOW}--- $1 ---${NC}"; }

http_ok() {
  local label="$1"
  local url="$2"
  if curl -sf --max-time 8 "$url" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label  ($url)"
  fi
}

echo "=========================================="
echo "  SOC AI Infrastructure Health Check"
echo "=========================================="

# --- Redpanda ---
header "Redpanda"
http_ok "Admin API reachable"       "http://localhost:9644/v1/brokers"
http_ok "Schema registry reachable" "http://localhost:8081/subjects"
http_ok "Console UI reachable"      "http://localhost:8080"

# --- OpenSearch ---
header "OpenSearch"
http_ok "Cluster health"   "http://localhost:9200/_cluster/health"
http_ok "Dashboards UI"    "http://localhost:5601/api/status"

# --- Qdrant ---
header "Qdrant"
http_ok "Health endpoint" "http://localhost:6333/healthz"

# --- MinIO ---
header "MinIO"
http_ok "Health endpoint" "http://localhost:9000/minio/health/live"

# --- PostgreSQL ---
header "PostgreSQL"
if docker exec postgres pg_isready -U "${POSTGRES_USER:-socai}" -q 2>/dev/null; then
  pass "Accepting connections"
else
  fail "Not ready (is the container running?)"
fi

# --- Kafka topics ---
header "Kafka Topics"
TOPICS="raw.siem norm.events enriched.events ai.triage.output feedback.events"

for topic in $TOPICS; do
  # Attempt to create — rpk is idempotent via the output check below
  docker exec redpanda rpk topic create "$topic" \
    --partitions 3 --replicas 1 > /dev/null 2>&1 || true

  if docker exec redpanda rpk topic list 2>/dev/null | grep -qF "$topic"; then
    pass "Topic ready: $topic"
  else
    fail "Topic unavailable: $topic"
  fi
done

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo ""
echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}Results: $PASS/$TOTAL passed — All checks PASSED.${NC}"
  exit 0
else
  echo -e "  ${RED}Results: $PASS/$TOTAL passed — $FAIL check(s) FAILED.${NC}"
  echo ""
  echo "  Is the stack running? Start it with:"
  echo "    docker compose -f docker/compose/infrastructure.yml up -d"
  echo ""
  echo "  Wait ~30 s for services to initialise, then re-run this script."
  exit 1
fi
