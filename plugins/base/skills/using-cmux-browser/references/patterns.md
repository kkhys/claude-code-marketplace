# cmux Browser Workflow Patterns

## Login Flow

Most web apps require authentication before anything useful happens. The standard approach:

```bash
cmux browser open https://app.example.com/login
cmux browser identify  # → surface:3
cmux browser surface:3 wait --load-state complete --timeout-ms 15000
cmux browser surface:3 snapshot --interactive --compact

# Fill credentials using refs from snapshot
cmux browser surface:3 fill "e1" "user@example.com"
cmux browser surface:3 fill "e2" "$PASSWORD"
cmux browser surface:3 click "e3" --snapshot-after
cmux browser surface:3 wait --url-contains "/dashboard" --timeout-ms 10000
```

If you need to repeat the login across sessions, save the authenticated state:

```bash
cmux browser surface:3 state save /tmp/session.json

# Later — restore without re-logging in
cmux browser surface:3 state load /tmp/session.json
cmux browser surface:3 reload --snapshot-after
```

Alternatively, inject session cookies directly to bypass the login page entirely:

```bash
cmux browser surface:3 cookies set session_id "abc123" --domain app.example.com --path /
cmux browser surface:3 reload --snapshot-after
```

## Form Submission with Verification

Fill, submit, and confirm the server accepted the input:

```bash
cmux browser surface:3 fill "#name" "Jane Smith"
cmux browser surface:3 fill "#email" "jane@example.com"
cmux browser surface:3 select "#plan" "enterprise"
cmux browser surface:3 check "#agree-terms"
cmux browser surface:3 click "button[type='submit']" --snapshot-after
cmux browser surface:3 wait --text "Thank you" --timeout-ms 10000
```

If submission fails, check for validation errors:

```bash
cmux browser surface:3 get text ".error-message"
cmux browser surface:3 snapshot --interactive --compact  # See current state
```

## Scraping Dynamic Data

For SPAs that render data after initial load, wait for the content to appear before reading it:

```bash
cmux browser open https://example.com/dashboard
cmux browser surface:3 wait --selector ".data-table" --timeout-ms 10000

# Read structured data
cmux browser surface:3 get count ".data-row"
cmux browser surface:3 get text ".data-table"
cmux browser surface:3 get html ".data-table"

# Or extract via JS for complex data
cmux browser surface:3 eval "JSON.stringify([...document.querySelectorAll('.data-row')].map(r => r.textContent))"
```

## Iframe Interaction

Some UIs embed content in iframes (payment forms, third-party widgets). Switch frame context before interacting:

```bash
cmux browser surface:3 frame "iframe[name='payment']"
cmux browser surface:3 snapshot --interactive --compact  # See iframe contents
cmux browser surface:3 fill "e10" "4111111111111111"
cmux browser surface:3 click "e12"
cmux browser surface:3 frame main  # Return to top-level document
```

## Multi-Tab Workflow

Work with multiple pages simultaneously:

```bash
cmux browser surface:3 tab new https://docs.example.com
cmux browser surface:3 tab list                      # See all tabs
cmux browser surface:3 tab switch 1                  # Switch to second tab
cmux browser surface:3 get text "h1"                 # Read from docs
cmux browser surface:3 tab switch 0                  # Back to first tab
```

## Debugging a Failing Interaction

When a click or fill doesn't work as expected:

```bash
# 1. Check what's actually on the page
cmux browser surface:3 snapshot --interactive --compact

# 2. Verify the element state
cmux browser surface:3 is visible "#submit-btn"
cmux browser surface:3 is enabled "#submit-btn"

# 3. Check for JS errors or console clues
cmux browser surface:3 errors list
cmux browser surface:3 console list

# 4. Take a visual screenshot for context
cmux browser surface:3 screenshot --out /tmp/debug.png

# 5. Check the URL — maybe a redirect happened
cmux browser surface:3 get url
```

## Waiting for SPA Readiness

Single-page apps often need a JS-level readiness check beyond load-state:

```bash
# Wait for app framework to initialize
cmux browser surface:3 wait --function "window.__appReady === true" --timeout-ms 15000

# Or wait for a specific element that only renders after data loads
cmux browser surface:3 wait --selector "[data-loaded='true']" --timeout-ms 10000
```

## File Download

Trigger a download and wait for it to complete:

```bash
cmux browser surface:3 click "#export-csv"
cmux browser surface:3 download --path /tmp/export.csv --timeout-ms 30000
```
