#!/usr/bin/env bash
# ── Install Istio on Minikube ─────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[istio-install]${NC} $*"; }
warn() { echo -e "${YELLOW}[istio-install]${NC} $*"; }

ISTIO_VERSION="1.21.2"

# ── 1. Start Minikube with enough resources ───────────────────────────────────
info "Starting Minikube (4 CPU, 8GB RAM)..."
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --kubernetes-version=v1.29.0 \
  --wait=all

# ── 2. Download istioctl ──────────────────────────────────────────────────────
if ! command -v istioctl &>/dev/null; then
  info "Downloading istioctl ${ISTIO_VERSION}..."
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
  export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
  echo "export PATH=\"\$PWD/istio-${ISTIO_VERSION}/bin:\$PATH\"" >> ~/.zshrc 2>/dev/null || true
  echo "export PATH=\"\$PWD/istio-${ISTIO_VERSION}/bin:\$PATH\"" >> ~/.bashrc 2>/dev/null || true
  info "istioctl installed. Add to PATH: export PATH=\"\$PWD/istio-${ISTIO_VERSION}/bin:\$PATH\""
else
  info "istioctl already installed: $(istioctl version --remote=false 2>/dev/null || echo 'unknown')"
fi

# ── 3. Install Istio (demo profile = Kiali + Jaeger + Prometheus included) ───
info "Installing Istio with demo profile..."
istioctl install --set profile=demo -y

# ── 4. Wait for Istio control plane ──────────────────────────────────────────
info "Waiting for Istio control plane..."
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n istio-system --timeout=120s

# ── 5. Install Kiali + Prometheus + Jaeger addons ────────────────────────────
info "Installing observability addons (Kiali, Prometheus, Jaeger, Grafana)..."
ISTIO_DIR=$(find . -maxdepth 2 -name "istio-${ISTIO_VERSION}" -type d 2>/dev/null | head -1)
if [ -n "$ISTIO_DIR" ]; then
  kubectl apply -f "${ISTIO_DIR}/samples/addons/"
else
  # Fallback – apply from upstream
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/prometheus.yaml
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/kiali.yaml
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/jaeger.yaml
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/grafana.yaml
fi

info "Waiting for Kiali..."
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=120s || warn "Kiali not ready yet – retry in a moment"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Istio installed successfully!       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
info "Next: bash scripts/deploy.sh"
