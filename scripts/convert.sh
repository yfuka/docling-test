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
: "${DOCLING_INPUT_DIR:?DOCLING_INPUT_DIR を .env に設定してください。}"
: "${DOCLING_OUTPUT_DIR:?DOCLING_OUTPUT_DIR を .env に設定してください。}"

pipeline="${1:-standard}"
if [[ "${pipeline}" != "standard" && "${pipeline}" != "vlm" ]]; then
  echo "使い方: $0 [standard|vlm]" >&2
  exit 1
fi

if [[ "${pipeline}" == "standard" ]]; then
  : "${DOCLING_DO_PICTURE_DESCRIPTION:?DOCLING_DO_PICTURE_DESCRIPTION を .env に設定してください。}"
  if [[ "${DOCLING_DO_PICTURE_DESCRIPTION}" != "true" && "${DOCLING_DO_PICTURE_DESCRIPTION}" != "false" ]]; then
    echo "DOCLING_DO_PICTURE_DESCRIPTION は true または false を指定してください。" >&2
    exit 1
  fi
  if [[ "${DOCLING_DO_PICTURE_DESCRIPTION}" == "true" ]]; then
    : "${DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG:?DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG を .env に設定してください。}"
  fi
else
  : "${DOCLING_VLM_CUSTOM_CONFIG:?DOCLING_VLM_CUSTOM_CONFIG を .env に設定してください。}"
fi

output_dir="${DOCLING_OUTPUT_DIR}/${pipeline}"
mkdir -p "${output_dir}"

shopt -s nullglob nocaseglob
if [[ "${pipeline}" == "standard" ]]; then
  files=(
    "${DOCLING_INPUT_DIR}"/*.pdf
    "${DOCLING_INPUT_DIR}"/*.docx
    "${DOCLING_INPUT_DIR}"/*.pptx
    "${DOCLING_INPUT_DIR}"/*.xlsx
    "${DOCLING_INPUT_DIR}"/*.html
    "${DOCLING_INPUT_DIR}"/*.md
    "${DOCLING_INPUT_DIR}"/*.csv
    "${DOCLING_INPUT_DIR}"/*.png
    "${DOCLING_INPUT_DIR}"/*.jpg
    "${DOCLING_INPUT_DIR}"/*.jpeg
    "${DOCLING_INPUT_DIR}"/*.tif
    "${DOCLING_INPUT_DIR}"/*.tiff
  )
else
  files=(
    "${DOCLING_INPUT_DIR}"/*.pdf
    "${DOCLING_INPUT_DIR}"/*.png
    "${DOCLING_INPUT_DIR}"/*.jpg
    "${DOCLING_INPUT_DIR}"/*.jpeg
    "${DOCLING_INPUT_DIR}"/*.tif
    "${DOCLING_INPUT_DIR}"/*.tiff
  )
fi

if (( ${#files[@]} == 0 )); then
  echo "${DOCLING_INPUT_DIR} に検証対象ファイルがありません。" >&2
  exit 1
fi

failed=0
for file in "${files[@]}"; do
  name="$(basename "$file")"
  output="${output_dir}/${name}.json"
  echo "変換中: ${name} (${pipeline})"

  form_options=(
    --form "files=@${file}"
    --form "to_formats=md"
    --form "to_formats=json"
    --form "image_export_mode=embedded"
    --form "abort_on_error=false"
  )

  if [[ "${pipeline}" == "standard" ]]; then
    form_options+=(
      --form "pipeline=standard"
      --form "do_ocr=true"
      --form 'ocr_custom_config={"kind":"rapidocr","lang":["chinese"],"backend":"torch","det_model_path":"/opt/app-root/src/.cache/docling/models/RapidOcr/custom/ppocrv5-server/ch_PP-OCRv5_det_server.pth","cls_model_path":"/opt/app-root/src/.cache/docling/models/RapidOcr/custom/ppocrv5-server/ch_ptocr_mobile_v2.0_cls_mobile.pth","rec_model_path":"/opt/app-root/src/.cache/docling/models/RapidOcr/custom/ppocrv5-server/ch_PP-OCRv5_rec_server.pth","rec_keys_path":"/opt/app-root/src/.cache/docling/models/RapidOcr/custom/ppocrv5-server/keys.txt"}'
      --form "do_table_structure=true"
      --form "table_mode=accurate"
    )
    if [[ "${DOCLING_DO_PICTURE_DESCRIPTION}" == "true" ]]; then
      form_options+=(
        --form "do_picture_description=true"
        --form "picture_description_custom_config=${DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG}"
      )
    fi
  else
    from_format=image
    if [[ "${file,,}" == *.pdf ]]; then
      from_format=pdf
    fi
    form_options+=(
      --form "pipeline=vlm"
      --form "from_formats=${from_format}"
    )
    form_options+=(--form "vlm_pipeline_custom_config=${DOCLING_VLM_CUSTOM_CONFIG}")
  fi

  http_code="$(
    curl --silent --show-error \
      --output "${output}" \
      --write-out "%{http_code}" \
      --request POST "${DOCLING_URL}/v1/convert/file" \
      "${form_options[@]}"
  )"

  if [[ "${http_code}" != "200" ]] \
    || ! grep -Eq '"status"[[:space:]]*:[[:space:]]*"(success|partial_success)"' "${output}" \
    || grep -Eq '"md_content"[[:space:]]*:[[:space:]]*(null|"")' "${output}"; then
    echo "失敗: ${name} (HTTP ${http_code})。応答: ${output}" >&2
    failed=1
  else
    echo "成功: ${output}"
  fi
done

exit "${failed}"
