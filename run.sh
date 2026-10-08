#!/usr/bin/env bash
set -euo pipefail

PREFIX="krasilnikov-01"
APP_PORT="8003"
APP_INTERNAL_PORT="5001"
DB_PORT="8005"
MARKER="sitelab"
DATABASE_URL="postgresql://postgres:lab@host.docker.internal:${DB_PORT}/lab"

docker rm -f "${PREFIX}-web" "${PREFIX}-db" >/dev/null 2>&1 || true
docker build --build-arg VERSION=2.0 -t "${PREFIX}/probe:2.0" .
docker volume create "${PREFIX}-data" >/dev/null

docker run -d --name "${PREFIX}-db" \
  -e POSTGRES_PASSWORD=lab \
  -e POSTGRES_DB=lab \
  -v "${PREFIX}-data:/var/lib/postgresql/data" \
  -p "${DB_PORT}:5432" \
  postgres:16-alpine >/dev/null

docker run -d --name "${PREFIX}-web" \
  --add-host host.docker.internal:host-gateway \
  -e APP_PORT="${APP_INTERNAL_PORT}" \
  -e MARKER="${MARKER}" \
  -e DATABASE_URL="${DATABASE_URL}" \
  -p "${APP_PORT}:${APP_INTERNAL_PORT}" \
  "${PREFIX}/probe:2.0" >/dev/null

SECONDS=0
until curl -sf -m 3 "localhost:${APP_PORT}/notes" >/dev/null; do
  if [ "$SECONDS" -ge 60 ]; then
    echo "Приложение не дождалось базы за 60 секунд." >&2
    docker logs "${PREFIX}-web" >&2 || true
    exit 1
  fi
  sleep 2
done

curl -fsS "localhost:${APP_PORT}/notes" | python3 -m json.tool --no-ensure-ascii
