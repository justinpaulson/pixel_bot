# Pixel SVG evaluation — October 15, 2026

The original production app was reachable and its OpenAI credential still worked. A GPT-4o rocket smoke test returned 560 bytes of SVG. The production database contained four users, two unfinished games, zero rounds, zero drawings, and zero failed jobs, so it did not demonstrate successful historical gameplay.

## Current-model comparison

All three models received the same Jurassic Park drawing instructions through the Responses API, with `reasoning.effort: low`, `store: false`, and a fresh composition seed. These are individual observations, not statistical latency benchmarks. The generated SVGs passed the application's sanitizer.

| Model | Seconds | SVG bytes | Visual observation |
| --- | ---: | ---: | --- |
| [GPT-6 Astra](svg-evaluation/gpt-6-astra.svg) | 61.4 | 5,801 | Clear dinosaur, patterned tour vehicle, and electric fence. Strongest movie-specific composition. |
| [GPT-6.1 Sol](svg-evaluation/gpt-6.1-sol.svg) | 68.0 | 5,142 | Recognizable dinosaur and vehicle, plus amber. Good result, no observed speed advantage in this sample. |
| [GPT-6 Luna](svg-evaluation/gpt-6-luna.svg) | 12.9 | 2,870 | Fast, but the gate and fragmented shapes made the intended movie substantially harder to identify. |

**Default: GPT-6 Astra.** Preserve the stronger illustration quality, start the clock only after generation, and generate one fresh drawing ahead during the active round to reduce subsequent waiting. The initial wait remains visible and honestly described in the game.

The current [OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model) and [migration guidance](https://developers.openai.com/api/docs/guides/latest-model/gpt-6-astra.md#migration-quickstart) were checked before implementation. The authenticated model list and actual requests confirmed access to all three evaluated models.

## Category samples from Astra

| Category | Answer / actual SVG | Seconds | SVG bytes |
| --- | --- | ---: | ---: |
| TV | [SpongeBob SquarePants](svg-evaluation/tv.svg) | 55.8 | 5,655 |
| Songs | [Rocket Man](svg-evaluation/music.svg) | 48.5 | 5,069 |
| Video games | [Super Mario Bros](svg-evaluation/games.svg) | 47.1 | 5,099 |
| Places | [Taj Mahal](svg-evaluation/places.svg) | 52.0 | 5,653 |
| Objects | [Telescope](svg-evaluation/objects.svg) | 28.0 | 2,527 |

The TV and game samples contain distinctive characters and settings. Rocket Man combines an astronaut, rocket, and oversized glasses. These drawings were inspected visually, not just checked for XML validity. Generated clues can still be ambiguous; the delayed category-specific hint, aliases, and explicit reveal provide a way through difficult rounds.

## Browser checks

A real three-round solo game generated Post Malone, Cher, and KISS. Verified incorrect-guess feedback, typo-tolerant acceptance of “Post Malon,” one-time scoring, answer reveal, pre-generated next-round activation with a fresh 90-second timer, host reveal, final scores, and the three-image gallery. A 390-pixel phone viewport had no horizontal overflow.

Two independent local browser sessions verified the invite/join flow and synchronized multiplayer state. A round timed out and revealed automatically. On the next round, the host correctly guessed The Matrix while the guest retained an active guess form and no visible answer; the guest then guessed “matrix,” both scores appeared, and the shared answer was revealed. Browser console inspection reported no errors or warnings. Automated request tests separately verify that outsiders cannot read state or artwork, a guest cannot start/skip another host's round, prepared future artwork is inaccessible, and the first correct party guess does not reveal the answer to other players.

Raw timing/size results are stored beside the SVGs in `svg-evaluation/results.json` and `svg-evaluation/categories.json`. These samples are evaluation artifacts, not a cache used by gameplay. The landing page uses one clearly labeled sample; actual rounds always call the model for new art.
