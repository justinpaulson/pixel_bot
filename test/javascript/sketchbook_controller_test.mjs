import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("../../app/javascript/controllers/sketchbook_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
  .replace("export default class", "globalThis.Sketchbook = class");

function setup({ reduced = false } = {}) {
  let now = 0;
  let id = 0;
  const frames = new Map();
  const timers = new Map();
  const listeners = new Map();
  const motion = { matches: reduced, addEventListener() {}, removeEventListener() {} };
  const element = () => ({
    style: {}, attributes: {}, children: [],
    setAttribute(name, value) { this.attributes[name] = value; },
    append(child) { this.children.push(child); },
    replaceChildren() { this.children = []; },
    getTotalLength() { return 100; },
    getPointAtLength(length) { return { x: length, y: length }; },
  });
  const document = {
    hidden: false,
    createElementNS: element,
    addEventListener(name, listener) { listeners.set(name, listener); },
    removeEventListener(name) { listeners.delete(name); },
  };
  const context = {
    document, window: { matchMedia: () => motion }, Date: { now: () => now },
    requestAnimationFrame(callback) { frames.set(++id, callback); return id; },
    cancelAnimationFrame(id) { frames.delete(id); },
    setInterval(callback) { timers.set(++id, callback); return id; },
    clearInterval(id) { timers.delete(id); },
  };
  runInNewContext(source, context);
  const controller = new context.Sketchbook();
  for (const target of ["art", "pencil", "caption", "elapsed", "waitCopy"]) controller[`${target}Target`] = element();
  controller.roundValue = "round-1";
  controller.connect();
  return {
    controller, frames, timers, document, motion, listeners,
    wait(milliseconds) { now += milliseconds; timers.forEach((callback) => callback()); },
    frame(time) {
      const pending = Array.from(frames.values());
      frames.clear();
      pending.forEach((callback) => callback(time));
    },
  };
}

test("doodles build progressively and cycle without resetting the wait clock", () => {
  const env = setup();
  const c = env.controller;
  const captions = new Set([c.captionTarget.textContent]);
  assert.ok(c.artTarget.children.every((path) => path.style.visibility === "hidden"));
  env.frame(0);
  env.frame(100);
  assert.ok(c.artTarget.children.some((path) => path.style.visibility === "visible"));
  assert.equal(c.pencilTarget.attributes.visibility, "visible");
  env.wait(65000);
  assert.equal(c.elapsedTarget.textContent, "1:05");
  assert.match(c.waitCopyTarget.textContent, /Still working/);
  for (let n = 0; n < 4; n++) {
    c.elapsed = 12000;
    env.frame(200 + n * 100);
    captions.add(c.captionTarget.textContent);
  }
  assert.equal(captions.size, 5);
  c.next();
  assert.equal(c.elapsedTarget.textContent, "1:05");
  assert.equal(env.frames.size, 1);
  assert.equal(env.timers.size, 1);
});

test("reduced motion shows complete art, permits manual switching, and does not animate", () => {
  const env = setup({ reduced: true });
  const c = env.controller;
  const caption = c.captionTarget.textContent;
  assert.ok(c.artTarget.children.every((path) => Math.abs(path.style.strokeDashoffset) < 0.001));
  assert.equal(c.pencilTarget.attributes.visibility, "hidden");
  assert.equal(env.frames.size, 0);
  c.next();
  assert.notEqual(c.captionTarget.textContent, caption);
  assert.equal(env.frames.size, 0);
  env.motion.matches = false;
  c.onMotionChange();
  assert.equal(env.frames.size, 1);
});

test("hidden tabs pause the pen while the elapsed wait remains accurate", () => {
  const env = setup();
  env.frame(0);
  env.frame(100);
  const elapsed = env.controller.elapsed;
  env.document.hidden = true;
  env.listeners.get("visibilitychange")();
  assert.equal(env.frames.size, 0);
  env.wait(30000);
  assert.equal(env.controller.elapsedTarget.textContent, "0:30");
  env.document.hidden = false;
  env.listeners.get("visibilitychange")();
  env.frame(30000);
  assert.equal(env.controller.elapsed, elapsed);
  assert.equal(env.frames.size, 1);
});

test("leaving generation cancels work and retrying starts a fresh wait", () => {
  const env = setup();
  const c = env.controller;
  env.wait(20000);
  c.roundValue = "";
  c.roundValueChanged();
  assert.equal(env.frames.size, 0);
  assert.equal(env.timers.size, 0);
  c.roundValue = "round-1";
  c.roundValueChanged();
  assert.equal(c.elapsedTarget.textContent, "0:00");
  assert.equal(env.frames.size, 1);
  assert.equal(env.timers.size, 1);
  c.disconnect();
  assert.equal(env.frames.size, 0);
  assert.equal(env.timers.size, 0);
  assert.equal(env.listeners.size, 0);
});
