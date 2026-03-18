---
name: creating-codepen-demo
description: Generate CodePen 2.0 demos with copy-paste ready code. Use when the user wants to create interactive demos, playground examples, UI component showcases, browser API demonstrations, CSS animations, or any front-end experiment for CodePen. Also trigger when the user mentions "CodePen", "pen", "playground demo", or wants to share a working code snippet that runs in the browser.
context: fork
---

# Creating CodePen Demos

Generate self-contained, copy-paste ready code for CodePen 2.0's file-based editor.

## Why CodePen 2.0 is different

Classic CodePen had three fixed panes (HTML fragment, CSS, JS). CodePen 2.0 uses a file-based model — you create actual files like `index.html`, `style.css`, `script.ts`. The HTML is a full document starting from `<!doctype html>`, not a fragment injected into `<body>`. This matters because the user copies each file into a separate tab in the editor.

## File structure

Default to 3 files — this keeps demos simple, portable, and within free-plan limits:

- `index.html` — Full HTML document (`<!doctype html>` at the top)
- `style.css` — Styles
- `script.ts` — Logic (TypeScript is natively supported; no build config needed)

Link them with relative paths in index.html:

```html
<link rel="stylesheet" href="./style.css" />
<script src="./script.ts"></script>
```

Add more files only when the demo genuinely requires separation (e.g., a Web Worker).

## Output format

Present each file as a labeled code block, then a suggested title:

**index.html**

```html
<!doctype html>
...
```

**style.css**

```css
body { ... }
```

**script.ts**

```ts
// logic here
```

Title: `Descriptive Title Here`

## Design philosophy

A viewer should open the pen and grasp what's happening within seconds. The code is the star — everything else gets out of the way.

- Minimal code — only what demonstrates the concept
- Dark background (`#0a0a0a`), light text (`#e0e0e0`), monospace font (`ui-monospace, Menlo, monospace`)
- No decorative elements (gradients, shadows, rounded corners) unless they ARE the demo
- If the demo needs interaction, one `<p>` explaining what to do
- No external dependencies — vanilla HTML/CSS/TS

This aesthetic keeps demos visually consistent and focuses attention on behavior, not chrome.

## Patterns by demo type

**Browser API** (Wake Lock, Clipboard, Geolocation, etc.):
- A clear control (button/input) to trigger the API
- Log events with timestamps to visualize state changes
- Handle error paths — many browser APIs need permissions or HTTPS

**UI component** (toggle, modal, accordion, etc.):
- Make it functional, not just visual
- Semantic HTML where possible
- Self-contained styling (no CSS reset, no utility classes)

**Animation** (CSS transitions, Web Animations API, requestAnimationFrame, etc.):
- Start on load or with a single interaction
- Keep the animated element visually prominent
- Prefer CSS for declarative effects; JS only for dynamic control

## Technical notes

- TypeScript: Use type assertions (`as HTMLButtonElement`) for DOM queries. No `tsconfig.json` needed — CodePen auto-detects `.ts` and `.tsx` extensions.
- Config files (`package.json`, `pen.config.json`, etc.) don't count toward the file limit, so the 3-file budget is entirely for your code.
- ESM imports: Bare module specifiers work (`import confetti from "canvas-confetti"`) — CodePen auto-generates `package.json` and import maps. Use sparingly; vanilla is preferred.
- Web Workers: Use a separate `.ts` file if you have room, otherwise inline with Blob:

```ts
const blob = new Blob([workerCode], { type: "application/javascript" });
const worker = new Worker(URL.createObjectURL(blob));
```

## Example

See [references/example.md](references/example.md) for a complete Screen Wake Lock API demo showing the expected file structure and style.
