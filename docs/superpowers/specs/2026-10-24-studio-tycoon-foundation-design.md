# Studio Tycoon — Foundation + Garage Era Slice (Design Spec)

- Date: 2026-10-24
- Status: Approved in brainstorming, pending written-spec review
- Working title: Studio Tycoon

## 1. Purpose and context

A commercial game-studio tycoon game for Steam on Windows and macOS. The player runs a game studio from a 1980s garage to a modern platform holder. The full vision has five systems that later specs will cover:

1. Core loop in five phases: Pre-Production, Production, Marketing, Release, Post-Launch
2. Staff system: personalities, team chemistry, crunch and burnout
3. Reviews and sales: reviews give specific reasons derived from the game's real stats
4. Dynamic market taste driven by world events (no permanent winning formula)
5. Era progression (1980s, 1990s, 2000s, 2010s, 2020s+) and a Grand Strategy late game (own digital store, own console, publisher/M&A)

**This spec covers only the foundation and the first vertical slice:**

- A data model and architecture that can hold every system and era above without a rewrite.
- A playable implementation of the Garage era (1980–1989) with the full five-phase loop in a reduced form.

### 1.1 Decisions made

| Topic | Decision |
|---|---|
| Goal | Commercial release |
| Launch platform | Steam on Windows and macOS. Linux and Steam Deck come later |
| Dev and test machine | macOS. The editor, GUT tests and local `.app` exports run on the Mac from day one |
| macOS distribution | Release builds are signed and notarized with an Apple Developer account. Local test builds use ad-hoc signing |
| Engine | Godot 4.7.2 stable (pinned; minimum 4.4 because typed `Dictionary[K, V]` needs it; `TileMapLayer` replaces the deprecated `TileMap`) |
| Language | GDScript with static typing everywhere |
| Test framework | GUT, run headless |
| Time model | Real time in weekly ticks, with pause and 1x/2x/4x speed |
| Presentation | 2D office scene with an overlay UI |
| Localization | English and Thai from day one |
| Architecture | Pure-data simulation core, stateless systems, UI as observer (approach A) |

### 1.2 Assumptions (confirmed)

1. Small team. Art comes from CC0 asset packs (Kenney at kenney.nl first; other sources only when the asset is CC0). Rules: CC0 only (no CC-BY, CC-BY-SA or "free for personal use"); every imported asset is listed in `assets/CREDITS.md` with pack name, source URL and license; one pixel scale across the game (chosen in the office-scene milestone); pixel textures import with filtering off. Custom or commissioned art may replace packs later without code changes, because scenes reference assets by path.
2. Content is data-driven: new genres, topics, platforms, events and review templates need no code change.
3. The simulation is separate from the UI and uses seeded RNG, so it is deterministic and unit-testable.
4. Save/load is in this slice.
5. The slice starts in 1980 with one person in a garage, allows up to 4 staff, and ends when the 1980s era ends (about 2–2.5 hours of play). A Garage-era project lasts 16–30 in-game weeks, which is about 5–8 minutes of real time. (Changed during spec review: the earlier 10–20 minutes per project did not fit a 2–3 hour era. See §4.1 for the arithmetic.)
6. Dynamic market taste exists in the 1980s in a light form.
7. Review text explains scores using the game's real stats.

### 1.3 Success criteria for the slice

1. The player can complete all five phases for a game, many times, across the 1980s.
2. Crunch versus delay is a real trade-off: each choice has a visible cost.
3. Review reasons match what the player did (for example, low tech focus produces a performance complaint).
4. No single configuration wins for the whole era (verified by the balance script in §9.3).
5. Save, load and continue gives the same result as an uninterrupted run.

### 1.4 Out of scope for this spec

- Content for eras 2–5
- Grand Strategy (own store, own console, publishing, M&A)
- Stock market, branches, outsourcing
- MMO and online-service mechanics
- Real mod support and Steam Workshop
- Steamworks integration (achievements, cloud saves)
- Final art and audio

The data model in §3 has hooks for these items, but this slice adds no fields or logic for them.

## 2. Architecture overview

```
            +-------------------+
 input ---> |  UI (Godot nodes) | <--- EventBus signals
            +---------+---------+
                      | Command
                      v
            +-------------------+
            |    GameRunner     |  autoload: clock, command queue, tick order
            +---------+---------+
                      | state, rng, week
                      v
            +-------------------+       +----------------+
            | Systems (static)  | ----> |   GameState    |  pure data
            +-------------------+       +----------------+
                      ^
                      | read-only
            +-------------------+
            | Content Resources |  data/*.tres
            +-------------------+
```

Rules:

1. `GameState` holds all mutable runtime data. It does not extend `Node`.
2. Systems hold no state. Each system is a class with static functions that take `GameState`, the RNG, and the current week.
3. Only Commands (player actions) and Systems (simulation) change `GameState`.
4. The UI reads `GameState` through read-only query helpers and sends Commands to `GameRunner`. The UI never changes `GameState` directly.
5. Content is read-only at runtime.

## 3. Data model

### 3.1 Identifiers and references

- Content uses `StringName` ids, for example `&"genre_rpg"`, `&"platform_home_micro_8bit"`.
- Runtime entities (Company, Staff, Project, Contract, ForumPost) use `int` ids. `GameState.next_id` is the only id counter.
- Entities refer to each other only by id. No entity holds an object reference to another entity.

### 3.2 `GameState`

| Field | Type | Notes |
|---|---|---|
| `schema_version` | int | Save format version |
| `week` | int | Weeks since 1980-W1 (week 0) |
| `rng_seed` | int | Seed at game start |
| `rng_state` | int | Current `RandomNumberGenerator.state` |
| `next_id` | int | Runtime id counter |
| `player_company_id` | int | |
| `companies` | Dictionary[int, Company] | Player and AI |
| `staff` | Dictionary[int, Staff] | |
| `projects` | Dictionary[int, Project] | |
| `contracts` | Dictionary[int, Contract] | |
| `market` | Market | |
| `active_events` | Array[ActiveWorldEvent] | |
| `forum_posts` | Array[ForumPost] | Capped history |
| `pending_decisions` | Array[Decision] | Drive auto-pause |

The era is not stored. It is derived from `week` through the era table.

### 3.3 Entities

**Company** — one type for the player, AI competitors and AI publishers.

- `id`, `name`, `kind` (`PLAYER`, `AI_DEVELOPER`, `AI_PUBLISHER`), `money` (int, whole currency units), `reputation` (0–100), `fan_count`
- Hook for later: subsidiaries, ownership and acting as a publisher use the same type. This slice creates the player and 3 AI publishers.

**Staff**

- `id`, `company_id`, `name`
- `skills`: design, tech, art, audio (0–100 each)
- `traits`: Array[StringName] that refer to `TraitDef` content
- `morale` (0–100), `burnout` (0–100), `salary` (per month)
- `assignment`: project id and role (`LEAD_DESIGN`, `LEAD_TECH`, `LEAD_ART`, `MEMBER`), or none

**Project**

- `id`, `company_id`, `title`
- `config`: platform id, engine id, genre id, topic id, art style id, business model id
- `phase` (see §6), `stage_index`, `stage_progress`
- `focus`: per stage, a split between tech and creative (sliders that sum to 100)
- `points`: design, tech, art, audio (accumulated quality)
- `bugs` (int), `hype` (0–100)
- `deadline_week`, `crunch` (bool), `delay_weeks_total`
- `contract_id` (or -1)
- After release: `release_week`, `review_results`, `units_sold`, `revenue`, `user_score`, `sentiment`

**Contract** — generic agreement between two companies.

- `id`, `kind` (this slice: `PUBLISHING`), `party_a`, `party_b`
- `advance`, `revenue_share_pct`, `deadline_week`, `late_penalty_per_week`
- `constraints`: Dictionary (for example `locked_genre`, `locked_platform`, `min_score`)
- Hook for later: store revenue cut, console exclusives and outsourcing reuse this type with new `kind` values.

**Market**

- `segment_size`: Dictionary[StringName, int] (players per audience segment) and `segment_growth_bp`: Dictionary[StringName, int] (yearly growth in basis points)
- `taste_bp`: Dictionary[StringName, int] keyed by genre id and topic id, in basis points 5000–15000 (10000 = neutral)
- `platform_install_base`: Dictionary[StringName, int]
- `focus_drift`: Dictionary keyed by genre id, holding the current offset (−10 to +10 per stage) from the genre's hidden ideal focus weights

**ActiveWorldEvent**: event id, start week, end week. Its modifiers come from content.

**ForumPost**: id, project id, week, topic key, sentiment, `replied` flag.

**Decision**: kind, related ids, deadline week, available option keys.

### 3.4 Content (custom `Resource` types, stored as `data/**/*.tres`)

| Class | Key fields |
|---|---|
| `EraDef` | id, start/end year, allowed business models, office level, max staff |
| `PlatformDef` | id, start/end week, `owner_company_id` (-1 for AI-owned), base install base, growth curve, tech ceiling, handheld flag |
| `EngineDef` | id, era, tech bonus, cost |
| `GenreDef` | id, hidden ideal focus weights per stage, base audience |
| `TopicDef` | id, genre affinities |
| `ArtStyleDef` | id, art point multiplier, tech cost |
| `BusinessModelDef` | id, revenue formula parameters |
| `TraitDef` | id, stat modifiers, conflicting trait ids, synergy trait ids |
| `WorldEventDef` | id, probability window, duration, taste modifiers, segment modifiers |
| `ReviewOutletDef` | id, dimension weights, bias |
| `ReviewTemplateDef` | id, dimension, strength or weakness, threshold, `tr` key, required params |

All player-facing text in content is a `tr()` key, never a literal string.

A future player-owned console is a `PlatformDef`-shaped runtime record whose `owner_company_id` is the player. This slice does not implement it.

### 3.5 Time and RNG

- Time is the integer `week`. Year = `1980 + week / 52`. Godot date types are not used.
- `GameState` stores the RNG seed and state. After load, `GameRunner` restores the state, so the run continues deterministically.
- Systems receive the `RandomNumberGenerator` as a parameter. Code in `src/core` and `src/systems` must not call the global `randi()`, `randf()` or `randomize()`. A test enforces this rule (§9.2).

## 4. Weekly tick and clock

### 4.1 Clock

- `GameRunner` (autoload) adds `delta × speed` to an accumulator in `_process`. At 1x, one week takes `TuningDef.seconds_per_week` (initial value 8.0). Speeds: 0 (pause), 1, 2, 4.
- Session length arithmetic at the initial value:
  - Era ticking at 1x: 520 weeks × 8 s ≈ 69 minutes.
  - Paused and menu time (concept wizard, decisions, reviews, forum) is about equal to ticking time: ≈ 60 minutes.
  - Total ≈ 2–2.5 hours. Players who use 2x/4x finish faster.
  - One 24-week project: 24 × 8 s ≈ 3.2 minutes of ticking plus 2–4 minutes of menus ≈ 5–8 minutes.
- A new `Decision` auto-pauses the game. Decisions in this slice: publisher offer, staff resignation request, deadline approaching (crunch or delay), bankruptcy warning.
- Commands sent while paused apply immediately. Commands sent while running apply at the start of the next tick.

### 4.2 Tick order

Each tick runs these steps in this order:

1. `CalendarSystem`: `week += 1`; emit `era_changed` if the era changes
2. `WorldEventSystem`: start and end events; apply market modifiers
3. `MarketSystem`: taste drift and segment growth
4. `StaffSystem`: morale, burnout, crunch effects, resignation checks
5. `ProductionSystem`: stage progress, quality points, bugs
6. `MarketingSystem`: hype growth and decay
7. `SalesSystem`: weekly units and revenue for released games
8. `LiveOpsSystem`: patch and DLC progress, forum posts, sentiment
9. `FinanceSystem`: salaries and rent (on the first week of each month), contract payments and penalties, bankruptcy check

Systems push events into a queue during the tick. `GameRunner` flushes the queue to `EventBus` after step 9, so the UI always sees the complete state of a tick.

## 5. Commands and EventBus

### 5.1 Command contract

```gdscript
class_name Command
extends RefCounted

func validate(state: GameState) -> CommandResult:
    return CommandResult.ok()

func apply(state: GameState, ctx: TickContext) -> void:
    pass
```

- `GameRunner.submit(cmd)` calls `validate`. On failure it emits `command_rejected(reason_key)`. The reason is a `tr()` key.
- Commands in this slice: `StartProject`, `AssignStaff`, `SetFocus`, `SetCrunch`, `DelayRelease`, `AcceptContract`, `DeclineContract`, `RunMarketing`, `ReleaseGame`, `StartPatch`, `StartDLC`, `ReplyForum`, `HireStaff`, `FireStaff`, `ResolveDecision`.

### 5.2 EventBus signals

`week_ticked`, `era_changed`, `money_changed`, `project_phase_changed`, `decision_required`, `review_published`, `sales_updated`, `staff_hired`, `staff_resigned`, `forum_post_created`, `command_rejected`.

## 6. Project lifecycle

```
CONCEPT -> PRODUCTION -> [POLISH] -> RELEASED -> LIVE -> RETIRED
                  \___ marketing runs during the last production stage ___/
```

### 6.1 CONCEPT (Pre-Production)

- The player picks platform, engine, genre, topic, art style and business model. The current `EraDef` limits the options. In the 1980s only the Premium business model is available.
- A publisher offer can arrive here or the player can request one. Accepting it creates a `Contract`: money advance now, constraints (locked genre or platform, fixed deadline), and a revenue share for the publisher.

### 6.2 PRODUCTION

- Three stages. Each stage has a tech-versus-creative focus slider.
- Each `GenreDef` has hidden ideal weights per stage. Market taste shifts these ideals slightly over time. The player learns them from review text and from post-mortem notes after release.
- Weekly points per staff member = skill × role multiplier × morale factor × chemistry factor.
- **Chemistry:** trait pairs listed as conflicting in `TraitDef` reduce efficiency and raise the bug rate for both people. Synergy pairs do the opposite. A lead with low skill in their role's discipline also raises the bug rate.
- **Crunch:** progress speed ×1.5, bug rate ×1.8, burnout +6 per week, morale −4 per week. When burnout is above 80, the weekly resignation chance starts at 5% and rises.
- **Delay:** pushes `deadline_week` back by N weeks. Each week of delay costs running expenses and −3 hype. Under a contract, each late week also costs `late_penalty_per_week`.

These numbers are the initial tuning values. They live in a `TuningDef` resource, not in code.

### 6.3 POLISH (optional)

Reduces bugs each week and adds no new points. The player can skip it.

### 6.4 Marketing

During the last production stage and polish, the player can run marketing actions:

- **Send review codes to influencers:** cost; hype gain scales with current quality.
- **Show at a trade show:** large cost; large hype gain; one per show date.
- **Open a beta:** reveals one hidden weakness as a forum post and adds some hype.

Hype decays each week when no action runs.

### 6.5 RELEASED and LIVE (Post-Launch)

- On release, `ReviewSystem` creates reviews (§7) and `SalesSystem` starts the sales curve.
- During LIVE: forum posts arrive based on bugs and review weaknesses. Replying to a post changes sentiment. A patch removes bugs and can raise user score. A DLC creates a small linked project that extends the long tail.
- When weekly sales fall below a threshold, the project moves to RETIRED.

## 7. Reviews and sales

### 7.1 Review dimensions

gameplay, tech/performance, graphics, audio, story, innovation, bugs, platform fit, market fit, value.

Each dimension score (0–10) comes from the project's points, its focus match against the genre's ideal, its bugs, the platform's tech ceiling, and market taste.

### 7.2 Outlets and score

Four `ReviewOutletDef` outlets. Each has its own dimension weights and a bias. Outlet score = weighted mean of the dimension scores + bias + a small seeded noise (±0.3). The noise never changes the strongest or weakest dimension.

### 7.3 Review text

1. Pick the strongest and the weakest dimension.
2. Pick the matching `ReviewTemplateDef` by dimension, strength or weakness, and threshold.
3. Fill parameters such as `{platform}` and `{genre}` through `tr()`.

Example result: "Gameplay is excellent, but performance is poor on handheld." This text appears only when the gameplay score is high and the tech score is low on a handheld platform.

### 7.4 Sales curve

- Launch week units = hype factor × review factor × addressable market. Addressable market = platform install base × genre taste × topic taste × segment fit.
- Later weeks decay exponentially, with a long tail. The decay rate improves with review score and positive sentiment.
- Revenue goes through the business model's formula, then through the contract's revenue share.

## 8. UI and localization

### 8.1 Scenes

- `Main.tscn`: root. Holds `OfficeScene`, `HUD` and `PanelLayer`.
- `OfficeScene` (Node2D): `TileMapLayer` room for the current era's office level, staff sprites with animation per state (working, crunching, idle, burned out), and floating bubbles for points and bugs.
- `HUD` (CanvasLayer): date, money, speed buttons, decision badge.
- Panels: Concept wizard, Staff, Project, Marketing, Forum, Review modal, Sales graph.

### 8.2 UI rules

- Panels read state only through `StateQueries` (read-only helper functions).
- Panels send Commands only through `GameRunner.submit`.
- Panels refresh on EventBus signals, not by polling every frame.

### 8.3 Localization

- `locale/strings.csv` with columns `keys,en,th`, imported as Godot translations.
- The theme uses Noto Sans Thai as a fallback font so Thai renders in every control.
- Every string goes through `tr()` with format parameters. No hard-coded player-facing text in scenes or scripts.

## 9. Save/load and testing

### 9.1 Save/load

- `SaveService` writes `user://saves/slot_<n>.json` through `to_dict()` / `from_dict()` on `GameState` and each entity.
- Each save has `schema_version`. On load, a migration chain upgrades older versions step by step.
- On load, the service checks every key and type before it builds the state. An invalid file gives an error message and does not change the current game.
- Autosave at the start of each quarter, in a separate autosave slot.
- Saves happen only at a tick boundary with the command queue empty, so no queued command is lost.

**JSON type rules** (Godot's JSON parser returns every number as `float`, and every dictionary key as `String`):

- `rng_seed` and `rng_state` are 64-bit and lose precision above 2^53. Store them as decimal strings.
- Every `int` field is cast back with `int()` in `from_dict()`.
- `Dictionary[int, …]` keys are converted back to `int`. `StringName` keys and values are converted back with `StringName()`.
- No float fields. Godot 4.7's JSON parser is not correctly rounded (about 12% of doubles in 0.5–1.5 parse back 1 ulp off), so floats cannot round-trip exactly. Every number in `GameState` and its entities is an `int`; ratios and multipliers are basis-point ints with a `_bp` suffix (`Fixed.ONE_BP` = 10000 = 1.0). Saves and the state hash use `JSON.stringify(data, "", true, true)` (sorted keys).
- **State hash** (used by the tests): `JSON.stringify(state.to_dict(), "", true, true).sha256_text()`. Sorted keys make the hash independent of dictionary insertion order, which can differ after a load.
- **Security rule:** never save or load `GameState` with `ResourceSaver` / `ResourceLoader`. A `.tres`/`.res` file can contain embedded scripts, so a shared save or a future mod file would allow code execution. Saves are JSON only.

### 9.2 Tests (GUT, headless)

Command: `godot --headless -s addons/gut/gut_cmdln.gd`

- **Unit tests:** one test file per system and per command.
- **Scenario tests:** a fixed seed plus a scripted list of commands, run for 520 weeks (the full 1980s). Assert:
  1. Two runs with the same seed and script give the same state hash.
  2. Save at week 260, load, continue to week 520: the final hash equals the uninterrupted run.
  3. Money, staff counts and stats stay inside their valid ranges.
- **Rule tests:** scan `src/core` and `src/systems` for global `randi`, `randf` and `randomize` calls and fail if any exist. Scan `src/ui` for direct writes to `GameState`.
- **Save tests:** round trip of each entity; rejection of malformed JSON; migration from each older schema version.

### 9.3 Balance script

`tools/balance_sim.gd` runs several bot strategies (for example "always the same genre and topic", "follow market taste", "always crunch", "never crunch") over many seeds. It reports the win rate of each strategy. Success criterion 4 holds when no fixed strategy wins on more than 60% of seeds.

## 10. Folder layout

```
project.godot
README.md
addons/gut/
src/core/        game_state.gd, entities/, commands/, event_bus.gd, game_runner.gd, save_service.gd, state_queries.gd
src/systems/     one file per system
src/content/     Resource class definitions (EraDef, GenreDef, ...)
src/ui/          office/, hud/, panels/
data/            eras/, platforms/, engines/, genres/, topics/, art_styles/, business_models/, traits/, events/, outlets/, review_templates/, tuning.tres
locale/          strings.csv
tests/           unit/, scenario/
tools/           balance_sim.gd
docs/superpowers/specs/
```

## 11. Follow-up specs (order)

1. Era 2 (1990s) content, office expansion, specialist hiring and in-house engine research
2. Dynamic market and world events at full depth
3. Eras 3–5 content (DVD/online, digital stores and microtransactions, cloud/VR/AI)
4. Grand Strategy: own digital store, own console and exclusives, publishing and M&A
5. Steamworks integration and mod support
