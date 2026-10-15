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
    "mascot",
    "canvasTitle",
    "canvasCopy",
    "caption",
    "guessForm",
    "guessInput",
    "guessButton",
    "feedback",
    "hint",
    "reveal",
    "answer",
    "revealCopy",
    "scoreTitle",
    "scoreboard",
    "shareUrl",
    "copyButton",
    "hostControls",
    "startButton",
    "nextButton",
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
          "Reconnecting to your game… If this continues, refresh the page.";
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
    if (this.roundId !== round?.id) {
      if (this.roundId) this.headingTarget.scrollIntoView({ block: "start" });
      this.roundId = round?.id;
      this.guessInputTarget.value = "";
      this.feedbackTarget.textContent = "";
      this.feedbackTarget.classList.remove("correct");
    }
    const headings = {
      lobby: "Assemble your guessing crew.",
      pending: "A little mystery in the making.",
      generating: "A little mystery in the making.",
      ready: "A little mystery in the making.",
      playing: "See it. Guess it. Get it.",
      revealed: "Ohhh. Now you see it.",
      failed: "Even artists have off days.",
      complete: "That's a wrap. Nice guessing!",
    };
    this.headingTarget.textContent = headings[phase] || "Welcome to Pixel.";
    this.categoryTarget.textContent = round?.category || "PIXEL'S STUDIO";
    this.roundLabelTarget.textContent = round
      ? `Round ${round.number} / ${state.round_limit}`
      : `${state.round_limit} rounds · 90 seconds each`;
    this.drawingTarget.hidden = !round?.image_url;
    this.placeholderTarget.hidden = Boolean(round?.image_url);
    if (
      round?.image_url &&
      this.drawingTarget.getAttribute("src") !== round.image_url
    )
      this.drawingTarget.src = round.image_url;
    this.mascotTarget.classList.toggle("is-drawing", generating);
    this.canvasTitleTarget.textContent =
      phase === "lobby"
        ? "Everyone's a guesser."
        : phase === "failed"
          ? "Let's give that another go."
          : "Pixel is drawing…";
    this.canvasCopyTarget.textContent =
      phase === "lobby"
        ? "Share the link, gather your people, and let Pixel do the drawing. You can start with just one player."
        : phase === "failed"
          ? round.error
          : "Making something brand new takes a moment, usually about a minute. Your clock starts when the art is ready.";
    this.captionTarget.textContent = generating
      ? "A brand-new drawing. No peeking."
      : revealed
        ? "Mystery solved. Art collected."
        : playing
          ? "The answer is a secret. Even from the host."
          : "A fresh drawing, just for this game.";
    this.guessFormTarget.hidden = !playing || round?.solved;
    this.revealTarget.hidden = !revealed;
    this.answerTarget.textContent = revealed ? round.answer : "";
    this.revealCopyTarget.textContent = round?.solved
      ? "You connected the dots. Nicely done."
      : "Some drawings are trickier than others. That's part of the fun.";
    if (playing && round.solved && !this.feedbackTarget.textContent) {
      this.feedbackTarget.textContent =
        "You got it! Let the others have their aha moment.";
      this.feedbackTarget.classList.add("correct");
    }
    this.hintTarget.hidden = !playing || !round.hint;
    this.hintTarget.textContent = round?.hint
      ? `A little nudge: ${round.hint}`
      : "";
    this.startButtonTarget.hidden = !state.host || phase !== "lobby";
    this.nextButtonTarget.hidden = !state.host || phase !== "revealed";
    this.retryButtonTarget.hidden = !state.host || phase !== "failed";
    this.skipButtonTarget.hidden = !state.host || !playing;
    this.againButtonTarget.hidden = phase !== "complete";
    this.waitingNoteTarget.textContent =
      !state.host && ["lobby", "revealed", "failed"].includes(phase)
        ? "Waiting for the host to start the next drawing."
        : "";
    this.scoreTitleTarget.textContent =
      phase === "complete"
        ? "The final scores"
        : state.mode === "solo"
          ? "Your score"
          : "The guessing crew";
    this.renderScores(state.players);
    this.renderGallery(state.gallery);
    this.updateClock();
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
          solved.textContent = "Got it!";
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
    const seconds = this.state.round?.ends_at
      ? Math.max(
          0,
          Math.ceil(
            (Date.parse(this.state.round.ends_at) - Date.now() - this.offset) /
              1000,
          ),
        )
      : 0;
    const active = this.state.phase === "playing";
    this.timerTarget.textContent = active
      ? `${seconds}s`
      : this.state.round?.status === "revealed"
        ? "✓"
        : "—";
    this.timerTarget.classList.toggle("urgent", active && seconds <= 15);
    this.guessInputTarget.disabled = !active || seconds <= 0 || this.submitting;
    this.guessButtonTarget.disabled = this.guessInputTarget.disabled;
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
      this.feedbackTarget.textContent =
        "That guess didn't get through. Please try again.";
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
      this.connectionTarget.textContent =
        "Couldn't complete that action. Wait a moment and try again.";
    } finally {
      this.actionPending = false;
    }
  }

  start() {
    this.action(`${this.baseUrlValue}/start`);
  }
  next() {
    this.action(`${this.baseUrlValue}/advance`, { round_id: this.roundId });
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
      this.copyButtonTarget.textContent = "Link copied ✓";
    } catch (error) {
      this.shareUrlTarget.select();
      this.copyButtonTarget.textContent = "Select and copy the link above";
    }
  }
}
