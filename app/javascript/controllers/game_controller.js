import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { stateUrl: String, baseUrl: String };
  static targets = [
    "heading",
    "connection",
    "category",
    "roundLabel",
    "timer",
    "drawing",
    "placeholder",
    "sketchbook",
    "canvasTitle",
    "canvasCopy",
    "guessForm",
    "guessInput",
    "guessButton",
    "feedback",
    "hint",
    "reveal",
    "answer",
    "nextCountdown",
    "scoreTitle",
    "scoreboard",
    "shareUrl",
    "copyButton",
    "startButton",
    "retryButton",
    "skipButton",
    "waitingNote",
    "againButton",
    "gallerySection",
    "gallery",
  ];

  connect() {
    this.abort = new AbortController();
    this.disconnected = false;
    this.poll();
    this.clock = setInterval(() => this.updateClock(), 250);
  }

  disconnect() {
    this.disconnected = true;
    this.abort.abort();
    clearTimeout(this.pollTimer);
    clearInterval(this.clock);
  }

  async poll() {
    if (this.polling || this.disconnected) return;
    clearTimeout(this.pollTimer);
    this.polling = true;
    try {
      const response = await fetch(this.stateUrlValue, {
        headers: { Accept: "application/json" },
        cache: "no-store",
        signal: this.abort.signal,
      });
      if (!response.ok || response.redirected)
        throw new Error("Connection lost");
      const state = await response.json();
      if (this.disconnected) return;
      this.state = state;
      this.offset = Date.parse(state.server_time) - Date.now();
      this.connectionTarget.textContent = "";
      this.render(state);
    } catch (error) {
      if (error.name !== "AbortError")
        this.connectionTarget.textContent =
          "Reconnecting… Refresh if this continues.";
    } finally {
      this.polling = false;
      if (!this.disconnected)
        this.pollTimer = setTimeout(() => this.poll(), 1800);
    }
  }

  render(state) {
    const round = state.round;
    const phase = state.phase;
    const playing = phase === "playing";
    const revealed = round?.status === "revealed";
    const generating = ["pending", "generating", "ready"].includes(phase);
    const roundChanged = this.roundId !== round?.id;
    if (roundChanged) {
      if (this.roundId) this.headingTarget.scrollIntoView({ block: "start" });
      this.roundId = round?.id;
      this.guessInputTarget.value = "";
      this.feedbackTarget.textContent = "";
      this.feedbackTarget.classList.remove("correct");
    }
    this.headingTarget.textContent =
      phase === "lobby"
        ? "Lobby"
        : phase === "complete"
          ? "Game over"
          : phase === "revealed"
            ? "Round over"
            : "Guess the drawing";
    this.categoryTarget.textContent = round?.category || "";
    this.roundLabelTarget.textContent = round
      ? `Round ${round.number} / ${state.round_limit}`
      : `${state.round_limit} rounds · ${state.round_duration_seconds} seconds each`;
    const sketchbookHadFocus = this.sketchbookTarget.contains(document.activeElement);
    this.sketchbookTarget.hidden = !generating;
    this.sketchbookTarget.dataset.sketchbookRoundValue = generating ? String(round.id) : "";
    this.drawingTarget.hidden = generating || !round?.image_url;
    this.placeholderTarget.hidden = generating || Boolean(round?.image_url);
    this.drawingTarget.dataset.drawingPresentationValue = JSON.stringify({
      id: !generating && round?.image_url ? round.id : null,
      sceneUrl: round?.scene_url,
      imageUrl: round?.image_url,
      startedAt: round?.started_at,
      serverTime: state.server_time,
      duration: state.drawing_duration_ms,
      complete: revealed,
    });
    this.canvasTitleTarget.textContent =
      phase === "lobby"
        ? "Ready?"
        : phase === "failed"
          ? "Drawing failed"
          : "Drawing…";
    this.canvasCopyTarget.textContent =
      phase === "lobby"
        ? ""
        : phase === "failed"
          ? round.error
          : "Usually about a minute.";
    this.guessFormTarget.hidden = !playing || round?.solved;
    this.revealTarget.hidden = !revealed;
    this.answerTarget.textContent = revealed ? round.answer : "";
    if (playing && round.solved && !this.feedbackTarget.textContent) {
      this.feedbackTarget.textContent = "Correct!";
      this.feedbackTarget.classList.add("correct");
    }
    this.hintTarget.hidden = !playing || !round.hint;
    this.hintTarget.textContent = round?.hint ? `Hint: ${round.hint}` : "";
    this.startButtonTarget.hidden = !state.host || phase !== "lobby";
    this.retryButtonTarget.hidden = !state.host || phase !== "failed";
    this.skipButtonTarget.hidden = !state.host || !playing;
    this.againButtonTarget.hidden = phase !== "complete";
    this.waitingNoteTarget.textContent =
      !state.host && ["lobby", "failed"].includes(phase)
        ? "Waiting for host…"
        : "";
    this.scoreTitleTarget.textContent =
      state.mode === "solo" ? "Score" : "Scores";
    this.renderScores(state.players);
    this.renderGallery(state.gallery);
    this.updateClock();
    if ((sketchbookHadFocus || roundChanged) && playing && !round.solved) this.guessInputTarget.focus();
  }

  renderScores(players) {
    const signature = JSON.stringify(players);
    if (this.scoreSignature === signature) return;
    this.scoreSignature = signature;
    this.scoreboardTarget.replaceChildren(
      ...players.map((player, index) => {
        const row = document.createElement("li");
        const avatar = document.createElement("span");
        avatar.className = `player-avatar avatar-${index % 4}`;
        avatar.textContent = player.name.slice(0, 1).toUpperCase();
        const name = document.createElement("span");
        name.className = "player-name";
        name.textContent = `${player.name}${player.me ? " (you)" : ""}`;
        const points = document.createElement("strong");
        points.textContent = player.points.toLocaleString();
        if (player.solved) {
          const solved = document.createElement("small");
          solved.textContent = "Correct";
          name.append(document.createElement("br"), solved);
        }
        row.append(avatar, name, points);
        return row;
      }),
    );
  }

  renderGallery(items) {
    this.gallerySectionTarget.hidden = !items.length;
    const signature = JSON.stringify(items);
    if (this.gallerySignature === signature) return;
    this.gallerySignature = signature;
    this.galleryTarget.replaceChildren(
      ...items.map((item) => {
        const card = document.createElement("figure");
        const img = document.createElement("img");
        img.src = item.image_url;
        img.alt = `Round ${item.number}: ${item.answer}`;
        img.loading = "lazy";
        const caption = document.createElement("figcaption");
        const number = document.createElement("small");
        number.textContent = `ROUND ${item.number}`;
        const answer = document.createElement("strong");
        answer.textContent = item.answer;
        caption.append(number, answer);
        card.append(img, caption);
        return card;
      }),
    );
  }

  updateClock() {
    if (!this.state) return;
    const seconds = this.secondsUntil(this.state.round?.ends_at);
    const active = this.state.phase === "playing";
    this.timerTarget.textContent = active
      ? `${seconds}s`
      : this.state.round?.status === "revealed"
        ? "✓"
        : "—";
    this.timerTarget.classList.toggle("urgent", active && seconds <= 5);
    this.guessInputTarget.disabled = !active || seconds <= 0 || this.submitting;
    this.guessButtonTarget.disabled = this.guessInputTarget.disabled;
    const nextRoundAt = this.state.phase === "revealed" && this.state.round?.next_round_at;
    this.nextCountdownTarget.hidden = !nextRoundAt;
    if (nextRoundAt) {
      const remaining = this.secondsUntil(nextRoundAt);
      this.nextCountdownTarget.textContent = remaining > 0
        ? `Next round in ${remaining}s`
        : "Starting next round…";
    }
  }

  secondsUntil(timestamp) {
    return timestamp
      ? Math.max(0, Math.ceil((Date.parse(timestamp) - Date.now() - this.offset) / 1000))
      : 0;
  }

  async guess(event) {
    event.preventDefault();
    if (
      this.submitting ||
      !this.state?.round ||
      !this.guessInputTarget.value.trim()
    )
      return;
    const roundId = this.state.round.id;
    this.submitting = true;
    this.updateClock();
    try {
      const response = await this.post(`/rounds/${roundId}/answer`, {
        answer: this.guessInputTarget.value,
      });
      const result = await response.json();
      if (roundId !== this.roundId) return;
      this.feedbackTarget.textContent = result.message;
      this.feedbackTarget.classList.toggle("correct", Boolean(result.accepted));
      if (response.ok) this.guessInputTarget.value = "";
      clearTimeout(this.pollTimer);
      await this.poll();
    } catch (error) {
      this.feedbackTarget.textContent = "Couldn't send guess. Try again.";
    } finally {
      this.submitting = false;
      this.updateClock();
      if (!this.guessFormTarget.hidden) this.guessInputTarget.focus();
    }
  }

  async post(url, values = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
        Accept: "application/json",
      },
      body: new URLSearchParams(values),
      signal: this.abort.signal,
    });
    if (!response.ok && response.status !== 429)
      throw new Error("Request failed");
    return response;
  }

  async action(url, values = {}) {
    if (this.actionPending) return;
    this.actionPending = true;
    try {
      const response = await this.post(url, values);
      if (response.status === 429)
        throw new Error("Please wait before trying again.");
      clearTimeout(this.pollTimer);
      await this.poll();
    } catch (error) {
      this.connectionTarget.textContent = "Something went wrong. Try again.";
    } finally {
      this.actionPending = false;
    }
  }

  start() {
    this.action(`${this.baseUrlValue}/start`);
  }
  retry() {
    this.action(`/rounds/${this.roundId}/retry_drawing`);
  }
  skip() {
    this.action(`/rounds/${this.roundId}/skip`);
  }

  async copyInvite() {
    try {
      await navigator.clipboard.writeText(this.shareUrlTarget.value);
      this.copyButtonTarget.textContent = "Copied ✓";
    } catch (error) {
      this.shareUrlTarget.select();
      this.copyButtonTarget.textContent = "Copy the selected link";
    }
  }
}
