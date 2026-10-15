import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { duration: Number };
  static targets = ["mode", "model", "category", "rounds", "preview", "previewName", "previewArtist", "categoryHint", "summary", "submitLabel", "modeHint"];

  connect() {
    this.update();
  }

  update() {
    const mode = this.modeTargets.find((input) => input.checked)?.value;
    const artist = this.modelTargets.find((input) => input.checked);
    if (!artist) return;
    for (const preview of this.previewTargets) preview.hidden = preview.dataset.model !== artist.value;
    this.previewNameTarget.textContent = `${artist.dataset.name}’s sketchbook`;
    this.previewArtistTarget.textContent = artist.dataset.name;
    this.categoryHintTarget.textContent = this.categoryTarget.selectedOptions[0]?.dataset.description || "";
    this.summaryTarget.textContent = `${this.roundsTarget.value} rounds · ${this.durationValue}s to guess · ${artist.dataset.challenge}`;
    this.submitLabelTarget.textContent = mode === "party" ? "Create room" : "Play solo";
    this.modeHintTarget.textContent = mode === "party" ? "Invite up to 11 friends with a private link." : "Just you, Pixel, and the clock.";
  }
}
