import type { CSSProperties } from "react";
import { Check } from "lucide-react";

const colors = ["#55b895", "#efad45", "#ec8f81", "#7eb9dc", "#aa91cd"];

/** Mounted once per awarded round; state polls must not restart the burst. */
export function Confetti() {
  return (
    <div className="confetti" aria-hidden="true">
      {Array.from({ length: 36 }, (_, i) => (
        <i
          key={i}
          style={
            {
              left: `${(i * 29) % 100}%`,
              backgroundColor: colors[i % colors.length],
              "--drift": `${((i * 37) % 150) - 75}px`,
              "--turn": `${i % 2 ? 540 : -540}deg`,
              animationDelay: `${(i % 9) * 35}ms`,
              animationDuration: `${1700 + (i % 5) * 140}ms`,
            } as CSSProperties
          }
        />
      ))}
    </div>
  );
}

export function CorrectAnswer({ points }: { points: number }) {
  return (
    <div className="correct-answer" role="status" aria-atomic="true">
      <span className="correct-check" aria-hidden="true">
        <Check size={25} strokeWidth={3} />
      </span>
      <strong>Got it!</strong>
      <span className="round-points">
        +{points.toLocaleString()}
        <small>points</small>
      </span>
    </div>
  );
}
