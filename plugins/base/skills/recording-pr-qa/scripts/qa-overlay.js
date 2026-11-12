// Init script for the recording-pr-qa skill: a caption card (what the test is
// doing), a check card (what the page and the checks said), a progress bar, a
// pointer with click rings and a keystroke display, drawn into the page so the
// screencast records them. The host is inert, aria-hidden and a closed shadow
// root, so snapshots, focus and the app's own queries skip it. State lives in
// sessionStorage so a navigation does not wipe it, and hide() takes the whole
// overlay out of frame for a viewport screenshot.
//
// The page itself is left alone. Retina density comes from the browser
// (--force-device-scale-factor=2), not from a CSS zoom: a zoomed root scales
// getBoundingClientRect, so anything the app positions from a measured rect —
// a tooltip, a popover, a menu — landed in the wrong place on film.
(() => {
  if (window.__qa) return;

  // A same-origin frame draws nothing: it hands its mouse, keys, scrolls and console to the top
  // overlay, which maps them through the frame's box. The device stage below is such a frame.
  if (window.top !== window) {
    let above = null;
    try { above = window.top.__qa; } catch { /* cross-origin */ }
    if (!above) return;
    for (const type of ["mousemove", "mousedown", "mouseup", "keydown", "scroll"])
      window.addEventListener(type, (e) => above.relay(window, type, e), true);
    for (const level of ["log", "info", "warn", "error"]) {
      const real = console[level];
      console[level] = (...args) => {
        above.relay(window, "console", { level, args });
        return real.apply(console, args);
      };
    }
    window.addEventListener("error", (e) => above.relay(window, "console", { level: "error", args: [e.message] }));
    return;
  }

  const STORE = "__qa";
  const MAX_LINES = 7;
  const OPEN_LINES = 12;
  const MAX_CHARS = 160;
  const HOLD_MS = 1200;
  const FADE_MS = 180;
  const PACE_MS = 15000;
  const MAX_CHECKS = 6;
  const MAX_KEYS = 12;
  const CONFETTI = 90;
  const COLORS = ["#6366f1", "#db2777", "#f59e0b", "#10b981", "#38bdf8", "#f43f5e"];
  const KEYS_MS = 1400;
  const CSS = `
    :host {
      all: initial; position: fixed; inset: 0; pointer-events: none; --card: rgba(17, 18, 24, 0.93); --fg: #fff; --muted: rgba(255, 255, 255, 0.8);
      --line: rgba(255, 255, 255, 0.14); --track: rgba(255, 255, 255, 0.24);
      --pass: #86efac; --fail: #fca5a5; --warn: #fcd34d;
    }
    /* A dark card sinks into a dark page, so the cards flip to light there. */
    :host([data-theme="light"]) {
      --card: rgba(255, 255, 255, 0.96); --fg: #14151a; --muted: rgba(20, 21, 26, 0.72);
      --line: rgba(0, 0, 0, 0.12); --track: rgba(0, 0, 0, 0.16);
      --pass: #15803d; --fail: #b91c1c; --warn: #b45309;
    }
    .bar, .chapter-card {
      font-family: -apple-system, "SF Pro Text", "Hiragino Sans", "Noto Sans JP", system-ui, sans-serif;
      -webkit-font-smoothing: antialiased; font-feature-settings: "palt"; color: var(--fg);
    }
    /* Two cards, each as wide as its text: a full-width slab hid a ninth of the page to show one line. */
    .bar {
      position: fixed; left: 16px; right: 16px; bottom: 16px; z-index: 2147483647;
      display: flex; justify-content: space-between; align-items: flex-end; gap: 12px;
      pointer-events: none; transition: opacity 200ms ease;
    }
    .bar[data-place="top"] { top: 16px; bottom: auto; align-items: flex-start; }
    .bar[data-empty="true"] { opacity: 0; }
    /* Beside the device: caption to its left, console to its right, both centred on its height. */
    .bar[data-device="true"] { inset: 0; display: block; }
    .bar[data-device="true"] .main, .bar[data-device="true"] .side {
      position: absolute; top: 50%; translate: 0 -50%; min-width: 0; width: var(--side); max-width: none;
    }
    .bar[data-device="true"] .main { left: 28px; }
    .bar[data-device="true"] .caption { min-width: 0; width: 100%; }
    .bar[data-device="true"] .side { right: 28px; }
    .caption, .console, .checks {
      box-sizing: border-box; border-radius: 14px; background: var(--card);
      border: 1px solid var(--line);
      box-shadow: 0 12px 36px rgba(0, 0, 0, 0.3), 0 2px 6px rgba(0, 0, 0, 0.18);
    }
    .main { display: flex; flex-direction: column; align-items: flex-start; gap: 12px; min-width: 0; max-width: 62%; }
    .caption { min-width: 300px; max-width: 100%; padding: 14px 20px 15px; }
    /* One segment per filmed case, so the viewer sees how far along the video is. */
    .progress { display: flex; align-items: center; gap: 4px; margin-bottom: 10px; }
    .progress:empty { display: none; }
    .progress i { flex: 1; min-width: 18px; height: 5px; border-radius: 3px; background: var(--track); overflow: hidden; }
    .progress i.done { background: var(--muted); }
    /* The current case's segment fills at a constant speed. A case has no known length, so the pace is
       the previous case's (PACE_MS for the first), aimed at nine tenths; the first check closes it. */
    .progress u {
      display: block; width: 90%; height: 100%; border-radius: 3px; background: linear-gradient(90deg, #6366f1, #db2777);
      animation: qa-creep ${PACE_MS}ms linear backwards; transition: width 360ms ease-out;
    }
    .progress[data-full="true"] u { width: 100%; animation: none; }
    .progress b { margin-left: 6px; font: 600 12px/1 ui-monospace, "SF Mono", Menlo, monospace; color: var(--muted); }
    .chapter-card .progress { width: 220px; margin: 22px auto 0; }
    .caption[data-empty="true"] { visibility: hidden; }
    .head { display: flex; align-items: center; gap: 10px; }
    .badge {
      flex: none; padding: 3px 10px; border-radius: 999px; background: linear-gradient(90deg, #6366f1, #db2777);
      font-size: 13px; font-weight: 700; line-height: 1.5; letter-spacing: 0.04em; white-space: nowrap; color: #fff;
    }
    .badge:empty { display: none; }
    .title { font-size: 22px; font-weight: 700; line-height: 1.35; letter-spacing: 0.01em; }
    .detail { margin-top: 6px; font-size: 16.5px; line-height: 1.5; color: var(--muted); white-space: pre-wrap; }
    .detail:empty { display: none; }
    .caption[data-tick="0"] { animation: qa-in-a 260ms cubic-bezier(0.2, 0.8, 0.2, 1); }
    .caption[data-tick="1"] { animation: qa-in-b 260ms cubic-bezier(0.2, 0.8, 0.2, 1); }
    /* The console: the page's own output, one tinted row per line, the way DevTools shows them. Off
       by default; "auto" shows it while it has lines, "open" keeps a taller one on screen. */
    /* The right column: the checklist of the case, then the console when a case needs it. */
    .side { display: flex; flex-direction: column; gap: 10px; width: 400px; max-width: 40%; margin-left: auto; }
    .side:has(.console[data-mode="open"]) { width: 520px; max-width: 46%; }
    /* The checks are listed before they run and tick as each one reads the page. */
    .checks { padding: 6px 0 8px; overflow: hidden; }
    .checks:has(.rows:empty) { display: none; }
    .checks-head, .console-head {
      display: flex; align-items: center; gap: 8px; padding: 6px 14px 8px; border-bottom: 1px solid var(--line);
      font-size: 12px; font-weight: 700; letter-spacing: 0.08em; color: var(--muted);
    }
    .checks-head b { margin-left: auto; font: 600 12.5px/1 ui-monospace, "SF Mono", Menlo, monospace; letter-spacing: 0; }
    .rows > div { display: flex; align-items: baseline; gap: 10px; padding: 7px 14px 0; font-size: 15px; line-height: 1.4; }
    .rows i {
      flex: none; align-self: center; width: 18px; height: 18px; box-sizing: border-box; border-radius: 50%;
      border: 2px solid var(--track); font: 700 12px/14px -apple-system, system-ui, sans-serif; text-align: center;
      color: #111; transition: background 200ms ease, border-color 200ms ease;
    }
    .rows span { color: var(--muted); }
    .rows b { margin-left: auto; padding-left: 12px; font: 600 13.5px/1.4 ui-monospace, "SF Mono", Menlo, monospace; text-align: right; word-break: break-all; }
    .rows .pass i { background: var(--pass); border-color: var(--pass); animation: qa-tick 320ms cubic-bezier(0.2, 0.9, 0.3, 1.4); }
    .rows .fail i { background: var(--fail); border-color: var(--fail); animation: qa-tick 320ms cubic-bezier(0.2, 0.9, 0.3, 1.4); }
    .rows .pass span, .rows .fail span { color: var(--fg); }
    .rows .pass b { color: var(--pass); } .rows .fail b { color: var(--fail); }
    .console { overflow: hidden; }
    .console[data-mode="auto"]:has(.log:empty), .console[data-mode="off"] { display: none; }
    .console-head { padding-top: 9px; }
    .checks-head::before, .console-head::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: linear-gradient(90deg, #6366f1, #db2777); }
    .log {
      padding: 6px; font: 13.5px/1.5 ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
      color: var(--muted); white-space: pre-wrap; word-break: break-all;
    }
    .console[data-mode="open"] .log { min-height: 150px; }
    .log:empty { padding: 0; }
    .log > div { padding: 3px 8px; border-left: 3px solid transparent; border-radius: 4px; }
    .log > div + div { margin-top: 2px; }
    .log > div:last-child { animation: qa-in-a 220ms ease-out; }
    .log > .fail, .log > .error { border-left-color: var(--fail); background: color-mix(in srgb, var(--fail) 16%, transparent); }
    .log > .warn { border-left-color: var(--warn); background: color-mix(in srgb, var(--warn) 12%, transparent); }
    .warn { color: var(--warn); } .error, .fail { color: var(--fail); } .pass { color: var(--pass); }
    /* The chapter scrim blurs the page and does not tint it. Nothing in a page, the top layer
       included, can paint over the scrollbar gutters, so on a page that reserves them a tint left a
       strip of the page colour down each side; a blur alone keeps that colour edge to edge. */
    .chapter {
      position: fixed; inset: 0; z-index: 2147483647; pointer-events: none;
      display: flex; align-items: center; justify-content: center;
      backdrop-filter: blur(14px) saturate(110%); animation: qa-fade 220ms ease-out;
    }
    .chapter[hidden] { display: none; }
    .chapter[data-leaving="true"] { opacity: 0; transition: opacity ${FADE_MS}ms ease-in; }
    .chapter-card {
      max-width: 680px; padding: 36px 52px; box-sizing: border-box; border-radius: 22px;
      background: var(--card); border: 1px solid var(--line);
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45); text-align: center;
      animation: qa-pop 320ms cubic-bezier(0.2, 0.9, 0.3, 1.1);
    }
    .chapter-mark { position: relative; width: 44px; margin: 0 auto 18px; }
    .chapter-mark:has(.chapter-num:empty) { width: 36px; }
    .chapter-mark:has(.chapter-num:empty) .ring { display: none; }
    /* A ring around the case number that closes as the card's hold runs out. */
    .ring { position: absolute; left: -8px; top: -8px; width: 60px; height: 60px; transform: rotate(-90deg); }
    .ring circle { fill: none; stroke-width: 3; stroke: var(--track); }
    .ring circle + circle {
      stroke: var(--fg); stroke-linecap: round; stroke-dasharray: 169.65;
      animation: qa-ring 1500ms linear backwards;
    }
    .chapter-num {
      width: 44px; border-radius: 999px; background: linear-gradient(90deg, #6366f1, #db2777);
      font-size: 20px; font-weight: 700; line-height: 44px; color: #fff;
    }
    .chapter-num:empty { width: 36px; height: 4px; }
    .chapter-title { font-size: 30px; font-weight: 700; line-height: 1.3; letter-spacing: 0.01em; }
    .chapter-detail { margin-top: 12px; color: var(--muted); font-size: 17px; line-height: 1.55; white-space: pre-wrap; }
    .chapter-detail:empty { display: none; }
    /* Two rings, dark inside white, so the click shows on any page colour. */
    .ripple {
      position: fixed; width: 56px; height: 56px; margin: -28px 0 0 -28px; border-radius: 50%;
      box-sizing: border-box; border: 2.5px solid rgba(20, 21, 26, 0.85);
      box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.9), inset 0 0 0 2px rgba(255, 255, 255, 0.9);
      pointer-events: none; z-index: 2147483647; animation: qa-ripple 620ms cubic-bezier(0.2, 0.7, 0.3, 1) forwards;
    }
    .ripple + .ripple { animation-delay: 110ms; animation-duration: 700ms; opacity: 0; }
    /* Drawn here rather than by Playwright: its pointer sits in a closed shadow root and cannot be sized. */
    .cursor {
      position: fixed; left: 0; top: 0; z-index: 2147483647; width: 28px; height: 38px; pointer-events: none;
      transition: transform 0ms cubic-bezier(0.45, 0.05, 0.2, 1);
      filter: drop-shadow(0 2px 5px rgba(0, 0, 0, 0.4));
    }
    .cursor[hidden] { display: none; }
    .cursor svg { display: block; width: 100%; height: 100%; transform-origin: 3px 3px; transition: transform 140ms ease; }
    .cursor[data-down="true"] svg { transform: scale(0.84); }
    /* Where the page is while it scrolls: a rail on the right edge whose thumb slides, with the direction. */
    .rail {
      position: fixed; right: 8px; top: 16px; bottom: 16px; width: 8px; border-radius: 4px; z-index: 2147483647;
      background: rgba(17, 18, 24, 0.22); box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.5); pointer-events: none;
      transition: opacity 320ms ease;
    }
    .rail[data-idle="true"] { opacity: 0; }
    .rail u {
      position: absolute; left: 0; right: 0; border-radius: 4px; background: linear-gradient(180deg, #6366f1, #db2777);
      transition: top 240ms cubic-bezier(0.3, 0, 0.2, 1);
    }
    .rail b {
      position: absolute; right: 16px; top: 50%; width: 30px; height: 30px; margin-top: -15px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center; background: rgba(17, 18, 24, 0.93); color: #fff;
      font: 700 17px/1 -apple-system, system-ui, sans-serif; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
    }
    /* Typed keys as keycaps, left-aligned on top of the caption card. Each cap arrives pressed down
       and springs back, the way a key travels. */
    .keys { display: flex; flex-wrap: wrap; gap: 7px; min-height: 0; transition: opacity 260ms ease; }
    .keys:empty { display: none; }
    .keys[data-idle="true"] { opacity: 0; }
    .keys kbd {
      min-width: 48px; height: 48px; padding: 0 14px; box-sizing: border-box; border-radius: 11px;
      display: flex; align-items: center; justify-content: center;
      background: linear-gradient(180deg, #34374a, #1c1d27); color: #fff; border: 1px solid rgba(255, 255, 255, 0.2);
      box-shadow: 0 5px 0 #06070b, 0 12px 22px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.22);
      font: 600 21px/1 -apple-system, "SF Pro Text", "Hiragino Sans", system-ui, sans-serif; white-space: pre;
    }
    .keys kbd:last-child { animation: qa-key 300ms cubic-bezier(0.2, 0.8, 0.3, 1); }
    .confetti { position: fixed; inset: 0; overflow: hidden; pointer-events: none; z-index: 2147483647; }
    .confetti i {
      position: absolute; top: -24px; width: 10px; height: 16px; border-radius: 2px;
      animation: qa-fall 2600ms cubic-bezier(0.3, 0.1, 0.6, 1) both;
    }
    @keyframes qa-fall {
      from { transform: translate(0, 0) rotate(0deg); opacity: 1; }
      85% { opacity: 1; }
      to { transform: translate(var(--drift), 105vh) rotate(var(--spin)); opacity: 0; }
    }
    @keyframes qa-tick { from { transform: scale(0.4); } }
    @keyframes qa-creep { from { width: 0; } }
    @keyframes qa-ring { from { stroke-dashoffset: 169.65; } }
    @keyframes qa-ripple { from { transform: scale(0.2); opacity: 1; } to { transform: scale(1.25); opacity: 0; } }
    @keyframes qa-key {
      from { opacity: 0; transform: translateY(-4px); }
      40% { opacity: 1; transform: translateY(5px); box-shadow: 0 0 0 #06070b, 0 3px 8px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.22); }
    }
    @keyframes qa-in-a { from { opacity: 0; transform: translateY(6px); } }
    @keyframes qa-in-b { from { opacity: 0; transform: translateY(6px); } }
    @keyframes qa-fade { from { opacity: 0; } }
    @keyframes qa-pop { from { opacity: 0; transform: scale(0.94); } }
  `;

  const STAGE_CSS = `
    :host { all: initial; position: fixed; inset: 0; }
    /* The stage takes the page's own background colour: the scrollbar gutters keep showing it, and
       any other colour would leave a strip down each side. */
    .stage {
      position: fixed; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center;
      gap: 16px; background: #fff;
    }
    .label {
      padding: 6px 16px; border-radius: 999px; background: rgba(17, 18, 24, 0.93); color: #fff;
      font: 600 13.5px/1.5 ui-monospace, "SF Mono", Menlo, monospace; letter-spacing: 0.02em;
    }
    .device {
      overflow: hidden; background: #fff; transition: width 520ms cubic-bezier(0.3, 0, 0.2, 1), height 520ms cubic-bezier(0.3, 0, 0.2, 1);
      box-shadow: 0 0 0 9px #0b0c11, 0 0 0 10px rgba(255, 255, 255, 0.35), 0 36px 80px rgba(20, 24, 40, 0.35);
    }
    iframe {
      display: block; border: 0; transform-origin: 0 0;
      transition: width 520ms cubic-bezier(0.3, 0, 0.2, 1), height 520ms cubic-bezier(0.3, 0, 0.2, 1);
    }
  `;

  const read = () => {
    try { return JSON.parse(sessionStorage.getItem(STORE)) || {}; } catch { return {}; }
  };
  const state = Object.assign(
    { title: "", detail: "", lines: [], place: "bottom", hidden: false, total: 0, index: 0, caseStart: 0, caseDone: false, pace: PACE_MS, checks: [], passed: 0, failed: 0, console: "off", device: null,
      cx: null, cy: null },
    read(),
  );
  const save = () => {
    try { sessionStorage.setItem(STORE, JSON.stringify(state)); } catch { /* opaque origin */ }
  };

  let els = null;
  // "ケース 3: title" and "3. title" carry the case number in the text: lift it into its own badge.
  const lead = (text, pattern) => {
    const m = pattern.exec(text);
    return m ? [m[1], m[2]] : ["", text];
  };
  // Long enough to read at about nine characters a second, within bounds that keep the video moving.
  const readTime = (text, min, max) => Math.min(max, Math.max(min, text.length * 110));
  // The colour behind the page: the root's, or the body's, which propagates to the canvas when the root has none.
  const pageRgb = () => {
    for (const el of [document.documentElement, document.body]) {
      const m = /rgba?\((\d+), (\d+), (\d+)(?:, ([\d.]+))?/.exec((el && getComputedStyle(el).backgroundColor) || "");
      if (m && m[4] !== "0") return [Number(m[1]), Number(m[2]), Number(m[3])];
    }
    return [255, 255, 255];
  };
  const pageColor = () => `rgb(${pageRgb().join(", ")})`;
  const theme = () => {
    const [r, g, b] = pageRgb();
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 < 0.3 ? "light" : "dark";
  };
  const segments = () => {
    if (!state.total) return "";
    // The delay places the fill in time: positive while the chapter card is still up, negative to
    // resume where it was when a navigation rebuilt the overlay.
    const fill = `<u style="animation-duration:${state.pace}ms;animation-delay:${state.caseStart - Date.now()}ms"></u>`;
    const cell = (i) => (i < state.index - 1 ? `<i class="done"></i>` : i === state.index - 1 ? `<i>${fill}</i>` : `<i class="todo"></i>`);
    return Array.from({ length: state.total }, (_, i) => cell(i)).join("") +
      `<b>${Math.min(state.index, state.total)} / ${state.total}</b>`;
  };
  // The travel time grows with the distance, so a short hop is not a slow drift.
  const moveCursor = (x, y) => {
    const far = state.cx === null ? 0 : Math.hypot(x - state.cx, y - state.cy);
    const travel = far < 4 ? 0 : Math.round(Math.min(750, Math.max(260, far * 1.1)));
    state.cx = x;
    state.cy = y;
    save();
    mount();
    if (els?.cursor) els.cursor.style.transitionDuration = `${travel}ms`;
    return travel;
  };
  const escape = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]);
  const render = () => {
    if (!els) return;
    els.host.style.display = state.hidden ? "none" : "";
    els.host.dataset.theme = theme();
    // Rewritten only when the case changes: a rewrite would restart the fill.
    const key = `${state.index}/${state.total}`;
    for (const el of [els.progress, els.chapterProgress]) {
      if (!el) continue;
      if (el.dataset.key !== key) el.innerHTML = segments();
      el.dataset.key = key;
      el.dataset.full = String(state.caseDone);
    }
    if (els.cursor) {
      els.cursor.hidden = state.cx === null;
      els.cursor.style.transform = `translate(${state.cx}px, ${state.cy}px)`;
    }
    els.bar.dataset.place = state.place;
    // Too little room beside a wide device: the cards go back to the bottom, over it.
    els.bar.dataset.device = String(Boolean(staged) && staged.side >= 240);
    if (staged) els.bar.style.setProperty?.("--side", `${Math.round(staged.side)}px`);
    // An empty bar fades out instead of sitting on the page as a blank slab.
    els.bar.dataset.empty = String(!state.title && !state.detail && !state.checks.length && !state.lines.length && state.console !== "open");
    const [badge, title] = lead(state.title, /^((?:ケース|Case)\s*\d+)\s*[:：]\s*(.+)$/s);
    if (els.caption) els.caption.dataset.empty = String(!state.title && !state.detail);
    if (els.badge) els.badge.textContent = badge;
    els.title.textContent = title;
    els.detail.textContent = state.detail;
    if (els.console) els.console.dataset.mode = state.console;
    if (els.rows) els.rows.innerHTML = state.checks.map((c) =>
      `<div class="${c.kind}"><i>${{ pass: "✓", fail: "✗" }[c.kind] ?? ""}</i><span>${escape(c.label)}</span><b>${escape(c.text)}</b></div>`).join("");
    if (els.count) els.count.textContent = `${state.checks.filter((c) => c.kind !== "todo").length} / ${state.checks.length}`;
    els.log.innerHTML = state.lines
      .slice(state.console === "open" ? -OPEN_LINES : -MAX_LINES)
      .map((l) => `<div class="${l.kind}">${escape(l.text)}</div>`)
      .join("");
  };
  // The top layer puts the overlay above the app's modal dialogs, whose backdrop would otherwise
  // dim the cards; the layer stacks in opening order, so the host is reopened after each of them.
  const raise = () => {
    try {
      if (els.host.matches?.(":popover-open")) els.host.hidePopover();
      els.host.showPopover?.();
    } catch { /* not connected yet */ }
  };
  // The device stage: the page again, in a frame of the size under test, on a plain backdrop. The
  // frame is same-origin, so cookies and X-Frame-Options: SAMEORIGIN hold, media queries see the
  // frame's width, and the cards sit beside the device instead of over a screen that small.
  let staged = null;
  const stage = () => {
    if (!state.device) {
      staged?.host.remove();
      staged = null;
      return;
    }
    const parent = document.body || document.documentElement;
    if (!staged) {
      const host = document.createElement("qa-stage");
      host.setAttribute("popover", "manual");
      // Open, so a frame locator reaches #qa-device.
      const root = host.attachShadow({ mode: "open" });
      root.innerHTML = `<style>${STAGE_CSS}</style><div class="stage"><div class="label"></div>` +
        `<div class="device"><iframe id="qa-device" title="device" src="${escape(location.href)}"></iframe></div></div>`;
      staged = { host, frame: root.querySelector("#qa-device"), device: root.querySelector(".device"),
        label: root.querySelector(".label") };
      const backdrop = root.querySelector(".stage");
      if (backdrop) backdrop.style.background = pageColor();
    }
    if (!staged.host.isConnected) {
      parent.appendChild(staged.host);
      try { staged.host.showPopover?.(); } catch { /* not connected yet */ }
      if (els?.host.isConnected) raise();
    }
    const { width, height, label } = state.device;
    const fit = Math.min(1, (window.innerHeight - 120) / height, (window.innerWidth - 96) / width);
    Object.assign(staged.frame.style, { width: `${width}px`, height: `${height}px`, transform: `scale(${fit})` });
    Object.assign(staged.device.style, { width: `${width * fit}px`, height: `${height * fit}px`,
      borderRadius: `${width < 600 ? 30 : 14}px` });
    staged.label.textContent = `${label ? `${label} · ` : ""}${width} × ${height}${fit < 1 ? ` · ${Math.round(fit * 100)}%` : ""}`;
    staged.side = (window.innerWidth - width * fit) / 2 - 56;
  };
  // The document the cases act on: the device's while the stage is up.
  const scene = () => staged?.frame.contentWindow ?? window;
  const mount = () => {
    const parent = document.body || document.documentElement;
    if (!parent) return;
    if (!els) {
      const host = document.createElement("qa-overlay");
      host.setAttribute("aria-hidden", "true");
      host.inert = true;
      host.setAttribute("popover", "manual");
      const root = host.attachShadow({ mode: "closed" });
      root.innerHTML =
        `<style>${CSS}</style><div class="bar"><div class="main"><div class="keys" data-idle="true"></div><div class="caption"><div class="progress"></div><div class="head"><span class="badge"></span>` +
        `<div class="title"></div></div><div class="detail"></div></div></div><div class="side">` +
        `<div class="checks"><div class="checks-head">CHECKS<b class="count"></b></div><div class="rows"></div></div>` +
        `<div class="console"><div class="console-head">CONSOLE</div><div class="log"></div></div></div></div>` +
        `<div class="chapter" hidden><div class="chapter-card"><div class="chapter-mark">` +
        `<svg class="ring" viewBox="0 0 60 60"><circle cx="30" cy="30" r="27"/><circle cx="30" cy="30" r="27"/></svg>` +
        `<div class="chapter-num"></div></div>` +
        `<div class="chapter-title"></div>` +
        `<div class="chapter-detail"></div><div class="progress chapter-progress"></div></div></div>` +
        `<div class="rail" data-idle="true"><u><b></b></u></div><div class="cursor" hidden><svg viewBox="0 0 22 30"><path d="M2 2v22l5.6-5.2 3.6 8.4 3.4-1.5-3.6-8.2H19z" ` +
        `fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg></div>`;
      els = { host, root, bar: root.querySelector(".bar"), title: root.querySelector(".title"),
        caption: root.querySelector(".caption"), badge: root.querySelector(".badge"),
        chapterNum: root.querySelector(".chapter-num"), cursor: root.querySelector(".cursor"), keys: root.querySelector(".keys"), rail: root.querySelector(".rail"),
        thumb: root.querySelector(".rail u"), arrow: root.querySelector(".rail b"),
        console: root.querySelector(".console"), rows: root.querySelector(".rows"),
        count: root.querySelector(".count"),
        ring: root.querySelector(".ring circle + circle"),
        progress: root.querySelector(".caption .progress"), chapterProgress: root.querySelector(".chapter-progress"),
        detail: root.querySelector(".detail"), log: root.querySelector(".log"),
        chapter: root.querySelector(".chapter"), chapterTitle: root.querySelector(".chapter-title"),
        chapterDetail: root.querySelector(".chapter-detail") };
    }
    stage();
    // Reopened only when attached: reopening restarts every animation in the overlay.
    if (!els.host.isConnected) {
      parent.appendChild(els.host);
      raise();
    }
    render();
  };

  const fmt = (v) => {
    if (typeof v === "string") return v;
    if (v instanceof Error) return v.message;
    try { return JSON.stringify(v); } catch { return String(v); }
  };
  const clip = (text) => (text.length > MAX_CHARS ? `${text.slice(0, MAX_CHARS)}…` : text);
  const push = (kind, text) => {
    state.lines.push({ kind, text: clip(text) });
    state.lines = state.lines.slice(-OPEN_LINES);
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
  // Keys pressed, shown as keycaps the way a screen recorder does. A run of keys stays on screen
  // together and fades once typing stops; a password field shows dots.
  const MODIFIERS = ["Meta", "Control", "Alt", "Shift"];
  const KEYCAP = { Meta: "⌘", Control: "⌃", Alt: "⌥", Shift: "⇧", Enter: "↵ Enter", Escape: "esc", Tab: "⇥ Tab",
    Backspace: "⌫", Delete: "⌦", " ": "Space", ArrowUp: "↑", ArrowDown: "↓", ArrowLeft: "←", ArrowRight: "→" };
  let caps = [];
  let chorded = false;
  let capsTimer = 0;
  let lastY = 0;
  let railTimer = 0;
  // Where a frame sits in the top viewport, and how much the stage scaled it.
  const box = (win) => {
    const frame = win === window ? null : win.frameElement;
    if (!frame) return { left: 0, top: 0, right: window.innerWidth, bottom: window.innerHeight, scale: 1, framed: false };
    const rect = frame.getBoundingClientRect();
    return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, scale: rect.width / (frame.offsetWidth || rect.width), framed: true };
  };
  const HANDLERS = {
    mousemove(win, e) {
      const at = box(win);
      moveCursor(at.left + e.clientX * at.scale, at.top + e.clientY * at.scale);
    },
    // The pointer dips and two rings spread where the mouse went down, so a click reads as a click on film.
    mousedown(win, e) {
      const at = box(win);
      const x = at.left + e.clientX * at.scale;
      const y = at.top + e.clientY * at.scale;
      moveCursor(x, y);
      if (!els) return;
      if (els.cursor) els.cursor.dataset.down = "true";
      for (let ring = 0; ring < 2; ring += 1) {
        const dot = document.createElement("div");
        dot.className = "ripple";
        dot.style.left = `${x}px`;
        dot.style.top = `${y}px`;
        els.root.appendChild(dot);
        setTimeout(() => dot.remove(), 850);
      }
    },
    mouseup() {
      if (els?.cursor) els.cursor.dataset.down = "false";
    },
    keydown(_win, e) {
      mount();
      // A modifier shows with the key it modifies, not on its own.
      if (!els?.keys || e.repeat || MODIFIERS.includes(e.key)) return;
      const held = MODIFIERS.filter((m) => e.getModifierState?.(m));
      // Shift alone with a printable key is already in the character it produced.
      const chord = held.length === 1 && held[0] === "Shift" && e.key.length === 1 ? [] : held;
      const secret = e.target?.type === "password" && e.key.length === 1;
      const cap = secret ? "•" : KEYCAP[e.key] ?? (chord.length && e.key.length === 1 ? e.key.toUpperCase() : e.key);
      // A chord replaces the row; plain typing extends it.
      caps = chord.length ? [...chord.map((m) => KEYCAP[m]), cap] : [...(chorded ? [] : caps), cap].slice(-MAX_KEYS);
      chorded = chord.length > 0;
      els.keys.innerHTML = caps.map((c) => `<kbd>${escape(c)}</kbd>`).join("");
      els.keys.dataset.idle = "false";
      clearTimeout(capsTimer);
      capsTimer = setTimeout(() => {
        caps = [];
        chorded = false;
        if (!els?.keys) return;
        els.keys.dataset.idle = "true";
        // Emptied once faded, so the caption card settles back without a gap above it.
        setTimeout(() => { if (!caps.length) els.keys.innerHTML = ""; }, 280);
      }, KEYS_MS);
    },
    scroll(win) {
      const page = win.document.scrollingElement;
      if (!els?.rail || !page || page.scrollHeight <= win.innerHeight) return;
      const at = box(win);
      // Beside the frame that scrolled, or on the viewport's right edge.
      Object.assign(els.rail.style, at.framed
        ? { left: `${at.right + 16}px`, right: "auto", top: `${at.top}px`, bottom: `${window.innerHeight - at.bottom}px` }
        : { left: "auto", right: "8px", top: "16px", bottom: "16px" });
      const size = Math.max(8, (win.innerHeight / page.scrollHeight) * 100);
      els.thumb.style.height = `${size}%`;
      els.thumb.style.top = `${(page.scrollTop / (page.scrollHeight - win.innerHeight)) * (100 - size)}%`;
      if (page.scrollTop !== lastY) els.arrow.textContent = page.scrollTop > lastY ? "↓" : "↑";
      lastY = page.scrollTop;
      els.rail.dataset.idle = "false";
      clearTimeout(railTimer);
      railTimer = setTimeout(() => { els.rail.dataset.idle = "true"; }, 900);
    },
    console(_win, { level, args }) {
      push(level, `${MARK[level]} ${args.map(fmt).join(" ")}`);
    },
  };
  for (const type of ["mousemove", "mousedown", "mouseup", "keydown", "scroll"])
    window.addEventListener(type, (e) => HANDLERS[type](window, e), true);
  window.addEventListener("toggle", (e) => {
    if (els && e.target !== els.host && e.newState === "open") raise();
  }, true);
  window.addEventListener("error", (e) => push("error", `✖ ${e.message}`));
  window.addEventListener("unhandledrejection", (e) => push("error", `✖ ${fmt(e.reason)}`));

  const card = (num, title, detail, hold) => {
    mount();
    if (!els) return Promise.resolve();
    if (els.chapterNum) els.chapterNum.textContent = num;
    els.chapterTitle.textContent = title;
    els.chapterDetail.textContent = detail;
    if (els.ring) els.ring.style.animationDuration = `${hold}ms`;
    els.chapter.dataset.leaving = "false";
    els.chapter.hidden = false;
    return new Promise((resolve) => setTimeout(() => {
      els.chapter.dataset.leaving = "true";
      setTimeout(() => {
        els.chapter.hidden = true;
        resolve();
      }, FADE_MS);
    }, hold));
  };

  window.__qa = Object.freeze({
    chapter(title, detail = "", hold = readTime(`${title}${detail}`, 1500, 3500)) {
      if (state.index < state.total) state.index += 1;
      // The segment starts to fill when the card has left, not behind it.
      state.caseStart = Date.now() + hold + FADE_MS;
      state.caseDone = false;
      // The caption's checks and the console belong to the current case only.
      state.checks = [];
      state.lines = [];
      save();
      const [num, text] = lead(String(title), /^(\d+)\s*[.．:：]\s*(.+)$/s);
      return card(num, text, String(detail), hold);
    },
    // The closing card: the tally of every check since clear(), with confetti when none failed.
    finish(hold = 3200) {
      const ok = state.failed === 0 && state.passed > 0;
      state.index = state.total + 1;
      state.title = "";
      state.detail = "";
      state.checks = [];
      state.lines = [];
      save();
      mount();
      const total = state.passed + state.failed;
      const shown = card(ok ? "✓" : "!", ok ? "すべてのチェックが通過" : `${state.failed} 件のチェックが失敗`,
        `${total} 件中 ${state.passed} 件 OK`, hold);
      // Appended after the card, so the pieces fall in front of its blurred backdrop.
      if (ok && els) {
        const box = document.createElement("div");
        box.className = "confetti";
        box.innerHTML = Array.from({ length: CONFETTI }, (_, i) => {
          const rand = (min, max) => Math.round(min + Math.random() * (max - min));
          return `<i style="left:${rand(0, 100)}%;background:${COLORS[i % COLORS.length]};` +
            `--drift:${rand(-160, 160)}px;--spin:${rand(-900, 900)}deg;animation-delay:${rand(0, 700)}ms"></i>`;
        }).join("");
        els.root.appendChild(box);
        setTimeout(() => box.remove(), hold + FADE_MS);
      }
      return shown.then(() => ({ passed: state.passed, failed: state.failed }));
    },
    // Caption: title (case or step) and detail (what is done, what to expect).
    // Resolves after `hold` ms so the viewer can read it before the action.
    step(title, detail = "", hold = readTime(`${title}${detail}`, HOLD_MS, 4000)) {
      state.title = String(title);
      state.detail = String(detail);
      save();
      mount();
      // Flipping the attribute restarts the entrance animation for each new caption.
      if (els?.caption) els.caption.dataset.tick = els.caption.dataset.tick === "0" ? "1" : "0";
      return new Promise((resolve) => setTimeout(resolve, hold));
    },
    // How many cases the video films: each chapter then fills one segment of the progress bar.
    cases(total) {
      state.total = Math.max(0, Math.floor(Number(total)) || 0);
      state.index = 0;
      state.caseDone = false;
      save();
      mount();
    },
    // Called by the frames (see the top of this file).
    relay(win, type, e) {
      HANDLERS[type]?.(win, e);
    },
    // Puts the page in a device frame of this size, for a mobile or narrow-width case; called again it
    // resizes the frame in view, and with no size it goes back to the full page. point(), scroll() and
    // frame() then address the device's document. Layout only: the user agent and touch stay desktop.
    device(width, height, label = "") {
      state.device = width ? { width: Number(width), height: Number(height) || 800, label: String(label) } : null;
      save();
      mount();
      // Long enough for the frame to load or to finish resizing.
      return new Promise((resolve) => setTimeout(resolve, 900));
    },
    // The document under test: the device's while the stage is up, the page's otherwise.
    frame() {
      return scene().document;
    },
    // Glides the pointer to the element a CSS selector names and resolves on arrival: run it before
    // the click, which would otherwise land while the pointer is still on its way.
    point(target) {
      const el = typeof target === "string" ? scene().document.querySelector(target) : target;
      if (!el) throw new Error(`__qa.point: no element matches ${target}`);
      el.scrollIntoViewIfNeeded?.();
      const rect = el.getBoundingClientRect();
      const at = box(scene());
      const travel = moveCursor(at.left + (rect.left + rect.width / 2) * at.scale, at.top + (rect.top + rect.height / 2) * at.scale);
      return new Promise((resolve) => setTimeout(resolve, travel + 150));
    },
    log(text) {
      push("log", `› ${fmt(text)}`);
    },
    // Lists the case's checks before they run, so the viewer sees what will be verified; check()
    // then ticks each by its label.
    plan(...labels) {
      state.checks = labels.flat().map((label) => ({ kind: "todo", label: String(label), text: "" })).slice(0, MAX_CHECKS);
      state.caseDone = false;
      save();
      mount();
    },
    // Ticks the label's row in the checklist with what was read, or marks it failed, and returns both
    // so the CLI prints them. `expected` may be a value, a predicate, or absent
    // (truthy check).
    check(label, actual, expected) {
      const pass = typeof expected === "function" ? Boolean(expected(actual))
        : expected === undefined ? Boolean(actual)
        : JSON.stringify(actual) === JSON.stringify(expected);
      const want = typeof expected === "function" || expected === undefined ? "" : ` (expected ${fmt(expected)})`;
      state[pass ? "passed" : "failed"] += 1;
      const row = { kind: pass ? "pass" : "fail", label: String(label), text: clip(`${fmt(actual)}${pass ? "" : want}`) };
      // Ticks the row plan() listed under this label, or adds one.
      const planned = state.checks.findIndex((c) => c.kind === "todo" && c.label === row.label);
      if (planned >= 0) state.checks[planned] = row;
      else state.checks = [...state.checks, row].slice(-MAX_CHECKS);
      // The case ends when nothing is left to tick: its length sets the next segment's pace.
      if (!state.caseDone && !state.checks.some((c) => c.kind === "todo")) {
        if (state.total) state.pace = Math.min(60000, Math.max(3000, Math.round((Date.now() - state.caseStart) / 0.9)));
        state.caseDone = true;
      }
      save();
      mount();
      original.log.call(console, `[qa] ${pass ? "PASS" : "FAIL"} ${label}: ${fmt(actual)}`);
      return { pass, actual };
    },
    // Scrolls the page with an ease the viewer can follow, where scrollTo or a wheel command would
    // cut to the new position: "top", "bottom", a y offset, or a CSS selector to bring to the middle.
    scroll(to, duration) {
      const view = scene();
      const page = view.document.scrollingElement;
      const max = page.scrollHeight - view.innerHeight;
      const el = typeof to === "string" && to !== "top" && to !== "bottom" ? view.document.querySelector(to) : null;
      if (typeof to === "string" && to !== "top" && to !== "bottom" && !el) throw new Error(`__qa.scroll: no element matches ${to}`);
      const rect = el?.getBoundingClientRect();
      const wanted = to === "top" ? 0 : to === "bottom" ? max
        : el ? page.scrollTop + rect.top + rect.height / 2 - view.innerHeight / 2 : Number(to);
      const end = Math.min(max, Math.max(0, wanted));
      const start = page.scrollTop;
      const time = duration ?? Math.min(1600, Math.max(450, Math.abs(end - start) * 0.5));
      const jump = (y) => view.scrollTo({ top: y, behavior: "instant" });
      if (!window.requestAnimationFrame || time <= 0 || end === start) {
        jump(end);
        return Promise.resolve();
      }
      return new Promise((resolve) => {
        const t0 = performance.now();
        const frame = (now) => {
          const t = Math.min(1, (now - t0) / time);
          jump(start + (end - start) * (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2));
          if (t < 1) window.requestAnimationFrame(frame);
          else resolve();
        };
        window.requestAnimationFrame(frame);
      });
    },
    // Hidden unless a case needs it: "open" keeps a tall console on screen for a case whose observable
    // is what the console says, "auto" shows a small one while it has lines, anything else hides it.
    console(mode) {
      state.console = ["open", "auto"].includes(mode) ? mode : "off";
      save();
      mount();
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
    // Back to an empty bar and no progress: run it before the recording starts, then cases().
    clear() {
      state.title = "";
      state.detail = "";
      state.lines = [];
      state.checks = [];
      state.pace = PACE_MS;
      state.total = 0;
      state.index = 0;
      state.caseDone = false;
      state.passed = 0;
      state.failed = 0;
      state.console = "off";
      state.device = null;
      save();
      mount();
    },
  });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount);
  else mount();
})();
