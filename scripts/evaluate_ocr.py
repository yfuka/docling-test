import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXPECTED = ROOT / "evaluation" / "ocr_expected.json"


def normalize(text):
    text = text.replace("\u00a0", " ")
    return re.sub(r"\s+", " ", text).strip()


def extract_text(response):
    document = response.get("document")
    if isinstance(document, dict):
        value = document.get("md_content")
        if isinstance(value, str):
            return value
    return ""


def source_name(path):
    name = path.name
    for suffix in (".json",):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def find_rules(expected, result_path, source):
    candidates = [source, source_name(result_path)]
    candidates.extend(
        candidate[: -len(".json")]
        for candidate in list(candidates)
        if candidate.endswith(".json")
    )
    for candidate in candidates:
        if candidate in expected["documents"]:
            document = expected["documents"][candidate]
            rules = {
                "required_terms": [],
                "regex": [],
                "ordered_terms": [],
                "tables": [],
            }
            for set_name in document["expectation_sets"]:
                expectation_set = expected["expectation_sets"][set_name]
                for key in rules:
                    rules[key].extend(expectation_set.get(key, []))
            rules["minimum_ratio"] = document.get(
                "minimum_ratio",
                expected["minimum_ratio"],
            )
            return candidate, rules
    raise KeyError(f"正解定義がありません: {source or result_path.name}")


def evaluate(text, rules):
    normalized = normalize(text)
    checks = []

    def add(kind, expected, passed, weight=1):
        checks.append(
            {
                "kind": kind,
                "expected": expected,
                "passed": passed,
                "weight": weight,
            }
        )

    for item in rules.get("required_terms", []):
        add("required_text", item, normalize(item) in normalized)

    for regex in rules.get("regex", []):
        add(
            "required_pattern",
            regex["name"],
            re.search(regex["pattern"], normalized) is not None,
        )

    for group in rules.get("ordered_terms", []):
        positions = [normalized.find(normalize(item)) for item in group]
        add(
            "ordered_text",
            group,
            all(position >= 0 for position in positions)
            and positions == sorted(positions),
            weight=len(group),
        )

    for table in rules.get("tables", []):
        add(
            "table_header",
            table["name"],
            all(normalize(cell) in normalized for cell in table["header"] if cell),
            weight=len(table["header"]),
        )
        for row in table["rows"]:
            add(
                "table_row",
                row,
                all(normalize(cell) in normalized for cell in row if cell),
                weight=len([cell for cell in row if cell]),
            )

    earned = sum(check["weight"] for check in checks if check["passed"])
    total = sum(check["weight"] for check in checks)
    score = earned / total if total else 1.0
    threshold = rules["minimum_ratio"]
    return {
        "passed": score >= threshold,
        "score": round(score, 4),
        "threshold": threshold,
        "text_length": len(normalized),
        "checks": checks,
    }


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
        sys.stderr.reconfigure(errors="replace")

    parser = argparse.ArgumentParser(
        description="Doclingの変換結果を正解ルールと照合します。"
    )
    parser.add_argument("results", nargs="+", type=Path, help="結果JSON")
    parser.add_argument(
        "--expected",
        type=Path,
        default=DEFAULT_EXPECTED,
        help="正解定義JSON",
    )
    parser.add_argument(
        "--source",
        help="入力文書名。結果JSONが1件の場合のみ指定できます。",
    )
    parser.add_argument("--output", type=Path, help="評価レポートの保存先")
    args = parser.parse_args()

    if args.source and len(args.results) != 1:
        parser.error("--source は結果JSONが1件の場合のみ指定できます")

    expected = json.loads(args.expected.read_text(encoding="utf-8"))
    reports = []
    failed = False

    for path in args.results:
        try:
            response = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"FAIL {path}: {error}", file=sys.stderr)
            failed = True
            continue

        status = response.get("status")
        if status not in ("success", "partial_success"):
            print(f"FAIL {path.name}: status={status!r}", file=sys.stderr)
            failed = True
            continue

        source = args.source or response.get("source_filename", "")
        try:
            document_name, rules = find_rules(expected, path, source)
        except KeyError as error:
            print(error, file=sys.stderr)
            failed = True
            continue

        text = extract_text(response)
        if not text:
            print(f"FAIL {path.name}: document.md_content がありません", file=sys.stderr)
            failed = True
            continue

        report = evaluate(text, rules)
        report["result"] = str(path)
        report["document"] = document_name
        report["status"] = status
        reports.append(report)
        failed = failed or not report["passed"]

        status = "PASS" if report["passed"] else "FAIL"
        print(f"{status} {document_name}: {report['score']:.1%}")
        for check in report["checks"]:
            if not check["passed"]:
                print(f"  - {check['kind']}: {check['expected']}")

    output = {"passed": not failed, "reports": reports}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(output, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
