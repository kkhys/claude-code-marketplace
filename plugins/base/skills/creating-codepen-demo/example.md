# Example: Screen Wake Lock API Demo

## index.html

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="stylesheet" href="./style.css" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Screen Wake Lock API Demo</title>
  </head>
  <body>
    <p>
      Click the button to toggle wake lock. Save as a local HTML file to test.
    </p>
    <button id="toggle">Enable Wake Lock</button>
    <div id="log"></div>
    <script src="./script.ts"></script>
  </body>
</html>
```

## script.ts

```ts
const log = document.getElementById("log") as HTMLDivElement;
const toggle = document.getElementById("toggle") as HTMLButtonElement;
let lock: WakeLockSentinel | null = null;

const addEntry = (text: string) => {
  const el = document.createElement("div");
  el.textContent = `${new Date().toLocaleTimeString("en-GB")} ${text}`;
  log.prepend(el);
};

const requestLock = async () => {
  try {
    lock = await navigator.wakeLock.request("screen");
    lock.addEventListener("release", () => {
      addEntry("wake lock released");
      toggle.textContent = "Enable Wake Lock";
    });
    addEntry("wake lock acquired");
    toggle.textContent = "Disable Wake Lock";
  } catch (e) {
    addEntry(`error: ${e instanceof Error ? e.message : String(e)}`);
  }
};

toggle.addEventListener("click", async () => {
  if (lock) {
    await lock.release();
    lock = null;
  } else {
    await requestLock();
  }
});

document.addEventListener("visibilitychange", async () => {
  if (document.visibilityState === "visible" && lock !== null) {
    await requestLock();
  }
});
```

## style.css

```css
body {
  font-family: ui-monospace, Menlo, monospace;
  font-size: 14px;
  padding: 16px;
  background: #0a0a0a;
  color: #e0e0e0;
}

button {
  font: inherit;
  background: #e0e0e0;
  color: #0a0a0a;
  border: none;
  padding: 6px 12px;
  cursor: pointer;
  margin-bottom: 12px;
}

#log {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
```
