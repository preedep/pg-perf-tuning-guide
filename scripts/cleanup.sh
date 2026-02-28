#!/bin/bash

set -e

echo "=== Cleaning up PostgreSQL Performance Tuning Guide ==="
echo ""

read -p "This will delete all resources in the 'corebank' namespace. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Deleting namespace and all resources..."
kubectl delete namespace corebank

echo ""
echo "=== Cleanup Complete ==="
echo ""
