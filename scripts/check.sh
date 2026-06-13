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

docker compose ps
docker compose exec -T docling-serve nvidia-smi
docker compose exec -T docling-serve python -c \
  'import torch; print(f"torch={torch.__version__} cuda={torch.cuda.is_available()} devices={torch.cuda.device_count()}"); assert torch.cuda.is_available()'
curl --silent --fail "${DOCLING_URL}/version"
echo
