#!/usr/bin/env bash
set -euo pipefail

# Offline tests for qa-overlay.js.
#
# The init script runs in a node vm with a stub window, document, console
# and sessionStorage standing in for the browser. The tests cover the host
# the page must not see (inert, aria-hidden), the caption and panel API
# (chapter, step, check, log, place, hide, show, clear), the console mirror with
# escaping, the
# line cap and truncation, the click ripple, the state restored after a
# navigation, the mount deferred until the document has a body, and the
# zoom applied as soon as the document has a root.

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
    appendChild(c) { c.isConnected = true; this.children.push(c); return c; },
    attachShadow() { return shadow; },
    remove() { if (this.parent) this.parent.children = this.parent.children.filter((c) => c !== this); },
  });
  for (const sel of [".bar", ".title", ".detail", ".log", ".chapter", ".chapter-title", ".chapter-detail"])
    parts[sel] = element("div");
  const body = element("body");
  const listeners = {};
  const record = (level) => (...args) => calls.push([level, args.map(String).join(" ")]);
  const observers = [];
  const win = {
    document: {
      body, documentElement: readyState === "loading" ? null : element("html"), readyState, createElement: element,
      addEventListener(type, fn) { listeners[`document:${type}`] = fn; },
    },
    MutationObserver: class { constructor(cb) { this.cb = cb; observers.push(this); } observe() {} disconnect() { this.off = true; } },
    sessionStorage: storage,
    getComputedStyle: (el) => ({ zoom: el.style.zoom || "1" }),
    console: { log: record("log"), info: record("info"), warn: record("warn"), error: record("error") },
    setTimeout,
    addEventListener(type, fn) { listeners[type] = fn; },
  };
  win.window = win;
  return { win, parts, body, listeners, shadow, observers, element };
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
  const { win, parts, body, listeners, shadow } = makeWindow(storage, calls);
  vm.runInNewContext(source, win);
  const log = () => parts[".log"].innerHTML;

  await test("host is inert, aria-hidden, appended to body", () => {
    const host = body.children[0];
    assert.equal(host.tag, "qa-overlay");
    assert.equal(host.attrs["aria-hidden"], "true");
    assert.equal(host.inert, true);
    assert.equal(typeof win.__qa, "object");
  });

  await test("the document is zoomed 2x", () => {
    assert.equal(win.document.documentElement.style.zoom, "2");
  });

  const held = win.__qa.step("ケース 1", "期待", 0);
  await test("step sets the caption and returns a promise", () => {
    assert.equal(typeof held.then, "function");
    assert.equal(parts[".title"].textContent, "ケース 1");
    assert.equal(parts[".detail"].textContent, "期待");
  });
  await held;

  await test("check passes on equal values and echoes to the real console", () => {
    const result = win.__qa.check("rows", 10, 10);
    assert.equal(result.pass, true);
    assert.equal(result.actual, 10);
    assert.match(log(), /class="pass">✓ rows: 10</);
    assert.deepEqual(calls.at(-1), ["log", "[qa] PASS rows: 10"]);
  });

  await test("check fails with the expected value shown", () => {
    assert.equal(win.__qa.check("rows", 9, 10).pass, false);
    assert.match(log(), /class="fail">✗ rows: 9 \(expected 10\)</);
    assert.deepEqual(calls.at(-1), ["log", "[qa] FAIL rows: 9"]);
  });

  await test("check takes a predicate, a truthy test, and structured values", () => {
    assert.equal(win.__qa.check("more", 30, (n) => n > 10).pass, true);
    assert.equal(win.__qa.check("open", "").pass, false);
    assert.equal(win.__qa.check("state", { a: [1] }, { a: [1] }).pass, true);
    assert.match(log(), /✓ state: {"a":\[1\]}</);
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
    assert.equal(parts[".title"].textContent, "");
  });

  await test("hide takes the host out of frame and show brings it back", () => {
    const host = body.children.find((c) => c.tag === "qa-overlay");
    win.__qa.hide();
    assert.equal(host.style.display, "none");
    assert.equal(JSON.parse(storage.getItem("__qa")).hidden, true);
    win.__qa.show();
    assert.equal(host.style.display, "");
  });

  await test("a mousedown keeps its ripple at the pointer across zoom levels", async () => {
    for (const zoom of [2, 1, 1.25]) {
      win.document.documentElement.style.zoom = String(zoom);
      listeners.mousedown({ clientX: 100, clientY: 200 });
      const ripple = shadow.children.at(-1);
      assert.equal(ripple.className, "ripple");
      assert.equal(parseFloat(ripple.style.left) * zoom, 100);
      assert.equal(parseFloat(ripple.style.top) * zoom, 200);
    }
    win.document.documentElement.style.zoom = "2";
    await new Promise((r) => setTimeout(r, 750));
    assert.ok(!shadow.children.some((c) => c.className === "ripple"));
  });

  await test("chapter displays literal text until its hold finishes", async () => {
    const heldChapter = win.__qa.chapter("3. <test>", "Expected <result>", 0);
    assert.equal(typeof heldChapter.then, "function");
    assert.equal(parts[".chapter"].hidden, false);
    assert.equal(parts[".chapter-title"].textContent, "3. <test>");
    assert.equal(parts[".chapter-detail"].textContent, "Expected <result>");
    await heldChapter;
    assert.equal(parts[".chapter"].hidden, true);
    assert.ok(!storage.getItem("__qa").includes("3. <test>"));
  });

  await test("state survives a navigation through sessionStorage", () => {
    win.__qa.step("ケース 2", "d2", 0);
    win.__qa.log("kept");
    const next = makeWindow(storage, []);
    vm.runInNewContext(source, next.win);
    assert.equal(next.parts[".title"].textContent, "ケース 2");
    assert.equal(next.parts[".detail"].textContent, "d2");
    assert.match(next.parts[".log"].innerHTML, /kept/);
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

  await test("zoom waits for the root element when the script runs before it exists", () => {
    const early = makeWindow(makeStorage(), [], "loading");
    vm.runInNewContext(source, early.win);
    assert.equal(early.observers.length, 1);
    early.win.document.documentElement = early.element("html");
    early.observers[0].cb();
    assert.equal(early.win.document.documentElement.style.zoom, "2");
    assert.equal(early.observers[0].off, true);
  });

  console.log(`${passed} tests passed`);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
JS
