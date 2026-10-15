import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("../../app/javascript/controllers/drawing_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
  .replace("export default class", "globalThis.Drawing = class");
const node = (tag, attributes = {}, children = []) => ({ tag, attributes, children });
const scene = {
  view_box: "0 0 512 512",
  art: node("g", { fill: "#aabbcc", stroke: "#123456", "stroke-width": "4" }, [
    node("rect", { width: "512", height: "512", fill: "#fffdf7" }),
    node("g", { transform: "translate(10 20)", opacity: "0.7" }, [
      node("path", { d: "M0 0L100 0", "stroke-dasharray": "3 4", "fill-opacity": "0.5" }),
      node("circle", { cx: "50", cy: "50", r: "20", stroke: "none" }),
    ]),
  ]),
};
const settle = () => new Promise((resolve) => setImmediate(resolve));

function setup({ reduced = false, fetcher } = {}) {
  let now = Date.parse("2026-10-15T12:00:00Z");
  let nextId = 0;
  const frames = new Map(), timers = new Map(), listeners = new Map();
  const motion = { matches: reduced, addEventListener() {}, removeEventListener() {} };
  const matrix = { inverse() { return this; }, multiply() { return this; } };
  const element = (namespace, tagName = "g") => ({
    tagName, attributes: {}, style: {}, children: [],
    setAttribute(name, value) { this.attributes[name] = String(value); },
    getAttribute(name) { return this.attributes[name] ?? null; },
    hasAttribute(name) { return name in this.attributes; },
    removeAttribute(name) { delete this.attributes[name]; if (name === "style") this.style = {}; },
    toggleAttribute(name, enabled) { if (enabled) this.setAttribute(name, ""); else this.removeAttribute(name); },
    append(child) { this.children.push(child); child.parentElement = this; },
    replaceChildren(...children) { this.children = []; children.forEach((child) => this.append(child)); },
    getTotalLength() { return 100; },
    getPointAtLength(length) { return { x: length, y: 25 }; },
    getScreenCTM() { return matrix; },
    createSVGPoint() { return { matrixTransform() { return this; } }; },
  });
  const inherited = (element, attribute, fallback) => element.attributes[attribute] ??
    (element.parentElement ? inherited(element.parentElement, attribute, fallback) : fallback);
  const document = {
    hidden: false, createElementNS: element,
    addEventListener(name, listener) { listeners.set(name, listener); },
    removeEventListener(name) { listeners.delete(name); },
  };
  let requests = 0;
  const context = {
    document, AbortController, Date: { now: () => now, parse: Date.parse },
    window: {
      matchMedia: () => motion,
      getComputedStyle: (element) => ({
        fillOpacity: inherited(element, "fill-opacity", "1"),
        stroke: inherited(element, "stroke", "none"),
        strokeWidth: inherited(element, "stroke-width", "1"),
      }),
    },
    fetch: (...args) => { requests++; return fetcher ? fetcher(...args) : Promise.resolve({ ok: true, json: async () => scene }); },
    requestAnimationFrame(callback) { frames.set(++nextId, callback); return nextId; },
    cancelAnimationFrame(id) { frames.delete(id); },
    setTimeout(callback) { timers.set(++nextId, callback); return nextId; },
    clearTimeout(id) { timers.delete(id); },
  };
  runInNewContext(source, context);
  const controller = new context.Drawing();
  for (const target of ["svg", "art", "pencil", "fallback", "caption"]) controller[`${target}Target`] = element();
  const startedAt = new Date(now + 5000).toISOString();
  controller.presentationValue = {
    id: 1, sceneUrl: "/rounds/1/drawing.json", imageUrl: "/rounds/1/drawing", duration: 6000,
    startedAt, serverTime: startedAt, complete: false,
  };
  controller.connect();
  return {
    controller, frames, timers, document, motion, listeners, requests: () => requests,
    tick(milliseconds) {
      now += milliseconds;
      const callbacks = [...frames.values(), ...timers.values()];
      frames.clear(); timers.clear(); callbacks.forEach((callback) => callback());
    },
    poll() {
      controller.presentationValue.serverTime = new Date(now + 5000).toISOString();
      controller.presentationValueChanged();
    },
  };
}

test("saved geometry traces, fills, and restores its exact original styles in six seconds", async () => {
  const env = setup();
  await settle();
  const c = env.controller;
  assert.equal(c.svgTarget.hasAttribute("hidden"), false);
  assert.equal(c.strokes.length, 2, "paper is not a stroke");
  assert.ok(c.strokes.every(({ element }) => element.style.visibility === "hidden"));
  env.tick(2100);
  const path = c.strokes[0].element;
  assert.equal(path.style.visibility, "visible");
  assert.ok(path.style.strokeDashoffset > 0 && path.style.strokeDashoffset < 100);
  assert.ok(path.style.fillOpacity > 0 && path.style.fillOpacity < 0.5);
  assert.equal(c.pencilTarget.attributes.visibility, "visible");
  assert.equal(path.parentElement.attributes.transform, "translate(10 20)");
  env.poll();
  assert.equal(env.requests(), 1, "state polls do not fetch or restart the scene");
  assert.equal(c.elapsed, 2100);
  env.tick(2400);
  assert.equal(c.strokes[1].element.style.stroke, "#28362f", "fill-only shapes get a temporary pencil outline");
  env.tick(1500);
  assert.ok(c.strokes.every(({ element }) => Object.keys(element.style).length === 0));
  assert.equal(path.attributes["stroke-dasharray"], "3 4");
  assert.equal(path.attributes["fill-opacity"], "0.5");
  assert.equal(c.strokes[1].element.attributes.stroke, "none");
  assert.equal(c.pencilTarget.attributes.visibility, "hidden");
  assert.equal(c.captionTarget.hidden, true);
  assert.equal(env.frames.size, 0);
});

test("reduced motion reveals layers on the same schedule without pen motion or early clues", async () => {
  const env = setup({ reduced: true });
  await settle();
  env.tick(2500);
  assert.ok(env.controller.strokes.every(({ element }) => element.style.visibility === "hidden"));
  assert.equal(env.frames.size, 0);
  assert.equal(env.timers.size, 1);
  env.tick(1000);
  assert.equal(env.controller.strokes[0].element.style.visibility, undefined);
  assert.equal(env.controller.strokes[1].element.style.visibility, "hidden");
  assert.equal(env.controller.pencilTarget.attributes.visibility, "hidden");
  env.tick(2500);
  assert.equal(env.timers.size, 0);
});

test("hidden tabs and late responses catch up instead of replaying the intro", async () => {
  let respond;
  const env = setup({ fetcher: () => new Promise((resolve) => { respond = resolve; }) });
  env.tick(4500);
  respond({ ok: true, json: async () => scene });
  await settle();
  assert.equal(env.controller.elapsed, 4500);
  assert.equal(env.controller.strokes[0].element.style.visibility, undefined);
  env.document.hidden = true;
  env.listeners.get("visibilitychange")();
  assert.equal(env.frames.size, 0);
  env.tick(30000);
  env.document.hidden = false;
  env.listeners.get("visibilitychange")();
  assert.equal(env.controller.captionTarget.hidden, true);
  assert.equal(env.frames.size, 0);
});

test("an early answer reveal completes the drawing and disconnect cancels remaining work", async () => {
  const env = setup();
  await settle();
  env.tick(500);
  env.controller.presentationValue.complete = true;
  env.poll();
  assert.ok(env.controller.strokes.every(({ element }) => Object.keys(element.style).length === 0));
  assert.equal(env.frames.size, 0);
  env.controller.disconnect();
  assert.equal(env.listeners.size, 0);
  assert.equal(env.controller.request.signal.aborted, true);
});

test("stale requests cannot overwrite a new round and failures show the static drawing", async () => {
  const pending = [];
  const env = setup({ fetcher: () => new Promise((resolve) => pending.push(resolve)) });
  env.controller.presentationValue = { ...env.controller.presentationValue, id: 2, sceneUrl: "/rounds/2/drawing.json", imageUrl: "/rounds/2/drawing" };
  env.poll();
  pending[0]({ ok: true, json: async () => scene });
  await settle();
  assert.equal(env.controller.strokes, null);
  pending[1]({ ok: false });
  await settle();
  assert.equal(env.controller.fallbackTarget.src, "/rounds/2/drawing");
  assert.equal(env.controller.fallbackTarget.hidden, false);
  assert.equal(env.controller.svgTarget.hasAttribute("hidden"), true);
});

test("the browser refuses markup, event handlers, paint URLs, and invalid viewports", async () => {
  const env = setup();
  await settle();
  for (const art of [node("script"), node("path", { onclick: "bad()" }), node("path", { fill: "url(https://example.com)" }), node("path", { style: "fill:red" })]) {
    assert.throws(() => env.controller.build({ view_box: "0 0 512 512", art }));
  }
  assert.throws(() => env.controller.build({ ...scene, view_box: "0 0 -1 NaN" }));
  env.controller.disconnect();
});
