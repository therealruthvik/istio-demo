#!/usr/bin/env bash
# ── Deploy istio-demo services ────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

# ── 1. Namespace (with istio-injection label) ─────────────────────────────────
info "Creating namespace with Istio injection enabled..."
kubectl apply -f "$ROOT/k8s/namespace/namespace.yaml"

# ── 2. Deploy services ────────────────────────────────────────────────────────
info "Deploying database-svc..."
kubectl apply -f "$ROOT/k8s/services/database-svc.yaml"

info "Deploying backend..."
kubectl apply -f "$ROOT/k8s/services/backend.yaml"

info "Deploying frontend..."
kubectl apply -f "$ROOT/k8s/services/frontend.yaml"

# ── 3. Apply Istio configs ────────────────────────────────────────────────────
info "Applying Istio Gateway..."
kubectl apply -f "$ROOT/k8s/istio/gateway.yaml"

info "Applying VirtualServices..."
kubectl apply -f "$ROOT/k8s/istio/virtual-services.yaml"

info "Applying DestinationRules..."
kubectl apply -f "$ROOT/k8s/istio/destination-rules.yaml"

info "Applying PeerAuthentication (strict mTLS)..."
kubectl apply -f "$ROOT/k8s/istio/peer-authentication.yaml"

# ── 4. Wait for pods ──────────────────────────────────────────────────────────
info "Waiting for pods to be ready (this may take 2-3 min)..."
kubectl wait --for=condition=ready pod -l app=database-svc -n istio-demo --timeout=180s
kubectl wait --for=condition=ready pod -l app=backend      -n istio-demo --timeout=180s
kubectl wait --for=condition=ready pod -l app=frontend     -n istio-demo --timeout=180s

# ── 5. Verify sidecar injection ───────────────────────────────────────────────
info "Verifying Istio sidecar injection (should show 2/2 READY):"
kubectl get pods -n istio-demo

# ── 6. Get access URL ────────────────────────────────────────────────────────
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Istio Demo deployed!                               ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  App:      http://${INGRESS_HOST}:${INGRESS_PORT}/                 ║${NC}"
echo -e "${CYAN}║  JSON:     http://${INGRESS_HOST}:${INGRESS_PORT}/api/products     ║${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  Kiali:    bash scripts/open-kiali.sh                ║${NC}"
echo -e "${CYAN}║  Jaeger:   bash scripts/open-jaeger.sh               ║${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  Fault inject demo:                                  ║${NC}"
echo -e "${CYAN}║    bash scripts/demo-fault-injection.sh              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
info "Save this URL: http://${INGRESS_HOST}:${INGRESS_PORT}"
