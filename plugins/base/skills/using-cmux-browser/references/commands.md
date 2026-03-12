# cmux Browser Command Reference

## Navigation

| Command | Description |
|---------|-------------|
| `open <url>` | Open URL in current surface |
| `open-split <url>` | Open URL in a new split |
| `navigate <url> [--snapshot-after]` | Navigate to URL |
| `back` | Go back |
| `forward` | Go forward |
| `reload [--snapshot-after]` | Reload page |
| `url` | Get current URL |
| `focus-webview` | Focus the webview |
| `is-webview-focused` | Check if webview is focused |

## Waiting

| Option | Description |
|--------|-------------|
| `--load-state <s>` | `networkidle`, `domcontentloaded`, or `complete` |
| `--selector "<css>"` | Wait for element to appear |
| `--text "<text>"` | Wait for text to be visible |
| `--url-contains "<fragment>"` | Wait for URL fragment |
| `--function "<js>"` | Wait for JS expression to be truthy |
| `--timeout-ms <n>` | Timeout in milliseconds |

## DOM Interaction

| Command | Description |
|---------|-------------|
| `click <selector> [--snapshot-after]` | Click element |
| `dblclick <selector>` | Double-click element |
| `hover <selector>` | Hover over element |
| `focus <selector>` | Focus element |
| `check <selector>` | Check checkbox |
| `uncheck <selector>` | Uncheck checkbox |
| `scroll-into-view <selector>` | Scroll element into view |
| `type <selector> <text>` | Type text (appends to existing) |
| `fill <selector> --text <text>` | Fill field (replaces existing) |
| `press <key>` | Press keyboard key |
| `keydown <key>` | Key down event |
| `keyup <key>` | Key up event |
| `select <selector> <value>` | Select `<option>` by value |
| `scroll [--selector <s>] [--dx <n>] [--dy <n>] [--snapshot-after]` | Scroll |

## Inspection

| Command | Description |
|---------|-------------|
| `snapshot [--interactive] [--compact] [--selector <s>] [--max-depth <n>]` | Get accessibility tree |
| `screenshot --out <path>` | Take screenshot |
| `get title` | Page title |
| `get url` | Current URL |
| `get text <selector>` | Element text |
| `get html <selector>` | Element outer HTML |
| `get value <selector>` | Input value |
| `get attr <selector> --attr <name>` | Attribute value |
| `get count <selector>` | Count of matching elements |
| `get box <selector>` | Bounding box |
| `get styles <selector> --property <css-prop>` | Computed style |
| `is visible <selector>` | Visibility check |
| `is enabled <selector>` | Enabled state check |
| `is checked <selector>` | Checked state check |
| `find role <role> --name <name>` | Find by ARIA role |
| `find text <text>` | Find by text content |
| `find label <text>` | Find by label |
| `find placeholder <text>` | Find by placeholder |
| `find alt <text>` | Find by alt text |
| `find title <text>` | Find by title attribute |
| `find testid <id>` | Find by data-testid |
| `find first <selector>` | First match |
| `find last <selector>` | Last match |
| `find nth <n> <selector>` | nth match (0-based) |
| `highlight <selector>` | Highlight element visually |

## JavaScript

| Command | Description |
|---------|-------------|
| `eval "<expression>"` | Evaluate JS, returns result |
| `eval --script "<code>"` | Execute JS script |
| `addinitscript "<code>"` | Run script on each navigation |
| `addscript "<code>"` | Inject script into current page |
| `addstyle "<css>"` | Inject CSS into current page |

## State / Session

| Command | Description |
|---------|-------------|
| `cookies get [--name <n>]` | Get all or named cookies |
| `cookies set <name> <value> [--domain <d>] [--path <p>]` | Set cookie |
| `cookies clear [--name <n>] [--all]` | Clear cookies |
| `storage local set <key> <value>` | Set localStorage item |
| `storage local get <key>` | Get localStorage item |
| `storage local clear` | Clear localStorage |
| `storage session set <key> <value>` | Set sessionStorage item |
| `storage session get <key>` | Get sessionStorage item |
| `state save <path>` | Save full browser state to file |
| `state load <path>` | Load browser state from file |

## Tabs

| Command | Description |
|---------|-------------|
| `tab list` | List all tabs |
| `tab new <url>` | Open new tab |
| `tab switch <index\|surface>` | Switch to tab by index or surface |
| `tab close [surface]` | Close current or specified tab |

## Console and Errors

| Command | Description |
|---------|-------------|
| `console list` | Get console messages |
| `console clear` | Clear console messages |
| `errors list` | Get JS errors |
| `errors clear` | Clear JS errors |

## Frames

```bash
cmux browser surface:2 frame "iframe[name='checkout']"  # Enter iframe context
cmux browser surface:2 click "#pay-now"                  # Interact within frame
cmux browser surface:2 frame main                        # Return to top-level
```

## Dialogs

```bash
cmux browser surface:2 dialog accept                     # Accept dialog
cmux browser surface:2 dialog accept "Confirmed"         # Accept with message
cmux browser surface:2 dialog dismiss                    # Dismiss dialog
```

## Downloads

```bash
cmux browser surface:2 click "a#download-report"
cmux browser surface:2 download --path /tmp/report.csv --timeout-ms 30000
```
