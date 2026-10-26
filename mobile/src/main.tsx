import { StudioLaunch } from './StudioLaunch';
import React, { useCallback, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { App as NativeApp } from "@capacitor/app";
import { Haptics, NotificationType } from "@capacitor/haptics";
import { Preferences } from "@capacitor/preferences";
import { Share } from "@capacitor/share";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronDown,
  Copy,
  DoorOpen,
  HelpCircle,
  Link,
  Play,
  Send,
  Settings2,
  Share2,
  Sparkles,
  Trophy,
  UserRound,
  UsersRound,
  X,
} from "lucide-react";
import {
  ApiError,
  ensureSession,
  initializeSession,
  request,
  roomId,
} from "./api";
import type { Config, Game, Setup } from "./types";
import { Drawing, Sketchbook } from "./Drawings";
import { Confetti, CorrectAnswer } from "./Celebration";
import { startDrawingControllers } from "./drawing";
import "./styles.css";

const fallbackConfig: Config = {
  categories: [
    { id: "mix", name: "Everything" },
    { id: "movies", name: "Movies" },
    { id: "tv", name: "TV shows" },
    { id: "music", name: "Songs" },
    { id: "stars", name: "Pop stars" },
    { id: "games", name: "Video games" },
    { id: "places", name: "Places" },
    { id: "objects", name: "Objects" },
  ],
  artists: [
    { id: "gpt-6-astra", name: "Astra", challenge: "Easier" },
    { id: "gpt-6.1-sol", name: "Sol", challenge: "Balanced" },
    { id: "gpt-6-luna", name: "Luna", challenge: "Harder" },
  ],
  default_artist: "gpt-6-astra",
  rounds: [3, 5, 10],
  max_players: 12,
};
const initialSetup: Setup = {
  mode: "solo",
  category: "mix",
  round_limit: 5,
  drawing_model: "gpt-6-astra",
};
const feedbackHaptic = () =>
  Haptics.notification({ type: NotificationType.Success }).catch(() => {});

function Sheet({
  title,
  close,
  children,
}: {
  title: string;
  close: () => void;
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current!;
    dialog.showModal();
    return () => dialog.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className="sheet"
      onCancel={close}
      onClick={(e) => {
        if (e.target === e.currentTarget) close();
      }}
      aria-label={title}
    >
      <div className="sheet-handle" />
      <header>
        <h2>{title}</h2>
        <button className="icon-button" aria-label="Close" onClick={close}>
          <X />
        </button>
      </header>
      {children}
    </dialog>
  );
}

function PixelApp() {
  const [ready, setReady] = useState(false);
  const [config, setConfig] = useState(fallbackConfig);
  const [setup, setSetup] = useState(initialSetup);
  const [name, setName] = useState("");
  const [game, setGame] = useState<Game | null>(null);
  const [lastGame, setLastGame] = useState<string | null>(null);
  const [sheet, setSheet] = useState<
    | "join"
    | "settings"
    | "help"
    | "scores"
    | "leave"
    | "reveal"
    | "gallery"
    | null
  >(null);
  const [invite, setInvite] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [connection, setConnection] = useState("");
  const [guess, setGuess] = useState("");
  const [feedback, setFeedback] = useState("");
  const [accepted, setAccepted] = useState(false);
  const [award, setAward] = useState<{
    gameId: string;
    roundId: number;
    points: number;
  } | null>(null);
  const [now, setNow] = useState(Date.now());
  const [active, setActive] = useState(true);
  const input = useRef<HTMLInputElement>(null);
  const generation = useRef(0);
  const stateRevision = useRef(0);
  const serverOffset = useRef(0);
  const gameRef = useRef<Game | null>(null);
  gameRef.current = game;

  const receive = useCallback((next: Game) => {
    stateRevision.current++;
    serverOffset.current = Date.parse(next.server_time) - Date.now();
    setGame(next);
    setConnection("");
  }, []);

  useEffect(() => {
    (async () => {
      try {
        await initializeSession();
        const [savedName, savedRoom, savedSetup] = await Promise.all(
          ["nickname", "last-game", "setup"].map((key) =>
            Preferences.get({ key }),
          ),
        );
        setName(savedName.value || "");
        setLastGame(savedRoom.value);
        if (savedSetup.value) {
          try {
            const stored = JSON.parse(savedSetup.value);
            if (
              ["solo", "party"].includes(stored.mode) &&
              fallbackConfig.categories.some((c) => c.id === stored.category) &&
              fallbackConfig.artists.some(
                (a) => a.id === stored.drawing_model,
              ) &&
              [3, 5, 10].includes(stored.round_limit)
            )
              setSetup(stored);
          } catch {
            /* Keep safe defaults. */
          }
        }
      } catch {
        setError("Couldn’t load your player. Please reopen Pixel.");
      }
      setReady(true);
      request<Config>("/config")
        .then(setConfig)
        .catch(() => {});
    })();
  }, []);

  useEffect(() => {
    const openInvite = (url: string) => {
      const id = roomId(url);
      if (id) {
        setInvite(id);
        setError("");
        setSheet("join");
      }
    };
    const listener = NativeApp.addListener("appUrlOpen", (event) =>
      openInvite(event.url),
    );
    const stateListener = NativeApp.addListener("appStateChange", (event) =>
      setActive(event.isActive),
    );
    NativeApp.getLaunchUrl()
      .then((result) => {
        if (result?.url) openInvite(result.url);
      })
      .catch(() => {});
    const visibility = () => setActive(!document.hidden);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      listener.then((h) => h.remove());
      stateListener.then((h) => h.remove());
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);

  useEffect(() => {
    const listener = NativeApp.addListener("backButton", () => {
      if (sheet) setSheet(null);
      else if (game) setSheet(game.phase === "complete" ? null : "leave");
      if (!sheet && game?.phase === "complete") leave();
      if (!sheet && !game) NativeApp.minimizeApp();
    });
    return () => {
      listener.then((h) => h.remove());
    };
  }, [sheet, game?.id, game?.phase]);

  useEffect(() => {
    if (!game?.id || !active) return;
    let stopped = false;
    let timer: ReturnType<typeof setTimeout>;
    const id = game.id;
    const epoch = generation.current;
    const poll = async () => {
      const revision = stateRevision.current;
      try {
        const next = await request<Game>(`/games/${id}/state`);
        if (
          !stopped &&
          generation.current === epoch &&
          revision === stateRevision.current
        )
          receive(next);
      } catch (e) {
        if (stopped || generation.current !== epoch) return;
        if (e instanceof ApiError && [401, 403, 404].includes(e.status)) {
          generation.current++;
          setGame(null);
          setLastGame(null);
          await Preferences.remove({ key: "last-game" });
          setError(
            e.status === 401
              ? "Your session ended. Start a new game."
              : "This room is unavailable.",
          );
        } else setConnection("Reconnecting…");
      } finally {
        if (!stopped) timer = setTimeout(poll, 1500);
      }
    };
    poll();
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [game?.id, active, receive]);

  useEffect(() => {
    if (!game || !active) return;
    const timer = setInterval(() => setNow(Date.now()), 200);
    return () => clearInterval(timer);
  }, [!!game, active]);
  useEffect(() => {
    setGuess("");
    setFeedback("");
    setAccepted(false);
    setAward(null);
  }, [game?.id, game?.round?.id]);
  useEffect(() => {
    if (game?.phase === "complete") {
      setLastGame(null);
      Preferences.remove({ key: "last-game" });
    }
  }, [game?.phase]);
  useEffect(() => {
    if (ready) Preferences.set({ key: "setup", value: JSON.stringify(setup) });
  }, [setup, ready]);

  async function action(work: () => Promise<void>) {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await work();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Please try again.");
    } finally {
      setBusy(false);
    }
  }
  async function enter(next: Game) {
    generation.current++;
    receive(next);
    setSheet(null);
    setFeedback("");
    setGuess("");
    setLastGame(next.id);
    await Preferences.set({ key: "last-game", value: next.id });
  }
  function create() {
    action(async () => {
      await ensureSession(name);
      await enter(
        await request<Game>("/games", "POST", { ...setup, display_name: name }),
      );
    });
  }
  function join() {
    action(async () => {
      const id = roomId(invite);
      if (!id) throw new Error("Paste a Pixel invite link.");
      await ensureSession(name);
      await enter(
        await request<Game>(`/games/${id}/join`, "POST", {
          display_name: name,
        }),
      );
    });
  }
  function leave() {
    generation.current++;
    setGame(null);
    setSheet(null);
    setError("");
    setConnection("");
  }
  function mutate(path: string) {
    action(async () => {
      stateRevision.current++;
      const epoch = generation.current;
      const next = await request<Game>(path, "POST");
      if (generation.current === epoch) receive(next);
    });
  }
  async function share() {
    if (!game) return;
    try {
      await Share.share({
        title: "Play Pixel",
        text: "Pixel draws. We guess.",
        url: `https://pixel.justinpaulson.com/games/${game.id}`,
        dialogTitle: "Invite friends",
      });
    } catch {
      /* Dismissing the share sheet is not a connection error. */
    }
  }
  async function copyInvite() {
    if (!game) return;
    try {
      await navigator.clipboard.writeText(
        `https://pixel.justinpaulson.com/games/${game.id}`,
      );
      setFeedback("Invite copied");
    } catch {
      setError("Use the share button to send your invite.");
    }
  }
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!game?.round || busy || accepted || game.round.solved || !guess.trim())
      return;
    const roundId = game.round.id,
      epoch = generation.current,
      submitted = guess;
    // Keep focus and the keyboard in place across submissions and state polls.
    input.current?.focus({ preventScroll: true });
    await action(async () => {
      stateRevision.current++;
      const result = await request<{
        message: string;
        accepted: boolean;
        points?: number;
      }>(`/rounds/${roundId}/answer`, "POST", { answer: submitted });
      if (
        generation.current !== epoch ||
        gameRef.current?.round?.id !== roundId
      )
        return;
      setFeedback(result.accepted ? "Got it!" : result.message);
      setAccepted(result.accepted);
      setGuess((current) => (current === submitted ? "" : current));
      if (result.accepted) {
        if (result.points !== undefined) {
          setAward({ gameId: game.id, roundId, points: result.points });
        }
        feedbackHaptic();
        input.current?.blur();
      }
      const next = await request<Game>(`/games/${game.id}/state`);
      if (generation.current === epoch) receive(next);
    });
  }

  const round = game?.round;
  const artist =
    config.artists.find((a) => a.id === setup.drawing_model) ||
    config.artists[0];
  const seconds = round?.ends_at
    ? Math.max(
        0,
        Math.ceil(
          (Date.parse(round.ends_at) - now - serverOffset.current) / 1000,
        ),
      )
    : 0;
  const nextSeconds = round?.next_round_at
    ? Math.max(
        0,
        Math.ceil(
          (Date.parse(round.next_round_at) - now - serverOffset.current) / 1000,
        ),
      )
    : 0;
  const solved = round?.solved || accepted;
  const score = game?.players.find((p) => p.me)?.points || 0;
  const loading =
    game && ["pending", "generating", "ready"].includes(game.phase);
  const playing = game?.phase === "playing";
  const revealed = game && ["revealed", "complete"].includes(game.phase);
  const currentAward =
    award?.gameId === game?.id && award?.roundId === round?.id ? award : null;

  return (
    <div className={`app-shell${game ? "" : " home-shell"}`}>
      <header className="topbar">
        {game ? (
          <button
            className="icon-button"
            aria-label="Leave game"
            onClick={() =>
              game.phase === "complete" ? leave() : setSheet("leave")
            }
          >
            <ArrowLeft />
          </button>
        ) : (
          <a className="wordmark" href="#" aria-label="Pixel home">
            <img src="/mark.svg" alt="" />
            pixel<span>.</span>
          </a>
        )}
        {game && (
          <span className="room-title">
            {round ? `${round.number} / ${game.round_limit}` : "Your room"}
          </span>
        )}
        {game ? (
          <button
            className="score-pill"
            onClick={() => setSheet("scores")}
            aria-label={`Scores, ${score} points`}
          >
            <Trophy size={17} />
            {score.toLocaleString()}
          </button>
        ) : (
          <button
            className="icon-button"
            aria-label="Player settings"
            onClick={() => setSheet("settings")}
          >
            <Settings2 />
          </button>
        )}
      </header>
      {error && (
        <div className="notice" role="alert">
          <span>{error}</span>
          <button
            className="icon-button"
            aria-label="Dismiss error"
            onClick={() => setError("")}
          >
            <X size={18} />
          </button>
        </div>
      )}
      {connection && (
        <div className="connection" role="status">
          {connection}
        </div>
      )}
      {!game ? (
        <main className="home">
          <section className="hero">
            <h1 className="eyebrow">THE AI DRAWING GAME</h1>
            <button
              className="icon-button help-button"
              aria-label="How to play"
              onClick={() => setSheet("help")}
            >
              <HelpCircle size={21} />
            </button>
          </section>
          <div className="preview-card">
            <img
              src={`/artists/${artist.name.toLowerCase()}.svg`}
              alt={`${artist.name} drawing Jurassic Park`}
            />
            <div className="preview-caption">
              <span>
                <Sparkles size={13} /> {artist.name}’s sketchbook
              </span>
              <span>Jurassic Park · example</span>
            </div>
          </div>
          <div className="segmented modes" role="group" aria-label="Play mode">
            {(["solo", "party"] as const).map((mode) => (
              <button
                key={mode}
                aria-pressed={setup.mode === mode}
                className={setup.mode === mode ? "selected" : ""}
                onClick={() => setSetup((s) => ({ ...s, mode }))}
              >
                {mode === "solo" ? (
                  <UserRound size={19} />
                ) : (
                  <UsersRound size={21} />
                )}{" "}
                {mode === "solo" ? "Solo" : "Friends"}
              </button>
            ))}
          </div>
          <div className="setup-row">
            <label className="category">
              <span>Category</span>
              <div>
                <select
                  aria-label="Category"
                  value={setup.category}
                  onChange={(e) =>
                    setSetup((s) => ({ ...s, category: e.target.value }))
                  }
                >
                  {config.categories.map((c) => (
                    <option value={c.id} key={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
                <ChevronDown size={16} />
              </div>
            </label>
            <fieldset className="rounds">
              <legend>Rounds</legend>
              <div className="segmented">
                {config.rounds.map((n) => (
                  <button
                    key={n}
                    aria-pressed={setup.round_limit === n}
                    className={setup.round_limit === n ? "selected" : ""}
                    onClick={() => setSetup((s) => ({ ...s, round_limit: n }))}
                  >
                    {n}
                  </button>
                ))}
              </div>
            </fieldset>
          </div>
          <fieldset className="artists">
            <legend>Artist</legend>
            <div>
              {config.artists.map((a) => (
                <button
                  key={a.id}
                  aria-pressed={setup.drawing_model === a.id}
                  className={`artist artist-${a.name.toLowerCase()} ${setup.drawing_model === a.id ? "selected" : ""}`}
                  onClick={() =>
                    setSetup((s) => ({ ...s, drawing_model: a.id }))
                  }
                >
                  <span className="artist-dot" />
                  <strong>{a.name}</strong>
                  <small>{a.challenge}</small>
                  {setup.drawing_model === a.id && <Check size={14} />}
                </button>
              ))}
            </div>
          </fieldset>
          <button
            className="primary launch"
            disabled={!ready || busy}
            onClick={create}
          >
            {busy ? "Opening…" : setup.mode === "solo" ? "Play" : "Create room"}
            <ArrowRight size={22} />
          </button>
          <div className="home-links">
            <button
              className="text-button"
              onClick={() => {
                setError("");
                setSheet("join");
              }}
            >
              <Link size={16} />
              Join room
            </button>
            {lastGame && (
              <button
                className="text-button"
                disabled={busy}
                onClick={() =>
                  action(async () => {
                    try {
                      await enter(
                        await request<Game>(`/games/${lastGame}/state`),
                      );
                    } catch (e) {
                      if (
                        e instanceof ApiError &&
                        [401, 403, 404].includes(e.status)
                      ) {
                        setLastGame(null);
                        await Preferences.remove({ key: "last-game" });
                      }
                      throw e;
                    }
                  })
                }
              >
                Resume
                <ArrowRight size={15} />
              </button>
            )}
          </div>
        </main>
      ) : (
        <main className={`game ${game.phase}`}>
          <div className="game-meta">
            <span>
              {round?.category ||
                config.categories.find((c) => c.id === setup.category)?.name ||
                "Pixel"}
            </span>
            <span>
              {config.artists.find((a) => a.id === game.drawing_model)?.name}
            </span>
          </div>
          <section className="canvas-card" aria-label="Drawing">
            {playing && (
              <div
                className={`clock ${seconds <= 5 ? "urgent" : ""}`}
                aria-label={`${seconds} seconds left`}
              >
                {seconds}
                <svg viewBox="0 0 44 44" aria-hidden="true">
                  <circle
                    cx="22"
                    cy="22"
                    r="19"
                    style={{
                      strokeDasharray: 120,
                      strokeDashoffset:
                        120 * (1 - seconds / game.round_duration_seconds),
                    }}
                  />
                </svg>
              </div>
            )}
            {(playing || revealed) && round?.scene_url && (
              <Drawing key={round.id} game={game} />
            )}
            {loading && round && <Sketchbook key={round.id} round={round.id} />}
            {game.phase === "lobby" && (
              <div className="lobby-art">
                <div className="room-orbit">
                  <UsersRound size={54} />
                  <span className="orbit-dot one" />
                  <span className="orbit-dot two" />
                  <Sparkles className="orbit-spark" size={30} />
                </div>
                <h1>Better together.</h1>
                <p>
                  {game.players.length} / {config.max_players} players
                </p>
                <button className="primary" onClick={share}>
                  <Share2 size={19} />
                  Invite friends
                </button>
                <button className="text-button" onClick={copyInvite}>
                  <Copy size={15} />
                  Copy link
                </button>
              </div>
            )}
            {game.phase === "failed" && (
              <div className="empty-state">
                <img src="/mark.svg" alt="" />
                <h2>One more try?</h2>
                <p>The drawing didn’t arrive.</p>
                {game.host ? (
                  <button
                    className="primary"
                    disabled={busy}
                    onClick={() => mutate(`/rounds/${round!.id}/retry_drawing`)}
                  >
                    Retry drawing
                    <ArrowRight size={18} />
                  </button>
                ) : (
                  <p>Waiting for the host</p>
                )}
              </div>
            )}
            {currentAward && (
              <Confetti
                key={`${currentAward.gameId}-${currentAward.roundId}`}
              />
            )}
          </section>
          {currentAward && (
            <CorrectAnswer
              key={`${currentAward.gameId}-${currentAward.roundId}`}
              points={currentAward.points}
            />
          )}
          {game.phase === "lobby" && (
            <>
              <div className="player-chips">
                {game.players.map((p, i) => (
                  <span key={i}>
                    <span className="avatar">
                      {p.name.slice(0, 1).toUpperCase()}
                    </span>
                    {p.name}
                    {p.me && <small>you</small>}
                  </span>
                ))}
              </div>
              {game.host ? (
                <button
                  className="primary launch"
                  disabled={busy}
                  onClick={() => mutate(`/games/${game.id}/start`)}
                >
                  Start
                  <Play size={19} />
                </button>
              ) : (
                <p className="quiet centered">Waiting for the host</p>
              )}
            </>
          )}
          {playing && (
            <div className="guess-area">
              {solved ? (
                currentAward ? (
                  <p className="quiet centered">Waiting for everyone</p>
                ) : (
                  <div className="got-it" role="status">
                    <Check size={24} />
                    <strong>{accepted ? feedback : "Got it!"}</strong>
                    <span>Waiting for everyone</span>
                  </div>
                )
              ) : (
                <form className="guess-form" onSubmit={submit}>
                  <input
                    ref={input}
                    aria-label="Your guess"
                    placeholder="Your guess…"
                    value={guess}
                    onChange={(e) => setGuess(e.target.value)}
                    maxLength={120}
                    autoComplete="off"
                    autoCapitalize="off"
                    spellCheck={false}
                    enterKeyHint="send"
                    disabled={seconds === 0}
                  />
                  <button
                    className="send-button"
                    aria-label="Send guess"
                    aria-disabled={busy || seconds === 0 || !guess.trim()}
                    onPointerDown={(e) => {
                      if (
                        e.pointerType === "mouse" &&
                        document.activeElement === input.current
                      )
                        e.preventDefault();
                    }}
                  >
                    <Send size={21} />
                  </button>
                </form>
              )}
              {!solved && (
                <p className="guess-feedback" role="status">
                  {feedback || (seconds === 0 ? "Time’s up" : "\u00a0")}
                </p>
              )}
              {!solved && round?.hint && <p className="hint">{round.hint}</p>}
            </div>
          )}
          {revealed && (
            <div className="reveal" aria-live="polite">
              <span className="eyebrow">
                {game.phase === "complete" ? "FINAL DRAWING" : "IT’S"}
              </span>
              <h1>{round?.answer}</h1>
              {game.phase === "complete" ? (
                <>
                  <div className="final-score">
                    <Trophy size={20} />
                    {score.toLocaleString()}
                    <span>points</span>
                  </div>
                  <button className="primary launch" onClick={leave}>
                    Play again
                    <ArrowRight size={20} />
                  </button>
                </>
              ) : (
                <p className="quiet">Next drawing in {nextSeconds}s</p>
              )}
            </div>
          )}
          <div className="room-actions">
            {game.mode === "party" && game.phase !== "lobby" && (
              <button className="text-button" onClick={share}>
                <Share2 size={17} />
                Invite
              </button>
            )}
            {game.host && playing && (
              <button
                className="text-button"
                onClick={() => setSheet("reveal")}
              >
                Reveal
              </button>
            )}
            {game.gallery.length > 0 && (
              <button
                className="text-button"
                onClick={() => setSheet("gallery")}
              >
                Drawings<span className="count">{game.gallery.length}</span>
              </button>
            )}
          </div>
        </main>
      )}
      {sheet === "join" && (
        <Sheet title="Join room" close={() => setSheet(null)}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              join();
            }}
          >
            <label className="field">
              Invite link
              <input
                value={invite}
                onChange={(e) => setInvite(e.target.value)}
                placeholder="Paste your invite"
                autoCapitalize="off"
                autoCorrect="off"
                spellCheck={false}
                autoFocus
                required
              />
            </label>
            <label className="field">
              Nickname
              <input
                value={name}
                onChange={(e) => {
                  setName(e.target.value);
                  Preferences.set({ key: "nickname", value: e.target.value });
                }}
                placeholder="You"
                maxLength={24}
              />
            </label>
            {error && (
              <p className="sheet-error" role="alert">
                {error}
              </p>
            )}
            <button className="primary launch" disabled={busy || !ready}>
              Join
              <ArrowRight size={20} />
            </button>
          </form>
        </Sheet>
      )}
      {sheet === "settings" && (
        <Sheet title="Your player" close={() => setSheet(null)}>
          <label className="field">
            Nickname
            <input
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                Preferences.set({ key: "nickname", value: e.target.value });
              }}
              maxLength={24}
              placeholder="You"
              autoComplete="nickname"
            />
          </label>
          <p className="quiet">No account needed.</p>
          <div className="room-actions">
            <a
              className="text-button"
              href="https://pixel.justinpaulson.com/privacy"
              target="_blank"
              rel="noreferrer"
            >
              Privacy
            </a>
            <a
              className="text-button"
              href="https://pixel.justinpaulson.com/support"
              target="_blank"
              rel="noreferrer"
            >
              Help
            </a>
          </div>
          <button className="primary launch" onClick={() => setSheet(null)}>
            Done
            <Check size={20} />
          </button>
        </Sheet>
      )}
      {sheet === "help" && (
        <Sheet title="See it. Guess it." close={() => setSheet(null)}>
          <div className="how-to">
            <p>
              <span>1</span>Pixel draws a mystery picture.
            </p>
            <p>
              <span>2</span>You have 30 seconds to guess.
            </p>
            <p>
              <span>3</span>Faster guesses score more.
            </p>
          </div>
          <p className="quiet">
            Play solo or invite up to 11 friends. Everyone guesses.
          </p>
          <button className="primary launch" onClick={() => setSheet(null)}>
            Got it
            <Check size={20} />
          </button>
        </Sheet>
      )}
      {sheet === "scores" && game && (
        <Sheet title="Scores" close={() => setSheet(null)}>
          <ol className="scoreboard">
            {game.players.map((p, i) => (
              <li key={i} className={p.me ? "me" : ""}>
                <span className="rank">{i + 1}</span>
                <span>
                  {p.name}
                  {p.me && <small>you</small>}
                </span>
                {p.solved && <Check size={17} />}
                <strong>{p.points.toLocaleString()}</strong>
              </li>
            ))}
          </ol>
        </Sheet>
      )}
      {sheet === "leave" && (
        <Sheet title="Back to the menu?" close={() => setSheet(null)}>
          <p className="quiet">The game keeps going. You can resume.</p>
          <button className="primary launch" onClick={leave}>
            Leave
            <DoorOpen size={20} />
          </button>
          <button className="secondary launch" onClick={() => setSheet(null)}>
            Keep playing
          </button>
        </Sheet>
      )}
      {sheet === "reveal" && game && (
        <Sheet title="Reveal the answer?" close={() => setSheet(null)}>
          <p className="quiet">This ends the round for everyone.</p>
          <button
            className="primary launch"
            disabled={busy}
            onClick={() => {
              setSheet(null);
              mutate(`/rounds/${round!.id}/skip`);
            }}
          >
            Reveal
            <ArrowRight size={20} />
          </button>
          <button className="secondary launch" onClick={() => setSheet(null)}>
            Keep guessing
          </button>
        </Sheet>
      )}
      {sheet === "gallery" && game && (
        <Sheet title="The sketchbook" close={() => setSheet(null)}>
          <div className="gallery">
            {game.gallery.map((item) => (
              <figure key={item.number}>
                <Drawing
                  game={game}
                  roundId={Number(item.image_url.match(/\/rounds\/(\d+)/)?.[1])}
                  imagePath={item.image_url}
                  label={item.answer}
                />
                <figcaption>
                  <span>{item.number}</span>
                  {item.answer}
                </figcaption>
              </figure>
            ))}
          </div>
        </Sheet>
      )}
    </div>
  );
}

startDrawingControllers();
createRoot(document.getElementById("root")!).render(<StudioLaunch><PixelApp /></StudioLaunch>);
