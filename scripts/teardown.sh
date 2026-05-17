#!/usr/bin/env bash
# ── Teardown istio-demo ───────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[teardown]${NC} $*"; }
confirm() { read -r -p "$(echo -e "${RED}$* [y/N]: ${NC}")" ans; [[ "$ans" =~ ^[Yy]$ ]]; }

confirm "Delete istio-demo namespace + all services?" || { info "Aborted."; exit 0; }

info "Deleting istio-demo namespace..."
kubectl delete namespace istio-demo --timeout=60s 2>/dev/null || true

if confirm "Uninstall Istio control plane?"; then
  info "Uninstalling Istio..."
  istioctl uninstall --purge -y
  kubectl delete namespace istio-system --timeout=60s 2>/dev/null || true
fi

if confirm "Stop Minikube?"; then
  minikube stop
fi

echo -e "${GREEN}Teardown complete.${NC}"
