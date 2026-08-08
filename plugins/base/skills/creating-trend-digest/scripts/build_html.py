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

    data = json.loads(args.input.read_text())
    # "</" would terminate the inline <script> block early
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = args.template.read_text().replace("__DATA_JSON__", payload)
    args.output.write_text(html)
    print(f"digest: {args.output}")


if __name__ == "__main__":
    main()
