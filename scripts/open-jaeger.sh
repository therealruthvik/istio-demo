#!/usr/bin/env bash
# Open Jaeger distributed tracing UI

ISTIOCTL=$(find "$HOME" /usr/local/bin . -name "istioctl" -type f 2>/dev/null | head -1)

if [ -n "$ISTIOCTL" ]; then
  echo "Opening Jaeger via istioctl at http://localhost:16686 ..."
  "$ISTIOCTL" dashboard jaeger
else
  echo "istioctl not found – using kubectl port-forward instead..."
  echo "Opening Jaeger at http://localhost:16686 (Ctrl+C to close)"
  kubectl port-forward svc/tracing -n istio-system 16686:80
fi
