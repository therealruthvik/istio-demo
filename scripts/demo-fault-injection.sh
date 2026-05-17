#!/usr/bin/env bash
# ── Fault Injection Demo ──────────────────────────────────────────────────────
# Shows Istio retries absorbing errors from database-svc
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[demo]${NC} $*"; }
warn()    { echo -e "${YELLOW}[demo]${NC} $*"; }
section() { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
URL="http://${INGRESS_HOST}:${INGRESS_PORT}"

section "1. Baseline — everything healthy"
info "Sending 5 requests with no faults..."
for i in {1..5}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL/api/products")
  echo "  Request $i → HTTP $STATUS"
  sleep 0.5
done

section "2. Injecting faults into database-svc"
warn "Applying: 50% delay (3s) + 20% HTTP 500 errors on database-svc"
kubectl apply -f "$(dirname "$0")/../k8s/istio/fault-injection.yaml"
sleep 3

info "Sending 10 requests WITH faults (Istio retries should hide most errors)..."
SUCCESS=0; FAIL=0
for i in {1..10}; do
  START=$(date +%s%N)
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL/api/products" || echo "000")
  END=$(date +%s%N)
  MS=$(( (END - START) / 1000000 ))
  if [ "$STATUS" = "200" ]; then
    echo -e "  Request $i → ${GREEN}HTTP $STATUS${NC} (${MS}ms)"
    ((SUCCESS++))
  else
    echo -e "  Request $i → ${RED}HTTP $STATUS${NC} (${MS}ms)"
    ((FAIL++))
  fi
  sleep 0.5
done

echo ""
info "Results: ${SUCCESS}/10 success, ${FAIL}/10 failed"
info "Retries absorbed most 500s. Delays visible in response times."

section "3. Removing fault injection"
kubectl delete -f "$(dirname "$0")/../k8s/istio/fault-injection.yaml"
info "Faults removed. System back to normal."

section "4. Verifying recovery"
for i in {1..3}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL/api/products")
  echo -e "  Request $i → ${GREEN}HTTP $STATUS${NC}"
  sleep 0.5
done

echo ""
echo -e "${GREEN}Demo complete! Open Kiali to see the mesh graph:${NC}"
echo "  bash scripts/open-kiali.sh"
