#!/bin/bash

set -e

echo "=== Switching PostgreSQL to Tuned Configuration ==="
echo ""

# Update the StatefulSet to use tuned config
kubectl patch statefulset postgres -n corebank --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/name",
    "value": "postgres-config-tuned"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env/1/valueFrom/configMapKeyRef/name",
    "value": "postgres-config-tuned"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env/2/valueFrom/configMapKeyRef/name",
    "value": "postgres-config-tuned"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/volumes/1/configMap/name",
    "value": "postgres-config-tuned"
  }
]'

echo "Deleting PostgreSQL pod to apply new configuration..."
kubectl delete pod postgres-0 -n corebank

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=300s statefulset/postgres -n corebank

echo ""
echo "=== PostgreSQL is now using tuned configuration ==="
echo ""
