#!/usr/bin/env bash
set -euo pipefail

# Offline tests for qa-overlay.js.
#
# The init script runs in a node vm with a stub window, document, console
# and sessionStorage standing in for the browser. The tests cover the host
# the page must not see (inert, aria-hidden), the caption and panel API
# (chapter, step, check, log, place, hide, show, clear), the console mirror with
# escaping, the
# line cap and truncation, the progress bar, the pointer, the click rings,
# the keystroke display, the state restored after a navigation, the mount
# deferred until the document has a body, and the page left unzoomed.

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
readonly SCRIPT="${TEST_DIR}/qa-overlay.js"

node --check "${SCRIPT}"
node - "${SCRIPT}" <<'JS'
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");

const source = fs.readFileSync(process.argv[2], "utf8");

const makeStorage = () => {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
  };
};

const makeWindow = (storage, calls, readyState = "complete") => {
  const parts = {};
  const shadow = {
    innerHTML: "", children: [], querySelector: (sel) => parts[sel],
    appendChild(c) { c.parent = shadow; shadow.children.push(c); return c; },
  };
  const element = (tag) => ({
    tag, attrs: {}, children: [], isConnected: false, dataset: {}, textContent: "", innerHTML: "", style: {},
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(c) { c.isConnected = true; c.parent = this; this.children.push(c); return c; },
    attachShadow() { return shadow; },
    showPopover() { this.shown = (this.shown || 0) + 1; },
    remove() {
      if (this.parent) this.parent.children = this.parent.children.filter((c) => c !== this);
      this.isConnected = false;
    },
    getBoundingClientRect() { return this.rect; },
  });
  for (const sel of [".bar", ".caption", ".badge", ".title", ".detail", ".log", ".chapter", ".chapter-num", ".chapter-title", ".chapter-detail",
    ".cursor", ".caption .progress", ".chapter-progress", ".ring circle + circle", ".keys",
    ".console", ".rows", ".count", ".rail", ".rail u", ".rail b",
    "#qa-device", ".device", ".label"])
    parts[sel] = element("div");
  const body = element("body");
  const listeners = {};
  const targets = {};
  const record = (level) => (...args) => calls.push([level, args.map(String).join(" ")]);
  const observers = [];
  const win = {
    document: {
      body, documentElement: readyState === "loading" ? null : element("html"), readyState, createElement: element,
      querySelector: (sel) => targets[sel],
      scrollingElement: { scrollHeight: 3000, scrollTop: 0 },
      addEventListener(type, fn) { listeners[`document:${type}`] = fn; },
    },
    MutationObserver: class { constructor(cb) { this.cb = cb; observers.push(this); } observe() {} disconnect() { this.off = true; } },
    sessionStorage: storage,
    getComputedStyle: (el) => ({ zoom: el.style.zoom || "1" }),
    console: { log: record("log"), info: record("info"), warn: record("warn"), error: record("error") },
    setTimeout, clearTimeout, innerHeight: 1000, innerWidth: 1280, location: { href: "https://app.test/page?a=1&b=<2>" },
    scrollTo({ top }) { win.document.scrollingElement.scrollTop = top; },
    addEventListener(type, fn) { listeners[type] = fn; },
  };
  win.window = win;
  win.top = win;
  return { win, parts, body, listeners, shadow, observers, element, targets };
};

let passed = 0;
const test = async (name, fn) => {
  await fn();
  passed += 1;
  console.log(`ok - ${name}`);
};

(async () => {
  const calls = [];
  const storage = makeStorage();
  const { win, parts, body, listeners, shadow, targets, element } = makeWindow(storage, calls);
  vm.runInNewContext(source, win);
  const log = () => parts[".log"].innerHTML;
  const checks = () => parts[".rows"].innerHTML;

  await test("every element and animation the script creates has its rule in the stylesheet", () => {
    for (const rule of [".ripple {", ".confetti {", ".confetti i {", ".keys kbd {", ".rows i {", ".cursor {", ".rail {"])
      assert.ok(source.includes(rule), rule);
    const used = [...source.matchAll(/animation: (qa-[a-z-]+)/g)].map((m) => m[1]);
    for (const name of new Set(used)) assert.ok(source.includes(`@keyframes ${name} `), name);
  });

  await test("host is inert, aria-hidden, appended to body", () => {
    const host = body.children[0];
    assert.equal(host.tag, "qa-overlay");
    assert.equal(host.attrs["aria-hidden"], "true");
    assert.equal(host.inert, true);
    assert.equal(host.attrs.popover, "manual");
    assert.equal(typeof win.__qa, "object");
  });

  await test("the page is left unzoomed, so the app's own measurements hold", () => {
    assert.equal(win.document.documentElement.style.zoom, undefined);
    assert.equal(win.document.documentElement.children.length, 0);
  });

  const held = win.__qa.step("ケース 1", "期待", 0);
  await test("step sets the caption and returns a promise", () => {
    assert.equal(typeof held.then, "function");
    assert.equal(parts[".title"].textContent, "ケース 1");
    assert.equal(parts[".detail"].textContent, "期待");
    assert.equal(parts[".bar"].dataset.empty, "false");
  });
  await held;

  await test("each step flips the tick that restarts the caption animation", () => {
    const before = parts[".caption"].dataset.tick;
    win.__qa.step("ケース 1", "期待", 0);
    assert.notEqual(parts[".caption"].dataset.tick, before);
  });

  await test("a case number leading the caption moves into the badge", () => {
    win.__qa.step("ケース 12: 末尾から <移動>", "", 0);
    assert.equal(parts[".badge"].textContent, "ケース 12");
    assert.equal(parts[".title"].textContent, "末尾から <移動>");
    win.__qa.step("ケース 1", "期待", 0);
    assert.equal(parts[".badge"].textContent, "");
    assert.equal(parts[".title"].textContent, "ケース 1");
  });

  await test("check passes on equal values and echoes to the real console", () => {
    const result = win.__qa.check("rows", 10, 10);
    assert.equal(result.pass, true);
    assert.equal(result.actual, 10);
    assert.equal(checks(), `<div class="pass"><i>✓</i><span>rows</span><b>10</b></div>`);
    assert.equal(log(), "");
    assert.deepEqual(calls.at(-1), ["log", "[qa] PASS rows: 10"]);
  });

  await test("check fails with the expected value shown", () => {
    assert.equal(win.__qa.check("rows", 9, 10).pass, false);
    assert.match(checks(), /<div class="fail"><i>✗<\/i><span>rows<\/span><b>9 \(expected 10\)<\/b><\/div>$/);
    assert.deepEqual(calls.at(-1), ["log", "[qa] FAIL rows: 9"]);
  });

  await test("check takes a predicate, a truthy test, and structured values", () => {
    assert.equal(win.__qa.check("more", 30, (n) => n > 10).pass, true);
    assert.equal(win.__qa.check("open", "").pass, false);
    assert.equal(win.__qa.check("state", { a: [1] }, { a: [1] }).pass, true);
    assert.match(checks(), /<span>state<\/span><b>{"a":\[1\]}<\/b>/);
    for (let i = 0; i < 8; i += 1) win.__qa.check(`c${i}`, 1, 1);
    assert.equal(checks().match(/<div/g).length, 6);
  });

  await test("console output is mirrored, escaped, and still reaches the console", () => {
    win.console.warn("<b>", { x: 1 });
    assert.match(log(), /class="warn">⚠ &lt;b&gt; {"x":1}</);
    assert.deepEqual(calls.at(-1), ["warn", "<b> [object Object]"]);
    listeners.error({ message: "boom" });
    assert.match(log(), /class="error">✖ boom</);
    listeners.unhandledrejection({ reason: "nope" });
    assert.match(log(), /✖ nope</);
  });

  await test("plan lists the checks ahead, check ticks them by label, and the case ends with the last", async () => {
    win.__qa.cases(1);
    await win.__qa.chapter("1. a", "", 0);
    win.__qa.plan("行数", ["<続き>", "active"]);
    assert.equal(checks().match(/class="todo"><i><\/i>/g).length, 3);
    assert.match(checks(), /<span>&lt;続き&gt;<\/span><b><\/b>/);
    assert.equal(parts[".count"].textContent, "0 / 3");
    win.__qa.check("active", "#a", "#a");
    assert.match(checks(), /^<div class="todo">.*<div class="todo">.*<div class="pass"><i>✓<\/i><span>active<\/span><b>#a<\/b><\/div>$/);
    assert.equal(parts[".caption .progress"].dataset.full, "false");
    win.__qa.check("行数", 20, 20);
    win.__qa.check("<続き>", false, true);
    assert.equal(parts[".count"].textContent, "3 / 3");
    assert.equal(parts[".caption .progress"].dataset.full, "true");
    win.__qa.check("extra", 1, 1);
    assert.equal(parts[".count"].textContent, "4 / 4");
    win.__qa.clear();
  });

  await test("the console holds the page's output only, and opens taller or goes away on request", () => {
    assert.equal(parts[".console"].dataset.mode, "off");
    win.__qa.console("open");
    for (let i = 0; i < 15; i += 1) win.__qa.log(`open${i}`);
    assert.equal(parts[".console"].dataset.mode, "open");
    assert.equal(log().match(/<div/g).length, 12);
    assert.ok(!log().includes("rows"));
    win.__qa.console("auto");
    assert.equal(parts[".console"].dataset.mode, "auto");
    win.__qa.console("anything else");
    assert.equal(parts[".console"].dataset.mode, "off");
  });

  await test("panel keeps the last seven lines and truncates long ones", () => {
    for (let i = 0; i < 10; i += 1) win.__qa.log(`line${i}`);
    assert.equal(log().match(/<div/g).length, 7);
    assert.ok(!log().includes("line2"));
    assert.ok(log().includes("line3"));
    win.__qa.log("x".repeat(200));
    assert.match(log(), /› x{158}…</);
  });

  await test("place moves the bar, clear empties bar and panel", () => {
    win.__qa.place("top");
    assert.equal(parts[".bar"].dataset.place, "top");
    win.__qa.place("elsewhere");
    assert.equal(parts[".bar"].dataset.place, "bottom");
    win.__qa.clear();
    assert.equal(log(), "");
    assert.equal(checks(), "");
    assert.equal(parts[".title"].textContent, "");
    assert.equal(parts[".bar"].dataset.empty, "true");
  });

  await test("hide takes the host out of frame and show brings it back", () => {
    const host = body.children.find((c) => c.tag === "qa-overlay");
    win.__qa.hide();
    assert.equal(host.style.display, "none");
    assert.equal(JSON.parse(storage.getItem("__qa")).hidden, true);
    win.__qa.show();
    assert.equal(host.style.display, "");
  });

  await test("a mousedown draws two rings at the pointer and removes them", async () => {
    listeners.mousedown({ clientX: 100, clientY: 200 });
    const rings = shadow.children.filter((c) => c.className === "ripple");
    assert.equal(rings.length, 2);
    assert.equal(rings[0].style.left, "100px");
    assert.equal(rings[1].style.top, "200px");
    await new Promise((r) => setTimeout(r, 900));
    assert.ok(!shadow.children.some((c) => c.className === "ripple"));
  });

  await test("keys show as keycaps: typing extends the row, a chord replaces it, a password is dots", () => {
    const keys = () => parts[".keys"].innerHTML;
    const down = (key, mods = [], target = {}) => listeners.keydown({ key, target, getModifierState: (m) => mods.includes(m) });
    down("a"); down("B", ["Shift"]); down("Enter");
    assert.equal(keys(), "<kbd>a</kbd><kbd>B</kbd><kbd>↵ Enter</kbd>");
    assert.equal(parts[".keys"].dataset.idle, "false");
    down("Meta", ["Meta"]);
    assert.equal(keys(), "<kbd>a</kbd><kbd>B</kbd><kbd>↵ Enter</kbd>");
    down("k", ["Meta", "Shift"]);
    assert.equal(keys(), "<kbd>⌘</kbd><kbd>⇧</kbd><kbd>K</kbd>");
    down("x");
    assert.equal(keys(), "<kbd>x</kbd>");
    down("s", [], { type: "password" }); down("<");
    assert.equal(keys(), "<kbd>x</kbd><kbd>•</kbd><kbd>&lt;</kbd>");
    for (let i = 0; i < 20; i += 1) down("z");
    assert.equal(keys().match(/<kbd>/g).length, 12);
  });

  await test("chapter displays literal text until its hold finishes", async () => {
    const heldChapter = win.__qa.chapter("3. <test>", "Expected <result>", 0);
    assert.equal(typeof heldChapter.then, "function");
    assert.equal(parts[".chapter"].hidden, false);
    assert.equal(parts[".chapter-num"].textContent, "3");
    assert.equal(parts[".chapter-title"].textContent, "<test>");
    assert.equal(parts[".chapter-detail"].textContent, "Expected <result>");
    assert.equal(parts[".chapter"].dataset.leaving, "false");
    await heldChapter;
    assert.equal(parts[".chapter"].hidden, true);
    assert.equal(parts[".chapter"].dataset.leaving, "true");
    assert.ok(!storage.getItem("__qa").includes("<test>"));
    await win.__qa.chapter("準備", "", 0);
    assert.equal(parts[".chapter-num"].textContent, "");
    assert.equal(parts[".chapter-title"].textContent, "準備");
  });

  await test("cases draws one segment per case and each chapter fills the next", async () => {
    const bar = () => parts[".caption .progress"].innerHTML;
    assert.equal(bar(), "");
    win.__qa.cases(3);
    assert.equal(bar().match(/class="todo"/g).length, 3);
    await win.__qa.chapter("1. a", "", 0);
    await win.__qa.chapter("2. b", "", 0);
    assert.match(bar(), /^<i class="done"><\/i><i><u style="animation-duration:15000ms;animation-delay:-?\d+ms"><\/u><\/i><i class="todo"><\/i><b>2 \/ 3<\/b>$/);
    assert.equal(parts[".chapter-progress"].dataset.key, "2/3");
    await win.__qa.chapter("3. c", "", 0);
    await win.__qa.chapter("4. d", "", 0);
    assert.equal(parts[".ring circle + circle"].style.animationDuration, "0ms");
    assert.match(bar(), /<b>3 \/ 3<\/b>$/);
    win.__qa.clear();
    assert.equal(bar(), "");
  });

  await test("the current segment keeps its fill until the case changes, and the first check closes it", async () => {
    win.__qa.cases(2);
    await win.__qa.chapter("1. a", "", 0);
    const progress = parts[".caption .progress"];
    const before = progress.innerHTML;
    assert.equal(progress.dataset.full, "false");
    await new Promise((r) => setTimeout(r, 5));
    win.__qa.log("no rewrite");
    win.__qa.check("ok", 1, 1);
    assert.equal(progress.innerHTML, before);
    assert.equal(progress.dataset.full, "true");
    await win.__qa.chapter("2. b", "", 0);
    assert.equal(progress.dataset.full, "false");
    assert.notEqual(progress.innerHTML, before);
    // The first case took a few ms, so the pace is clamped to its floor.
    assert.match(progress.innerHTML, /animation-duration:3000ms/);
    win.__qa.clear();
  });

  await test("the overlay reopens in the top layer after the app opens a dialog", () => {
    const host = body.children.find((c) => c.tag === "qa-overlay");
    const before = host.shown;
    listeners.toggle({ target: {}, newState: "open" });
    assert.equal(host.shown, before + 1);
    listeners.toggle({ target: host, newState: "open" });
    listeners.toggle({ target: {}, newState: "closed" });
    assert.equal(host.shown, before + 1);
  });

  await test("a chapter starts with no checks and an empty console", async () => {
    win.__qa.log("previous case");
    win.__qa.check("previous", 1, 1);
    await win.__qa.chapter("1. next", "", 0);
    assert.equal(log(), "");
    assert.equal(checks(), "");
  });

  await test("finish tallies the checks and throws confetti only when none failed", async () => {
    win.__qa.clear();
    win.__qa.cases(1);
    win.__qa.check("a", 1, 1);
    win.__qa.check("b", 2, 2);
    const done = win.__qa.finish(0);
    const confetti = shadow.children.find((c) => c.className === "confetti");
    assert.equal(confetti.innerHTML.match(/<i /g).length, 90);
    assert.equal(parts[".chapter-num"].textContent, "✓");
    assert.equal(parts[".chapter-detail"].textContent, "2 件中 2 件 OK");
    assert.match(parts[".caption .progress"].innerHTML, /^<i class="done"><\/i><b>/);
    assert.deepEqual({ ...(await done) }, { passed: 2, failed: 0 });
    await new Promise((r) => setTimeout(r, 250));
    assert.ok(!shadow.children.some((c) => c.className === "confetti"));

    win.__qa.check("c", 1, 2);
    await win.__qa.finish(0);
    assert.ok(!shadow.children.some((c) => c.className === "confetti"));
    assert.equal(parts[".chapter-title"].textContent, "1 件のチェックが失敗");
    win.__qa.clear();
    await win.__qa.finish(0);
    assert.ok(!shadow.children.some((c) => c.className === "confetti"));
    win.__qa.clear();
  });

  await test("scroll goes to top, bottom, an offset or an element, clamped to the page", async () => {
    const page = win.document.scrollingElement;
    await win.__qa.scroll("bottom");
    assert.equal(page.scrollTop, 2000);
    await win.__qa.scroll(500);
    assert.equal(page.scrollTop, 500);
    targets["#row"] = Object.assign(element("li"), { rect: { left: 0, top: 800, width: 10, height: 100 } });
    await win.__qa.scroll("#row");
    assert.equal(page.scrollTop, 850);
    await win.__qa.scroll(99999);
    assert.equal(page.scrollTop, 2000);
    await win.__qa.scroll("top");
    assert.equal(page.scrollTop, 0);
    assert.throws(() => win.__qa.scroll("#none"), /no element matches #none/);
  });

  await test("a scroll shows the rail with the thumb at the page position and the direction", () => {
    const page = win.document.scrollingElement;
    page.scrollTop = 1000;
    listeners.scroll();
    assert.equal(parts[".rail"].dataset.idle, "false");
    assert.equal(parts[".rail u"].style.height, `${(1000 / 3000) * 100}%`);
    assert.equal(parts[".rail u"].style.top, `${0.5 * (100 - (1000 / 3000) * 100)}%`);
    assert.equal(parts[".rail b"].textContent, "↓");
    page.scrollTop = 200;
    listeners.scroll();
    assert.equal(parts[".rail b"].textContent, "↑");
    page.scrollTop = 0;
  });

  await test("device puts the page in a frame of that size and moves the cards beside it", async () => {
    const shown = win.__qa.device(390, 844, "iPhone 15");
    const stageHost = body.children.find((c) => c.tag === "qa-stage");
    assert.equal(stageHost.attrs.popover, "manual");
    assert.match(shadow.innerHTML, /<iframe id="qa-device" title="device" src="https:\/\/app.test\/page\?a=1&amp;b=&lt;2&gt;">/);
    assert.equal(parts["#qa-device"].style.width, "390px");
    assert.equal(parts["#qa-device"].style.height, "844px");
    assert.equal(parts["#qa-device"].style.transform, "scale(1)");
    assert.equal(parts[".label"].textContent, "iPhone 15 · 390 × 844");
    assert.equal(parts[".bar"].dataset.device, "true");
    assert.equal(JSON.parse(storage.getItem("__qa")).device.width, 390);
    assert.equal(typeof shown.then, "function");

    win.__qa.device(768, 1024);
    assert.equal(parts["#qa-device"].style.transform, `scale(${880 / 1024})`);
    assert.equal(parts[".label"].textContent, "768 × 1024 · 86%");
    win.__qa.device(1200, 800);
    assert.equal(parts[".bar"].dataset.device, "false");

    win.__qa.device();
    assert.ok(!body.children.some((c) => c.tag === "qa-stage"));
    assert.equal(parts[".bar"].dataset.device, "false");
    assert.equal(JSON.parse(storage.getItem("__qa")).device, null);
  });

  await test("a same-origin frame draws nothing and relays its events through the frame's box", () => {
    const inner = makeWindow(makeStorage(), []);
    inner.win.top = win;
    inner.win.frameElement = { offsetWidth: 400, getBoundingClientRect: () => ({ left: 440, top: 100, right: 640, bottom: 500, width: 200 }) };
    vm.runInNewContext(source, inner.win);
    assert.equal(inner.body.children.length, 0);
    assert.equal(inner.win.__qa, undefined);
    inner.listeners.mousemove({ clientX: 100, clientY: 40 });
    assert.equal(parts[".cursor"].style.transform, "translate(490px, 120px)");
    inner.win.document.scrollingElement.scrollTop = 500;
    inner.listeners.scroll({});
    assert.equal(parts[".rail"].style.left, "656px");
    assert.equal(parts[".rail"].style.top, "100px");
    inner.win.console.warn("from frame");
    assert.match(log(), /class="warn">⚠ from frame</);

    const foreign = makeWindow(makeStorage(), []);
    Object.defineProperty(foreign.win, "top", { get() { throw new Error("cross-origin"); } });
    vm.runInNewContext(source, foreign.win);
    assert.equal(foreign.body.children.length, 0);
    win.__qa.clear();
  });

  await test("the pointer follows the mouse in layout px and dips while a button is down", () => {
    const fresh = makeWindow(makeStorage(), []);
    vm.runInNewContext(source, fresh.win);
    assert.equal(fresh.parts[".cursor"].hidden, true);
    listeners.mousemove({ clientX: 200, clientY: 100 });
    assert.equal(parts[".cursor"].hidden, false);
    assert.equal(parts[".cursor"].style.transform, "translate(200px, 100px)");
    listeners.mousedown({ clientX: 200, clientY: 100 });
    assert.equal(parts[".cursor"].dataset.down, "true");
    listeners.mouseup({});
    assert.equal(parts[".cursor"].dataset.down, "false");
  });

  await test("point glides the pointer to the element's centre and resolves on arrival", async () => {
    targets["#go"] = Object.assign(element("button"), { rect: { left: 400, top: 200, width: 100, height: 50 } });
    const arrived = win.__qa.point("#go");
    assert.equal(parts[".cursor"].style.transform, "translate(450px, 225px)");
    assert.equal(parts[".cursor"].style.transitionDuration, "307ms");
    await arrived;
    assert.throws(() => win.__qa.point("#missing"), /no element matches #missing/);
  });

  await test("state survives a navigation through sessionStorage", () => {
    win.__qa.step("ケース 2", "d2", 0);
    win.__qa.log("kept");
    const next = makeWindow(storage, []);
    vm.runInNewContext(source, next.win);
    assert.equal(next.parts[".title"].textContent, "ケース 2");
    assert.equal(next.parts[".detail"].textContent, "d2");
    assert.match(next.parts[".log"].innerHTML, /kept/);
    assert.equal(next.parts[".cursor"].style.transform, "translate(450px, 225px)");
  });

  await test("a second run in the same page keeps the first API", () => {
    const before = win.__qa;
    vm.runInNewContext(source, win);
    assert.equal(win.__qa, before);
  });

  await test("a detached host is appended again on the next write", () => {
    body.children[0].isConnected = false;
    win.__qa.log("back");
    assert.equal(body.children.length, 2);
    assert.equal(body.children[1], body.children[0]);
  });

  await test("mount waits for DOMContentLoaded while the document is loading", () => {
    const loading = makeWindow(makeStorage(), [], "loading");
    vm.runInNewContext(source, loading.win);
    assert.equal(loading.body.children.length, 0);
    loading.listeners["document:DOMContentLoaded"]();
    assert.equal(loading.body.children.length, 1);
  });

  console.log(`${passed} tests passed`);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
JS
