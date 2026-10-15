import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("../../app/javascript/controllers/game_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
  .replace("export default class", "globalThis.Game = class");

function setup({ finePointer = false } = {}) {
  let now = Date.parse("2026-10-15T12:00:00Z");
  const document = { activeElement: null };
  const context = {
    Date: { now: () => now, parse: Date.parse },
    document,
    window: { matchMedia: () => ({ matches: finePointer }) },
    clearTimeout,
  };
  runInNewContext(source, context);
  const controller = new context.Game();
  for (const target of context.Game.targets) {
    controller[`${target}Target`] = {
      textContent: "", value: "", dataset: {}, hidden: false,
      classList: { toggle() {}, remove() {}, add() {} },
      contains: () => false,
    };
  }
  const focusCalls = [];
  controller.guessInputTarget.focus = (options) => {
    focusCalls.push(options);
    document.activeElement = controller.guessInputTarget;
  };
  controller.offset = 5000;
  controller.submitting = false;
  controller.renderScores = () => {};
  controller.renderGallery = () => {};
  controller.poll = async () => {};
  const timestamp = (seconds) => new Date(now + controller.offset + seconds * 1000).toISOString();
  return { controller, document, focusCalls, timestamp, tick: (seconds) => { now += seconds * 1000; controller.updateClock(); } };
}

function playing(options) {
  const fixture = setup(options);
  const c = fixture.controller;
  c.roundId = 1;
  c.state = { phase: "playing", round: { id: 1, status: "playing", ends_at: fixture.timestamp(20) } };
  c.updateClock();
  return fixture;
}

const submit = () => ({ preventDefault() {} });

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

const wrongGuess = { ok: true, json: async () => ({ message: "Not quite.", accepted: false }) };

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

test("submitting keeps the input editable and focused while blocking duplicate guesses", async () => {
  const { controller: c, document, focusCalls } = playing();
  const request = deferred();
  let requests = 0;
  c.post = () => { requests++; return request.promise; };
  c.guessInputTarget.value = "first guess";
  document.activeElement = c.guessInputTarget;

  const pending = c.guess(submit());
  assert.equal(c.guessInputTarget.disabled, false);
  assert.equal(c.guessButtonTarget.disabled, true);
  assert.equal(document.activeElement, c.guessInputTarget);
  await c.guess(submit());
  assert.equal(requests, 1);

  c.guessInputTarget.value = "next guess";
  request.resolve(wrongGuess);
  await pending;
  assert.equal(c.guessInputTarget.value, "next guess");
  assert.equal(c.guessButtonTarget.disabled, false);
  assert.equal(focusCalls.length, 0);
});

test("responses clear the submitted answer without reclaiming focus after the player moves away", async () => {
  const { controller: c, document, focusCalls } = playing();
  const request = deferred();
  c.post = () => request.promise;
  c.guessInputTarget.value = "wrong answer";
  document.activeElement = c.guessInputTarget;
  const pending = c.guess(submit());
  const otherControl = {};
  document.activeElement = otherControl;
  request.resolve(wrongGuess);
  await pending;
  assert.equal(c.guessInputTarget.value, "");
  assert.equal(c.feedbackTarget.textContent, "Not quite.");
  assert.equal(document.activeElement, otherControl);
  assert.equal(focusCalls.length, 0);
});

test("a failed request preserves the guess without refocusing or overwriting a newer round", async () => {
  for (const roundChanged of [false, true]) {
    const { controller: c, focusCalls } = playing();
    const request = deferred();
    c.post = () => request.promise;
    c.guessInputTarget.value = "try again";
    const pending = c.guess(submit());
    if (roundChanged) c.roundId = 2;
    request.reject(new Error("Offline"));
    await pending;
    assert.equal(c.guessInputTarget.value, "try again");
    assert.equal(c.feedbackTarget.textContent, roundChanged ? "" : "Couldn't send guess. Try again.");
    assert.equal(c.guessButtonTarget.disabled, false);
    assert.equal(focusCalls.length, 0);
  }
});

test("tapping Guess preserves an existing input focus without blocking other button interactions", () => {
  const { controller: c, document } = playing();
  let prevented = 0;
  const pointer = (button) => ({ button, preventDefault() { prevented++; } });
  c.keepGuessFocus(pointer(0));
  assert.equal(prevented, 0);
  document.activeElement = c.guessInputTarget;
  c.keepGuessFocus(pointer(0));
  assert.equal(prevented, 1);
  c.keepGuessFocus(pointer(2));
  assert.equal(prevented, 1);
});

test("keyboard activation of Guess returns focus synchronously without scrolling", async () => {
  const { controller: c, document, focusCalls } = playing();
  c.post = async () => wrongGuess;
  document.activeElement = c.guessButtonTarget;
  c.guessInputTarget.value = "keyboard guess";
  const pending = c.guess(submit());
  assert.equal(document.activeElement, c.guessInputTarget);
  assert.equal(focusCalls[0].preventScroll, true);
  await pending;
  assert.equal(focusCalls.length, 1);
});

test("new rounds preserve the page position and only autofocus for mouse and keyboard devices", () => {
  for (const finePointer of [false, true]) {
    const { controller: c, focusCalls } = playing({ finePointer });
    c.headingTarget.scrollIntoView = () => assert.fail("Round changes must not scroll the page");
    c.state.round.id = 2;
    c.render(c.state);
    assert.equal(focusCalls.length, finePointer ? 1 : 0);
    if (finePointer) assert.equal(focusCalls[0].preventScroll, true);
    c.render(c.state);
    assert.equal(focusCalls.length, finePointer ? 1 : 0);
  }
});

test("the input still closes when the round is solved or expires during submission", () => {
  const { controller: c, tick } = playing();
  c.submitting = true;
  c.state.round.solved = true;
  c.updateClock();
  assert.equal(c.guessInputTarget.disabled, true);
  c.state.round.solved = false;
  tick(20);
  assert.equal(c.guessInputTarget.disabled, true);
  assert.equal(c.guessButtonTarget.disabled, true);
});
