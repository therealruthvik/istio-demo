#!/usr/bin/env bash
# Open Kiali service mesh dashboard

ISTIOCTL=$(find "$HOME" /usr/local/bin . -name "istioctl" -type f 2>/dev/null | head -1)

if [ -n "$ISTIOCTL" ]; then
  echo "Opening Kiali via istioctl at http://localhost:20001 ..."
  "$ISTIOCTL" dashboard kiali
else
  echo "istioctl not found – using kubectl port-forward instead..."
  echo "Opening Kiali at http://localhost:20001 (Ctrl+C to close)"
  kubectl port-forward svc/kiali -n istio-system 20001:20001
fi
