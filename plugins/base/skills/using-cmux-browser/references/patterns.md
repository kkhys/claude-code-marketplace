# cmux Browser Workflow Patterns

## Navigate, Wait, Inspect

```bash
cmux browser open https://example.com/login
cmux browser surface:2 wait --load-state complete --timeout-ms 15000
cmux browser surface:2 snapshot --interactive --compact
cmux browser surface:2 get title
```

## Fill a Form and Verify Success

```bash
cmux browser surface:2 fill "#email" --text "ops@example.com"
cmux browser surface:2 fill "#password" --text "$PASSWORD"
cmux browser surface:2 click "button[type='submit']" --snapshot-after
cmux browser surface:2 wait --text "Welcome"
cmux browser surface:2 is visible "#dashboard"
```

## Capture Debug Artifacts on Failure

```bash
cmux browser surface:2 console list
cmux browser surface:2 errors list
cmux browser surface:2 screenshot --out /tmp/failure.png
cmux browser surface:2 snapshot --interactive --compact
```

## Persist and Restore Browser Session

```bash
cmux browser surface:2 state save /tmp/session.json
# ...later...
cmux browser surface:2 state load /tmp/session.json
cmux browser surface:2 reload
```

## Work Inside an Iframe

```bash
cmux browser surface:2 frame "iframe[name='checkout']"
cmux browser surface:2 fill "#card-number" --text "4111111111111111"
cmux browser surface:2 click "#pay-now"
cmux browser surface:2 frame main
```

## Multi-Tab Workflow

```bash
cmux browser open-split https://app.example.com
cmux browser surface:2 tab list
cmux browser surface:2 tab new https://docs.example.com
cmux browser surface:2 tab switch 1
```

## Bypass Login by Injecting Session Cookie

```bash
cmux browser surface:2 cookies set session_id "abc123" --domain example.com --path /
cmux browser surface:2 reload --snapshot-after
```

## Wait for Dynamic Content

```bash
cmux browser surface:2 wait --function "window.__appReady === true" --timeout-ms 10000
cmux browser surface:2 wait --selector "#dynamic-content" --timeout-ms 5000
```

## Scrape Dynamic Data

```bash
cmux browser open https://example.com/data
cmux browser surface:2 wait --selector ".data-table" --timeout-ms 10000
cmux browser surface:2 get html ".data-table"
cmux browser surface:2 get count ".data-row"
```

## Handle Download

```bash
cmux browser surface:2 click "a#export-csv"
cmux browser surface:2 download --path /tmp/export.csv --timeout-ms 30000
```
