#!/usr/bin/env sh
# Stop all containers (no-op if none are running), rebuild with no cache, then up with force recreate.
set -e

cd "$(dirname "$0")"

echo "Stopping containers (docker compose down)..."
docker compose down || true

echo "Building with no cache..."
docker compose build --no-cache

echo "Starting with force recreate..."
docker compose up -d --force-recreate

echo "Done. App at http://localhost:8080"
