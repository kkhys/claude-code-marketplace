---
name: using-cmux-browser
description: Live browser automation using the cmux browser CLI. MUST use this skill whenever the user asks to open a URL in a real browser, interact with a live web page, fill and submit web forms, click buttons on a page, scrape or read content from a website, inspect live page state (DOM, cookies, localStorage), navigate between pages, take browser screenshots, wait for dynamic/SPA content to render, work inside iframes, or debug a web UI by viewing it. Also trigger for Japanese phrases like "ブラウザで開いて", "ページを確認して", "スクショ撮って", "フォームに入力して", "ボタンを押して", "Cookie を確認したい", or any request to visually verify a deployed/staging/localhost page. This skill is for controlling a real browser instance — do NOT use it for writing HTML/CSS/JS code, writing Playwright/Cypress test scripts, making curl/wget/fetch API requests, reading local HTML files, or building UI components.
allowed-tools: Bash(cmux:*)
context: fork
disable-model-invocation: true
---

# cmux Browser Automation

cmux browser is a CLI for automating browser interactions. Every operation runs as a shell command — no Playwright API or Node.js required.

## Core Concept: Surface Targeting

A "surface" is a browser pane managed by cmux. Most commands need a surface target.

```bash
cmux browser identify                     # List all browser surfaces
cmux browser open https://example.com     # Create a new browser surface
cmux browser open-split https://example.com  # Open in a new split pane
```

After opening, `identify` returns the new surface ref. Use it to target subsequent commands:

```bash
cmux browser surface:2 navigate https://example.com
cmux browser --surface surface:2 navigate https://example.com  # Equivalent
```

## The Ref-Based Workflow

This is the primary interaction pattern with cmux browser. `snapshot --interactive` returns an accessibility tree where each interactive element has a ref:

```bash
$ cmux browser surface:2 snapshot --interactive --compact
- document "Login"
    - textbox "Email" [ref=e5]
    - textbox "Password" [ref=e6]
    - button "Sign in" [ref=e7]
    - link "Forgot password?" [ref=e8]
```

Use the ref value directly as a selector — just the ref itself, without brackets:

```bash
cmux browser surface:2 fill "e5" "user@example.com"
cmux browser surface:2 fill "e6" "s3cret"
cmux browser surface:2 click "e7" --snapshot-after
```

Refs persist across multiple snapshots and navigations within the same surface. Once assigned, a ref remains valid until the surface is closed. This means you can snapshot, plan your actions, and execute them without worrying about refs going stale.

The standard automation loop:

1. **Snapshot** — Read the page structure and get refs
2. **Plan** — Identify which elements to interact with
3. **Act** — Use refs (or CSS selectors) to interact
4. **Verify** — Use `--snapshot-after`, `wait`, or `get` to confirm the result

## Selectors

You can target elements two ways:

| Type | Example | When to use |
|------|---------|-------------|
| Ref | `"e5"` | After taking a snapshot. Fast and unambiguous. |
| CSS | `"input[name='email']"` | When you know the DOM structure. Works without a prior snapshot. |

Both work in all commands that accept a selector (`click`, `fill`, `type`, `get`, etc.).

When unsure which selector to use, snapshot first and use refs. If the page structure is known (you wrote the HTML or read the source), CSS selectors work fine without a snapshot.

## Waiting

Pages are asynchronous. Always wait before interacting with freshly loaded or dynamically rendered content.

```bash
# After navigation — wait for the page to finish loading
cmux browser surface:2 wait --load-state complete --timeout-ms 15000

# For dynamic content — wait for a specific element to appear
cmux browser surface:2 wait --selector "#results" --timeout-ms 10000

# For state confirmation — wait for text or URL change
cmux browser surface:2 wait --text "Order confirmed" --timeout-ms 10000
cmux browser surface:2 wait --url-contains "/dashboard" --timeout-ms 10000

# For SPA readiness — wait for a JS condition
cmux browser surface:2 wait --function "window.__appReady === true" --timeout-ms 10000
```

Always set `--timeout-ms`. Without it, a missing element blocks indefinitely. Use 10000-15000ms for page loads, 5000ms for element waits.

## Essential Operations

```bash
# Navigation
cmux browser surface:2 navigate https://example.com --snapshot-after
cmux browser surface:2 back
cmux browser surface:2 forward
cmux browser surface:2 reload --snapshot-after
cmux browser surface:2 url                          # Get current URL

# Form interaction
cmux browser surface:2 fill "selector" "text"       # Replace input value
cmux browser surface:2 fill "selector"               # Clear input
cmux browser surface:2 type "selector" "text"        # Append text
cmux browser surface:2 select "#region" "us-east"    # Select dropdown option
cmux browser surface:2 check "#terms"                # Check checkbox
cmux browser surface:2 press Enter                   # Press key

# Clicking
cmux browser surface:2 click "selector" --snapshot-after

# Reading page state
cmux browser surface:2 get title
cmux browser surface:2 get text "h1"
cmux browser surface:2 get value "#email"
cmux browser surface:2 get attr "a.primary" --attr href
cmux browser surface:2 get count ".list-item"
cmux browser surface:2 is visible "#checkout"

# Scrolling
cmux browser surface:2 scroll --dy 500
cmux browser surface:2 scroll-into-view "#footer"

# JavaScript
cmux browser surface:2 eval "document.title"
```

The `--snapshot-after` flag on action commands returns an inline snapshot immediately after the action — useful for verifying the effect without a separate call.

## Debugging

When interactions fail or produce unexpected results:

```bash
cmux browser surface:2 snapshot --interactive --compact  # What's actually on the page?
cmux browser surface:2 get url                           # Am I on the right page?
cmux browser surface:2 console list                      # Check console output
cmux browser surface:2 errors list                       # Check JS errors
cmux browser surface:2 screenshot --out /tmp/debug.png   # Visual capture
```

## Common Workflow Example

```bash
# Open and wait
cmux browser open https://app.example.com/login
cmux browser identify  # → surface:5
cmux browser surface:5 wait --load-state complete --timeout-ms 15000

# Discover page structure
cmux browser surface:5 snapshot --interactive --compact
# Output:
#   - textbox "Email" [ref=e1]
#   - textbox "Password" [ref=e2]
#   - button "Log in" [ref=e3]

# Fill and submit
cmux browser surface:5 fill "e1" "ops@example.com"
cmux browser surface:5 fill "e2" "$PASSWORD"
cmux browser surface:5 click "e3" --snapshot-after
cmux browser surface:5 wait --text "Welcome" --timeout-ms 10000
```

See [commands.md](references/commands.md) for the full command reference.
See [patterns.md](references/patterns.md) for advanced workflow patterns (login bypass, iframe handling, multi-tab, session persistence, downloads).
