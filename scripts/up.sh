#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo ".env がありません。.env.example をコピーして設定してください。" >&2
  exit 1
fi

set -a
source .env
set +a

: "${DOCLING_URL:?DOCLING_URL を .env に設定してください。}"

nvidia-smi
docker compose config --quiet
docker compose up -d

echo "Docling Serve の起動を待っています..."
for _ in {1..120}; do
  if curl --silent --fail "${DOCLING_URL}/version" >/dev/null; then
    echo "起動しました: ${DOCLING_URL}/ui"
    exit 0
  fi
  sleep 5
done

docker compose logs --tail 100 docling-serve
echo "Docling Serve が10分以内に起動しませんでした。" >&2
exit 1
