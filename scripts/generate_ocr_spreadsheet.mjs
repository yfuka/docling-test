import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = new URL("../documents/", import.meta.url);
await fs.mkdir(outputDir, { recursive: true });

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("OCR評価表");
const imageSheet = workbook.worksheets.add("帳票画像");
sheet.showGridLines = false;
imageSheet.showGridLines = false;

sheet.getRange("A1:F1").merge();
sheet.getRange("A1").values = [["日本語 OCR・表抽出 評価サンプル"]];
sheet.getRange("A1:F1").format = {
  fill: "#2E5D7B",
  font: { name: "Yu Gothic", size: 18, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange("A1:F1").format.rowHeight = 34;

sheet.getRange("A2:F2").merge();
sheet.getRange("A2").values = [[
  "セル結合、漢字、かな、英数字、日付、金額、似た字形、複数行セルの抽出確認用"
]];
sheet.getRange("A2:F2").format = {
  fill: "#E8F1F6",
  font: { name: "Yu Gothic", size: 10, color: "#2E5D7B" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange("A2:F2").format.rowHeight = 26;

const values = [
  ["伝票番号", "取引先・住所", "商品名", "数量", "金額（税込）", "備考・判別文字"],
  ["INV-2026-00081", "株式会社 青空物流\n東京都千代田区丸の内1-2-3", "抹茶入り緑茶 500ml", 12, "¥1,280", "O0Q / I1l"],
  ["JP13-0001-0427", "北海食品株式会社\n北海道札幌市北区北7条西2丁目", "国産りんご（ふじ）", 8, "¥3,456", "S5 / B8 / Z2"],
  ["ORD-A-00105", "有限会社みなと精工\n神奈川県横浜市中区海岸通4-5", "精密ねじ M3×12", 250, "¥2,450", "0/O、rn/m"],
  ["REQ-808-C15", "西日本デジタル合同会社\n大阪府大阪市北区梅田3-1-1", "USB-C ケーブル 1.5m", 3, "¥6,600", "I/1/l、全角Ａ１"],
];
sheet.getRange("A4:F8").values = values;
sheet.getRange("A4:F4").format = {
  fill: "#DCE6ED",
  font: { name: "Yu Gothic", size: 10, bold: true, color: "#1F4055" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#91A4B0" },
};
sheet.getRange("A5:F8").format = {
  font: { name: "Yu Gothic", size: 10, color: "#222222" },
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#C7D1D8" },
};
sheet.getRange("D5:D8").format.horizontalAlignment = "center";
sheet.getRange("A4:F4").format.rowHeight = 30;
sheet.getRange("A5:F8").format.rowHeight = 46;

sheet.getRange("A10:B10").values = [["項目", "文字列"]];
sheet.getRange("A11:B15").values = [
  ["ひらがな", "あいうえお・がぎぐげご・ぱぴぷぺぽ"],
  ["カタカナ", "アイウエオ・ヴァイオリン・コンピューター"],
  ["全角半角", "ＡＢＣ１２３ / ABC123 / ﾊﾝｶｸｶﾅ"],
  ["記号", "「」『』（）［］【】・…―〜／￥〒 ※ ○ × △ □"],
  ["連絡先", "03-1234-5678 / ocr-test@example.jp"],
];
sheet.getRange("A10:B10").format = {
  fill: "#DCE6ED",
  font: { name: "Yu Gothic", size: 10, bold: true, color: "#1F4055" },
  horizontalAlignment: "center",
  borders: { preset: "all", style: "thin", color: "#91A4B0" },
};
sheet.getRange("A11:B15").format = {
  font: { name: "Yu Gothic", size: 10, color: "#222222" },
  wrapText: true,
  verticalAlignment: "center",
  borders: { preset: "all", style: "thin", color: "#C7D1D8" },
};
sheet.getRange("A11:A15").format.fill = "#F2F4F7";
sheet.getRange("A11:A15").format.font = {
  name: "Yu Gothic", size: 10, bold: true, color: "#2E5D7B"
};
sheet.getRange("A10:B15").format.rowHeight = 26;

sheet.freezePanes.freezeRows(4);
sheet.getRange("A:A").format.columnWidth = 19;
sheet.getRange("B:B").format.columnWidth = 38;
sheet.getRange("C:C").format.columnWidth = 27;
sheet.getRange("D:D").format.columnWidth = 10;
sheet.getRange("E:E").format.columnWidth = 17;
sheet.getRange("F:F").format.columnWidth = 22;

imageSheet.getRange("A1:H1").merge();
imageSheet.getRange("A1").values = [["スキャン風帳票画像"]];
imageSheet.getRange("A1:H1").format = {
  fill: "#2E5D7B",
  font: { name: "Yu Gothic", size: 18, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
imageSheet.getRange("A1:H1").format.rowHeight = 34;
imageSheet.getRange("A:H").format.columnWidth = 12;
const imageBytes = await fs.readFile(new URL("../documents/japanese_ocr_photo.png", import.meta.url));
const imageDataUrl = `data:image/png;base64,${imageBytes.toString("base64")}`;
imageSheet.images.add({
  dataUrl: imageDataUrl,
  anchor: {
    from: { row: 2, col: 1 },
    extent: { widthPx: 640, heightPx: 960 },
  },
});

const check = await workbook.inspect({
  kind: "table",
  range: "OCR評価表!A1:F15",
  include: "values,formulas",
  tableMaxRows: 15,
  tableMaxCols: 6,
});
console.log(check.ndjson);

const preview = await workbook.render({
  sheetName: "OCR評価表",
  range: "A1:F15",
  scale: 1.5,
  format: "png",
});
await fs.writeFile(
  new URL("../results/japanese_ocr_xlsx_preview.png", import.meta.url),
  new Uint8Array(await preview.arrayBuffer()),
);
const imagePreview = await workbook.render({
  sheetName: "帳票画像",
  range: "A1:H45",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  new URL("../results/japanese_ocr_xlsx_image_preview.png", import.meta.url),
  new Uint8Array(await imagePreview.arrayBuffer()),
);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(new URL("japanese_ocr_sample.xlsx", outputDir));
