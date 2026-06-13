# OCR評価

`ocr_expected.json` は、各サンプルをDoclingで変換した際に期待する文字列と表内容を定義します。

評価対象はDocling Serveレスポンスの `document.md_content` です。次のルールを重み付きで採点します。

- `required_terms`: 必須文字列
- `regex`: 日付、住所、電話番号などの正規表現
- `ordered_terms`: 見出しや表行の出現順
- `tables`: 表見出しと各行に含まれる値

全角・半角、`O/0`、`I/1/l` も評価対象なので、文字幅の正規化は行いません。改行や連続空白だけを同一視します。

## 実行

standard pipelineの結果をまとめて評価します。

```bash
python scripts/evaluate_ocr.py results/standard/japanese_ocr_*.json
```

1件だけ別名の結果を評価する場合は、元文書名を指定します。

```bash
python scripts/evaluate_ocr.py result.json --source japanese_ocr_image.pdf
```

JSONレポートも保存できます。

```bash
python scripts/evaluate_ocr.py results/standard/japanese_ocr_*.json \
  --output results/standard/ocr_evaluation.json
```

すべて合格なら終了コード `0`、変換失敗、必須出力の欠落、閾値未満が1件でもあれば `1` を返します。
