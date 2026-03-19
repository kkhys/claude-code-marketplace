# cmux Browser Command Reference

All commands are prefixed with `cmux browser <surface>`. Selectors accept both refs (`e5`) and CSS selectors (`#email`).

## Navigation

| Command | Description |
|---------|-------------|
| `open <url>` | Create a browser surface and open URL |
| `open-split <url>` | Open URL in a new split pane |
| `navigate <url> [--snapshot-after]` | Navigate to URL |
| `back [--snapshot-after]` | Go back in history |
| `forward [--snapshot-after]` | Go forward in history |
| `reload [--snapshot-after]` | Reload page |
| `url` | Get current URL |

## Waiting

All wait options combine with `--timeout-ms <n>` (recommended).

| Option | Description |
|--------|-------------|
| `--load-state <state>` | `complete`, `domcontentloaded`, or `networkidle` |
| `--selector "<css>"` | Wait for element to appear |
| `--text "<text>"` | Wait for text to be visible |
| `--url-contains "<fragment>"` | Wait for URL to contain fragment |
| `--function "<js>"` | Wait for JS expression to return truthy |

## DOM Interaction

| Command | Description |
|---------|-------------|
| `click <selector> [--snapshot-after]` | Click element |
| `dblclick <selector> [--snapshot-after]` | Double-click element |
| `hover <selector> [--snapshot-after]` | Hover over element |
| `focus <selector>` | Focus element |
| `check <selector> [--snapshot-after]` | Check checkbox |
| `uncheck <selector> [--snapshot-after]` | Uncheck checkbox |
| `scroll-into-view <selector> [--snapshot-after]` | Scroll element into view |
| `fill <selector> [text] [--snapshot-after]` | Fill field (replaces existing; empty text clears) |
| `type <selector> <text> [--snapshot-after]` | Type text (appends to existing) |
| `press <key> [--snapshot-after]` | Press keyboard key |
| `keydown <key> [--snapshot-after]` | Key down event |
| `keyup <key> [--snapshot-after]` | Key up event |
| `select <selector> <value> [--snapshot-after]` | Select option by value |
| `scroll [--selector <css>] [--dx <n>] [--dy <n>] [--snapshot-after]` | Scroll page or element |

## Inspection

| Command | Description |
|---------|-------------|
| `snapshot [--interactive] [--compact] [--selector <css>] [--max-depth <n>] [--cursor]` | Get accessibility tree |
| `screenshot [--out <path>]` | Take screenshot |
| `get title` | Page title |
| `get url` | Current URL |
| `get text <selector>` | Element text content |
| `get html <selector>` | Element outer HTML |
| `get value <selector>` | Input value |
| `get attr <selector> --attr <name>` | Attribute value |
| `get count <selector>` | Count of matching elements |
| `get box <selector>` | Bounding box (x, y, width, height) |
| `get styles <selector> --property <css-prop>` | Computed CSS property |
| `is visible <selector>` | Visibility check |
| `is enabled <selector>` | Enabled state check |
| `is checked <selector>` | Checked state check |

## Finding Elements

| Command | Description |
|---------|-------------|
| `find role <role> [--name <name>]` | Find by ARIA role |
| `find text <text>` | Find by text content |
| `find label <text>` | Find by label text |
| `find placeholder <text>` | Find by placeholder |
| `find alt <text>` | Find by alt text |
| `find title <text>` | Find by title attribute |
| `find testid <id>` | Find by data-testid |
| `find first <selector>` | First matching element |
| `find last <selector>` | Last matching element |
| `find nth <n> <selector>` | nth match (0-based) |
| `highlight <selector>` | Highlight element visually |

## JavaScript

| Command | Description |
|---------|-------------|
| `eval "<expression>"` | Evaluate JS expression, returns result |
| `addinitscript "<code>"` | Run script on each navigation |
| `addscript "<code>"` | Inject script into current page |
| `addstyle "<css>"` | Inject CSS into current page |

## State / Session

| Command | Description |
|---------|-------------|
| `cookies get [--name <n>]` | Get all or named cookies |
| `cookies set <name> <value> [--domain <d>] [--path <p>]` | Set cookie |
| `cookies clear [--name <n>] [--all]` | Clear cookies |
| `storage local get <key>` | Get localStorage item |
| `storage local set <key> <value>` | Set localStorage item |
| `storage local clear` | Clear localStorage |
| `storage session get <key>` | Get sessionStorage item |
| `storage session set <key> <value>` | Set sessionStorage item |
| `state save <path>` | Save full browser state (cookies + storage) to file |
| `state load <path>` | Load browser state from file |

## Tabs

| Command | Description |
|---------|-------------|
| `tab list` | List all tabs |
| `tab new <url>` | Open URL in new tab |
| `tab switch <index\|surface>` | Switch to tab |
| `tab close [surface]` | Close current or specified tab |

## Console / Errors

| Command | Description |
|---------|-------------|
| `console list` | Get console messages |
| `console clear` | Clear console messages |
| `errors list` | Get JS errors |
| `errors clear` | Clear JS errors |

## Frames

Switch context to an iframe before interacting with its contents:

```bash
cmux browser surface:2 frame "iframe[name='checkout']"  # Enter iframe
cmux browser surface:2 click "#pay-now"                  # Interact inside frame
cmux browser surface:2 frame main                        # Return to top-level
```

## Dialogs

```bash
cmux browser surface:2 dialog accept                     # Accept alert/confirm
cmux browser surface:2 dialog accept "Confirmed"         # Accept with prompt text
cmux browser surface:2 dialog dismiss                    # Dismiss dialog
```

## Downloads

```bash
cmux browser surface:2 click "#download-link"
cmux browser surface:2 download --path /tmp/report.csv --timeout-ms 30000
```
