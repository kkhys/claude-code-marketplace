---
name: using-cmux-browser
description: Browser automation using the cmux browser CLI. Use when navigating web pages, interacting with DOM elements, filling forms, inspecting page state, or automating browser workflows with cmux.
---

# cmux Browser Automation

## Surface Targeting

Most commands require a surface. Discover available surfaces first:

```bash
cmux browser identify                     # List all surfaces
cmux browser identify --surface surface:2 # Inspect specific surface
```

Target syntax (positional and flag are equivalent):

```bash
cmux browser surface:2 <command>
cmux browser --surface surface:2 <command>
```

## Essential Operations

### Open and Navigate

```bash
cmux browser open https://example.com
cmux browser open-split https://example.com

cmux browser surface:2 navigate https://example.org --snapshot-after
cmux browser surface:2 back
cmux browser surface:2 forward
cmux browser surface:2 reload --snapshot-after
cmux browser surface:2 url
```

### Wait for State

```bash
cmux browser surface:2 wait --load-state complete --timeout-ms 15000
cmux browser surface:2 wait --selector "#checkout" --timeout-ms 10000
cmux browser surface:2 wait --text "Order confirmed"
cmux browser surface:2 wait --url-contains "/dashboard"
cmux browser surface:2 wait --function "window.__appReady === true"
```

### DOM Interaction

```bash
cmux browser surface:2 click "button[type='submit']" --snapshot-after
cmux browser surface:2 fill "#email" --text "user@example.com"
cmux browser surface:2 fill "#email" --text ""           # Clear field
cmux browser surface:2 type "#search" "query text"       # Append text
cmux browser surface:2 press Enter
cmux browser surface:2 select "#region" "us-east"
cmux browser surface:2 check "#terms"
cmux browser surface:2 scroll --dy 800
```

### Inspection

```bash
cmux browser surface:2 snapshot --interactive --compact  # Accessibility tree
cmux browser surface:2 screenshot --out /tmp/page.png

cmux browser surface:2 get title
cmux browser surface:2 get text "h1"
cmux browser surface:2 get value "#email"
cmux browser surface:2 get attr "a.primary" --attr href

cmux browser surface:2 is visible "#checkout"
cmux browser surface:2 is enabled "button[type='submit']"

cmux browser surface:2 find role button --name "Continue"
cmux browser surface:2 find text "Order confirmed"
```

## Common Workflow Pattern

```bash
# 1. Open and wait
cmux browser open https://example.com/login
cmux browser surface:2 wait --load-state complete --timeout-ms 15000

# 2. Fill and submit
cmux browser surface:2 fill "#email" --text "ops@example.com"
cmux browser surface:2 fill "#password" --text "$PASSWORD"
cmux browser surface:2 click "button[type='submit']" --snapshot-after
cmux browser surface:2 wait --text "Welcome"

# 3. Debug on failure
cmux browser surface:2 console list
cmux browser surface:2 errors list
cmux browser surface:2 screenshot --out /tmp/failure.png
```

See [commands.md](references/commands.md) for the full command reference.
See [patterns.md](references/patterns.md) for advanced workflow patterns.
