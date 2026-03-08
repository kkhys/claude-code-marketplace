---
name: creating-codepen-demo
description: Creates CodePen 2.0 demos with copy-paste ready code. Use when creating interactive demos, code examples, or browser API demonstrations for CodePen.
---

# Creating CodePen Demos

Generate copy-paste ready code for CodePen 2.0.

## Output Format

CodePen 2.0 uses a file-based structure. Output each file with its filename:

```
**index.html**
[code block]

**style.css**
[code block]

**script.ts**
[code block]

Title: `{title}`
```

- `index.html` is a complete HTML document (`<!doctype html>` from the top)
- TypeScript is natively supported via `.ts` extension
- Free plan allows up to 3 files — default to `index.html`, `style.css`, `script.ts`

## Style

- Ultra minimal — only what is needed to demonstrate the concept
- Dark background, light text
- No decorative elements, no emojis
- If the demo requires user interaction, include a single `<p>` instruction

## Example

See [example.md](example.md) for a full demo (Screen Wake Lock API).

## CodePen 2.0 Notes

- Web Workers can be separate `.ts` files if file count allows, otherwise use inline Blob:

```ts
const blob = new Blob([code], { type: "application/javascript" });
const worker = new Worker(URL.createObjectURL(blob));
```
