// Init script for the recording-pr-qa skill: a caption bar (what the test is
// doing) and a console panel (what the page and the checks said), drawn into
// the page so the screencast records them. The host is inert, aria-hidden and
// a closed shadow root, so snapshots, focus and the app's own queries skip it.
// State lives in sessionStorage so a navigation does not wipe the bar, and
// hide() takes the whole overlay out of frame for a viewport screenshot.
//
// The page is also zoomed ZOOM times: Playwright records at the CSS viewport
// size and never above it, so a 2560x1800 viewport with zoom 2 is the one way
// to film the 1280x900 layout at Retina density. Media queries still see the
// full viewport width, and rects and scroll offsets come back in zoomed px.
(() => {
  if (window.__qa) return;

  const ZOOM = 2;
  const KEY = "__qa";
  const MAX_LINES = 7;
  const MAX_CHARS = 160;
  const HOLD_MS = 1200;
  const CSS = `
    :host { all: initial; }
    .bar {
      position: fixed; left: 0; right: 0; bottom: 0; z-index: 2147483647;
      display: grid; grid-template-columns: 3fr 2fr; gap: 16px;
      height: 140px; padding: 12px 18px; box-sizing: border-box;
      background: rgba(16, 16, 20, 0.9); color: #fff; pointer-events: none;
      font: 15px/1.4 -apple-system, "Hiragino Sans", "Noto Sans JP", system-ui, sans-serif;
    }
    .bar[data-place="top"] { top: 0; bottom: auto; }
    .title { font-size: 22px; font-weight: 700; }
    .detail { margin-top: 6px; font-size: 17px; color: #ddd; white-space: pre-wrap; }
    .log {
      margin: 0; padding-left: 14px; border-left: 1px solid #555; overflow: hidden;
      font: 14px/1.35 ui-monospace, SFMono-Regular, Menlo, monospace; color: #d6e6ef;
      white-space: pre-wrap; word-break: break-all;
    }
    .warn { color: #ffcc66; } .error, .fail { color: #ff7b7b; } .pass { color: #8ce99a; }
    .ripple {
      position: fixed; width: 44px; height: 44px; margin: -22px 0 0 -22px; border-radius: 50%;
      border: 3px solid #ff5a5f; background: rgba(255, 90, 95, 0.3); pointer-events: none;
      z-index: 2147483647; animation: qa-ripple 600ms ease-out forwards;
    }
    @keyframes qa-ripple { from { transform: scale(0.3); opacity: 1; } to { transform: scale(1.7); opacity: 0; } }
  `;

  const read = () => {
    try { return JSON.parse(sessionStorage.getItem(KEY)) || {}; } catch { return {}; }
  };
  const state = Object.assign({ title: "", detail: "", lines: [], place: "bottom", hidden: false }, read());
  const save = () => {
    try { sessionStorage.setItem(KEY, JSON.stringify(state)); } catch { /* opaque origin */ }
  };

  let els = null;
  const escape = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]);
  const render = () => {
    if (!els) return;
    els.host.style.display = state.hidden ? "none" : "";
    els.bar.dataset.place = state.place;
    els.title.textContent = state.title;
    els.detail.textContent = state.detail;
    els.log.innerHTML = state.lines
      .slice(-MAX_LINES)
      .map((l) => `<div class="${l.kind}">${escape(l.text)}</div>`)
      .join("");
  };
  const mount = () => {
    const parent = document.body || document.documentElement;
    if (!parent) return;
    if (!els) {
      const host = document.createElement("qa-overlay");
      host.setAttribute("aria-hidden", "true");
      host.inert = true;
      const root = host.attachShadow({ mode: "closed" });
      root.innerHTML =
        `<style>${CSS}</style><div class="bar"><div><div class="title"></div>` +
        `<div class="detail"></div></div><div class="log"></div></div>`;
      els = { host, root, bar: root.querySelector(".bar"), title: root.querySelector(".title"),
        detail: root.querySelector(".detail"), log: root.querySelector(".log") };
    }
    if (!els.host.isConnected) parent.appendChild(els.host);
    render();
  };

  const fmt = (v) => {
    if (typeof v === "string") return v;
    if (v instanceof Error) return v.message;
    try { return JSON.stringify(v); } catch { return String(v); }
  };
  const push = (kind, text) => {
    const line = text.length > MAX_CHARS ? `${text.slice(0, MAX_CHARS)}…` : text;
    state.lines.push({ kind, text: line });
    state.lines = state.lines.slice(-MAX_LINES);
    save();
    mount();
  };

  const original = {};
  const MARK = { log: "›", info: "›", warn: "⚠", error: "✖" };
  for (const level of Object.keys(MARK)) {
    original[level] = console[level];
    console[level] = (...args) => {
      push(level, `${MARK[level]} ${args.map(fmt).join(" ")}`);
      return original[level].apply(console, args);
    };
  }
  // A ripple where the mouse went down, so a click reads as a click on film.
  window.addEventListener("mousedown", (e) => {
    mount();
    if (!els) return;
    const dot = document.createElement("div");
    dot.className = "ripple";
    dot.style.left = `${e.clientX}px`;
    dot.style.top = `${e.clientY}px`;
    els.root.appendChild(dot);
    setTimeout(() => dot.remove(), 700);
  }, true);
  window.addEventListener("error", (e) => push("error", `✖ ${e.message}`));
  window.addEventListener("unhandledrejection", (e) => push("error", `✖ ${fmt(e.reason)}`));

  window.__qa = Object.freeze({
    // Caption: title (case or step) and detail (what is done, what to expect).
    // Resolves after `hold` ms so the viewer can read it before the action.
    step(title, detail = "", hold = HOLD_MS) {
      state.title = String(title);
      state.detail = String(detail);
      save();
      mount();
      return new Promise((resolve) => setTimeout(resolve, hold));
    },
    log(text) {
      push("log", `› ${fmt(text)}`);
    },
    // Logs "✓ label: actual" or "✗ label: actual (expected …)" and returns both
    // so the CLI prints them. `expected` may be a value, a predicate, or absent
    // (truthy check).
    check(label, actual, expected) {
      const pass = typeof expected === "function" ? Boolean(expected(actual))
        : expected === undefined ? Boolean(actual)
        : JSON.stringify(actual) === JSON.stringify(expected);
      const want = typeof expected === "function" || expected === undefined ? "" : ` (expected ${fmt(expected)})`;
      push(pass ? "pass" : "fail", `${pass ? "✓" : "✗"} ${label}: ${fmt(actual)}${pass ? "" : want}`);
      original.log.call(console, `[qa] ${pass ? "PASS" : "FAIL"} ${label}: ${fmt(actual)}`);
      return { pass, actual };
    },
    // "top" when the bar would hide the element under test.
    place(where) {
      state.place = where === "top" ? "top" : "bottom";
      save();
      mount();
    },
    // Out of frame for a screenshot that needs the whole viewport, and back.
    hide() {
      state.hidden = true;
      save();
      mount();
    },
    show() {
      state.hidden = false;
      save();
      mount();
    },
    // Back to an empty bar: run it before the recording starts.
    clear() {
      state.title = "";
      state.detail = "";
      state.lines = [];
      save();
      mount();
    },
  });

  const zoom = () => {
    if (!document.documentElement) return false;
    document.documentElement.style.zoom = String(ZOOM);
    return true;
  };
  if (!zoom()) {
    const watcher = new MutationObserver(() => { if (zoom()) watcher.disconnect(); });
    watcher.observe(document, { childList: true });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount);
  else mount();
})();
