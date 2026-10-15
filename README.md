# Pixel

[Play Pixel](https://pixel.justinpaulson.com) — everybody guesses; Pixel draws.

Solo or private rooms for up to 12 players, with 3, 5, or 10 rounds. Every round gets an AI-drawn SVG, reusing saved artwork when the same answer has been drawn before. Nobody, including the host, sees the answer before the reveal. Categories include movies, TV, songs, pop stars, video games, places, and everyday objects, plus a mixed mode. The curated catalog currently contains 180 prompts; it does not repeat an answer within a game.

## How the game works

- Join with a nickname; accounts are optional. Share the room's private URL for multiplayer.
- The current round and two upcoming rounds are prepared as soon as a game starts. That buffer refills on every advance, up to the selected round limit. Production has three drawing workers and a separate worker for cache lookups and round timers.
- Completed drawings are reused for the same answer, category, hint, model, and artwork version, including artwork saved before this feature. They are sanitized again before reuse. Cache misses call GPT-6 Astra through OpenAI's Responses API and typically take about a minute; cache hits need no provider call. Future answers and artwork are never sent to clients early.
- While waiting, Pixel’s sketchbook draws five playful warm-up illustrations stroke by stroke, adds color, and cycles every 12 seconds. Players can choose the next doodle; these are clearly labeled as unrelated to the answer. An elapsed wait clock reassures players that the round timer has not started. Reduced-motion mode shows a finished doodle with manual switching, and animation pauses in hidden tabs and stops when the round is ready.
- The 15-second timer starts only when the drawing becomes playable. A descriptive hint appears after 5 seconds.
- All players, including the host, can guess. Matching ignores case, punctuation, accents, and articles, supports curated aliases, and tolerates small typos in longer answers.
- A correct answer earns 1,000 minus 10 points per elapsed second, with a floor of 100. Each player can score once per round. Others continue guessing without seeing the correct answer.
- The round reveals when everyone has guessed, time runs out, or the host explicitly ends it. The host advances after a reveal; the final round completes the game. Finished illustrations form a gallery.
- Failures show a retry button. Requests recover stalled generation after three minutes and expired timers even if a scheduled job is delayed.

## Development

Ruby 3.3.6, Rails 8.1, SQLite, Bundler. The UI uses plain CSS and Stimulus with import maps; no Node build or Tailwind binary is required.

```sh
bundle install
bin/rails db:prepare
bin/dev
```

Provide `OPENAI_API_KEY`, or keep the existing encrypted Rails credential `openai_access_token` and supply its `config/master.key` / `RAILS_MASTER_KEY`. Never commit keys. `PIXEL_MODEL` overrides the default `gpt-6-astra` when evaluating other Responses-compatible reasoning models. Production explicitly sets Astra in `config/deploy.yml`.

Development uses the in-process Active Job adapter. Production runs Solid Queue under Puma and persists its queue in the existing storage volume. Restarting a development server can interrupt a drawing; the retry flow recovers it.

## Validation

```sh
bin/rails db:test:prepare test
node --test test/javascript/*.mjs
bin/rubocop
bin/brakeman --no-pager
bin/importmap audit
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

Tests stub the provider and require no production key. They cover scoring, timeouts, answer secrecy, membership/host authorization, a three-round preparation window, cache compatibility and safety, idempotent jobs, safe SVG delivery, model requests, and guest play. See [the model evaluation](docs/svg-evaluation.md) for real provider samples and browser verification. Increment `DrawingBot::ARTWORK_VERSION` when changing illustration instructions enough to invalidate saved art.

## Privacy and drawing safety

Answers and aliases stay on the server until reveal. Future drawings, raw provider messages, emails, and prompts are excluded from the client state. Only room members can read its state and images. Guessing, joining, and host actions are POST requests with CSRF protection and rate limits; scores and memberships have database uniqueness constraints.

SVG output is parsed with external entity access disabled, rebuilt from an allowlist of geometry and presentation attributes, stripped of text/metadata/scripts/links, and served as an isolated image with a sandboxed content security policy. The app never inserts raw model SVG into the page DOM. OpenAI response storage is disabled.

## Deployment

Push `main` to run `.github/workflows/deploy.yml`. The reusable CI workflow must pass tests, style, security scanning, dependency auditing, and production asset compilation before Kamal deploys the exact commit. Deployments are serialized. GitHub-hosted runners are configured; no Mac runner is required by these workflows.

The deployment uses Amazon ECR in `us-east-1`, the existing EC2 server, Kamal's HTTPS proxy, and the `pixel_bot_storage` volume. Required GitHub secrets are `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `RAILS_MASTER_KEY`, `SSH_PRIVATE_KEY`, and `SSH_KNOWN_HOSTS`.

For an authorized manual deployment with AWS and SSH access:

```sh
bundle exec kamal deploy
```

The October 2026 migrations preserve historical games and users. Legacy rooms display a restart invitation because their drawing/prompting rules are incompatible. A pre-migration SQLite backup is stored on the production volume at `/rails/storage/backups/pre-redesign-2026-10-15.sqlite3`. Roll back application code with Kamal if necessary; additive schema changes allow the old release to boot. Restoring a database backup would discard subsequent games and should be a deliberate recovery action.
