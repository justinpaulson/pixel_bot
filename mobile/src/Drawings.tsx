import type { Game } from "./types";

function Pencil() {
  return (
    <g transform="rotate(35)">
      <path
        d="M-5-10V-49Q0-56 5-49V-10L0 0Z"
        fill="var(--canyon)"
        stroke="var(--ink)"
        strokeWidth="2"
      />
      <path
        d="M-5-10 0 0 5-10Z"
        fill="var(--canvas)"
        stroke="var(--ink)"
        strokeWidth="2"
      />
      <path
        d="M-5-41H5M0-35V-15"
        fill="none"
        stroke="var(--canvas)"
        strokeWidth="2"
      />
    </g>
  );
}
export function Drawing({
  game,
  roundId,
  imagePath,
  label,
}: {
  game: Game;
  roundId?: number;
  imagePath?: string;
  label?: string;
}) {
  const round = game.round;
  const presentation = {
    id: roundId || round?.id,
    sceneUrl: imagePath || round?.scene_url,
    startedAt: roundId ? null : round?.started_at,
    serverTime: game.server_time,
    duration: game.drawing_duration_ms,
    complete: !!roundId || round?.status === "revealed",
  };
  return (
    <div
      className="puzzle-drawing"
      data-controller="drawing"
      data-drawing-presentation-value={JSON.stringify(presentation)}
    >
      <svg
        data-drawing-target="svg"
        viewBox="0 0 512 512"
        role="img"
        aria-label={label || "Guess the drawing"}
        {...{ hidden: true }}
      >
        <g data-drawing-target="art" />
        <g data-drawing-target="pencil" visibility="hidden" aria-hidden="true">
          <Pencil />
        </g>
      </svg>
      <img data-drawing-target="fallback" alt="Guess the drawing" hidden />
      <span
        className="drawing-caption"
        data-drawing-target="caption"
        role="status"
      >
        Opening the sketchbook…
      </span>
    </div>
  );
}
export function Sketchbook({ round }: { round: number }) {
  return (
    <div
      className="sketchbook"
      data-controller="sketchbook"
      data-sketchbook-round-value={String(round)}
    >
      <div className="sketchbook-heading">
        <h2>
          Pixel is drawing<span className="dots">…</span>
        </h2>
        <span data-sketchbook-target="elapsed">0:00</span>
      </div>
      <p data-sketchbook-target="waitCopy">Your timer hasn’t started.</p>
      <svg viewBox="0 0 400 260" aria-hidden="true">
        <g
          data-sketchbook-target="art"
          fill="none"
          stroke="var(--ink)"
          strokeWidth="3.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <g data-sketchbook-target="pencil" visibility="hidden">
          <Pencil />
        </g>
      </svg>
      <span data-sketchbook-target="caption" hidden />
      <div className="sketchbook-footer">
        <span>Just a warm-up doodle</span>
        <button
          className="icon-button"
          aria-label="Next doodle"
          data-action="sketchbook#next"
        >
          ↻
        </button>
      </div>
    </div>
  );
}
