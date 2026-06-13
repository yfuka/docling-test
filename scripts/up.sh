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

mode="${1:-docling}"
if [[ "${mode}" != "docling" && "${mode}" != "vllm" ]]; then
  echo "使い方: $0 [docling|vllm]" >&2
  exit 1
fi

nvidia-smi
if [[ "${mode}" == "vllm" ]]; then
  : "${VLLM_URL:?VLLM_URL を .env に設定してください。}"
  if [[ "${DOCLING_VLM_MODE}" != "api" || "${DOCLING_ENABLE_REMOTE_SERVICES}" != "true" || "${DOCLING_ALLOW_CUSTOM_VLM_CONFIG}" != "true" ]]; then
    echo "vllm モードでは Docling の API VLM 設定を有効にしてください。" >&2
    exit 1
  fi
  : "${DOCLING_VLM_CUSTOM_CONFIG:?DOCLING_VLM_CUSTOM_CONFIG を .env に設定してください。}"
  docker compose --profile vllm config --quiet
  docker compose --profile vllm up -d

  echo "vLLM の起動を待っています..."
  for _ in {1..120}; do
    if curl --silent --fail "${VLLM_URL}/v1/models" >/dev/null; then
      echo "vLLM が起動しました: ${VLLM_URL}/v1/models"
      break
    fi
    sleep 5
  done

  if ! curl --silent --fail "${VLLM_URL}/v1/models" >/dev/null; then
    docker compose --profile vllm logs --tail 100 vllm-openai
    echo "vLLM が10分以内に起動しませんでした。" >&2
    exit 1
  fi
else
  docker compose config --quiet
  docker compose up -d
fi

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
