import { Application } from "@hotwired/stimulus";
import Drawing from "../../app/javascript/controllers/drawing_controller.js";
import Sketchbook from "../../app/javascript/controllers/sketchbook_controller.js";
import { request } from "./api";

// Use the exact same sanitized geometry and synchronized animation as the web.
class MobileDrawing extends Drawing {
  async load(presentation) {
    const marker = new AbortController();
    this.request = marker;
    const current = () =>
      this.active && !marker.signal.aborted && this.request === marker;
    try {
      const scene = await request(presentation.sceneUrl.replace(/\.json$/, ""));
      if (!current()) return;
      this.build(scene);
      this.resume();
    } catch {
      if (!current()) return;
      this.captionTarget.hidden = false;
      this.captionTarget.textContent = "Reconnecting…";
      clearTimeout(this.retryTimer);
      this.retryTimer = setTimeout(() => {
        if (current()) this.load(presentation);
      }, 3000);
    }
  }
  disconnect() {
    clearTimeout(this.retryTimer);
    super.disconnect();
  }
}
class MobileSketchbook extends Sketchbook {
  updateWait() {
    const seconds = Math.max(
      0,
      Math.floor((Date.now() - this.waitStarted) / 1000),
    );
    this.elapsedTarget.textContent = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
    this.waitCopyTarget.textContent =
      seconds < 60
        ? "Your timer hasn’t started."
        : "Still drawing. Hang tight.";
  }
}
export function startDrawingControllers() {
  const application = Application.start();
  application.register("drawing", MobileDrawing);
  application.register("sketchbook", MobileSketchbook);
}
