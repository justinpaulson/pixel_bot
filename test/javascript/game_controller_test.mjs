import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("../../app/javascript/controllers/game_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
  .replace("export default class", "globalThis.Game = class");

function setup() {
  let now = Date.parse("2026-10-15T12:00:00Z");
  const context = { Date: { now: () => now, parse: Date.parse } };
  runInNewContext(source, context);
  const controller = new context.Game();
  controller.offset = 5000;
  controller.submitting = false;
  controller.timerTarget = { classList: { toggle() {} } };
  controller.guessInputTarget = {};
  controller.guessButtonTarget = {};
  controller.nextCountdownTarget = {};
  const timestamp = (seconds) => new Date(now + controller.offset + seconds * 1000).toISOString();
  return { controller, timestamp, tick: (seconds) => { now += seconds * 1000; controller.updateClock(); } };
}

test("guessing uses the server deadline for the full twenty seconds", () => {
  const { controller: c, timestamp, tick } = setup();
  c.state = { phase: "playing", round: { status: "playing", ends_at: timestamp(20) } };
  c.updateClock();
  assert.equal(c.timerTarget.textContent, "20s");
  assert.equal(c.guessInputTarget.disabled, false);
  assert.equal(c.nextCountdownTarget.hidden, true);
  tick(19);
  assert.equal(c.timerTarget.textContent, "1s");
  assert.equal(c.guessInputTarget.disabled, false);
  tick(1);
  assert.equal(c.guessInputTarget.disabled, true);
});

test("the shared reveal countdown reaches zero without negative time or client-side advancing", () => {
  const { controller: c, timestamp, tick } = setup();
  c.state = { phase: "revealed", round: { status: "revealed", next_round_at: timestamp(12) } };
  c.updateClock();
  assert.equal(c.nextCountdownTarget.hidden, false);
  assert.equal(c.nextCountdownTarget.textContent, "Next round in 12s");
  assert.equal(c.timerTarget.textContent, "✓");
  assert.equal(c.guessInputTarget.disabled, true);
  tick(11);
  assert.equal(c.nextCountdownTarget.textContent, "Next round in 1s");
  tick(4);
  assert.equal(c.nextCountdownTarget.textContent, "Starting next round…");
});

test("completed games and unfinished drawings do not show a next-round countdown", () => {
  const { controller: c, timestamp } = setup();
  for (const phase of ["complete", "pending", "generating", "failed", "lobby"]) {
    c.state = { phase, round: { status: phase, next_round_at: timestamp(12) } };
    c.updateClock();
    assert.equal(c.nextCountdownTarget.hidden, true);
    assert.equal(c.guessInputTarget.disabled, true);
  }
});
