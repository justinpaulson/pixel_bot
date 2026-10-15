import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "form",
    "mode",
    "artist",
    "preview",
    "previewName",
    "submitLabel",
    "nickname",
    "sheet",
    "invite",
    "error",
  ];

  connect() {
    try {
      const saved = JSON.parse(localStorage.getItem("pixel-web-setup") || "{}");
      for (const key of ["mode", "category", "round_limit", "drawing_model"]) {
        for (const field of this.formTarget.elements) {
          if (field.name !== key) continue;
          if (field.type === "radio" && field.value === saved[key])
            field.checked = true;
          if (
            field.tagName === "SELECT" &&
            [...field.options].some((option) => option.value === saved[key])
          )
            field.value = saved[key];
        }
      }
      this.setName(
        this.nicknameTargets[0].value ||
          localStorage.getItem("pixel-web-nickname") ||
          "",
      );
    } catch {
      /* Storage is optional; the menu still works without it. */
    }
    this.update();
    this.element.classList.add("mobile-menu-ready");
  }

  disconnect() {
    this.sheetTargets.forEach((sheet) => sheet.close());
    this.element.classList.remove("mobile-menu-ready");
  }

  update() {
    const artist = this.artistTargets.find((input) => input.checked);
    this.previewTargets.forEach((preview) => {
      preview.hidden = preview.dataset.model !== artist.value;
    });
    this.previewNameTarget.textContent = `${artist.dataset.name}’s sketchbook`;
    this.submitLabelTarget.textContent =
      this.modeTargets.find((input) => input.checked).value === "party"
        ? "Create room"
        : "Play";
    const fields = new FormData(this.formTarget);
    const setup = Object.fromEntries(
      ["mode", "category", "round_limit", "drawing_model"].map((key) => [
        key,
        fields.get(key),
      ]),
    );
    try {
      localStorage.setItem("pixel-web-setup", JSON.stringify(setup));
    } catch {
      /* Optional. */
    }
  }

  setName(name) {
    this.nicknameTargets.forEach((input) => {
      input.value = name;
    });
  }

  nameChanged(event) {
    this.setName(event.target.value);
    try {
      localStorage.setItem("pixel-web-nickname", event.target.value);
    } catch {
      /* Optional. */
    }
  }

  open(event) {
    this.errorTarget.hidden = true;
    this.sheetTargets
      .find(
        (sheet) => sheet.dataset.sheet === event.currentTarget.dataset.sheet,
      )
      .showModal();
  }

  close(event) {
    event.currentTarget.closest("dialog").close();
  }

  backdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close();
  }

  join(event) {
    const value = this.inviteTarget.value.trim();
    const uuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    let id = uuid.test(value) ? value : null;
    if (!id) {
      try {
        const url = new URL(value);
        const isWeb =
          url.origin === window.location.origin ||
          url.origin === "https://pixel.justinpaulson.com";
        const isApp =
          url.protocol === "pixelguess:" && url.hostname === "games";
        const candidate = isWeb
          ? url.pathname.match(/^\/games\/([^/]+)\/?$/)?.[1]
          : isApp
            ? url.pathname.slice(1)
            : null;
        if (candidate && uuid.test(candidate)) id = candidate;
      } catch {
        /* Show the same friendly error for malformed links. */
      }
    }
    if (!id) {
      event.preventDefault();
      this.errorTarget.textContent = "Paste a Pixel invite link.";
      this.errorTarget.hidden = false;
      return;
    }
    // Submit through the website's existing cookie session and CSRF-protected join action.
    event.currentTarget.action = `/games/${id}/join`;
  }
}
