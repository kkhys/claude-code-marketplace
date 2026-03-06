---
name: creating-codepen-demo
description: Creates CodePen demos with copy-paste ready HTML/CSS/JS. Use when creating interactive demos, code examples, or browser API demonstrations for CodePen.
---

# Creating CodePen Demos

Generate copy-paste ready code for CodePen's three panels.

## Output Format

Always output three labeled code blocks, even if a panel is empty:

```
**HTML**
[code block]

**CSS**
[code block]

**JS**
[code block]

Title: `{title}`
```

## Style

- Ultra minimal — only what is needed to demonstrate the concept
- Dark background, light text
- No decorative elements, no emojis
- If the demo requires user interaction, include a single `<p>` instruction

## CodePen Constraints

- Three panels only (HTML, CSS, JS) — no separate files
- External resources must be loaded via CDN URLs
- Web Workers require inline Blob pattern:

```js
const blob = new Blob([code], { type: "application/javascript" });
const worker = new Worker(URL.createObjectURL(blob));
```
