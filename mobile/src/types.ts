export type Setup = {
  mode: "solo" | "party";
  category: string;
  round_limit: number;
  drawing_model: string;
};
export type Config = {
  categories: { id: string; name: string }[];
  artists: { id: string; name: string; challenge: string }[];
  default_artist: string;
  rounds: number[];
  max_players: number;
};
export type Game = {
  id: string;
  share_url: string;
  phase: string;
  host: boolean;
  mode: string;
  round_limit: number;
  drawing_model: string;
  server_time: string;
  round_duration_seconds: number;
  drawing_duration_ms: number;
  players: { name: string; me: boolean; points: number; solved: boolean }[];
  round: null | {
    id: number;
    number: number;
    category: string;
    status: string;
    started_at: string | null;
    ends_at: string | null;
    solved: boolean;
    next_round_at: string | null;
    image_url: string | null;
    scene_url: string | null;
    hint: string | null;
    answer: string | null;
    error: string | null;
  };
  gallery: { number: number; answer: string; image_url: string }[];
};
