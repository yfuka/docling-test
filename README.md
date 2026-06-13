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
検出された画像だけを VLM で説明できます。`.env` を次のように設定します。

```dotenv
DOCLING_DO_PICTURE_DESCRIPTION=true
DOCLING_PICTURE_DESCRIPTION_MODE=preset
DOCLING_PICTURE_DESCRIPTION_PRESET=smolvlm
DOCLING_PICTURE_DESCRIPTION_AREA_THRESHOLD=0.05
```

その後、通常どおり実行します。

```bash
./scripts/convert.sh standard
```

`DOCLING_PICTURE_DESCRIPTION_AREA_THRESHOLD` は、ページ面積に対して説明対象とする
図版の最小割合です。`0.05` ならページ面積の 5% 未満の小さな図版は除外します。
生成された説明は Markdown と Docling JSON 内の図版要素に含まれます。

これはページ全体を VLM で読み取る `./scripts/convert.sh vlm` とは別機能です。
無効に戻す場合は `DOCLING_DO_PICTURE_DESCRIPTION=false` にします。

キャプションのプロンプトを変更する場合は、カスタム設定へ切り替えます。

```dotenv
DOCLING_PICTURE_DESCRIPTION_MODE=custom
DOCLING_ALLOW_CUSTOM_PICTURE_DESCRIPTION_CONFIG=true
DOCLING_PICTURE_DESCRIPTION_CUSTOM_CONFIG='{"model_spec":{"name":"SmolVLM-256M","default_repo_id":"HuggingFaceTB/SmolVLM-256M-Instruct","prompt":"図版を日本語で説明してください。","response_format":"plaintext","engine_overrides":{"transformers":{"torch_dtype":"bfloat16","extra_config":{"transformers_model_type":"automodel-imagetexttotext"}}}},"engine_options":{"engine_type":"auto_inline"},"prompt":"図版を日本語で説明してください。図表の場合は傾向、軸、凡例も含めてください。","generation_config":{"max_new_tokens":300,"do_sample":false},"picture_area_threshold":0.05,"batch_size":8,"scale":2.0}'
```

実際にキャプション生成へ渡される指示は、カスタム設定直下の `prompt` です。
`generation_config.max_new_tokens` で説明の最大長も調整できます。設定変更後は
Docling Serve を再起動してください。

VLM pipeline は PDF と画像を対象に実行します。DOCX、PPTX、XLSX は VLM
pipeline の対応外であるため、standard pipeline で検証してください。

```bash
./scripts/convert.sh vlm
```

既定の VLM プリセットは `granite_docling` で、`.env` の
`DOCLING_VLM_PRESET` から変更できます。初回実行時は VLM モデルの取得に時間が
かかる場合があります。結果は `results/vlm/` に保存されます。

### 外部 VLM への切り替え

Ollama、vLLM、LM Studio、クラウドサービスなどの OpenAI 互換
`/v1/chat/completions` エンドポイントへ切り替えられます。

`.env` で次を設定し、Docling Serve を再起動してください。

```dotenv
DOCLING_VLM_MODE=api
DOCLING_LOAD_MODELS_AT_BOOT=false
DOCLING_ENABLE_REMOTE_SERVICES=true
DOCLING_ALLOW_CUSTOM_VLM_CONFIG=true
DOCLING_VLM_CUSTOM_CONFIG='{"model_spec":{"name":"External VLM","default_repo_id":"qwen2.5vl:7b","prompt":"Convert this page to markdown. Do not miss any text and only output the bare markdown!","response_format":"markdown","supported_engines":["api"],"api_overrides":{"api":{"params":{"model":"qwen2.5vl:7b","max_tokens":8192}}}},"engine_options":{"engine_type":"api","url":"http://host.docker.internal:11434/v1/chat/completions","headers":{},"params":{"model":"qwen2.5vl:7b","max_tokens":8192},"timeout":120,"concurrency":1},"scale":2.0,"batch_size":1}'
```

`url`、`model`、`headers` を接続先に合わせて変更します。Bearer 認証を使う場合の
`headers` は次の形式です。

```json
{"Authorization":"Bearer API_KEY"}
```

一般的な VLM は `response_format` を `markdown` にします。DocTags を生成する
Docling 専用モデルだけ、`doctags` を指定してください。API キーを含む `.env` は
Git に追加しないでください。

ローカルプリセットへ戻す場合は、次の設定に戻して再起動します。

```dotenv
DOCLING_VLM_MODE=preset
DOCLING_LOAD_MODELS_AT_BOOT=true
DOCLING_ENABLE_REMOTE_SERVICES=false
DOCLING_ALLOW_CUSTOM_VLM_CONFIG=false
```

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
