#!/usr/bin/env bash
set -e

echo "🚀 Rebuilding backend containers & running DB migrations..."
docker compose -f infra/docker-compose.yml up --build -d

echo ""
echo "------------------------------------------------"
echo "📊 Migration Execution Logs:"
echo "------------------------------------------------"
docker compose -f infra/docker-compose.yml logs migrate

echo ""
echo "------------------------------------------------"
echo "✅ Active Service Status:"
echo "------------------------------------------------"
docker compose -f infra/docker-compose.yml ps
