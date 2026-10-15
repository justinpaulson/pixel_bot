import { Controller } from "@hotwired/stimulus";

const SVG = "http://www.w3.org/2000/svg";
const ELEMENTS = new Set(["g", "path", "circle", "ellipse", "rect", "line", "polyline", "polygon"]);
const ATTRIBUTES = new Set([
  "x", "y", "x1", "x2", "y1", "y2", "cx", "cy", "r", "rx", "ry", "width", "height",
  "stroke-width", "stroke-miterlimit", "opacity", "fill-opacity", "stroke-opacity", "stroke-dashoffset",
  "fill", "stroke", "d", "points", "stroke-dasharray", "transform", "stroke-linecap", "stroke-linejoin",
  "fill-rule", "clip-rule",
]);

export default class extends Controller {
  static values = { presentation: Object };
  static targets = ["svg", "art", "pencil", "fallback", "caption"];

  connect() {
    this.active = true;
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.onVisibility = () => this.resume();
    this.onMotion = () => this.resume();
    document.addEventListener("visibilitychange", this.onVisibility);
    this.motion.addEventListener("change", this.onMotion);
    this.sync();
  }

  disconnect() {
    this.active = false;
    this.stop();
    this.request?.abort();
    this.roundId = null;
    document.removeEventListener("visibilitychange", this.onVisibility);
    this.motion.removeEventListener("change", this.onMotion);
  }

  presentationValueChanged() {
    if (this.active) this.sync();
  }

  sync() {
    const presentation = this.presentationValue;
    this.offset = Date.parse(presentation.serverTime) - Date.now();
    if (presentation.id !== this.roundId) {
      this.roundId = presentation.id;
      this.stop();
      this.request?.abort();
      this.strokes = null;
      this.elapsed = 0;
      this.svgTarget.toggleAttribute("hidden", true);
      this.fallbackTarget.hidden = true;
      this.pencilTarget.setAttribute("visibility", "hidden");
      this.captionTarget.hidden = false;
      this.captionTarget.textContent = "Uncapping the pencil…";
      if (presentation.id) this.load(presentation);
    } else {
      this.resume();
    }
  }

  async load(presentation) {
    const request = new AbortController();
    this.request = request;
    try {
      const response = await fetch(presentation.sceneUrl, {
        headers: { Accept: "application/json" }, cache: "no-store", signal: request.signal,
      });
      if (!response.ok || response.redirected) throw new Error("Drawing unavailable");
      const scene = await response.json();
      if (!this.active || request.signal.aborted || this.request !== request) return;
      this.build(scene);
      this.resume();
    } catch (error) {
      if (!this.active || request.signal.aborted || this.request !== request) return;
      // Older browsers or a failed scene request can still show the safe image.
      this.stop();
      this.strokes = null;
      this.svgTarget.toggleAttribute("hidden", true);
      this.fallbackTarget.src = presentation.imageUrl;
      this.fallbackTarget.hidden = false;
      this.captionTarget.hidden = true;
    }
  }

  build(scene) {
    const viewport = String(scene.view_box).trim().split(/[\s,]+/).map(Number);
    if (viewport.length !== 4 || !viewport.every(Number.isFinite) || viewport[2] <= 0 || viewport[3] <= 0)
      throw new Error("Invalid viewport");
    const shapes = [];
    let count = 0;
    const buildNode = (node, depth = 0) => {
      if (++count > 2048 || depth > 32 || !ELEMENTS.has(node.tag)) throw new Error("Invalid geometry");
      const element = document.createElementNS(SVG, node.tag);
      for (const [name, value] of Object.entries(node.attributes)) {
        // The server validates values. Keep a second, narrow boundary here so
        // model markup, event handlers, URLs and styles never enter the DOM.
        if (!ATTRIBUTES.has(name) || typeof value !== "string" || /url\s*\(|[<>]/i.test(value))
          throw new Error("Invalid presentation attribute");
        element.setAttribute(name, value);
      }
      if (node.tag === "g") {
        for (const child of node.children) element.append(buildNode(child, depth + 1));
      } else {
        shapes.push(element);
      }
      return element;
    };
    const art = buildNode(scene.art);
    if (!shapes.length) throw new Error("Empty drawing");
    this.svgTarget.setAttribute("viewBox", scene.view_box);
    this.artTarget.replaceChildren(art);
    this.svgTarget.toggleAttribute("hidden", false);
    this.strokes = shapes.filter((shape, index) => !this.isPaper(shape, index, viewport)).map((element) => {
      const style = window.getComputedStyle(element);
      let length = 0;
      try { length = element.getTotalLength(); } catch { /* Degenerate shapes simply fill in. */ }
      if (!Number.isFinite(length)) length = 0;
      return {
        element, length, weight: Math.max(90, Math.min(length, 900)),
        fillOpacity: Number(style.fillOpacity),
        stroke: style.stroke === "none" ? "#28362f" : style.stroke,
        strokeWidth: style.stroke === "none" ? "2.5px" : style.strokeWidth,
      };
    });
    const total = this.strokes.reduce((sum, stroke) => sum + stroke.weight, 0);
    let position = 0;
    for (const stroke of this.strokes) {
      stroke.start = position / total;
      stroke.duration = stroke.weight / total;
      position += stroke.weight;
    }
  }

  isPaper(shape, index, viewport) {
    // A full-canvas background is already the paper, not a pencil stroke.
    return index === 0 && shape.tagName === "rect" && !shape.hasAttribute("transform") &&
      ["x", "y", "width", "height"].every((name, i) => Number(shape.getAttribute(name) || 0) === viewport[i]);
  }

  stop() {
    cancelAnimationFrame(this.frame);
    clearTimeout(this.stepTimer);
  }

  resume() {
    this.stop();
    if (!this.active || !this.strokes || document.hidden) return;
    this.paint();
  }

  paint() {
    const presentation = this.presentationValue;
    const duration = Math.max(1000, Math.min(Number(presentation.duration) || 6000, 10000));
    const startedAt = Date.parse(presentation.startedAt);
    // Wall time catches late arrivals and background tabs up to everyone else.
    // Polls can correct clock drift, but never rewind an already visible stroke.
    this.elapsed = presentation.complete || !Number.isFinite(startedAt) ? duration :
      Math.max(this.elapsed, Date.now() + this.offset - startedAt);
    const fraction = Math.max(0, Math.min(1, this.elapsed / duration));
    const reduced = this.motion.matches;
    let current;
    for (const stroke of this.strokes) {
      const progress = Math.max(0, Math.min(1, (fraction - stroke.start) / stroke.duration));
      const element = stroke.element;
      if (progress >= 1 || fraction >= 1) {
        element.removeAttribute("style");
      } else if (progress <= 0 || reduced) {
        element.style.visibility = "hidden";
      } else {
        element.style.visibility = "visible";
        element.style.stroke = stroke.stroke;
        element.style.strokeWidth = stroke.strokeWidth;
        element.style.strokeLinecap = "round";
        element.style.strokeLinejoin = "round";
        element.style.strokeDasharray = `${stroke.length} ${stroke.length}`;
        element.style.strokeDashoffset = stroke.length * (1 - progress);
        element.style.fillOpacity = stroke.fillOpacity * Math.max(0, (progress - 0.65) / 0.35);
        current = { stroke, progress };
      }
    }
    this.pencilTarget.setAttribute("visibility", "hidden");
    if (current?.stroke.length && !reduced) this.movePencil(current);
    this.captionTarget.hidden = fraction >= 1;
    this.captionTarget.textContent = reduced ? "The clue is taking shape…" : "Follow the pencil · guess anytime";
    if (fraction < 1) {
      if (reduced) this.stepTimer = setTimeout(() => this.paint(), 100);
      else this.frame = requestAnimationFrame(() => this.paint());
    }
  }

  movePencil({ stroke, progress }) {
    const point = stroke.element.getPointAtLength(stroke.length * progress);
    const shapeMatrix = stroke.element.getScreenCTM();
    const canvasMatrix = this.svgTarget.getScreenCTM();
    if (!shapeMatrix || !canvasMatrix) return;
    const local = this.svgTarget.createSVGPoint();
    local.x = point.x;
    local.y = point.y;
    const tip = local.matrixTransform(canvasMatrix.inverse().multiply(shapeMatrix));
    this.pencilTarget.setAttribute("transform", `translate(${tip.x} ${tip.y})`);
    this.pencilTarget.setAttribute("visibility", "visible");
  }
}
