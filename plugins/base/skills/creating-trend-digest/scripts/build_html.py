#!/usr/bin/env python3
"""Render enriched.json into a self-contained digest HTML page."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--template",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets" / "template.html",
    )
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    # "</" would terminate the inline <script> block early
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    template = args.template.read_text(encoding="utf-8")
    if "__DATA_JSON__" not in template:
        raise SystemExit(f"template has no __DATA_JSON__ placeholder: {args.template}")
    args.output.write_text(template.replace("__DATA_JSON__", payload), encoding="utf-8")
    print(f"digest: {args.output}")


if __name__ == "__main__":
    main()
