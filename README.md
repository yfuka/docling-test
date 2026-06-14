# Docling GPU 検証環境

NVIDIA GPU 上で Docling Serve を Docker Compose で起動し、PDF、DOCX、PPTX、
XLSX などをまとめて変換するための検証環境です。

既定では Docling Serve `v1.23.0` の CUDA 12.8 イメージを使用します。

## GPU マシンの前提

- Linux
- NVIDIA ドライバー
- Docker Engine と Docker Compose v2
- NVIDIA Container Toolkit
- Bash、curl

まず GPU がコンテナから見えることを確認してください。

```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.8.1-base-ubuntu24.04 nvidia-smi
```

## 設定

```bash
cp .env.example .env
chmod +x scripts/*.sh
```

必要に応じて `.env` を編集します。日本語 OCR を試す場合は、使用する OCR
エンジンに合わせて `DOCLING_OCR_LANG` を設定してください。

## デプロイと確認

```bash
./scripts/up.sh
./scripts/check.sh
```

- UI: `http://GPUマシン:5001/ui`
- OpenAPI: `http://GPUマシン:5001/docs`

`check` はコンテナ内で `nvidia-smi` を実行し、PyTorch の
`torch.cuda.is_available()` が真であることを検査します。

## 文書の一括変換

登録済みのOCR評価用入力を展開します。

```bash
tar -xf evaluation/ocr_inputs.tar
```

独自の検証対象を使う場合は、ファイルを `documents/` に配置します。

```bash
./scripts/convert.sh standard
```

対応する検証対象は PDF、DOCX、PPTX、XLSX、HTML、Markdown、CSV、主要画像形式です。
OCR、表構造認識、正確な表モードを有効にし、Markdown と Docling JSON を
`results/standard/<元ファイル名>.json` に保存します。

### PDF 内の図版へのキャプション生成

`standard` pipeline では、本文や表の変換を維持したまま、PDF 内で図版として
検出された画像だけを VLM で説明できます。デフォルトでは無効です。
有効にする場合は `.env` を次のように設定します。

```dotenv
DOCLING_DO_PICTURE_DESCRIPTION=true
```

`DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG`には、後述のvLLM用設定を使用します。
その後、通常どおり実行します。

```bash
./scripts/convert.sh standard
```

カスタム設定内の`picture_area_threshold`は、ページ面積に対して説明対象とする
図版の最小割合です。`0.05`ならページ面積の5%未満の小さな図版は除外します。
生成された説明は Markdown と Docling JSON 内の図版要素に含まれます。

これはページ全体を VLM で読み取る `./scripts/convert.sh vlm` とは別機能です。
無効に戻す場合は `DOCLING_DO_PICTURE_DESCRIPTION=false` にします。

実際にキャプション生成へ渡される指示は、カスタム設定直下の `prompt` です。
`generation_config.max_new_tokens` で説明の最大長も調整できます。設定変更後は
Docling Serve を再起動してください。この設定は Compose 内の `vllm-openai` を使うため、
`./scripts/up.sh` で Docling Serve と vLLM の両方を起動します。

VLM pipeline は PDF と画像を対象に実行します。DOCX、PPTX、XLSX は VLM
pipeline の対応外であるため、standard pipeline で検証してください。

```bash
./scripts/convert.sh vlm
```

結果は`results/vlm/`に保存されます。

### 外部 VLM への切り替え

Ollama、vLLM、LM Studio、クラウドサービスなどの OpenAI 互換
`/v1/chat/completions` エンドポイントへ切り替えられます。

#### vLLM でセルフホストする

Compose の `vllm` profile で、OpenAI 互換 API を提供する `vllm-openai` を
必要な場合だけ起動できます。`.env` の次の値を GPU メモリと使用するモデルに
合わせて変更してください。

```dotenv
VLLM_IMAGE=vllm/vllm-openai:latest
VLLM_PORT=8000
VLLM_URL=http://localhost:8000
VLLM_MODEL=Qwen/Qwen3.5-2B
VLLM_SERVED_MODEL_NAME=qwen3.5-2b
VLLM_GPU_MEMORY_UTILIZATION=0.6
VLLM_MAX_MODEL_LEN=8192
HF_TOKEN=
```

非公開または利用承諾が必要な Hugging Face モデルでは `HF_TOKEN` を設定します。
Docling から同じ Compose 内の vLLM へ接続するため、VLM 設定も変更します。

```dotenv
DOCLING_VLM_CUSTOM_CONFIG='{"model_spec":{"name":"Self-hosted VLM","default_repo_id":"qwen3.5-2b","prompt":"Convert this page to markdown. Do not miss any text and only output the bare markdown!","response_format":"markdown","supported_engines":["api"],"api_overrides":{"api":{"params":{"model":"qwen3.5-2b","max_tokens":4096}}}},"engine_options":{"engine_type":"api","url":"http://vllm-openai:8000/v1/chat/completions","headers":{},"params":{"model":"qwen3.5-2b","max_tokens":4096},"timeout":120,"concurrency":1},"scale":2.0,"batch_size":1}'
DOCLING_DO_PICTURE_DESCRIPTION=true
DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG='{"model_spec":{"name":"Self-hosted picture description VLM","default_repo_id":"qwen3.5-2b","prompt":"Describe this image in Japanese. Include visible text and explain charts, axes, legends, and trends when present.","response_format":"plaintext","supported_engines":["api"],"api_overrides":{"api":{"params":{"model":"qwen3.5-2b","max_tokens":512}}}},"engine_options":{"engine_type":"api","url":"http://vllm-openai:8000/v1/chat/completions","headers":{},"params":{"model":"qwen3.5-2b","max_tokens":512},"timeout":120,"concurrency":1},"prompt":"Describe this image in Japanese. Include visible text and explain charts, axes, legends, and trends when present.","generation_config":{"max_new_tokens":512,"do_sample":false},"picture_area_threshold":0.05,"batch_size":1,"scale":2.0}'
```

`VLLM_SERVED_MODEL_NAME` と JSON 内の `model` は同じ値にします。
`max_tokens` は `VLLM_MAX_MODEL_LEN` より小さくし、画像とプロンプト用の入力トークンを残します。
VLM pipeline を使う場合は `vllm` を指定して起動と確認を実行します。
画像説明だけを有効にした場合は、通常の `./scripts/up.sh` と `./scripts/check.sh` でも
vLLM が自動的に対象になります。

```bash
./scripts/up.sh vllm
./scripts/check.sh vllm
./scripts/convert.sh standard
./scripts/convert.sh vlm
```

モデルは `vllm-cache` Docker volume に保存されます。
`DOCLING_DO_PICTURE_DESCRIPTION=false` の通常起動では `vllm-openai` は起動しません。
Docling と vLLM が同じ GPU を使うため、メモリ不足になる場合は
`VLLM_GPU_MEMORY_UTILIZATION` を下げてください。

#### 別の OpenAI 互換 API を使う

`.env` で次を設定し、Docling Serve を再起動してください。

```dotenv
DOCLING_VLM_CUSTOM_CONFIG='{"model_spec":{"name":"External VLM","default_repo_id":"qwen2.5vl:7b","prompt":"Convert this page to markdown. Do not miss any text and only output the bare markdown!","response_format":"markdown","supported_engines":["api"],"api_overrides":{"api":{"params":{"model":"qwen2.5vl:7b","max_tokens":4096}}}},"engine_options":{"engine_type":"api","url":"http://host.docker.internal:11434/v1/chat/completions","headers":{},"params":{"model":"qwen2.5vl:7b","max_tokens":4096},"timeout":120,"concurrency":1},"scale":2.0,"batch_size":1}'
```

画像説明も外部APIへ送る場合は、`DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG`内の
`url`と`model`も同じ接続先に変更します。Bearer認証を使う場合の`headers`は
次の形式です。

```json
{"Authorization":"Bearer API_KEY"}
```

一般的な VLM は `response_format` を `markdown` にします。DocTags を生成する
Docling 専用モデルだけ、`doctags` を指定してください。API キーを含む `.env` は
Git に追加しないでください。

GPU 使用状況は別ターミナルで確認できます。

```bash
watch -n 1 nvidia-smi
```

停止は次のコマンドです。

```bash
./scripts/down.sh
```

## 補足

- 初回起動はイメージ取得とモデル読み込みに時間がかかります。
- Office 文書は内容によって GPU 負荷が小さい場合があります。GPU の効果を確認する
  には、スキャン PDF、画像を含む PDF、複雑な表を含む PDF も試してください。
- CUDA イメージには `latest` タグがないため、`.env` でバージョンを明示しています。
