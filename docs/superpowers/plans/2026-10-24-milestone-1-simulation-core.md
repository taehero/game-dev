# Milestone 1: Simulation Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless, deterministic, saveable simulation core for Studio Tycoon, plus a debug HUD that shows the clock running on macOS.

**Architecture:** Pure-data `GameState` (RefCounted entities referenced by id) changed only by Commands and stateless Systems. `GameSession` (RefCounted) owns the clock, command queue and tick loop so it is testable without a scene tree; the `GameRunner` autoload wraps it and forwards events to the `EventBus` autoload. Saves are JSON with explicit type rules and schema validation.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), GUT 9.x.

**Spec:** `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md` (sections 2, 3, 4, 5.1, 5.2, 9, 10). Milestone 1 does not implement gameplay systems (§6–§8 except the debug HUD); their files exist as no-op stubs.

## Global Constraints

- Godot 4.7.2 at `/Users/chanapols/homebrew/bin/godot`. Project path has a leading space: always quote `"/Users/chanapols/Projects/ game-dev"`.
- Static typing on every variable, parameter and return. Typed `Array[T]` and `Dictionary[K, V]`.
- `src/core/` and `src/systems/` use no Node APIs and no global `randi`/`randf`/`randomize`/`randi_range`/`randf_range`. RNG comes from `GameState.rng` via `TickContext.rng`.
- Entities reference each other by id only. Runtime ids are `int` from `GameState.alloc_id()`; content ids are `StringName`.
- Money is `int`.
- Every player-facing string goes through `tr()` with a key in `locale/strings.csv` (`keys,en,th`).
- Tuning numbers live in `data/tuning.tres` (`TuningDef`), never as literals in systems or commands.
- Saves: JSON only. `JSON.stringify(data, "", true, true)` (sorted keys). No `float` anywhere in `GameState` or entities: ratios, multipliers and chances are `int` basis points with a `_bp` suffix (`Fixed.ONE_BP` = 10000 = 1.0); simulation math uses `Fixed.mul_bp()` / `Fixed.roll_bp()` (Ruling 3: Godot 4.7 JSON parsing is not correctly rounded). `rng_seed` and `rng_state` stored as decimal strings. Every int cast back with `int()`. Int dictionary keys converted back with `int()`; StringName keys/values with `StringName()`.
- Enums serialize as their name string (e.g. `"PLAYER"`), not as ints.
- Scripts registered as autoloads (`EventBus`, `GameRunner`) must NOT declare `class_name` (Godot errors when a class_name hides an autoload).
- Until the first public build, `schema_version` stays `1` and fields may be added without a migration.
- Commit after each task, Conventional Commits, with the agent's `Co-Authored-By` line.

## Review Focus

1. **Huge frame delta** (laptop sleep, window drag, debugger pause): the clock must not run hundreds of ticks in one frame. Cap at `TuningDef.max_ticks_per_frame` and drop the remainder. Test in Task 8.
2. **Corrupt or hand-edited save** (truncated JSON, wrong types, missing keys, dangling ids such as `staff.company_id` pointing nowhere): load must refuse with an error key and leave the current game untouched. Tests in Tasks 9.
3. **Save from a newer build** (`schema_version` greater than current): refused with `error.save_newer_version`, not half-loaded. Test in Task 9.
4. **Crash or kill during save:** the previous save file must stay intact (write temp file, then rename). Test in Task 9.
5. **Slot name from outside input** (`"../../x"`): only `slot_1`…`slot_9` and `autosave` are accepted, so no path traversal. Test in Task 9.

---

## File map

```
project.godot                       Task 1, 6, 8, 11 (autoloads, main scene, translations)
README.md                           Task 1
.gutconfig.json                     Task 1
addons/gut/                         Task 1 (vendored)
src/core/save_schema.gd             Task 2   SaveSchema: type checks for dicts from JSON
src/content/tuning_def.gd           Task 2   TuningDef resource class
data/tuning.tres                    Task 2
src/core/entities/company.gd        Task 3
src/core/entities/staff.gd          Task 3
src/core/entities/contract.gd       Task 3
src/core/entities/project.gd        Task 4
src/core/entities/market.gd         Task 4
src/core/entities/active_world_event.gd  Task 4
src/core/entities/forum_post.gd     Task 4
src/core/entities/decision.gd       Task 4
src/core/calendar.gd                Task 5   week math
src/core/game_state.gd              Task 5
src/core/state_hash.gd              Task 5
tests/helpers/fixtures.gd           Task 3 (json_round_trip), Task 5 (state builders)
src/core/commands/command.gd        Task 6
src/core/commands/command_result.gd Task 6
src/core/commands/hire_staff_command.gd  Task 6
src/core/tick_context.gd            Task 6
src/core/event_bus.gd               Task 6   autoload "EventBus"
src/core/simulation.gd              Task 7   tick order
src/systems/*.gd                    Task 7   9 systems (2 real, 7 stubs)
src/core/game_session.gd            Task 8
src/core/game_runner.gd             Task 8   autoload "GameRunner"
src/core/load_result.gd             Task 9
src/core/save_service.gd            Task 9
tests/helpers/scenario.gd           Task 10
tests/scenario/test_determinism.gd  Task 10
tests/unit/test_rules.gd            Task 10
src/core/state_queries.gd           Task 11
src/ui/debug_hud.tscn + .gd         Task 11
src/ui/main.tscn                    Task 11
locale/strings.csv                  Task 11
```

---

### Task 1: Project skeleton and GUT

**Files:**
- Create: `project.godot`, `README.md`, `.gutconfig.json`, `addons/gut/` (vendored), `tests/unit/test_smoke.gd`

**Interfaces:**
- Produces: working command `godot --headless -s addons/gut/gut_cmdln.gd -gexit` that runs `tests/unit` and `tests/scenario`.

- [ ] **Step 1: Create `project.godot`** with `config/name="Studio Tycoon"`, `config/features=PackedStringArray("4.7")`, renderer `gl_compatibility` (2D game, widest Mac/Windows support). No main scene yet.

- [ ] **Step 2: Vendor GUT.** Find the newest GUT 9.x release at https://github.com/bitwes/Gut/releases whose notes support Godot 4.7 (check with `curl -s https://api.github.com/repos/bitwes/Gut/releases`). Copy only its `addons/gut/` folder into the project. Enable it in `project.godot` under `[editor_plugins]`. Record the GUT version in `README.md`.

- [ ] **Step 3: Create `.gutconfig.json`** exactly as in `.claude/skills/gut-testing/SKILL.md`. Create empty `tests/scenario/` with a `.gdkeep` file.

- [ ] **Step 4: Write the smoke test** `tests/unit/test_smoke.gd`:

```gdscript
extends GutTest

func test_engine_version_is_4_7() -> void:
    var v: Dictionary = Engine.get_version_info()
    assert_eq(v["major"], 4)
    assert_eq(v["minor"], 7)
```

- [ ] **Step 5: Run.** `godot --headless --import` then `godot --headless -s addons/gut/gut_cmdln.gd -gexit`. Expected: 1 test, 1 passing, exit code 0.

- [ ] **Step 6: Write `README.md`**: one-paragraph description, pinned Godot 4.7.2 and GUT version, the two commands above, link to spec and `CLAUDE.md`.

- [ ] **Step 7: Commit** `chore: add Godot project skeleton and GUT`.

---

### Task 2: SaveSchema and TuningDef

**Files:**
- Create: `src/core/save_schema.gd`, `src/content/tuning_def.gd`, `data/tuning.tres`
- Test: `tests/unit/test_save_schema.gd`, `tests/unit/test_tuning_def.gd`

**Interfaces:**
- Produces:
  - `class_name SaveSchema` with `static func check(d: Variant, schema: Dictionary) -> bool`. `schema` maps field name → type tag: `"int"`, `"float"`, `"string"`, `"bool"`, `"dict"`, `"array"`. Returns false if `d` is not a Dictionary, a key is missing, or a type does not match. `"int"` accepts a JSON float only when it has no fractional part. `"float"` accepts int or float. `"string"` accepts String or StringName.
  - `class_name TuningDef extends Resource` with `@export` fields and these default values (spec §4.1, §6.2):
    `seconds_per_week: float = 8.0`, `max_ticks_per_frame: int = 4`, `start_money: int = 20000`, `start_year: int = 1980`, `weeks_per_year: int = 52`, `max_staff_default: int = 4`, `hire_skill_min: int = 10`, `hire_skill_max: int = 40`, `crunch_speed_bp: int = 15000`, `crunch_bug_bp: int = 18000`, `crunch_burnout_per_week: int = 6`, `crunch_morale_per_week: int = -4`, `resign_burnout_threshold: int = 80`, `resign_base_chance_bp: int = 500`, `delay_hype_per_week: int = -3`.
  - `static func load_default() -> TuningDef` returns `load("res://data/tuning.tres")`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_save_schema.gd
extends GutTest
const S := {"id": "int", "name": "string", "rate": "float", "on": "bool", "tags": "array", "m": "dict"}

func _ok() -> Dictionary:
    return {"id": 3.0, "name": "a", "rate": 1, "on": true, "tags": [], "m": {}}

func test_accepts_json_shaped_dict() -> void:
    assert_true(SaveSchema.check(_ok(), S))

func test_rejects_missing_key() -> void:
    var d := _ok(); d.erase("name")
    assert_false(SaveSchema.check(d, S))

func test_rejects_fractional_int() -> void:
    var d := _ok(); d["id"] = 3.5
    assert_false(SaveSchema.check(d, S))

func test_rejects_wrong_type() -> void:
    var d := _ok(); d["on"] = "yes"
    assert_false(SaveSchema.check(d, S))

func test_rejects_non_dict() -> void:
    assert_false(SaveSchema.check([1, 2], S))
```

```gdscript
# tests/unit/test_tuning_def.gd
extends GutTest

func test_default_tuning_matches_spec() -> void:
    var t: TuningDef = TuningDef.load_default()
    assert_eq(t.seconds_per_week, 8.0)
    assert_eq(t.max_ticks_per_frame, 4)
    assert_eq(t.crunch_speed_bp, 15000)
    assert_eq(t.crunch_bug_bp, 18000)
    assert_eq(t.crunch_burnout_per_week, 6)
    assert_eq(t.crunch_morale_per_week, -4)
    assert_eq(t.resign_burnout_threshold, 80)
    assert_eq(t.resign_base_chance_bp, 500)
    assert_eq(t.delay_hype_per_week, -3)
```

- [ ] **Step 2: Run, expect FAIL** (unknown classes).
- [ ] **Step 3: Implement `SaveSchema.check` and `TuningDef`; write `data/tuning.tres`** with the default values (see `content-authoring` skill for `.tres` format).
- [ ] **Step 4: Run** `godot --headless --import` then the suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat(core): add SaveSchema and TuningDef`.

---

### Task 3: Entities A — Company, Staff, Contract

**Files:**
- Create: `src/core/entities/company.gd`, `staff.gd`, `contract.gd`, `tests/helpers/fixtures.gd`
- Test: `tests/unit/test_entities_a.gd`

**Interfaces:**
- Consumes: `SaveSchema.check` (Task 2).
- Produces (each class `extends RefCounted`, has `func to_dict() -> Dictionary`, `static func from_dict(d: Dictionary) -> <Class>`, and `const SCHEMA: Dictionary` for `SaveSchema.check`):
  - `Company`: `enum Kind { PLAYER, AI_DEVELOPER, AI_PUBLISHER }`; `id: int`, `name: String`, `kind: Kind`, `money: int`, `reputation: int` (0–100), `fan_count: int`.
  - `Staff`: `enum Role { NONE, LEAD_DESIGN, LEAD_TECH, LEAD_ART, MEMBER }`; `id: int`, `company_id: int`, `name: String`, `skills: Dictionary[StringName, int]` (keys `&"design"`, `&"tech"`, `&"art"`, `&"audio"`), `traits: Array[StringName]`, `morale: int = 70`, `burnout: int = 0`, `salary: int`, `assigned_project_id: int = -1`, `role: Role = Role.NONE`.
  - `Contract`: `enum Kind { PUBLISHING }`; `id: int`, `kind: Kind`, `party_a: int`, `party_b: int`, `advance: int`, `revenue_share_pct: int`, `deadline_week: int`, `late_penalty_per_week: int`, `locked_genre: StringName = &""`, `locked_platform: StringName = &""`, `min_score: int = 0`.
  - `Fixtures` (`tests/helpers/fixtures.gd`, `class_name Fixtures`): `static func json_round_trip(d: Dictionary) -> Dictionary` = `JSON.parse_string(JSON.stringify(d, "", true, true))`.

Ruling recorded here: spec §3.3 lists Contract `constraints` as a Dictionary. The plan uses explicit typed fields (`locked_genre`, `locked_platform`, `min_score`) because JSON loses value types inside a free-form dictionary. New constraint kinds add fields.

- [ ] **Step 1: Write failing tests.** For each of the three classes, build an instance with every field set to a non-default value, then:

```gdscript
func test_staff_survives_json_round_trip() -> void:
    var s := _sample_staff()
    var back: Staff = Staff.from_dict(Fixtures.json_round_trip(s.to_dict()))
    assert_eq(JSON.stringify(back.to_dict(), "", true, true), JSON.stringify(s.to_dict(), "", true, true))
    assert_eq(typeof(back.id), TYPE_INT)
    assert_eq(typeof(back.skills.keys()[0]), TYPE_STRING_NAME)
    assert_eq(back.role, Staff.Role.LEAD_TECH)

func test_staff_schema_accepts_round_tripped_dict() -> void:
    assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_staff().to_dict()), Staff.SCHEMA))

func test_enum_serializes_as_name() -> void:
    assert_eq(_sample_staff().to_dict()["role"], "LEAD_TECH")
```

Same three tests for `Company` (kind `AI_PUBLISHER`) and `Contract` (`locked_genre = &"genre_rpg"`, `min_score = 70`).

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the three classes and `Fixtures.json_round_trip`.** Follow the entity template in the `gdscript-conventions` skill. An unknown enum name in `from_dict` is a schema failure, so add the enum check to `SCHEMA` handling: use type tag `"string"` in `SCHEMA` and let `GameState.validate_dict` (Task 5) check enum names with `Kind.keys().has(...)`.
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add Company, Staff and Contract entities`.

---

### Task 4: Entities B — Project, Market, ActiveWorldEvent, ForumPost, Decision

**Files:**
- Create: `src/core/entities/project.gd`, `market.gd`, `active_world_event.gd`, `forum_post.gd`, `decision.gd`
- Test: `tests/unit/test_entities_b.gd`

**Interfaces:**
- Consumes: `SaveSchema`, `Fixtures.json_round_trip`.
- Produces (same `to_dict` / `from_dict` / `SCHEMA` contract as Task 3):
  - `Project`: `enum Phase { CONCEPT, PRODUCTION, POLISH, RELEASED, LIVE, RETIRED }`; `id: int`, `company_id: int`, `title: String`, `config: Dictionary[StringName, StringName]` (keys `&"platform"`, `&"engine"`, `&"genre"`, `&"topic"`, `&"art_style"`, `&"business_model"`), `phase: Phase = Phase.CONCEPT`, `stage_index: int = 0`, `stage_progress: int = 0` (0–100), `focus: Array[int] = [50, 50, 50]` (tech share per stage), `points: Dictionary[StringName, int]` (design/tech/art/audio), `bugs: int = 0`, `hype: int = 0`, `deadline_week: int`, `crunch: bool = false`, `delay_weeks_total: int = 0`, `contract_id: int = -1`, `release_week: int = -1`, `units_sold: int = 0`, `revenue: int = 0`, `user_score: int = 0`, `sentiment: int = 0`.
  - `Market`: `segment_size: Dictionary[StringName, int]`, `segment_growth_bp: Dictionary[StringName, int]` (basis points per year), `taste_bp: Dictionary[StringName, int]` (5000–15000, 10000 = neutral), `platform_install_base: Dictionary[StringName, int]`, `focus_drift: Dictionary[StringName, Array]` (each value 3 ints, −10..10).
  - `ActiveWorldEvent`: `event_id: StringName`, `start_week: int`, `end_week: int`.
  - `ForumPost`: `id: int`, `project_id: int`, `week: int`, `topic_key: StringName`, `sentiment: int`, `replied: bool = false`.
  - `Decision`: `id: int`, `kind: StringName`, `related_ids: Array[int]`, `deadline_week: int`, `option_keys: Array[StringName]`.

Ruling recorded here: Project `review_results` (spec §3.3) is deferred to the review milestone, where its shape is defined. Allowed by the pre-release schema rule in Global Constraints.

- [ ] **Step 1: Write failing tests:** the same round-trip, schema and enum-name tests as Task 3 for all five classes. Add for `Market`:

```gdscript
func test_market_taste_bp_survives_exactly_as_int() -> void:
    var m := Market.new()
    m.taste_bp[&"genre_rpg"] = 11001
    var back: Market = Market.from_dict(Fixtures.json_round_trip(m.to_dict()))
    assert_eq(typeof(back.taste_bp[&"genre_rpg"]), TYPE_INT)
    assert_eq(back.taste_bp[&"genre_rpg"], 11001)

func test_market_focus_drift_values_are_ints() -> void:
    var m := Market.new()
    m.focus_drift[&"genre_rpg"] = [-3, 0, 7]
    var back: Market = Market.from_dict(Fixtures.json_round_trip(m.to_dict()))
    assert_eq(typeof(back.focus_drift[&"genre_rpg"][2]), TYPE_INT)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the five classes.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add Project, Market and event entities`.

---

### Task 5: Calendar, GameState, StateHash, Fixtures

**Files:**
- Create: `src/core/calendar.gd`, `src/core/game_state.gd`, `src/core/state_hash.gd`
- Modify: `tests/helpers/fixtures.gd`
- Test: `tests/unit/test_calendar.gd`, `tests/unit/test_game_state.gd`

**Interfaces:**
- Consumes: all entities (Tasks 3–4), `TuningDef`, `SaveSchema`.
- Produces:
  - `class_name Calendar`: `static func year(week: int, t: TuningDef) -> int` (= `t.start_year + week / t.weeks_per_year`); `static func week_in_year(week: int, t: TuningDef) -> int`; `static func is_month_start(week: int, t: TuningDef) -> bool` (week_in_year % 13 in {0, 4, 8}: 4-4-5 weeks per quarter, 12 months); `static func is_quarter_start(week: int, t: TuningDef) -> bool` (week_in_year % 13 == 0).
  - `class_name GameState extends RefCounted`: fields from spec §3.2 — `schema_version: int = 1`, `week: int = 0`, `rng: RandomNumberGenerator`, `rng_seed: int`, `next_id: int = 1`, `player_company_id: int`, `companies: Dictionary[int, Company]`, `staff: Dictionary[int, Staff]`, `projects: Dictionary[int, Project]`, `contracts: Dictionary[int, Contract]`, `market: Market`, `active_events: Array[ActiveWorldEvent]`, `forum_posts: Array[ForumPost]`, `pending_decisions: Array[Decision]`.
    - `static func new_game(seed: int, studio_name: String, t: TuningDef) -> GameState`: sets `rng.seed = seed`, creates the player `Company` (kind PLAYER, `money = t.start_money`, reputation 0).
    - `func alloc_id() -> int`: returns `next_id` then increments.
    - `func sorted_ids(d: Dictionary) -> Array[int]`: keys sorted ascending.
    - `func staff_of(company_id: int) -> Array[int]`: sorted staff ids with that company.
    - `func to_dict() -> Dictionary`: entity dicts keyed by `str(id)`; `rng_seed` and `rng_state` as decimal strings (`str(rng.state)`).
    - `static func validate_dict(d: Variant) -> bool`: `SaveSchema.check` for state and every nested entity, enum names valid, and reference integrity: `player_company_id` exists; every `staff.company_id`, `project.company_id` exists; `staff.assigned_project_id` is -1 or exists; `contract.party_a/party_b` exist; `next_id` greater than every id in use.
    - `static func from_dict(d: Dictionary) -> GameState`: assumes `validate_dict` passed; restores `rng.seed` then `rng.state` via `String.to_int()`.
  - `class_name StateHash`: `static func of(state: GameState) -> String` = `JSON.stringify(state.to_dict(), "", true, true).sha256_text()`.
  - `Fixtures` adds: `static func tuning() -> TuningDef` (fresh `TuningDef.new()` with defaults, so tests do not depend on `.tres` edits), `static func new_state(seed: int) -> GameState` (`GameState.new_game(seed, "Test Studio", tuning())`), `static func add_staff(state: GameState, overrides: Dictionary = {}) -> int`, `static func add_project(state: GameState, overrides: Dictionary = {}) -> int`. Overrides set fields by name with `set()`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_calendar.gd
extends GutTest
var t := Fixtures.tuning()

func test_year_from_week() -> void:
    assert_eq(Calendar.year(0, t), 1980)
    assert_eq(Calendar.year(51, t), 1980)
    assert_eq(Calendar.year(52, t), 1981)
    assert_eq(Calendar.year(519, t), 1989)

func test_twelve_month_starts_per_year() -> void:
    var n := 0
    for w in 52:
        if Calendar.is_month_start(w, t): n += 1
    assert_eq(n, 12)

func test_four_quarter_starts_per_year() -> void:
    assert_eq([0, 13, 26, 39].filter(func(w: int) -> bool: return Calendar.is_quarter_start(w, t)).size(), 4)
    assert_false(Calendar.is_quarter_start(14, t))
```

```gdscript
# tests/unit/test_game_state.gd
extends GutTest

func test_new_game_creates_player_company_with_start_money() -> void:
    var s := Fixtures.new_state(1)
    var c: Company = s.companies[s.player_company_id]
    assert_eq(c.kind, Company.Kind.PLAYER)
    assert_eq(c.money, 20000)

func test_alloc_id_is_unique_and_increasing() -> void:
    var s := Fixtures.new_state(1)
    var a := s.alloc_id(); var b := s.alloc_id()
    assert_gt(b, a)

func test_64bit_seed_and_state_survive_round_trip() -> void:
    var s := Fixtures.new_state(9007199254740993)  # 2^53 + 1
    s.rng.randi(); s.rng.randi()
    var d := Fixtures.json_round_trip(s.to_dict())
    assert_typeof(d["rng_state"], TYPE_STRING)
    var back := GameState.from_dict(d)
    assert_eq(back.rng_seed, 9007199254740993)
    assert_eq(back.rng.randi(), s.rng.randi())

func test_full_state_round_trip_preserves_hash() -> void:
    var s := Fixtures.new_state(5)
    Fixtures.add_staff(s); Fixtures.add_project(s)
    s.market.taste_bp[&"genre_rpg"] = 12346
    var back := GameState.from_dict(Fixtures.json_round_trip(s.to_dict()))
    assert_eq(StateHash.of(back), StateHash.of(s))

func test_hash_ignores_dictionary_insertion_order() -> void:
    var a := Fixtures.new_state(5); var b := Fixtures.new_state(5)
    a.market.taste_bp[&"x"] = 10000; a.market.taste_bp[&"y"] = 11000
    b.market.taste_bp[&"y"] = 11000; b.market.taste_bp[&"x"] = 10000
    assert_eq(StateHash.of(a), StateHash.of(b))

func test_validate_rejects_dangling_company_id() -> void:
    var s := Fixtures.new_state(5)
    var sid := Fixtures.add_staff(s)
    var d := Fixtures.json_round_trip(s.to_dict())
    d["staff"][str(sid)]["company_id"] = 999
    assert_false(GameState.validate_dict(d))

func test_validate_rejects_unknown_enum_name() -> void:
    var d := Fixtures.json_round_trip(Fixtures.new_state(5).to_dict())
    d["companies"][str(d["player_company_id"])]["kind"] = "GOD"
    assert_false(GameState.validate_dict(d))

func test_validate_rejects_next_id_not_above_used_ids() -> void:
    var d := Fixtures.json_round_trip(Fixtures.new_state(5).to_dict())
    d["next_id"] = 1
    assert_false(GameState.validate_dict(d))

func test_validate_accepts_valid_state() -> void:
    var s := Fixtures.new_state(5); Fixtures.add_staff(s)
    assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `Calendar`, `GameState`, `StateHash`, extend `Fixtures`.** `new_game` stores `rng_seed` and creates `market = Market.new()`.
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add GameState, Calendar and StateHash`.

---

### Task 6: Command, TickContext, EventBus, HireStaffCommand

**Files:**
- Create: `src/core/commands/command.gd`, `command_result.gd`, `hire_staff_command.gd`, `src/core/tick_context.gd`, `src/core/event_bus.gd`
- Modify: `project.godot` (autoload `EventBus="*res://src/core/event_bus.gd"`)
- Test: `tests/unit/test_tick_context.gd`, `tests/unit/test_event_bus.gd`, `tests/unit/test_hire_staff_command.gd`

**Interfaces:**
- Consumes: `GameState`, `TuningDef`, `Staff`, `Fixtures`.
- Produces:
  - `class_name CommandResult extends RefCounted`: `ok: bool`, `reason_key: StringName`; `static func success() -> CommandResult`; `static func fail(key: StringName) -> CommandResult`. (Named `success` because `ok` is the field.)
  - `class_name TickContext extends RefCounted`: `state: GameState`, `rng: RandomNumberGenerator` (= `state.rng`), `tuning: TuningDef`, `events: Array[Dictionary]`; `func _init(p_state: GameState, p_tuning: TuningDef)`; `func emit(name: StringName, payload: Dictionary = {}) -> void` appends `{"name": name, "payload": payload}`.
  - `class_name Command extends RefCounted`: `func validate(state: GameState, tuning: TuningDef) -> CommandResult` (default success); `func apply(ctx: TickContext) -> void`.
  - `class_name HireStaffCommand extends Command`: `_init(p_company_id: int, p_name: String, p_salary: int)`. Validate: company exists → else `&"error.company_not_found"`; `salary > 0` → else `&"error.invalid_salary"`; `state.staff_of(company_id).size() < tuning.max_staff_default` → else `&"error.staff_limit"`. Apply: new `Staff` with `alloc_id()`, each of the four skills `ctx.rng.randi_range(tuning.hire_skill_min, tuning.hire_skill_max)` drawn in order design, tech, art, audio; emit `&"staff_hired"` with `{"staff_id": id}`.
  - `event_bus.gd` (autoload `EventBus`, `extends Node`, NO `class_name`): one `signal <name>(payload: Dictionary)` for each of `week_ticked`, `era_changed`, `money_changed`, `project_changed`, `project_phase_changed`, `decision_required`, `review_published`, `sales_updated`, `staff_hired`, `staff_resigned`, `forum_post_created`, `command_rejected`; `func dispatch(name: StringName, payload: Dictionary) -> bool` emits the matching signal and returns true, or calls `push_warning` and returns false for an unknown name.

Ruling recorded here: `project_changed` is added to the spec §5.2 signal list for non-phase project edits (crunch, focus), as used in the `gdscript-conventions` skill.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_hire_staff_command.gd
extends GutTest

func test_hire_adds_staff_with_skills_in_range() -> void:
    var s := Fixtures.new_state(3); var t := Fixtures.tuning()
    var cmd := HireStaffCommand.new(s.player_company_id, "Ada", 800)
    assert_true(cmd.validate(s, t).ok)
    var ctx := TickContext.new(s, t)
    cmd.apply(ctx)
    assert_eq(s.staff.size(), 1)
    var st: Staff = s.staff.values()[0]
    for k in [&"design", &"tech", &"art", &"audio"]:
        assert_between(st.skills[k], 10, 40)
    assert_eq(ctx.events[0]["name"], &"staff_hired")

func test_hire_is_deterministic_for_same_seed() -> void:
    var a := Fixtures.new_state(3); var b := Fixtures.new_state(3); var t := Fixtures.tuning()
    HireStaffCommand.new(a.player_company_id, "Ada", 800).apply(TickContext.new(a, t))
    HireStaffCommand.new(b.player_company_id, "Ada", 800).apply(TickContext.new(b, t))
    assert_eq(StateHash.of(a), StateHash.of(b))

func test_hire_rejected_at_staff_limit() -> void:
    var s := Fixtures.new_state(3); var t := Fixtures.tuning()
    for i in 4: Fixtures.add_staff(s)
    assert_eq(HireStaffCommand.new(s.player_company_id, "X", 800).validate(s, t).reason_key, &"error.staff_limit")

func test_hire_rejected_for_unknown_company() -> void:
    var s := Fixtures.new_state(3)
    assert_eq(HireStaffCommand.new(999, "X", 800).validate(s, Fixtures.tuning()).reason_key, &"error.company_not_found")

func test_hire_rejected_for_zero_salary() -> void:
    var s := Fixtures.new_state(3)
    assert_eq(HireStaffCommand.new(s.player_company_id, "X", 0).validate(s, Fixtures.tuning()).reason_key, &"error.invalid_salary")
```

```gdscript
# tests/unit/test_event_bus.gd
extends GutTest

func test_dispatch_emits_matching_signal() -> void:
    watch_signals(EventBus)
    assert_true(EventBus.dispatch(&"week_ticked", {"week": 1}))
    assert_signal_emitted_with_parameters(EventBus, "week_ticked", [{"week": 1}])

func test_dispatch_unknown_name_returns_false() -> void:
    assert_false(EventBus.dispatch(&"no_such_event", {}))
```

`tests/unit/test_tick_context.gd`: `emit` appends name and payload in order; `ctx.rng` is the same object as `state.rng`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement, register the `EventBus` autoload.**
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add commands, TickContext and EventBus`.

---

### Task 7: Simulation tick order and systems

**Files:**
- Create: `src/core/simulation.gd`; `src/systems/calendar_system.gd`, `world_event_system.gd`, `market_system.gd`, `staff_system.gd`, `production_system.gd`, `marketing_system.gd`, `sales_system.gd`, `live_ops_system.gd`, `finance_system.gd`
- Test: `tests/unit/test_simulation.gd`, `tests/unit/test_calendar_system.gd`, `tests/unit/test_finance_system.gd`

**Interfaces:**
- Consumes: `TickContext`, `GameState`, `Calendar`, `TuningDef`.
- Produces:
  - Every system: `class_name <Name>System extends RefCounted` with `static func tick(ctx: TickContext) -> void`. Seven are no-op stubs in this milestone: WorldEvent, Market, Staff, Production, Marketing, Sales, LiveOps. Each stub body is `pass` with a one-line comment naming its spec section.
  - `CalendarSystem.tick`: `state.week += 1`; emit `&"week_ticked"` with `{"week": state.week}`. (`era_changed` is added with the era table in the content milestone.)
  - `FinanceSystem.tick`: if `Calendar.is_month_start(state.week, tuning)`, for each company in sorted id order, subtract the sum of salaries of its staff; emit `&"money_changed"` with `{"company_id": id, "money": money}` for each company whose money changed.
  - `class_name Simulation`: `const SYSTEMS: Array = [CalendarSystem, WorldEventSystem, MarketSystem, StaffSystem, ProductionSystem, MarketingSystem, SalesSystem, LiveOpsSystem, FinanceSystem]` (spec §4.2 order); `static func step(ctx: TickContext) -> void` calls `tick(ctx)` on each in order.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_simulation.gd
extends GutTest

func test_system_order_matches_spec() -> void:
    assert_eq(Simulation.SYSTEMS, [CalendarSystem, WorldEventSystem, MarketSystem, StaffSystem,
        ProductionSystem, MarketingSystem, SalesSystem, LiveOpsSystem, FinanceSystem])

func test_step_advances_week_and_emits_week_ticked_first() -> void:
    var s := Fixtures.new_state(1); var ctx := TickContext.new(s, Fixtures.tuning())
    Simulation.step(ctx)
    assert_eq(s.week, 1)
    assert_eq(ctx.events[0]["name"], &"week_ticked")
```

```gdscript
# tests/unit/test_finance_system.gd
extends GutTest

func test_salaries_paid_on_month_start_only() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    Fixtures.add_staff(s, {"salary": 500}); Fixtures.add_staff(s, {"salary": 300})
    s.week = 4  # month start (week_in_year 4)
    FinanceSystem.tick(TickContext.new(s, t))
    assert_eq(s.companies[s.player_company_id].money, 20000 - 800)
    s.week = 5
    FinanceSystem.tick(TickContext.new(s, t))
    assert_eq(s.companies[s.player_company_id].money, 19200)

func test_no_money_event_when_no_salaries() -> void:
    var s := Fixtures.new_state(1); s.week = 4
    var ctx := TickContext.new(s, Fixtures.tuning())
    FinanceSystem.tick(ctx)
    assert_eq(ctx.events.size(), 0)
```

`tests/unit/test_calendar_system.gd`: one tick from week 0 gives week 1 and one `week_ticked` event with payload `{"week": 1}`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add tick order, calendar and finance systems`.

---

### Task 8: GameSession clock and GameRunner autoload

**Files:**
- Create: `src/core/game_session.gd`, `src/core/game_runner.gd`, `tests/helpers/add_decision_command.gd`
- Modify: `project.godot` (autoload `GameRunner="*res://src/core/game_runner.gd"`, after `EventBus`)
- Test: `tests/unit/test_game_session.gd`

**Interfaces:**
- Consumes: `GameState`, `TuningDef`, `Command`, `CommandResult`, `TickContext`, `Simulation`, `Calendar`.
- Produces:
  - `class_name GameSession extends RefCounted`:
    - `state: GameState`, `tuning: TuningDef`, `speed: int = 0`, `autosave_due: bool = false`.
    - `func _init(p_state: GameState, p_tuning: TuningDef)`.
    - `func set_speed(s: int) -> void`: accepts only 0, 1, 2, 4; anything else is ignored with `push_warning`.
    - `func submit(cmd: Command) -> CommandResult`: validate; on failure queue event `&"command_rejected"` `{"reason_key": key}`. If `speed == 0` apply now with a new `TickContext`; otherwise append to the command queue.
    - `func advance(delta: float) -> int`: adds `delta * speed` to the accumulator; ticks = `floor(acc / tuning.seconds_per_week)`; if ticks > `tuning.max_ticks_per_frame`, run only the cap and reset the accumulator to 0; otherwise subtract the consumed time. Runs `step_once()` per tick and stops early if a step paused the game. Returns ticks run.
    - `func step_once() -> void`: one `TickContext`; apply queued commands in submit order (re-validate each; a now-invalid one emits `command_rejected`); `Simulation.step(ctx)`; if `pending_decisions.size()` grew during this step, `speed = 0` and emit `&"decision_required"` `{"decision_id": <newest id>}`; if `Calendar.is_quarter_start(state.week, tuning)` set `autosave_due = true`.
    - `func drain_events() -> Array[Dictionary]`: returns and clears all events produced since the last drain, in order.
    - `func can_save() -> bool`: true when the command queue is empty.
  - `game_runner.gd` (autoload `GameRunner`, `extends Node`, NO `class_name`): `var session: GameSession`; `func start_new_game(seed: int, studio_name: String) -> void`; `func submit(cmd: Command) -> CommandResult` (delegates); `func set_speed(s: int) -> void`; `_process(delta)`: return if `session` is null (GUT runs with autoloads loaded); otherwise `session.advance(delta)`, then dispatch every drained event through `EventBus.dispatch`. Autosave wiring is added in Task 9.
  - `AddDecisionCommand` (tests only, `class_name AddDecisionCommand extends Command`): apply appends a `Decision` with `alloc_id()`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_game_session.gd
extends GutTest

func _session() -> GameSession:
    return GameSession.new(Fixtures.new_state(1), Fixtures.tuning())

func test_paused_does_not_tick() -> void:
    var g := _session()
    assert_eq(g.advance(100.0), 0)
    assert_eq(g.state.week, 0)

func test_one_week_per_8_seconds_at_1x() -> void:
    var g := _session(); g.set_speed(1)
    assert_eq(g.advance(7.9), 0)
    assert_eq(g.advance(0.2), 1)
    assert_eq(g.state.week, 1)

func test_4x_runs_four_times_faster() -> void:
    var g := _session(); g.set_speed(4)
    assert_eq(g.advance(2.0), 1)

func test_huge_delta_is_capped_and_remainder_dropped() -> void:
    var g := _session(); g.set_speed(4)
    assert_eq(g.advance(3600.0), 4)
    assert_eq(g.advance(0.0), 0)

func test_invalid_speed_ignored() -> void:
    var g := _session(); g.set_speed(3)
    assert_eq(g.speed, 0)

func test_command_applies_immediately_when_paused() -> void:
    var g := _session()
    g.submit(HireStaffCommand.new(g.state.player_company_id, "Ada", 800))
    assert_eq(g.state.staff.size(), 1)

func test_command_waits_for_next_tick_when_running() -> void:
    var g := _session(); g.set_speed(1)
    g.submit(HireStaffCommand.new(g.state.player_company_id, "Ada", 800))
    assert_eq(g.state.staff.size(), 0)
    assert_false(g.can_save())
    g.advance(8.0)
    assert_eq(g.state.staff.size(), 1)
    assert_true(g.can_save())

func test_rejected_command_emits_event() -> void:
    var g := _session()
    var r := g.submit(HireStaffCommand.new(999, "X", 800))
    assert_false(r.ok)
    assert_eq(g.drain_events()[0]["name"], &"command_rejected")

func test_new_decision_auto_pauses() -> void:
    var g := _session(); g.set_speed(1)
    g.submit(AddDecisionCommand.new())
    g.advance(16.0)
    assert_eq(g.speed, 0)
    assert_eq(g.state.week, 1)
    var names := g.drain_events().map(func(e: Dictionary) -> StringName: return e["name"])
    assert_has(names, &"decision_required")

func test_autosave_due_on_quarter_start() -> void:
    var g := _session(); g.state.week = 12; g.set_speed(1)
    g.advance(8.0)
    assert_true(g.autosave_due)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `GameSession`, `GameRunner`, `AddDecisionCommand`; register the autoload.**
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add GameSession clock and GameRunner autoload`.

---

### Task 9: SaveService

**Files:**
- Create: `src/core/load_result.gd`, `src/core/save_service.gd`
- Modify: `src/core/game_runner.gd` (autosave + `save_game` / `load_game`)
- Test: `tests/unit/test_save_service.gd`

**Interfaces:**
- Consumes: `GameState.to_dict/from_dict/validate_dict`, `GameSession.can_save/autosave_due`.
- Produces:
  - `class_name LoadResult extends RefCounted`: `ok: bool`, `state: GameState`, `error_key: StringName`.
  - `class_name SaveService extends RefCounted`:
    - `const SCHEMA_VERSION: int = 1`; `const DEFAULT_DIR: String = "user://saves"`.
    - `static var migrations: Dictionary[int, Callable] = {}` — key `n` migrates a version-`n` state dict to `n + 1`.
    - `static func serialize(state: GameState) -> String`: `JSON.stringify({"schema_version": SCHEMA_VERSION, "state": state.to_dict()}, "", true, true)`.
    - `static func deserialize(text: String) -> LoadResult`: parse failure or non-dict → `&"error.save_unreadable"`; version greater than `SCHEMA_VERSION` → `&"error.save_newer_version"`; apply migrations from the file version up; `GameState.validate_dict` false → `&"error.save_invalid"`; otherwise ok with `GameState.from_dict`.
    - `static func is_valid_slot(slot: String) -> bool`: matches `^(slot_[1-9]|autosave)$`.
    - `static func save_to_slot(state: GameState, slot: String, dir: String = DEFAULT_DIR) -> Error`: invalid slot → `ERR_INVALID_PARAMETER`; creates `dir` if missing; writes `<slot>.json.tmp`, closes it, then renames over `<slot>.json`.
    - `static func load_from_slot(slot: String, dir: String = DEFAULT_DIR) -> LoadResult`: invalid slot or missing file → `&"error.save_unreadable"`.
  - `GameRunner` additions: `func save_game(slot: String) -> Error` (returns `ERR_BUSY` if `not session.can_save()`); `func load_game(slot: String) -> LoadResult` (replaces `session` only when `ok`; on success sets speed 0); in `_process`, if `session.autosave_due and session.can_save()`, save to `autosave` and clear the flag.

- [ ] **Step 1: Write failing tests** (use a temp dir per test: `var dir := "user://test_saves_%d" % Time.get_ticks_usec()`; remove it in `after_each`)

```gdscript
func test_serialize_deserialize_round_trip_keeps_hash() -> void:
    var s := Fixtures.new_state(11); Fixtures.add_staff(s)
    var r := SaveService.deserialize(SaveService.serialize(s))
    assert_true(r.ok)
    assert_eq(StateHash.of(r.state), StateHash.of(s))

func test_truncated_json_is_unreadable() -> void:
    var text := SaveService.serialize(Fixtures.new_state(11))
    assert_eq(SaveService.deserialize(text.substr(0, text.length() / 2)).error_key, &"error.save_unreadable")

func test_newer_version_refused() -> void:
    var d: Dictionary = JSON.parse_string(SaveService.serialize(Fixtures.new_state(11)))
    d["schema_version"] = SaveService.SCHEMA_VERSION + 1
    assert_eq(SaveService.deserialize(JSON.stringify(d)).error_key, &"error.save_newer_version")

func test_wrong_type_is_invalid() -> void:
    var d: Dictionary = JSON.parse_string(SaveService.serialize(Fixtures.new_state(11)))
    d["state"]["week"] = "ten"
    assert_eq(SaveService.deserialize(JSON.stringify(d)).error_key, &"error.save_invalid")

func test_migration_runs_for_older_version() -> void:
    var d: Dictionary = JSON.parse_string(SaveService.serialize(Fixtures.new_state(11)))
    d["schema_version"] = 0
    SaveService.migrations[0] = func(st: Dictionary) -> Dictionary: st["week"] = 7; return st
    var r := SaveService.deserialize(JSON.stringify(d))
    SaveService.migrations.erase(0)
    assert_true(r.ok)
    assert_eq(r.state.week, 7)

func test_slot_names_reject_path_traversal() -> void:
    assert_false(SaveService.is_valid_slot("../../x"))
    assert_false(SaveService.is_valid_slot("slot_10"))
    assert_true(SaveService.is_valid_slot("slot_3"))
    assert_true(SaveService.is_valid_slot("autosave"))
    assert_eq(SaveService.save_to_slot(Fixtures.new_state(1), "../x", dir), ERR_INVALID_PARAMETER)

func test_save_and_load_slot() -> void:
    var s := Fixtures.new_state(11)
    assert_eq(SaveService.save_to_slot(s, "slot_1", dir), OK)
    assert_false(FileAccess.file_exists(dir + "/slot_1.json.tmp"))
    assert_eq(StateHash.of(SaveService.load_from_slot("slot_1", dir).state), StateHash.of(s))

func test_failed_write_keeps_previous_save() -> void:
    var s := Fixtures.new_state(11)
    SaveService.save_to_slot(s, "slot_1", dir)
    # simulate a crash mid-write: a stale tmp file exists, the real file must still load
    var f := FileAccess.open(dir + "/slot_1.json.tmp", FileAccess.WRITE); f.store_string("{\"trunc"); f.close()
    assert_true(SaveService.load_from_slot("slot_1", dir).ok)

func test_missing_slot_is_unreadable() -> void:
    assert_eq(SaveService.load_from_slot("slot_9", dir).error_key, &"error.save_unreadable")
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `LoadResult`, `SaveService`, and the `GameRunner` additions.** The service never uses `ResourceSaver`/`ResourceLoader`.
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add JSON SaveService with validation and migrations`.

---

### Task 10: Scenario determinism tests and rule tests

**Files:**
- Create: `tests/helpers/scenario.gd`, `tests/scenario/test_determinism.gd`, `tests/unit/test_rules.gd`

**Interfaces:**
- Consumes: `GameSession`, `HireStaffCommand`, `SaveService`, `StateHash`, `Fixtures`.
- Produces:
  - `class_name Scenario`: `const SCRIPT_BASIC: Dictionary = {0: [["hire", "Ada", 800]], 10: [["hire", "Bo", 700]], 30: [["hire", "Cy", 900]], 200: [["hire", "Di", 600]]}` (week → list of command specs). `static func advance(state: GameState, script: Dictionary, weeks: int) -> void`: drives a paused `GameSession` for `weeks` ticks: before each tick, submit the commands listed under the current `state.week` (applied immediately while paused), then `step_once()`. `static func run(state: GameState, script: Dictionary, weeks: int) -> String`: `advance` then `StateHash.of(state)`.

- [ ] **Step 1: Write the scenario tests**

```gdscript
# tests/scenario/test_determinism.gd
extends GutTest

func test_same_seed_same_hash_over_520_weeks() -> void:
    assert_eq(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
              Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520))

func test_different_seed_different_hash() -> void:
    assert_ne(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
              Scenario.run(Fixtures.new_state(8), Scenario.SCRIPT_BASIC, 520))

func test_save_at_260_load_continue_matches_uninterrupted() -> void:
    var full := Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
    var s := Fixtures.new_state(7)
    Scenario.advance(s, Scenario.SCRIPT_BASIC, 260)
    var loaded := SaveService.deserialize(SaveService.serialize(s))
    assert_true(loaded.ok)
    Scenario.advance(loaded.state, Scenario.SCRIPT_BASIC, 260)
    assert_eq(StateHash.of(loaded.state), full)

func test_values_stay_in_range() -> void:
    var s := Fixtures.new_state(7)
    Scenario.advance(s, Scenario.SCRIPT_BASIC, 520)
    assert_eq(s.week, 520)
    assert_eq(s.staff.size(), 4)
    for id in s.sorted_ids(s.staff):
        var st: Staff = s.staff[id]
        assert_between(st.morale, 0, 100)
        assert_between(st.burnout, 0, 100)
```

- [ ] **Step 2: Write `tests/unit/test_rules.gd`.** It reads every `.gd` file under the given folders with `DirAccess`/`FileAccess` and fails with the file path and line number on:
  - in `res://src/core/` and `res://src/systems/`: regex `(?<![\w.])(randi|randf|randomize|randi_range|randf_range)\s*\(` (global RNG; `rng.randi()` is allowed);
  - in `res://src/core/save_service.gd`: `ResourceSaver` or `ResourceLoader`;
  - in `res://src/core/entities/` and `res://src/core/game_state.gd`: the word `float` (no floats in state, Ruling 3);
  - in `res://src/systems/`: `pow(`, `exp(`, `log(`, `sin(`, `cos(`;
  - in `res://src/ui/`: regex `\bstate\.[\w.\[\]"&]+\s*[-+*/]?=[^=]` (direct state writes).
  Add one test that runs each regex against a known-bad string, so a broken regex cannot pass silently.

- [ ] **Step 3: Run suite. Expected: all pass.** If a determinism test fails, stop and report `BLOCKED` with both hashes; do not weaken the assertion.
- [ ] **Step 4: Commit** `test: add determinism scenarios and architecture rule tests`.

---

### Task 11: Debug HUD on macOS with EN/TH strings

**Files:**
- Create: `src/core/state_queries.gd`, `src/ui/debug_hud.tscn`, `src/ui/debug_hud.gd`, `src/ui/main.tscn`, `locale/strings.csv`
- Modify: `project.godot` (`run/main_scene="res://src/ui/main.tscn"`, `internationalization/locale/translations` with the imported `strings.en.translation` and `strings.th.translation`)
- Test: `tests/unit/test_localization.gd`, `tests/unit/test_debug_hud.gd`

**Interfaces:**
- Consumes: `GameRunner` autoload, `EventBus` signals, `Calendar`, `HireStaffCommand`.
- Produces:
  - `class_name StateQueries`: `static func date_text(state: GameState, t: TuningDef) -> String` → `tr("ui.hud.date").format({"year": Calendar.year(...), "week": Calendar.week_in_year(...) + 1})`; `static func player_money(state: GameState) -> int`; `static func staff_count(state: GameState, company_id: int) -> int`.
  - `debug_hud.gd` (`extends Control`): labels for date, money, staff count; buttons Pause / 1x / 2x / 4x / Hire (debug hire with a fixed name list) / Save / Load (`slot_1`). Refreshes on `EventBus.week_ticked`, `money_changed`, `staff_hired`, `command_rejected` (shows the rejected reason via `tr`). Buttons call `GameRunner.set_speed` / `GameRunner.submit` / `GameRunner.save_game` / `GameRunner.load_game` only.
  - `main.tscn`: root `Control` with the HUD; its script calls `GameRunner.start_new_game(int(Time.get_unix_time_from_system()), tr("ui.default_studio_name"))` in `_ready`.
  - `locale/strings.csv` keys (EN / TH):
    - `ui.hud.date` — `Year {year}, Week {week}` / `ปี {year} สัปดาห์ที่ {week}`
    - `ui.hud.money` — `Money: {money}` / `เงิน: {money}`
    - `ui.hud.staff` — `Staff: {count}` / `พนักงาน: {count}`
    - `ui.hud.pause` — `Pause` / `หยุด`
    - `ui.hud.hire` — `Hire` / `จ้างคน`
    - `ui.hud.save` — `Save` / `บันทึก`
    - `ui.hud.load` — `Load` / `โหลด`
    - `ui.default_studio_name` — `Garage Games` / `Garage Games`
    - `error.company_not_found` — `Company not found.` / `ไม่พบบริษัท`
    - `error.invalid_salary` — `Salary must be above zero.` / `เงินเดือนต้องมากกว่าศูนย์`
    - `error.staff_limit` — `Your studio is full.` / `สตูดิโอเต็มแล้ว`
    - `error.save_unreadable` — `The save file cannot be read.` / `อ่านไฟล์เซฟไม่ได้`
    - `error.save_newer_version` — `This save is from a newer version of the game.` / `เซฟนี้มาจากเกมเวอร์ชันใหม่กว่า`
    - `error.save_invalid` — `The save file is damaged.` / `ไฟล์เซฟเสียหาย`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_localization.gd
extends GutTest

func after_each() -> void:
    TranslationServer.set_locale("en")

func test_thai_translation_loads() -> void:
    TranslationServer.set_locale("th")
    assert_eq(tr("ui.hud.hire"), "จ้างคน")

func test_every_error_key_has_en_and_th() -> void:
    for key in ["error.company_not_found", "error.invalid_salary", "error.staff_limit",
            "error.save_unreadable", "error.save_newer_version", "error.save_invalid"]:
        TranslationServer.set_locale("en"); assert_ne(tr(key), key)
        TranslationServer.set_locale("th"); assert_ne(tr(key), key)
```

```gdscript
# tests/unit/test_debug_hud.gd
extends GutTest

func test_speed_button_sets_game_speed() -> void:
    GameRunner.start_new_game(1, "T")
    var hud: Control = add_child_autofree(load("res://src/ui/debug_hud.tscn").instantiate())
    hud.get_node("%Speed1x").pressed.emit()
    assert_eq(GameRunner.session.speed, 1)
    hud.get_node("%Pause").pressed.emit()
    assert_eq(GameRunner.session.speed, 0)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Use unique names (`%Speed1x`, `%Pause`, …) for buttons. No literal display strings in scripts or scenes; button text is set from `tr()` keys.
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Manual check on macOS.** Run `godot --path "/Users/chanapols/Projects/ game-dev"`. Expected: window opens, date advances at about one week per 8 s at 1x, Hire adds staff, salaries drop money on month starts, Save then Load restores the same date. Report what you saw. Thai glyph rendering is checked in the UI milestone, which adds Noto Sans Thai to the theme.
- [ ] **Step 6: Commit** `feat(ui): add debug HUD with EN/TH strings`.
