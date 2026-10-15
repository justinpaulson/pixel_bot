import { Controller } from "@hotwired/stimulus";

// These local illustrations are independent of the secret answer and provider output.
// Each path is another pen stroke; its color washes in after the outline is drawn.
const DOODLES = [
  {
    caption: "A very small adventure",
    paths: [
      ["M105 217Q200 200 295 217", "none"],
      ["M176 145Q141 148 139 187L178 175Z", "--mint"],
      ["M224 145Q259 148 261 187L222 175Z", "--mint"],
      ["M183 179Q171 205 200 230Q230 204 217 179Z", "--canyon"],
      ["M192 184Q187 201 200 215Q213 200 208 184Z", "--peach"],
      ["M176 179Q156 100 200 41Q244 100 224 179Z", "--ice"],
      ["M178 79Q200 90 222 79Q213 54 200 41Q188 54 178 79Z", "--canyon"],
      ["M218 119A18 18 0 1 1 182 119A18 18 0 1 1 218 119Z", "--mint"],
      ["M191 119Q191 110 201 110", "none"],
      ["M177 168H223", "none"],
      ["M98 83V105M87 94H109M293 133V149M285 141H301", "none"],
      ["M274 54 278 64 289 68 278 72 274 83 270 72 259 68 270 64Z", "--peach"],
      ["M113 155 117 160 113 165 109 160Z", "--canyon"],
    ],
  },
  {
    caption: "Going places. Eventually.",
    paths: [
      ["M82 211H320", "none"],
      ["M109 179Q85 179 86 194Q89 206 118 205H267Q298 205 300 180L303 147Q303 133 291 135Q280 137 280 158L276 177Z", "--mint"],
      ["M236 153A62 62 0 1 1 112 153A62 62 0 1 1 236 153Z", "--peach"],
      ["M220 154C220 106 131 106 131 155C131 192 201 195 202 157C203 133 152 130 151 156C151 173 184 174 184 158", "none"],
      ["M286 137 277 116M298 136 311 116", "none"],
      ["M280 113A5 5 0 1 1 270 113A5 5 0 1 1 280 113Z", "--ink"],
      ["M318 112A5 5 0 1 1 308 112A5 5 0 1 1 318 112Z", "--ink"],
      ["M288 164Q295 171 301 161", "none"],
      ["M141 89 144 57 201 57 204 89Z", "--ice"],
      ["M158 57V47Q172 38 187 47V57M143 69H202M166 65V76H180V65Z", "--canyon"],
      ["M69 163H87M61 182H74M248 220H266", "none"],
    ],
  },
  {
    caption: "Rooting for you",
    paths: [
      ["M120 224Q200 211 280 224", "none"],
      ["M200 170V70", "none"],
      ["M199 141C155 151 125 124 134 92C171 91 200 111 199 141Z", "--mint"],
      ["M201 119C244 126 273 97 261 68C225 71 201 91 201 119Z", "--mint"],
      ["M200 90C169 77 169 48 192 34C215 49 220 73 200 90Z", "--canyon"],
      ["M145 106 198 140M249 82 201 119M192 51 200 89", "none"],
      ["M155 169H245L232 217Q200 227 168 217Z", "--peach"],
      ["M150 158H250V175H150Z", "--canyon"],
      ["M186 190V194M215 190V194M195 200Q201 205 207 200", "none"],
      ["M102 71V89M93 80H111M288 146V162M280 154H296", "none"],
      ["M104 165Q111 155 117 165Q121 176 109 181Q97 174 104 165Z", "--ice"],
    ],
  },
  {
    caption: "Fully charged for absolutely nothing",
    paths: [
      ["M118 225H282", "none"],
      ["M178 187V216H157V226H189V187M214 187V226H245V216H225V187", "--mint"],
      ["M156 137Q139 135 132 161L116 151M244 138Q263 149 277 126", "none"],
      ["M110 146 116 151 110 160M273 121 277 126 285 123", "none"],
      ["M161 122H239V188Q200 202 161 188Z", "--ice"],
      ["M148 68Q148 58 159 58H241Q252 58 252 69V121Q252 132 240 132H160Q148 132 148 120Z", "--mint"],
      ["M200 58V39", "none"],
      ["M207 32A7 7 0 1 1 193 32A7 7 0 1 1 207 32Z", "--canyon"],
      ["M148 83H138V108H148M252 83H262V108H252", "--canyon"],
      ["M183 88A7 7 0 1 1 169 88A7 7 0 1 1 183 88Z", "--ink"],
      ["M230 88A7 7 0 1 1 216 88A7 7 0 1 1 230 88Z", "--ink"],
      ["M184 112Q200 122 216 112", "none"],
      ["M185 153H215V174H185Z", "--peach"],
      ["M192 163H208M200 156V170M297 76V94M288 85H306", "none"],
    ],
  },
  {
    caption: "A well-deserved little break",
    paths: [
      ["M103 217Q200 201 297 217", "none"],
      ["M250 125H267C303 125 303 177 267 179H248V165H267C286 164 286 141 267 141H250Z", "--mint"],
      ["M138 116H258L250 192Q198 216 146 192Z", "--peach"],
      ["M258 116C258 132 138 132 138 116C138 100 258 100 258 116Z", "--canyon"],
      ["M153 115Q198 105 242 115", "none"],
      ["M170 91C149 74 185 65 169 47M198 86C181 68 213 61 198 40M226 90C210 75 241 65 226 51", "none"],
      ["M178 151V156M218 151V156M189 169Q198 177 207 169", "none"],
      ["M263 205C263 186 308 186 308 205C308 224 263 224 263 205Z", "--canyon"],
      ["M275 200H278M290 207H293M281 212H284", "none"],
      ["M101 117V135M92 126H110M284 66V84M275 75H293", "none"],
    ],
  },
];

const DRAW_TIME = 8500;
const HOLD_TIME = 3500;

export default class extends Controller {
  static values = { round: String };
  static targets = ["art", "pencil", "caption", "elapsed", "waitCopy"];

  connect() {
    this.motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.onMotionChange = () => this.showDoodle();
    this.onVisibilityChange = () => this.resume();
    this.motion.addEventListener("change", this.onMotionChange);
    document.addEventListener("visibilitychange", this.onVisibilityChange);
    this.start();
  }

  disconnect() {
    this.stop();
    this.motion.removeEventListener("change", this.onMotionChange);
    document.removeEventListener("visibilitychange", this.onVisibilityChange);
  }

  roundValueChanged() {
    if (this.motion) this.start();
  }

  start() {
    this.stop();
    if (!this.roundValue) return;
    this.waitStarted = Date.now();
    this.index = Math.floor(Math.random() * DOODLES.length);
    this.updateWait();
    this.waitTimer = setInterval(() => this.updateWait(), 1000);
    this.showDoodle();
  }

  stop() {
    cancelAnimationFrame(this.frame);
    clearInterval(this.waitTimer);
  }

  updateWait() {
    const seconds = Math.max(0, Math.floor((Date.now() - this.waitStarted) / 1000));
    const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
    this.elapsedTarget.textContent = time;
    this.elapsedTarget.setAttribute("aria-label", `Time spent waiting: ${time}`);
    this.waitCopyTarget.textContent = seconds < 60
      ? "Usually about a minute. Your timer hasn’t started."
      : "Still working on your drawing. Your timer hasn’t started.";
  }

  next() {
    if (!this.roundValue) return;
    this.index = (this.index + 1) % DOODLES.length;
    this.showDoodle();
  }

  showDoodle() {
    if (!this.roundValue) return;
    cancelAnimationFrame(this.frame);
    const doodle = DOODLES[this.index];
    this.captionTarget.textContent = doodle.caption;
    this.artTarget.replaceChildren();
    let total = 0;
    this.strokes = doodle.paths.map(([d, color]) => {
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("d", d);
      path.setAttribute("fill", color === "none" ? "none" : `var(${color})`);
      this.artTarget.append(path);
      const length = path.getTotalLength();
      const weight = Math.max(90, length);
      const stroke = { path, length, start: total, weight };
      total += weight;
      path.style.strokeDasharray = `${length} ${length}`;
      return stroke;
    });
    this.strokes.forEach((stroke) => {
      stroke.start = (stroke.start / total) * DRAW_TIME;
      stroke.duration = (stroke.weight / total) * DRAW_TIME;
    });
    this.elapsed = this.motion.matches ? DRAW_TIME : 0;
    this.paint();
    this.resume();
  }

  resume() {
    cancelAnimationFrame(this.frame);
    this.lastFrame = null;
    if (!this.roundValue || this.motion.matches || document.hidden) return;
    this.frame = requestAnimationFrame((now) => this.tick(now));
  }

  tick(now) {
    if (this.lastFrame != null) this.elapsed += Math.min(now - this.lastFrame, 100);
    this.lastFrame = now;
    if (this.elapsed >= DRAW_TIME + HOLD_TIME) {
      this.next();
      return;
    }
    this.paint();
    this.frame = requestAnimationFrame((time) => this.tick(time));
  }

  paint() {
    let current;
    this.strokes.forEach((stroke) => {
      const progress = Math.min(1, Math.max(0, (this.elapsed - stroke.start) / stroke.duration));
      stroke.path.style.visibility = progress > 0 ? "visible" : "hidden";
      stroke.path.style.strokeDashoffset = stroke.length * (1 - progress);
      stroke.path.style.fillOpacity = Math.max(0, (progress - 0.7) / 0.3);
      if (progress > 0 && progress < 1) current = { stroke, progress };
    });
    this.pencilTarget.setAttribute("visibility", current && !this.motion.matches ? "visible" : "hidden");
    if (current) {
      const point = current.stroke.path.getPointAtLength(current.stroke.length * current.progress);
      this.pencilTarget.setAttribute("transform", `translate(${point.x} ${point.y})`);
    }
  }
}
