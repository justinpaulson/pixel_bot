# Pixel prompt catalog

Updated October 15, 2026. The expansion adds 1,554 entries to the original 180, for 1,734 category entries. A title can belong to multiple media categories; this is not a claim of 1,734 globally unique names.

| Category | Before | After | Added |
| --- | ---: | ---: | ---: |
| Songs | 24 | 489 | 465 |
| Movies | 30 | 323 | 293 |
| TV shows | 24 | 333 | 309 |
| Video games | 24 | 511 | 487 |
| Pop stars | 24 | 24 | 0 |
| Places | 24 | 24 | 0 |
| Objects | 30 | 30 | 0 |
| Everything | 180 | 1,734 | 1,554 |

## Song coverage and evidence

The expansion uses **U.S. Billboard Hot 100 weekly top-10 appearances** as its popularity baseline. This is not the annual top 10, the UK chart, or a list of songs released within the window. An older song that re-entered the top 10 during the window is eligible.

The research window is October 15, 1986 through October 15, 2026. The [public historical chart mirror](https://github.com/mhollingshead/billboard-hot-100) contained 2,087 consecutive eligible weekly charts, October 18, 1986 through October 10, 2026, with no missing weeks. Its October 17 chart was excluded because it falls after the cutoff. The window yielded 2,597 distinct chart-title/artist pairs before curation and before combining covers, alternate chart credits, and duplicate titles.

All **465 new playable song answers** have an observed top-10 chart match, recorded in [music-chart-evidence.tsv](prompt-catalog/music-chart-evidence.tsv). Each row keeps the playable answer, original chart title, credited artist, first observed top-10 date within this window, and best observed rank within the window. These dates are not release dates and the ranks are not necessarily all-time career peaks. Selected songs cover every calendar year from 1986 through 2026. The original 24 songs remain, including older classics that do not meet this particular chart-window rule.

The mirror is a secondary transcription of [Billboard's Hot 100](https://www.billboard.com/charts/hot-100/), not an official Billboard API. Historical weekly pages can be located at `https://www.billboard.com/charts/hot-100/YYYY-MM-DD/` using the ledger date. The research snapshot was downloaded from the mirror's `all.json`; its repository head was `f6295aee360db9afe913843e95230040bdeab41f`, and the downloaded file's SHA-256 was `a15bc305627f70631770787eab33123cf9471e778b55f68321188e1b23e390d7`. Raw chart archives are not shipped in the app.

This is a curated playable subset of the historical pool, not a claim that every possible drawable top-10 song has been added. Duplicate titles count once even if different artists charted with them. Abstract titles, ambiguous generic romance prompts, spelling-dependent ideas, and concepts lacking a useful composition were generally left out. A future pass can reconsider excluded titles with better clue ideas.

## Visual curation

Every new entry has a short public hint, accepted alternate names where useful, and an authored private visual composition. The composition must suggest recognizable objects, actions, characters, costumes, settings, or a literal title rebus without needing letters, logos, lyrics, a score display, or dialogue. Song hints identify the chart artist to distinguish otherwise similar title imagery. Mature source material is illustrated through non-graphic, general-audience props and silhouettes.

Examples include a sun peeking out of a pocket for “Pocketful Of Sunshine,” a bowl of noodles for “Lo Mein,” a bathhouse and white dragon for “Spirited Away,” a boy in a pine-tree cap and a triangular mystery figure for “Gravity Falls,” and a tiny horned mask and nail-shaped sword for “Hollow Knight.” Some pictures still rely on the delayed contextual hint; these are illustration briefs, not guarantees that every player will recognize every answer.

Movie, television, and game additions are editorial selections across eras and genres, not asserted chart rankings. Coverage includes animation, live-action adventure, comedy, classic television, anime, reality and factual television, arcade classics, console games, PC strategy, independent games, and mobile games. Familiar titles and imagery were cross-checked against reference coverage such as the [AFI film list](https://www.afi.com/afis-100-years-100-movies-10th-anniversary-edition/), [Nintendo's sales catalog](https://www.nintendo.co.jp/ir/en/finance/software/index.html), and [The Strong's World Video Game Hall of Fame](https://www.museumofplay.org/exhibits/world-video-game-hall-of-fame/). Those sources do not establish rankings or popularity for every added title. Hints and compositions are newly authored, not copied plot descriptions.

Duplicate canonical names and conflicting aliases within a category are rejected by the catalog tests. Several similar sequels and platform editions were omitted so they would not inflate the count with effectively identical drawings. Some sequels remain when their visual setting or central prop differs, such as a hoverboard in “Back to the Future Part II.”

## Storage and maintenance

`config/prompt_catalog/*.txt` is the authoritative server-side catalog. Each line is:

```text
Canonical answer|semicolon-separated aliases|public delayed hint|private visual composition
```

The original 180 entries retain their original answer, aliases, and hint, and may omit the fourth column. This preserves saved-artwork compatibility. New entries require a useful fourth column and should be checked against every existing answer and alias in their category using `AnswerMatcher.normalize`.

`PromptCatalog.entries` exposes only attributes that can be saved on a round. `DrawingBot` looks up the private composition by category and answer when generating new art. Compositions are not sent to clients, stored in public round state, or revealed with the answer. Historical rounds whose titles are absent from the current catalog still generate from their saved title and hint.

The selection algorithm, within-game exclusions, saved-artwork reuse, timing, scoring, and API contracts are unchanged. The website and native apps share the same server catalog, so this expansion does not require a new mobile binary. The three smaller categories were outside this expansion's scope.

To reconsider songs from the research source, download the mirror's `all.json` locally, filter weekly dates to the requested window, then keep rows whose `this_week` is between 1 and 10. Group by chart title and artist and retain the first date and best in-window rank. Select only after writing a workable composition; preserve the original chart title as an alias when shortening film suffixes or parenthetical subtitles. Add the evidence row alongside every newly selected song.

## Validation

Automated checks cover catalog size, normalized answer and alias collisions, the 120-character guess limit, chart evidence for new songs, existing exclusion behavior, private composition delivery to the illustrator, and absence of those instructions from game state before and after reveal. Existing game, cache, API, and privacy tests also exercise the expanded catalog.

Five real Astra drawings were generated, sanitized, rendered and visually inspected: [Walk Like An Egyptian](prompt-catalog/samples/walk-like-an-egyptian.svg), [Espresso](prompt-catalog/samples/espresso.svg), [Spirited Away](prompt-catalog/samples/spirited-away.svg), [Gravity Falls](prompt-catalog/samples/gravity-falls.svg), and [Hollow Knight](prompt-catalog/samples/hollow-knight.svg). All five produced recognizable compositions, readable silhouettes, and no text. Timing and output metadata are in [drawing-evaluation.json](prompt-catalog/drawing-evaluation.json); fresh generations took 26–65 seconds. These samples are review artifacts, not preloaded production cache entries.

These are samples, not a blind playtest of all 1,554 additions; recognizability can still vary by artist and generation.
