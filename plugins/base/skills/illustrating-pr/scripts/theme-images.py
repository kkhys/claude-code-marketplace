#!/usr/bin/env python3
"""Rewrite uploaded panel images so each follows the viewer's GitHub theme.

gh rewrites every ![alt](./file) in a body to the uploaded asset's URL, but
it reads references from markdown only, so a <picture> element cannot be
attached in one step. attach-explainer.sh therefore uploads the light and
dark PNGs as plain references, then runs this script on the text GitHub
stored: the i-th local reference in the uploaded text became the i-th asset
URL in the stored text, which is how a file name is mapped to its URL.

When both texts carry the illustrating-pr section markers, only the section
between them is read and rewritten, so images the author placed elsewhere in
a PR description are left alone and do not shift the pairing.

Every light panel with a dark twin becomes

    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="DARK">
      <source media="(prefers-color-scheme: light)" srcset="LIGHT">
      <img alt="..." src="LIGHT">
    </picture>

and the line that carried the dark twin's reference is removed.
"""

import argparse
import html
import re
import sys

START = "<!-- illustrating-pr:start -->"
END = "<!-- illustrating-pr:end -->"

LOCAL_REF = re.compile(r"!\[[^\]]*\]\(\./([^)\s]+)\)")
ASSET_REF = re.compile(
    r"!\[([^\]]*)\]\((https://github\.com/user-attachments/assets/[^)\s]+)\)"
)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def section_bounds(text):
    """Start and end offsets of the fenced section, or the whole text."""
    start = text.find(START)
    end = text.find(END, start + len(START)) if start >= 0 else -1
    if start < 0 or end < 0:
        return 0, len(text)
    return start, end


def picture(alt, light_url, dark_url):
    return (
        "<picture>\n"
        f'  <source media="(prefers-color-scheme: dark)" srcset="{dark_url}">\n'
        f'  <source media="(prefers-color-scheme: light)" srcset="{light_url}">\n'
        f'  <img alt="{html.escape(alt, quote=True)}" src="{light_url}">\n'
        "</picture>"
    )


def remove_line(text, start, end):
    """Drop the whole line holding text[start:end], newline included."""
    line_start = text.rfind("\n", 0, start) + 1
    line_end = text.find("\n", end)
    line_end = len(text) if line_end == -1 else line_end + 1
    return text[:line_start] + text[line_end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("uploaded", help="text as handed to gh, with ./file references")
    parser.add_argument("stored", help="text as GitHub stored it, with asset URLs")
    parser.add_argument(
        "--dark",
        action="append",
        default=[],
        metavar="LIGHT=DARK",
        help="file names of a light panel and its dark twin; repeatable",
    )
    args = parser.parse_args()

    uploaded = read(args.uploaded)
    stored = read(args.stored)

    up_start, up_end = section_bounds(uploaded)
    st_start, st_end = section_bounds(stored)
    names = LOCAL_REF.findall(uploaded[up_start:up_end])
    scope = stored[st_start:st_end]
    assets = list(ASSET_REF.finditer(scope))
    if len(names) != len(assets):
        sys.exit(
            f"error: uploaded text has {len(names)} local references but the stored "
            f"text has {len(assets)} asset URLs; cannot pair files to URLs"
        )

    dark_of = {}
    for pair in args.dark:
        light, sep, dark = pair.partition("=")
        if not sep or not light or not dark:
            sys.exit(f"error: --dark expects LIGHT=DARK, got {pair!r}")
        dark_of[light] = dark
    darks = set(dark_of.values())

    url_of = {}
    for name, match in zip(names, assets):
        if name in url_of:
            sys.exit(f"error: {name} is referenced more than once")
        url_of[name] = match.group(2)

    for light, dark in dark_of.items():
        if light not in url_of or dark not in url_of:
            sys.exit(f"error: no asset URL for {light} or {dark}")

    out = scope
    # Rewrite from the end so earlier match offsets stay valid.
    for name, match in reversed(list(zip(names, assets))):
        if name in dark_of:
            block = picture(match.group(1), match.group(2), url_of[dark_of[name]])
            out = out[: match.start()] + block + out[match.end() :]
        elif name in darks:
            out = remove_line(out, match.start(), match.end())

    # Each removed reference leaves the blank line that separated it.
    out = re.sub(r"\n{3,}", "\n\n", out)
    result = stored[:st_start] + out + stored[st_end:]
    sys.stdout.write(result.rstrip("\n") + "\n")


if __name__ == "__main__":
    main()
