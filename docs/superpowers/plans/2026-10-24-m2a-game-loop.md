# Milestone 2a: Game Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** All M2 data shapes (spec §4) plus a headless, deterministic 1980s game loop: content data, research, platforms, game and engine projects, production with nine sliders, reviews with reasons, and sales.

**Architecture:** Tasks 1–9 add every M2 data shape and shared surface first (content classes, entities, validator, removal, EventBus signals, the 15-step tick list, rules helpers), so M2b, M2c and the M2d scene can build on them in parallel. Tasks 10–12 author content. Tasks 13–18 add the loop as stateless systems and commands. Task 19 is the acceptance scenario. Content is read through `ContentDB.active()` (Ruling A1), so no M1 signature changes.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), GUT 9.x.

**Spec:** `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` (§3, §4, §5, §6, §9, §10, §12, §13, §14). `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md` still applies (§3.4 content, §6 lifecycle, §7 reviews). Where the two disagree, the M2 spec wins.

## Global Constraints

- Godot 4.7.2 at `/Users/chanapols/homebrew/bin/godot`. The project path has a leading space: always quote `"/Users/chanapols/Projects/ game-dev"`.
- `CLAUDE.md` hard rules 1–10 apply to every task. In short: pure-data `RefCounted` state, stateless systems, no global RNG, references by id, `tr()` for all text, JSON-only saves, tuning in `TuningDef`, no floats in state, sorted iteration.
- Numbers follow M2 spec §3. Everything is `int`. Ratios use `_bp` (10000 = 1.0). Review scores use `score_x10` (10–100). Hype, morale, quality and `tech_cap` are 0–100. Money is whole units. Use one `Fixed.mul_bp` step per tick, and no `pow`/`exp`. Curves are int tables with integer linear interpolation. Noise is `ctx.rng.randi_range(a, b)`.
- **Content is ints too.** Content `.tres` files hold no floats. The `content-authoring` skill example (`base_audience = 0.8`, 3-value `ideal_focus`) is stale. Follow this plan's field lists.
- Content dictionaries iterate through `GameState.sorted_names()`. Directory listings are sorted before loading.
- Runtime ids come from `GameState.alloc_id()`. Content ids are prefixed `StringName`s (`platform_`, `genre_`, `topic_`, `size_`, `feature_`, `research_`, `lic_engine_`, `outlet_`, `review_tpl_`, `office_`, `equipment_`, `level_`). They are unique across all content types.
- Enums serialize as their name string. Every new entity has `to_dict()`, `static from_dict()` and `const SCHEMA`.
- `schema_version` stays 1 (M2 spec §12). New fields need no migration. The validator is extended in the same task that adds each field.
- Only `src/core/removal.gd` may `.erase(` from `state.staff/equipment/contracts/loans/projects` (Task 7 rule test).
- `ContentDB.active()` is process-wide. A test that reaches a command, a system or `GameRunner` without calling `Fixtures.new_state()` must call `ContentDB.use(Fixtures.content())` in `before_each`. A test that installs real content restores fixture content in `after_all`. Otherwise results depend on file order and `-gselect`.
- Const and content containers are read-only or shared. Call `.duplicate()` on any const `Array`/`Dictionary` (`Project.DEFAULT_FOCUS`, `GameRules.ENGINE_FOCUS`) and any container read from a content def (`ideal_sliders`, licensed `features`) before storing it in state.
- Code tasks never edit `locale/strings.csv`. Every M2a `tr()` key is authored in content Tasks 10–12. Code tests compare reason keys, not translated text.
- Commit after each task with Conventional Commits and the agent's `Co-Authored-By` line. Stage files by explicit path.
- Run tests with `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd -gexit`. Judge the run by its exit code and quote the totals line.

## Rulings made by this plan

| # | Ruling | Why |
|---|---|---|
| A1 | `ContentDB` has a static active instance: `ContentDB.active()` (loaded lazily from `res://data`) and `ContentDB.use(db)`. Commands read `ContentDB.active()` in `validate`. `TickContext` gains `content: ContentDB = ContentDB.active()`, and systems and `apply` use `ctx.content`. `Fixtures.new_state()` installs `Fixtures.content()`, a small in-memory DB, so code tests never depend on `data/`. | Keeps M1 `validate(state, tuning)` and `TickContext.new(state, tuning)` unchanged for every parallel plan. Content is immutable, so a shared instance cannot break determinism. |
| A2 | `GameState.new_game` creates, in this id order: the player company, the owner `Staff` (`is_owner`, seat 0, all skills `owner_start_skill`, salary 0, name key `ui.default_owner_name`), one BOUGHT starter `Equipment` at seat 0, `OwnerProfile`, one BANK, one LENDER, two VENDORs and three AI_PUBLISHERs. AI company `name` holds a `tr()` key; the UI shows `tr(company.name)` (a player-typed name passes through `tr` unchanged). The office is `tuning.start_office_id`. | Spec §4.2 and §7.1. Seat math is final in M2a, so M2b cannot break the scenario. |
| A3 | Seats are derived. A seat is taken when a staff of that company has that `seat_index`. Seat count comes from `OfficeDef.seats`. A **worker** is a staff member who is seated, has equipment at the same seat index, and is assigned to the project. Only workers produce. | Spec §4.3 and §7.3. No extra state. |
| A4 | `Staff.week_points: Dictionary[StringName, int]` (new field) holds the points the staff member produced in the most recent Production step. Research (step 7) and M2b's Staff and Owner (steps 5–6) read it next tick, one tick before Production overwrites it. | §5 runs Staff, Owner and Research before Production, but each needs "the week's work". |
| A5 | `Staff.hired_week: int` (new field) is set by hiring. | M2b needs the hire anniversary (§7.2). This plan touches `HireStaffCommand` anyway. |
| A6 | `Contract.target_points` is `Dictionary[StringName, int]` (per point type), not `int`. | §7.6 says "target points per type". §4.6's `int` cannot express that. |
| A7 | For `ENGINE_LICENSE`, `Contract.deliverable` holds the `LicensedEngineDef` id. | §4.6 has no other field for it. |
| A8 | `Simulation.SYSTEMS` gets all 15 §5 steps now. Owner, Contracts, Awards and Hiring are no-op stubs that M2b and M2c fill. | M2b and M2c run in parallel; leaving the array to each plan guarantees a merge conflict. This deviates from the last line of §5. Flag it for a spec sync. |
| A9 | Task 8 adds every §10 signal to `EventBus`. | Unknown names return false in `dispatch`, and the M2d scene runs in parallel. |
| A10 | `StartProjectCommand` uses two static constructors, `game(...)` and `engine(...)`. `engine_ref` is split into `engine_id: int` and `licensed_engine_id: StringName` (the latter is used when `engine_id == -1`). `StartProject` assigns **every** free worker of the company to the new project. | §6.1 gives one untyped `engine_ref`. There is no AssignStaff in M2. |
| A11 | An item (topic, genre, size, feature, channel) is unlocked when no `ResearchDef.unlocks` lists it, or when the company has done one research that lists it. A platform with `dev_kit_cost == 0` counts as owned. One built-in licensed engine, `lic_engine_homebrew` (fee 0), is available without a contract. Any other licensed engine needs an `ENGINE_LICENSE` contract (M2b). | A new 1980 game must be playable before any M2b command exists. |
| A12 | Slider match is computed per stage as `max(0, 10000 − Σ|focus − ideal|)` over that stage's 3 values. Gameplay uses the average of the 3 stage matches. | §6.3 says "per stage". Summing all nine in one go would floor almost every real setting at 0. |
| A13 | `Project.stage_progress` becomes bp (0–10000), not 0–100. Weekly progress uses ceiling division, so a 6-week stage ends in exactly 6 weeks. | Precision. 10000 / 6 truncated would need 7 weeks. |
| A14 | Lifecycle: `StartProject` sets PRODUCTION. After the last stage, a GAME goes to POLISH (fixes bugs, adds no points). `ReleaseProject` is valid only in POLISH and sets RELEASED. The first sales tick sets LIVE, and sales below the floor set RETIRED. An ENGINE project goes from its last stage straight to RETIRED and creates the `GameEngine`. | Foundation §6. Engines are never released. |
| A15 | `ProjectSizeDef` gains `price: int` and `par_points: int`. `PlatformDef` gains `genre_fit_bp`. | §6.6 needs a price. Reviews need a par to score points against. The platform-fit dimension needs data. |
| A16 | `StateValidator` checks runtime int references only. Content-id references are checked at load time by `ContentDB.missing_refs(state)`. `GameRunner.load_game` refuses with `error.save_content_missing`. | `validate_dict` stays content-free. A save from an older content set must not crash a system. |
| A17 | When a platform is past its end week, its sales decay is `max(0, 2 × decay_bp − 10000)`, which doubles the weekly loss. | This is how §6.7's "twice as fast" works with `mul_bp` steps. |

---

## Review Focus

1. **Exported build:** Godot's export renames `x.tres` to `x.tres.remap`, so a `DirAccess` scan finds no `.tres` files. `ContentDB` must still load every def. Test in Task 2 (`test_content_paths_maps_remap_names`).
2. **A save whose content ids no longer exist** (content renamed in an update, or a hand-edited save): load must refuse with `error.save_content_missing` and leave the current game untouched, not crash on a missing def. Test in Task 8.
3. **All workers leave mid-project** (unseated, equipment gone, or assigned elsewhere): production must stall at zero progress, with no division by zero and no events. Test in Task 16.
4. **The platform retires while a game is in development:** release still works, and sales decay doubles. A new `StartProject` on that platform is refused. Tests in Tasks 15, 17 and 18.
5. **Releasing a game with almost no points or many bugs:** scores clamp to 10–100 with no division by zero, and a review still gets strength and weakness keys (generic fallback). Test in Task 17.

---

## File map

```
src/content/*_def.gd (15 new)          Task 1   content Resource classes
src/content/tuning_def.gd, data/tuning.tres   Task 1   all M2a tuning fields
src/core/content_db.gd                  Task 2, 8 (missing_refs)
tests/helpers/fixtures.gd               Task 2 (content), 4, 5, 6
src/core/entities/{owner_profile,equipment,game_engine,loan,candidate,review_result}.gd   Task 3
src/core/entities/{company,staff,contract}.gd   Task 4
src/core/entities/project.gd            Task 5
src/core/state_validator.gd             Task 4, 5, 6
src/core/game_state.gd                  Task 6
src/core/removal.gd                     Task 7
src/core/{event_bus,tick_context,simulation,game_session,game_runner}.gd   Task 8
src/systems/{platform,owner,research,contracts,awards,hiring}_system.gd   Task 8 (stubs); 13, 14 fill platform, research
src/core/game_rules.gd                  Task 9
src/core/commands/hire_staff_command.gd Task 9
data/{platforms,sizes,offices,equipment,levels}/, lic_engine_homebrew   Task 10 (content)
data/{genres,topics,engine_features,research}/, other licensed engines   Task 11 (content)
data/{outlets,review_templates}/        Task 12 (content)
locale/strings.csv                      Tasks 10–12 only
tests/unit/test_content_data.gd         Task 2 (generic), 10–12 (pinned values)
src/core/commands/{buy_research,buy_dev_kit}_command.gd   Task 14
src/core/commands/{start_project,set_sliders}_command.gd  Task 15
src/systems/production_system.gd        Task 16
src/systems/review_system.gd, src/core/commands/release_project_command.gd, src/core/state_queries.gd   Task 17
src/systems/sales_system.gd             Task 18
tests/helpers/{scenario,place_equipment_command}.gd, tests/scenario/test_m2a_playthrough.gd   Task 19
```

## Parallel groups

Tasks in the same group touch disjoint files and may run at the same time. A group starts when the groups it depends on are done.

| Group | Tasks | Depends on | Notes |
|---|---|---|---|
| P1 | 1, 3 | — | `src/content/`, tuning and the content-authoring skill vs new entity files |
| P2 | 2, 4 | 1 (for 2), 3 (for 4) | 2: `content_db.gd`, `fixtures.gd`, content tests. 4: three entities, validator, `test_entities_a`, `test_state_validator_m2` |
| P3 | 5 | 2, 4 | edits `fixtures.gd` and the validator, so it waits for both |
| P4 | 6 | 2, 5 | |
| P5 | 7, 8 | 6 | removal + rules test vs runtime plumbing |
| P6 | 9 | 8 | |
| C (content chain) | 10 → 11 → 12 | 2 | Sequential among themselves (`strings.csv`). Runs alongside P3–P7 because no code task touches `data/` or `strings.csv` |
| P7 | 13, 14, 15, 16, 17, 18 | 9 | Six disjoint system/command tasks; all use fixture content |
| P8 | 19, 20 | P7, C | Acceptance scenario on real content; spec sync (docs only) |

---

### Task 1: TuningDef M2a fields and content Resource classes

**Files:**
- Create: `src/content/platform_def.gd`, `genre_def.gd`, `topic_def.gd`, `review_outlet_def.gd`, `review_template_def.gd`, `office_def.gd`, `equipment_def.gd`, `engine_feature_def.gd`, `licensed_engine_def.gd`, `research_def.gd`, `project_size_def.gd`, `level_def.gd`, `perk_def.gd`, `marketing_channel_def.gd`, `award_def.gd`
- Modify: `src/content/tuning_def.gd`, `data/tuning.tres`, `tests/unit/test_tuning_def.gd`, `.claude/skills/content-authoring/SKILL.md`
- Test: `tests/unit/test_content_defs.gd`

**Interfaces:**
- Produces: each class is `class_name <Name> extends Resource` with `@export` fields of the listed types and no floats. Every class has `@export var id: StringName`. Every class except `LevelDef` and `ReviewTemplateDef` has `@export var name_key: StringName`.
  - `PlatformDef`: `kind: StringName` (`&"micro"`, `&"console"`, `&"arcade"`, `&"handheld"`), `launch_week: int`, `end_week: int` (absolute weeks since 1980-W1), `owner_company_id: int = -1`, `install_curve: Array[int]` (install base per quarter since launch), `tech_ceiling: int` (0–100), `handheld: bool`, `dev_kit_cost: int`, `rumor_weeks: int`, `genre_fit_bp: Dictionary[StringName, int]` (missing genre = 10000).
  - `GenreDef`: `ideal_sliders: Array[int]` (9 bp values, each stage's 3 sum to 10000).
  - `TopicDef`: `genre_fit_bp: Dictionary[StringName, int]` (5000–15000; missing genre = 10000).
  - `ReviewOutletDef`: `const DIMENSIONS: Array[StringName] = [&"gameplay", &"tech", &"graphics", &"audio", &"story", &"innovation", &"bugs", &"platform_fit", &"market_fit", &"value"]`; `weights_bp: Dictionary[StringName, int]`; `bias_x10: int` (−5..5).
  - `ReviewTemplateDef`: `dimension: StringName` (one of `DIMENSIONS` or `&"generic"`), `is_strength: bool`, `threshold_x10: int`, `text_key: StringName`.
  - `OfficeDef`: `seats: int`, `rent_per_month: int`, `electricity_base: int`, `moving_cost: int`, `scene_path: String`, `desk_positions: Array[Vector2i]`.
  - `EquipmentDef`: `tier: int`, `price: int`, `lease_per_month: int`, `power_per_month: int`, `speed_bp: int`, `bug_bp: int`, `recommended_until_year: int`.
  - `EngineFeatureDef`: `research_id: StringName` (`&""` = free), `tech_cap_add: int`, `dev_weeks: int`.
  - `LicensedEngineDef`: `year_from: int`, `year_to: int`, `fee: int`, `royalty_bp: int`, `tech_cap: int`, `features: Array[StringName]`.
  - `ResearchDef`: `cost_rp: int`, `prerequisites: Array[StringName]`, `unlocks: Array[StringName]`.
  - `ProjectSizeDef`: `base_weeks: int`, `min_staff: int`, `cost_multiplier_bp: int`, `audience_bp: int`, `price: int`, `par_points: int` (Ruling A15).
  - `LevelDef`: `level: int` (a `Staff.Level` value), `min_best_skill: int`, `min_total_exp: int`, `salary_bp: int`, `output_bp: int`.
  - `PerkDef`: `path: StringName` (`&"dev"` / `&"business"`), `max_rank: int`, `effects_bp_per_rank: Dictionary[StringName, int]`.
  - `MarketingChannelDef`: `year_from: int`, `year_to: int`, `cost: int`, `hype_gain: int`, `segment: StringName`.
  - `AwardDef`: `week_in_year: int`, `entry_fee: int`, `prize: int`, `fans: int`.
- `TuningDef` adds these fields with these initial values. Write the same values to `data/tuning.tres`:

| Field | Value | Used by |
|---|---|---|
| `start_office_id: StringName` | `&"office_garage"` | new game |
| `start_equipment_def: StringName` | `&"equipment_micro_1980"` | new game |
| `start_equipment_value: int` | `800` | new game |
| `owner_start_skill: int` | `30` | new game (§7.1) |
| `points_per_skill: int` | `10` | production |
| `morale_factor_min_bp: int` | `6000` | production (morale 0) |
| `morale_factor_max_bp: int` | `12000` | production (morale 100) |
| `bugs_per_staff_week_bp: int` | `20000` | production (2.0 bugs) |
| `engine_age_bug_bp_per_year: int` | `500` | production |
| `polish_bugs_fixed_per_staff_week: int` | `3` | production |
| `engine_base_tech_cap: int` | `30` | engine projects |
| `engine_min_staff: int` | `1` | engine projects |
| `research_per_point_bp: int` | `1000` | research (`RESEARCH_PER_POINT_BP`) |
| `review_par_score_x10: int` | `60` | reviews |
| `review_innovation_base_x10: int` | `40` | reviews |
| `review_innovation_per_feature_x10: int` | `8` | reviews |
| `review_innovation_new_combo_x10: int` | `20` | reviews |
| `review_bug_density_divisor: int` | `5` | reviews |
| `review_noise_x10: int` | `3` | reviews (§6.6 `randi_range(-3, 3)`) |
| `combo_great_x10: int` | `80` | concept wizard label |
| `combo_good_x10: int` | `65` | |
| `combo_okay_x10: int` | `50` | |
| `sales_hype_table_bp: Array[int]` | `[10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 20000]` | index `hype / 10` |
| `sales_review_table_bp: Array[int]` | `[1000, 1000, 2000, 3500, 5500, 8000, 10000, 13000, 17000, 22000, 28000]` | index `score_x10 / 10` |
| `sales_decay_table_bp: Array[int]` | `[5000, 5000, 6000, 7000, 7600, 8200, 8600, 8900, 9100, 9300, 9400]` | index `score_x10 / 10` |
| `sales_floor_units: int` | `10` | `SALES_FLOOR_UNITS` |

  `max_staff_default` stays until Task 9, which removes it together with its last users (§7.2: replaced by seats).

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_content_defs.gd
extends GutTest

func test_every_def_class_has_id_and_no_float_exports() -> void:
    for cls: GDScript in [PlatformDef, GenreDef, TopicDef, ReviewOutletDef, ReviewTemplateDef, OfficeDef,
            EquipmentDef, EngineFeatureDef, LicensedEngineDef, ResearchDef, ProjectSizeDef, LevelDef,
            PerkDef, MarketingChannelDef, AwardDef]:
        var r: Resource = cls.new()
        var names: Array = r.get_property_list().map(func(p: Dictionary) -> String: return p["name"])
        assert_has(names, "id", cls.resource_path)
        for p: Dictionary in r.get_property_list():
            if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
                assert_ne(p["type"], TYPE_FLOAT, "%s.%s is float" % [cls.resource_path, p["name"]])

func test_dimensions_are_the_ten_foundation_dimensions() -> void:
    assert_eq(ReviewOutletDef.DIMENSIONS.size(), 10)
    assert_eq(ReviewOutletDef.DIMENSIONS[0], &"gameplay")
```

In `test_tuning_def.gd`, extend `test_default_tuning_matches_spec` to assert `points_per_skill == 10`, `research_per_point_bp == 1000`, `review_noise_x10 == 3`, `sales_floor_units == 10`, `sales_decay_table_bp.size() == 11`, `sales_review_table_bp.size() == 11` and `sales_hype_table_bp.size() == 11` on `TuningDef.load_default()`.

- [ ] **Step 2: Run, expect FAIL** (unknown classes).
- [ ] **Step 3: Implement the 15 classes and the TuningDef fields; update `data/tuning.tres`.** In `.tres`, typed arrays are written `Array[int]([...])`.
- [ ] **Step 4: Update `.claude/skills/content-authoring/SKILL.md`.** The content author follows this skill exactly, so it must match the M2 classes:
  - Add the new folder rows: `data/offices/` `OfficeDef`, `data/equipment/` `EquipmentDef`, `data/engine_features/` `EngineFeatureDef`, `data/licensed_engines/` `LicensedEngineDef`, `data/research/` `ResearchDef`, `data/sizes/` `ProjectSizeDef`, `data/levels/` `LevelDef`, `data/perks/` `PerkDef`, `data/channels/` `MarketingChannelDef`, `data/awards/` `AwardDef`.
  - Replace the example with an int-only `GenreDef` that has `ideal_sliders = Array[int]([5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000])`.
  - Add one line: "No floats in content. Ratios are `_bp` ints, scores are `_x10` ints."
  - Show the typed-container syntax: `Dictionary[StringName, int]({&"genre_action": 15000})`, `Array[StringName]([&"feature_scrolling"])`, `Array[Vector2i]([Vector2i(2, 2)])`.
  - Change the checklist's validation test to `tests/unit/test_content_data.gd`.
- [ ] **Step 5: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 6: Commit** `feat(content): add M2 content resource classes and tuning fields`.

---

### Task 2: ContentDB and fixture content

**Files:**
- Create: `src/core/content_db.gd`, `tests/unit/test_content_db.gd`, `tests/unit/test_content_data.gd`
- Modify: `tests/helpers/fixtures.gd` (add `content()`; `new_state` installs it)

**Interfaces:**
- Consumes: Task 1 classes.
- Produces `class_name ContentDB extends RefCounted`:
  - `const DEFAULT_ROOT: String = "res://data"`.
  - Typed indexes, all `Dictionary[StringName, <Def>]`: `platforms`, `genres`, `topics`, `outlets`, `review_templates`, `offices`, `equipment`, `engine_features`, `licensed_engines`, `research`, `sizes`, `levels`, `perks`, `channels`, `awards`. `var errors: Array[String] = []`.
  - `static func content_paths(root: String) -> Array[String]`: recursive and sorted. It returns `.tres` paths, and maps `x.tres.remap` to `x.tres` with no duplicates.
  - `static func load_dir(root: String = DEFAULT_ROOT) -> ContentDB`: loads each path with `load()`. A `TuningDef` is skipped. A Resource of an unknown class appends `"unknown content type: <path>"` to `errors`.
  - `func add(def: Resource) -> bool`: indexes by class. A second def with an id already used by **any** class appends `"duplicate id: <id>"` to `errors`, calls `push_error`, keeps the first def, and returns false.
  - `func level_def(level: int) -> LevelDef`: returns the def with that `level` or `null`.
  - `func locking_research(item_id: StringName) -> Array[StringName]`: sorted research ids whose `unlocks` contain `item_id`.
  - `func is_unlocked(done: Array[StringName], item_id: StringName) -> bool` (Ruling A11).
  - `func validate() -> Array[String]`: cross-reference errors. Every research prerequisite and unlock id exists. Every feature `research_id` is empty or exists, and that research's `unlocks` lists the feature. Every licensed engine feature exists. Every genre's `ideal_sliders` has size 9 and each stage sums to 10000. Every topic and platform `genre_fit_bp` key is a genre, with a value in 5000–15000. Every outlet weight key is in `ReviewOutletDef.DIMENSIONS`, with at least one weight > 0. Every template dimension is in `DIMENSIONS` or `&"generic"`. Every size has `base_weeks >= 3` and `min_staff >= 1`.
  - `static func active() -> ContentDB` (lazy `load_dir()` when unset) and `static func use(db: ContentDB) -> void` (Ruling A1).
- `Fixtures` adds `static func content() -> ContentDB`. It builds this DB once with `add()`, caches it in a static var and returns it. `Fixtures.new_state()` calls `ContentDB.use(content())` before `GameState.new_game`. Add `static func use_real_content() -> void` (cached `load_dir()`, then `ContentDB.use`). **Tests in Tasks 9–18 assert against these exact fixture values:**

| Def | Values |
|---|---|
| `office_garage` | seats 2, rent 0, electricity_base 20, moving_cost 0, desk_positions `[(2,2),(5,2)]` |
| `office_small` | seats 5, rent 400, electricity_base 40, moving_cost 1500 |
| `equipment_micro_1980` | tier 1, price 1500, lease 60, power 10, speed_bp 10000, bug_bp 10000, recommended_until_year 1985 |
| `equipment_fx_fast` | tier 2, price 3000, speed_bp 15000, bug_bp 5000, recommended_until_year 1990 |
| `level_junior` / `level_mid` / `level_senior` / `level_lead` | level 0/1/2/3; min_best_skill 0/40/60/75; min_total_exp 0/2000/6000/12000; salary_bp 10000/13000/17000/22000; output_bp 10000/11500/13000/14500 |
| `size_small` | base_weeks 18, min_staff 1, cost_multiplier_bp 10000, audience_bp 100, price 12, par_points 9000 |
| `size_medium` | base_weeks 30, min_staff 2, cost_multiplier_bp 18000, audience_bp 180, price 20, par_points 24000 |
| `platform_fx_micro` | micro, launch_week −52, end_week 400, dev_kit_cost 0, rumor_weeks 0, tech_ceiling 40, install_curve `[40000, 52000, 64000, 70000]`, genre_fit_bp `{genre_fx_action: 12000}` |
| `platform_fx_console` | console, launch_week 20, end_week 60, dev_kit_cost 3000, rumor_weeks 8, tech_ceiling 60, install_curve `[0, 13000, 26000]` |
| `genre_fx_action` | ideal_sliders `[5000,3000,2000, 3000,3000,4000, 4000,3000,3000]` |
| `genre_fx_adventure` | ideal_sliders `[2000,4000,4000, 5000,3000,2000, 4000,3000,3000]` |
| `topic_fx_space` | genre_fit_bp `{genre_fx_action: 15000, genre_fx_adventure: 8000}` |
| `topic_fx_ghost` | genre_fit_bp `{genre_fx_adventure: 14000}` |
| `feature_fx_save` | research_id `&""`, tech_cap_add 5, dev_weeks 2 |
| `feature_fx_scroll` | research_id `research_fx_scroll`, tech_cap_add 10, dev_weeks 4 |
| `research_fx_scroll` | cost_rp 50, prerequisites [], unlocks [feature_fx_scroll] |
| `research_fx_adventure` | cost_rp 80, prerequisites [research_fx_scroll], unlocks [genre_fx_adventure, topic_fx_ghost] |
| `research_fx_medium` | cost_rp 100, unlocks [size_medium] |
| `lic_engine_homebrew` | year_from 1975, year_to 1999, fee 0, royalty_bp 0, tech_cap 40, features [feature_fx_save] |
| `lic_engine_fx_pro` | year_from 1980, year_to 1989, fee 5000, royalty_bp 1000, tech_cap 60, features [feature_fx_save, feature_fx_scroll] |
| `outlet_fx_a` | weights all 10 dimensions 1000, bias 0 |
| `outlet_fx_b` | weights `{gameplay 3000, tech 1000, graphics 1000, bugs 1000}`, bias 2 |
| `outlet_fx_c` | weights `{graphics 3000, audio 2000, story 1000}`, bias −2 |
| `outlet_fx_d` | weights `{innovation 2000, market_fit 2000, value 2000}`, bias 0 |
| templates | for each of the 10 dimensions: `review_tpl_fx_<dim>_strong` (is_strength, threshold 70, text_key `review.strong.<dim>`) and `review_tpl_fx_<dim>_weak` (not strength, threshold 40, text_key `review.weak.<dim>`); plus `review_tpl_fx_generic_strong` (generic, strength, threshold 0, `review.strong.generic`) and `review_tpl_fx_generic_weak` (generic, weakness, threshold 100, `review.weak.generic`) |

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_content_db.gd
extends GutTest

func test_content_paths_maps_remap_names() -> void:
    var dir := "user://content_test_%d" % Time.get_ticks_usec()
    DirAccess.make_dir_recursive_absolute(dir + "/b")
    for f: String in ["/b/z.tres.remap", "/a.tres", "/note.txt"]:
        FileAccess.open(dir + f, FileAccess.WRITE).close()
    assert_eq(ContentDB.content_paths(dir), [dir + "/a.tres", dir + "/b/z.tres"] as Array[String])

func test_duplicate_id_is_an_error_and_first_wins() -> void:
    var db := ContentDB.new()
    var a := GenreDef.new(); a.id = &"genre_x"; a.ideal_sliders = [10000,0,0,10000,0,0,10000,0,0]
    var b := TopicDef.new(); b.id = &"genre_x"
    assert_true(db.add(a))
    assert_false(db.add(b))
    assert_eq(db.errors.size(), 1)
    assert_true(db.genres.has(&"genre_x"))
    assert_false(db.topics.has(&"genre_x"))

func test_fixture_content_is_valid() -> void:
    assert_eq(Fixtures.content().validate(), [] as Array[String])
    assert_eq(Fixtures.content().errors, [] as Array[String])

func test_validate_catches_bad_sliders_and_dangling_unlock() -> void:
    var db := ContentDB.new()
    var g := GenreDef.new(); g.id = &"genre_bad"; g.ideal_sliders = [5000, 5000, 1, 10000, 0, 0, 10000, 0, 0]
    var r := ResearchDef.new(); r.id = &"research_bad"; r.unlocks = [&"topic_missing"]
    db.add(g); db.add(r)
    assert_eq(db.validate().size(), 2)

func test_unlocked_rules() -> void:
    var db := Fixtures.content()
    assert_true(db.is_unlocked([], &"genre_fx_action"))       # no research lists it
    assert_false(db.is_unlocked([], &"genre_fx_adventure"))
    assert_true(db.is_unlocked([&"research_fx_adventure"], &"genre_fx_adventure"))

func test_new_state_installs_fixture_content() -> void:
    Fixtures.new_state(1)
    assert_same(ContentDB.active(), Fixtures.content())
```

```gdscript
# tests/unit/test_content_data.gd  (real data; content tasks append pinned-value tests)
extends GutTest

func test_real_content_loads_without_errors() -> void:
    var db := ContentDB.load_dir()
    assert_eq(db.errors, [] as Array[String])
    assert_eq(db.validate(), [] as Array[String])
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `ContentDB` and the Fixtures additions.** Build each fixture def in its own small static builder in `fixtures.gd`. No `.tres` files.
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.** `data/` holds only `tuning.tres` at this point, so the real-content test passes trivially.
- [ ] **Step 5: Commit** `feat(core): add ContentDB with fixture content`.

---

### Task 3: New M2 entities

**Files:**
- Create: `src/core/entities/owner_profile.gd`, `equipment.gd`, `game_engine.gd`, `loan.gd`, `candidate.gd`, `review_result.gd`
- Test: `tests/unit/test_entities_m2.gd`

**Interfaces:**
- Consumes: `SaveSchema`, `Fixtures.json_round_trip`, `GameState.sorted_names`.
- Produces the same `to_dict` / `from_dict` / `SCHEMA` contract as M1 entities (spec §4.4, §4.5):
  - `OwnerProfile`: `staff_id: int = -1`, `xp: int = 0`, `skill_points: int = 0`, `perks: Dictionary[StringName, int] = {}`, `focus_dev_bp: int = 10000`.
  - `Equipment`: `enum Ownership { BOUGHT, LEASED }`; `id: int`, `company_id: int`, `def_id: StringName`, `ownership: Ownership = BOUGHT`, `seat_index: int = -1`, `bought_week: int = 0`, `value: int = 0`.
  - `GameEngine`: `enum Source { BUILT, OUTSOURCED }`; `id: int`, `company_id: int`, `name: String`, `features: Array[StringName]`, `tech_cap: int`, `source: Source = BUILT`, `built_week: int`.
  - `Loan`: `id`, `company_id`, `lender_id`, `principal`, `balance`, `rate_bp_per_month`, `payment_per_month`, `missed_payments: int = 0`, `taken_week` (all `int`).
  - `Candidate`: `id: int`, `name: String`, `skills: Dictionary[StringName, int]`, `traits: Array[StringName]`, `asking_salary: int`, `expires_week: int`, `level: int = 0` (a `Staff.Level` value, §7.2a "candidates come with a level"; stored as int here so this task does not depend on Task 4, and serialized as an int).
  - `ReviewResult`: `outlet_id: StringName`, `score_x10: int`, `strength_key: StringName`, `weakness_key: StringName`.
  - StringName-keyed dictionaries are rebuilt in `GameState.sorted_names` order in `from_dict`.

- [ ] **Step 1: Write failing tests.** For each of the six classes, write the three M1 tests: round trip with every field non-default (compare sorted JSON and check `typeof` on one int and one StringName), `SCHEMA` accepts the round-tripped dict, and enum-as-name where the class has an enum (`Equipment.ownership == "LEASED"`, `GameEngine.source == "OUTSOURCED"`). Add:

```gdscript
func test_owner_perks_keep_int_ranks() -> void:
    var o := OwnerProfile.new(); o.perks = {&"perk_coder": 2}
    var back := OwnerProfile.from_dict(Fixtures.json_round_trip(o.to_dict()))
    assert_eq(typeof(back.perks[&"perk_coder"]), TYPE_INT)
    assert_eq(back.perks[&"perk_coder"], 2)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the six classes.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add M2 entities owner, equipment, engine, loan, candidate, review`.

---

### Task 4: Company, Staff and Contract additions

**Files:**
- Modify: `src/core/entities/company.gd`, `staff.gd`, `contract.gd`, `src/core/state_validator.gd`, `tests/unit/test_entities_a.gd` (this task does not touch `fixtures.gd`; class defaults cover `add_staff`)
- Test: `tests/unit/test_entities_a.gd`, `tests/unit/test_state_validator_m2.gd`

**Interfaces:**
- Produces (spec §4.2, §4.3, §4.6, §7.2a, Rulings A4–A7):
  - `Company.Kind` = `{ PLAYER, AI_DEVELOPER, AI_PUBLISHER, BANK, LENDER, VENDOR }` (append only). New fields: `office_id: StringName = &""`, `research_points: int = 0`, `unlocked: Array[StringName] = []`, `dev_kits: Array[StringName] = []`, `months_negative: int = 0`, `awards: Array[StringName] = []`.
  - `Staff.Level` = `{ JUNIOR, MID, SENIOR, LEAD, MANAGER, EXECUTIVE }`. New fields: `exp: Dictionary[StringName, int] = {}`, `seat_index: int = -1`, `last_raise_week: int = 0`, `asking_raise: int = 0`, `is_owner: bool = false`, `level: Level = Level.JUNIOR`, `title: StringName = &""`, `hired_week: int = 0`, `week_points: Dictionary[StringName, int] = {}`.
  - `Contract.Kind` = `{ PUBLISHING, OUTSOURCE, CONTRACT_WORK, ENGINE_LICENSE }`. New fields: `price: int = 0`, `royalty_bp: int = 0`, `target_points: Dictionary[StringName, int] = {}`, `quality_roll: int = 0`, `delivery_week: int = -1`, `project_id: int = -1`, `deliverable: StringName = &""`.
  - `StateValidator` per-entity checks:
    - Company: new enum names; `unlocked`, `dev_kits` and `awards` are arrays of strings; `research_points` and `months_negative` are whole numbers ≥ 0.
    - Staff: `level` is a valid enum name; `exp` and `week_points` keys are a subset of `SKILL_KEYS` with whole values ≥ 0; `seat_index >= -1`.
    - Contract: `target_points` keys are a subset of `SKILL_KEYS` with whole values; `quality_roll` is in 0–100; `project_id` is -1 or a known project id (projects are validated before contracts).

- [ ] **Step 1: Write failing tests.** Extend `_sample_staff`, `_sample_company` and `_sample_contract` in `test_entities_a.gd` with non-default values for every new field (`level = SENIOR`, `kind = LENDER`, `kind = ENGINE_LICENSE`, `target_points = {&"art": 300}`). The existing round-trip tests then cover them. Add:

```gdscript
# tests/unit/test_state_validator_m2.gd
extends GutTest

func _dict_with_staff() -> Array:
    var s := Fixtures.new_state(5)
    var sid := Fixtures.add_staff(s)
    return [Fixtures.json_round_trip(s.to_dict()), str(sid)]

func test_rejects_unknown_staff_level() -> void:
    var x := _dict_with_staff(); x[0]["staff"][x[1]]["level"] = "CEO"
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_exp_key_outside_skills() -> void:
    var x := _dict_with_staff(); x[0]["staff"][x[1]]["exp"]["luck"] = 5
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_fractional_week_points() -> void:
    var x := _dict_with_staff(); x[0]["staff"][x[1]]["week_points"]["art"] = 1.5
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_contract_with_dangling_project() -> void:
    var s := Fixtures.new_state(5)
    var c := Contract.new(); c.id = s.alloc_id(); c.party_a = s.player_company_id; c.party_b = s.player_company_id
    c.project_id = 999
    s.contracts[c.id] = c
    assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))

func test_rejects_quality_roll_above_100() -> void:
    var s := Fixtures.new_state(5)
    var c := Contract.new(); c.id = s.alloc_id(); c.party_a = s.player_company_id; c.party_b = s.player_company_id
    c.quality_roll = 101
    s.contracts[c.id] = c
    assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement the fields, serialization and validator checks.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add M2 fields to company, staff and contract`.

---

### Task 5: Project changes

**Files:**
- Modify: `src/core/entities/project.gd`, `src/core/state_validator.gd`, `tests/helpers/fixtures.gd` (`add_project`), `tests/unit/test_entities_b.gd`, `tests/unit/test_game_state.gd`
- Test: `tests/unit/test_entities_b.gd`, `tests/unit/test_state_validator_m2.gd`

**Interfaces:**
- Consumes: `ReviewResult` (Task 3).
- Produces (spec §4.5, Ruling A13):
  - `Project.Kind` = `{ GAME, ENGINE, CONTRACT_WORK }`; `const WEEKLY_UNITS_CAP: int = 104`; `const DEFAULT_FOCUS: Array[int] = [3334, 3333, 3333, 3334, 3333, 3333, 3334, 3333, 3333]`.
  - New fields: `kind: Kind = GAME`, `size_id: StringName = &""`, `engine_id: int = -1`, `features: Array[StringName] = []`, `review_results: Array[ReviewResult] = []`, `weekly_units: Array[int] = []`, `promo_until_week: int = -1`, `promo_discount_bp: int = 0`, `mod_tools: bool = false`, `dlc_count: int = 0`.
  - `focus` default becomes `DEFAULT_FOCUS` (9 bp values: stage 1 Code/Design/Story, stage 2 Levels/Characters/AI, stage 3 Graphics/Audio/Balance).
  - `stage_progress` is bp, 0–10000.
  - Validator `_project_ok`:
    - `kind` is a valid enum name.
    - `focus` has 9 whole values, each 0–10000, and each consecutive triple sums to 10000.
    - `stage_progress` is 0–10000.
    - `features` is an array of strings.
    - Each `review_results` entry passes `ReviewResult.SCHEMA`, with `score_x10` 10–100.
    - `weekly_units` holds whole values ≥ 0, with size ≤ `WEEKLY_UNITS_CAP`.
    - `promo_discount_bp` is 0–10000.
    - `engine_id` is -1 or ≥ 1. The reference check against `engines` comes in Task 6.
  - `Fixtures.add_staff` / `add_project` overrides: when the field's current value is an `Array` or `Dictionary`, call `.assign(value)` on the existing typed container instead of `set()`, so tests can pass untyped literals such as `{"points": {&"art": 1}}`.
  - `Fixtures.add_project` defaults: `kind = GAME`, `size_id = &"size_small"`, `config = {&"platform": &"platform_fx_micro", &"genre": &"genre_fx_action", &"topic": &"topic_fx_space", &"engine": &"lic_engine_homebrew"}` (inserted in sorted order), `phase = PRODUCTION`.

- [ ] **Step 1: Write failing tests.**
  - In `test_entities_b.gd`, change `_sample_project` to set `focus = [2000, 3000, 5000, 3000, 3000, 4000, 5000, 2500, 2500]`, `kind = ENGINE`, `features = [&"feature_fx_save"]`, one `ReviewResult`, `weekly_units = [5, 3]` and `mod_tools = true`. Update the focus assertion to match.
  - In `test_game_state.gd`, change `test_validate_rejects_wrong_focus_length` to `[1, 2, 3]`, which is the old valid length and must now be rejected.
  - Add to `test_state_validator_m2.gd`:

```gdscript
func _project_dict() -> Array:
    var s := Fixtures.new_state(5)
    var pid := Fixtures.add_project(s)
    return [Fixtures.json_round_trip(s.to_dict()), str(pid)]

func test_accepts_default_project() -> void:
    assert_true(GameState.validate_dict(_project_dict()[0]))

func test_rejects_stage_not_summing_to_10000() -> void:
    var x := _project_dict(); x[0]["projects"][x[1]]["focus"][0] = 3333
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_weekly_units_over_cap() -> void:
    var x := _project_dict()
    var a: Array = []; a.resize(105); a.fill(1)
    x[0]["projects"][x[1]]["weekly_units"] = a
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_review_score_out_of_range() -> void:
    var x := _project_dict()
    x[0]["projects"][x[1]]["review_results"] = [{"outlet_id": "o", "score_x10": 101, "strength_key": "a", "weakness_key": "b"}]
    assert_false(GameState.validate_dict(x[0]))

func test_rejects_unknown_project_kind() -> void:
    var x := _project_dict(); x[0]["projects"][x[1]]["kind"] = "MOVIE"
    assert_false(GameState.validate_dict(x[0]))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add M2 project fields and nine-slider focus`.

---

### Task 6: GameState additions, reference checks and the M2 new game

**Files:**
- Modify: `src/core/game_state.gd`, `src/core/state_validator.gd`, `tests/helpers/fixtures.gd`, `tests/helpers/scenario.gd`, `tests/unit/test_game_state.gd`, `tests/unit/test_hire_staff_command.gd`, `tests/unit/test_game_session.gd`, `tests/scenario/test_determinism.gd`
- Test: `tests/unit/test_game_state.gd`, `tests/unit/test_state_validator_m2.gd`

**Interfaces:**
- Consumes: Tasks 3–5, TuningDef new-game fields.
- Produces (spec §4.1, Ruling A2):
  - `GameState` fields: `owner: OwnerProfile = OwnerProfile.new()`, `equipment: Dictionary[int, Equipment] = {}`, `engines: Dictionary[int, GameEngine] = {}`, `loans: Dictionary[int, Loan] = {}`, `candidates: Array[Candidate] = []`, `game_over: bool = false`. These go into `to_dict` / `from_dict` (int-keyed dicts are loaded in `_sorted_keys` order) and into `STATE_SCHEMA`.
  - `GameState.new_game(p_seed, studio_name, t)` keeps its signature and creates objects in the order of Ruling A2. Ids: player company 1, owner staff 2, starter equipment 3 (`def_id = t.start_equipment_def`, BOUGHT, seat 0, `value = t.start_equipment_value`), then bank 4, lender 5, vendors 6–7 and publishers 8–10. `OwnerProfile` has no id; `owner.staff_id` is 2. Company name keys are `company.bank.name`, `company.lender.name`, `company.vendor_1.name`, `company.vendor_2.name`, `company.publisher_1.name`, `company.publisher_2.name` and `company.publisher_3.name`. The player company gets `office_id = t.start_office_id`, and every AI company gets `&""`. `new_game` draws no RNG.
  - `func owner_staff_id() -> int` returns `owner.staff_id`.
  - Validator reference checks:
    - `owner` passes `OwnerProfile.SCHEMA`. `owner.staff_id` exists, that staff has `is_owner == true` and belongs to `player_company_id`, and exactly one staff in the state has `is_owner`.
    - Equipment, engines and loans: SCHEMA, enum names, keys by `str(id)`, and ids recorded in `used`. Their `company_id` exists.
    - A loan's `lender_id` is a company of kind BANK or LENDER.
    - Engine `tech_cap` is 0–100.
    - Candidates go through `_list(..., has_id = true)`, and their skill keys equal `SKILL_KEYS`.
    - Within one company, no two staff share a `seat_index >= 0`, and no two equipment share one.
    - `project.engine_id` is -1 or an existing engine.
    - `game_over` is bool.
  - `Fixtures` adds:
    - `static func add_equipment(state, overrides := {}) -> int`. Defaults: `def_id = &"equipment_micro_1980"`, player company, seat -1.
    - `static func add_engine(state, overrides := {}) -> int`. Defaults: player company, `features = [&"feature_fx_save"]`, `tech_cap = 35`, BUILT.
    - `static func add_worker(state, overrides := {}) -> int`. It calls `add_staff` with `seat_index` = the lowest seat no player staff uses, adds equipment at that seat, then applies `overrides`. It does not check office seats; tests that need more than 2 workers set the player company's `office_id = &"office_small"`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_game_state.gd (add)
func test_new_game_creates_owner_seated_with_equipment() -> void:
    var s := Fixtures.new_state(1)
    var owner: Staff = s.staff[s.owner_staff_id()]
    assert_true(owner.is_owner)
    assert_eq(owner.seat_index, 0)
    assert_eq(owner.salary, 0)
    for k: StringName in [&"design", &"tech", &"art", &"audio"]:
        assert_eq(owner.skills[k], 30)
    var eq: Equipment = s.equipment[3]
    assert_eq(eq.seat_index, 0)
    assert_eq(eq.def_id, &"equipment_micro_1980")
    assert_eq(s.companies[s.player_company_id].office_id, &"office_garage")

func test_new_game_creates_ai_companies_in_fixed_order() -> void:
    var s := Fixtures.new_state(1)
    var kinds: Array = s.sorted_ids(s.companies).map(func(id: int) -> String: return Company.Kind.keys()[s.companies[id].kind])
    assert_eq(kinds, ["PLAYER", "BANK", "LENDER", "VENDOR", "VENDOR", "AI_PUBLISHER", "AI_PUBLISHER", "AI_PUBLISHER"])
    assert_eq(s.next_id, 11)

func test_new_game_draws_no_rng() -> void:
    var s := Fixtures.new_state(1)
    var fresh := RandomNumberGenerator.new(); fresh.seed = 1
    assert_eq(s.rng.state, fresh.state)

func test_m2_state_round_trip_preserves_hash() -> void:
    var s := Fixtures.new_state(5)
    Fixtures.add_engine(s); Fixtures.add_worker(s)
    var l := Loan.new(); l.id = s.alloc_id(); l.company_id = s.player_company_id; l.lender_id = 4
    s.loans[l.id] = l
    var c := Candidate.new(); c.id = s.alloc_id(); c.skills = {&"art": 1, &"audio": 1, &"design": 1, &"tech": 1}
    s.candidates.append(c)
    var d := Fixtures.json_round_trip(s.to_dict())
    assert_true(GameState.validate_dict(d))
    assert_eq(StateHash.of(GameState.from_dict(d)), StateHash.of(s))
```

```gdscript
# tests/unit/test_state_validator_m2.gd (add)
func test_rejects_owner_pointing_at_non_owner_staff() -> void:
    var s := Fixtures.new_state(5); var sid := Fixtures.add_staff(s)
    var d := Fixtures.json_round_trip(s.to_dict()); d["owner"]["staff_id"] = sid
    assert_false(GameState.validate_dict(d))

func test_rejects_two_staff_in_one_seat() -> void:
    var s := Fixtures.new_state(5); Fixtures.add_staff(s, {"seat_index": 0})
    assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))

func test_rejects_loan_from_non_lender() -> void:
    var s := Fixtures.new_state(5)
    var l := Loan.new(); l.id = s.alloc_id(); l.company_id = s.player_company_id; l.lender_id = 8  # publisher
    s.loans[l.id] = l
    assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))

func test_rejects_dangling_engine_id() -> void:
    var s := Fixtures.new_state(5); Fixtures.add_project(s, {"engine_id": 999})
    assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))

func test_rejects_equipment_of_unknown_company() -> void:
    var s := Fixtures.new_state(5); var eid := Fixtures.add_equipment(s)
    var d := Fixtures.json_round_trip(s.to_dict()); d["equipment"][str(eid)]["company_id"] = 999
    assert_false(GameState.validate_dict(d))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Then fix the M1 tests that assumed an empty new game:
  - `test_hire_staff_command.gd::test_hire_adds_staff_with_skills_in_range`: expect `staff.size() == 2`, and read the hired staff by `s.staff[s.next_id - 1]`. The same applies to `test_game_state.gd::test_hired_staff_skill_order_survives_round_trip` (lines 202–203).
  - `test_game_session.gd`: staff counts become 2 after the hire, and `test_command_waits_for_next_tick_when_running` expects 1, then 2.
  - `test_determinism.gd::test_values_stay_in_range`: skip `is_owner` staff in the skill-range loop.
  - Any test that hardcodes an id other than the player company (1) must use the value returned by its fixture.
  - `Scenario.SCRIPT_BASIC` becomes `{0: [["hire", "Ada", 800]]}`. The owner now counts toward the M1 limit of 4, so the old fourth hire would be rejected; the garage seat rule in Task 9 allows exactly one hire. `test_values_stay_in_range` asserts `staff.size() == 2`.
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add M2 game state, reference checks and garage new game`.

---

### Task 7: Removal and the removal rule test

**Files:**
- Create: `src/core/removal.gd`, `tests/unit/test_removal.gd`
- Modify: `tests/unit/test_rules.gd`

**Interfaces:**
- Consumes: `GameState`, all entities.
- Produces `class_name Removal extends RefCounted` (spec §4.8). Each function returns `bool` (false when the id does not exist, or for the owner) and never touches RNG:
  - `static func remove_staff(state: GameState, staff_id: int) -> bool`: refuses `is_owner`. Erases the staff, which also frees its seat and project assignment (both live on the staff). Then removes decisions whose `related_ids` contain the id.
  - `static func remove_equipment(state, equipment_id) -> bool`: erases it (frees the seat) and removes related decisions.
  - `static func remove_contract(state, contract_id) -> bool`: sets `contract_id = -1` on each project that references it, then removes related decisions.
  - `static func remove_loan(state, loan_id) -> bool`: erases it and removes related decisions.
  - `static func remove_candidate(state, candidate_id) -> bool`: `remove_at` on the array, then removes related decisions.
  - `static func remove_decision(state, decision_id) -> bool`.
  - `static func _drop_decisions_about(state, id: int) -> void` (private helper).
- `test_rules.gd` adds `RuleScan.ENTITY_ERASE := "\\bstate\\.(staff|equipment|contracts|loans|projects)\\.erase\\s*\\("` and a test that scans `res://src` except `res://src/core/removal.gd`. Extend `RuleScan.scan` with an optional `exclude: Array[String] = []` parameter.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_removal.gd
extends GutTest

func _valid(s: GameState) -> bool:
    return GameState.validate_dict(Fixtures.json_round_trip(s.to_dict()))

func _decision_about(s: GameState, id: int) -> int:
    var d := Decision.new(); d.id = s.alloc_id(); d.kind = &"test"; d.related_ids = [id]
    s.pending_decisions.append(d)
    return d.id

func test_remove_staff_frees_seat_and_drops_decisions() -> void:
    var s := Fixtures.new_state(1); var sid := Fixtures.add_worker(s)
    _decision_about(s, sid)
    assert_true(Removal.remove_staff(s, sid))
    assert_false(s.staff.has(sid))
    assert_eq(s.pending_decisions.size(), 0)
    assert_true(_valid(s))

func test_owner_cannot_be_removed() -> void:
    var s := Fixtures.new_state(1)
    assert_false(Removal.remove_staff(s, s.owner_staff_id()))
    assert_true(s.staff.has(s.owner_staff_id()))

func test_remove_contract_clears_project_reference() -> void:
    var s := Fixtures.new_state(1)
    var c := Contract.new(); c.id = s.alloc_id(); c.party_a = 1; c.party_b = 8
    s.contracts[c.id] = c
    var pid := Fixtures.add_project(s, {"contract_id": c.id})
    assert_true(Removal.remove_contract(s, c.id))
    assert_eq(s.projects[pid].contract_id, -1)
    assert_true(_valid(s))

func test_remove_equipment_loan_candidate_decision_keep_state_valid() -> void:
    var s := Fixtures.new_state(1)
    var eid := Fixtures.add_equipment(s, {"seat_index": 1})
    var l := Loan.new(); l.id = s.alloc_id(); l.company_id = 1; l.lender_id = 4; s.loans[l.id] = l
    var c := Candidate.new(); c.id = s.alloc_id(); c.skills = {&"art": 1, &"audio": 1, &"design": 1, &"tech": 1}
    s.candidates.append(c)
    var did := _decision_about(s, c.id)
    assert_true(Removal.remove_equipment(s, eid)); assert_true(_valid(s))
    assert_true(Removal.remove_loan(s, l.id)); assert_true(_valid(s))
    assert_true(Removal.remove_candidate(s, c.id)); assert_true(_valid(s))
    assert_false(s.pending_decisions.any(func(d: Decision) -> bool: return d.id == did))
    assert_false(Removal.remove_decision(s, did))

func test_unknown_id_returns_false() -> void:
    assert_false(Removal.remove_loan(Fixtures.new_state(1), 999))
```

In `test_rules.gd`, add:
- a known-bad check: `RuleScan.matches(RuleScan.ENTITY_ERASE, "state.staff.erase(id)")` is true;
- a known-good check: `RuleScan.matches(RuleScan.ENTITY_ERASE, "d.erase(\"name\")")` is false;
- `test_entity_removal_only_in_removal_gd`, which runs `_assert_clean` over `res://src` with `removal.gd` excluded.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add Removal as the single entity deletion path`.

---

### Task 8: Runtime plumbing: signals, tick order, decisions and load checks

**Files:**
- Create: `src/systems/platform_system.gd`, `owner_system.gd`, `research_system.gd`, `contracts_system.gd`, `awards_system.gd`, `hiring_system.gd` (stubs)
- Modify: `src/core/event_bus.gd`, `src/core/tick_context.gd`, `src/core/simulation.gd`, `src/core/game_session.gd`, `src/core/game_runner.gd`, `src/core/content_db.gd` (`missing_refs`), `tests/unit/test_simulation.gd`, `tests/unit/test_game_session.gd`, `tests/unit/test_game_runner.gd`
- Test: same, plus `tests/unit/test_event_bus.gd`, `tests/unit/test_content_db.gd`

**Interfaces:**
- Produces:
  - `EventBus` adds one `signal <name>(payload: Dictionary)` for each §10 event. That is all of `points_gained`, `bug_found`, `project_stage_changed`, `research_done`, `platform_rumored`, `platform_launched`, `platform_retired`, `raise_requested`, `staff_fired`, `equipment_changed`, `loan_taken`, `payment_missed`, `repossessed`, `contract_offered`, `contract_completed`, `award_result`, `promotion_started`, `game_over` and `game_loaded` (`staff_hired` already exists). M2a payloads:

| Event | Payload |
|---|---|
| `points_gained` | `{staff_id, project_id, type: StringName, amount: int}` |
| `bug_found` | `{staff_id, project_id}` |
| `project_stage_changed` | `{project_id, stage_index}` |
| `project_phase_changed` | `{project_id, phase: String}` (+ `engine_id` when an engine finishes) |
| `research_done` | `{company_id, research_id: StringName}` |
| `platform_rumored` / `platform_launched` / `platform_retired` | `{platform_id: StringName}` |
| `review_published` | `{project_id}` |
| `sales_updated` | `{project_id, units, revenue}` |
| `game_loaded` | `{}` |

  - `TickContext` adds `var content: ContentDB`, set to `ContentDB.active()` in `_init`. The signature is unchanged.
  - `Simulation.SYSTEMS` follows the §5 order (Ruling A8): Calendar, WorldEvent, Market, Platform, Staff, Owner, Research, Production, Contracts, Marketing, Sales, LiveOps, Awards, Finance, Hiring. The six new files are `class_name <X>System extends RefCounted` with `static func tick(_ctx: TickContext) -> void: pass` plus a comment naming the spec step and the plan that fills it.
  - `GameSession` §4.9:
    - `step_once` snapshots `state.next_id` before applying queued commands. After `Simulation.step`, if any decision has `id >= snapshot`, it sets `speed = 0` and emits `decision_required` with the highest such id.
    - `submit` while paused takes the same snapshot around `apply` and emits `decision_required` if the command added a decision.
    - The size comparison goes away.
  - `ContentDB.missing_refs(state: GameState) -> Array[String]` returns one message per content id in the state that is not in this DB:
    - company `office_id` when not empty, every `unlocked` id in `research`, and every `dev_kits` id in `platforms`;
    - equipment `def_id`;
    - project `size_id` when not empty, config `platform`/`genre`/`topic` when not empty, config `engine` when not empty (in `licensed_engines`), `features`, and review `outlet_id`;
    - engine `features`;
    - any `seat_index` on staff or equipment that is ≥ that company's office seats.
  - `GameRunner.load_game`: after a successful deserialize, if `ContentDB.active().missing_refs(r.state)` is not empty, it returns a failed `LoadResult` with `&"error.save_content_missing"` and keeps the old session. On success it calls `session.push_event(&"game_loaded", {})`, so the next `_process` dispatches it. New: `GameSession.push_event(name: StringName, payload: Dictionary) -> void` appends to `_events`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_simulation.gd (replace order test)
func test_system_order_matches_m2_spec() -> void:
    assert_eq(Simulation.SYSTEMS, [CalendarSystem, WorldEventSystem, MarketSystem, PlatformSystem, StaffSystem,
        OwnerSystem, ResearchSystem, ProductionSystem, ContractsSystem, MarketingSystem, SalesSystem,
        LiveOpsSystem, AwardsSystem, FinanceSystem, HiringSystem])
```

```gdscript
# tests/unit/test_game_session.gd (add)
class SwapDecisionCommand extends Command:
    func apply(ctx: TickContext) -> void:
        ctx.state.pending_decisions.remove_at(0)   # not Removal: keeps Task 8 independent of Task 7
        var d := Decision.new(); d.id = ctx.state.alloc_id(); d.kind = &"test"
        ctx.state.pending_decisions.append(d)

func test_decision_swap_in_one_step_still_pauses() -> void:
    var g := _session()
    var old := Decision.new(); old.id = g.state.alloc_id(); g.state.pending_decisions.append(old)
    g.set_speed(1)
    g.submit(SwapDecisionCommand.new())
    g.advance(8.0)
    assert_eq(g.speed, 0)
    var ev := g.drain_events().filter(func(e: Dictionary) -> bool: return e["name"] == &"decision_required")
    assert_eq(ev[0]["payload"]["decision_id"], g.state.pending_decisions[0].id)

func test_paused_command_adding_decision_emits_decision_required() -> void:
    var g := _session()
    g.submit(AddDecisionCommand.new())
    var names := g.drain_events().map(func(e: Dictionary) -> StringName: return e["name"])
    assert_has(names, &"decision_required")
```

```gdscript
# tests/unit/test_game_runner.gd (add; reuse the file's temp save_dir setup)
func test_load_refuses_save_with_unknown_content_id() -> void:
    GameRunner.start_new_game(3, "T")
    GameRunner.session.state.companies[GameRunner.session.state.player_company_id].office_id = &"office_gone"
    GameRunner.save_game("slot_1")
    GameRunner.start_new_game(4, "T2")
    var before := StateHash.of(GameRunner.session.state)
    var r: LoadResult = GameRunner.load_game("slot_1")
    assert_false(r.ok)
    assert_eq(r.error_key, &"error.save_content_missing")
    assert_eq(StateHash.of(GameRunner.session.state), before)

func test_successful_load_emits_game_loaded() -> void:
    GameRunner.start_new_game(3, "T"); GameRunner.save_game("slot_1")
    watch_signals(EventBus)
    GameRunner.load_game("slot_1")
    GameRunner._process(0.0)
    assert_signal_emitted(EventBus, "game_loaded")
```

In `test_content_db.gd`, add `test_missing_refs_lists_unknown_equipment_def`: a fixture state whose equipment `def_id = &"equipment_gone"` gives exactly 1 message, and an untouched fixture state gives `[]`. In `test_event_bus.gd`, add `test_every_m2_event_has_a_signal`, which loops over the 20 §10 names plus `review_published` and `sales_updated` and asserts `EventBus.has_signal(name)`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** The `test_game_runner` tests depend on `ContentDB.active()` being fixture content. Call `Fixtures.new_state(0)` in `before_each` of `test_game_runner.gd` to install it. The tests in this file already set a temp `save_dir`; keep that.
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add M2 signals, tick order, decision detection and content load check`.

---

### Task 9: GameRules and the seat rule for hiring

**Files:**
- Create: `src/core/game_rules.gd`, `tests/unit/test_game_rules.gd`
- Modify: `src/core/commands/hire_staff_command.gd`, `src/content/tuning_def.gd`, `data/tuning.tres`, `tests/unit/test_hire_staff_command.gd`, `tests/unit/test_debug_hud.gd` (`before_each`: `ContentDB.use(Fixtures.content())`), `tests/scenario/test_determinism.gd`

**Interfaces:**
- Consumes: `ContentDB`, all state shapes.
- Produces `class_name GameRules extends RefCounted`. These are read-only helpers shared by commands, systems and `StateQueries`; none of them mutates state.
  - `enum PlatformStatus { UNANNOUNCED, RUMORED, ON_SALE, RETIRED }`
  - `const SLIDER_TYPES: Array[StringName] = [&"tech", &"design", &"design", &"design", &"art", &"tech", &"art", &"audio", &"tech"]`. This is §6.3's mapping, in focus index order.
  - `const ENGINE_FOCUS: Array[int] = [10000, 0, 0, 10000, 0, 0, 10000, 0, 0]`. All Code, so engine work produces tech points.
  - `static func platform_status(def: PlatformDef, week: int) -> PlatformStatus`. RETIRED when `week >= end_week`. ON_SALE when `week >= launch_week`. RUMORED when `rumor_weeks > 0 and week >= launch_week - rumor_weeks`. Otherwise UNANNOUNCED.
  - `static func has_dev_kit(state, content, company_id: int, platform_id: StringName) -> bool` (Ruling A11)
  - `static func is_unlocked(state, content, company_id: int, item_id: StringName) -> bool` → `content.is_unlocked(company.unlocked, item_id)`
  - `static func office_seats(state, content, company_id) -> int` (0 when the office is unknown)
  - `static func free_seat(state, content, company_id) -> int`: lowest seat index in `[0, seats)` that no staff of the company uses, or -1.
  - `static func equipment_at_seat(state, company_id, seat: int) -> int`: equipment id or -1. Uses sorted ids.
  - `static func free_workers(state, company_id) -> Array[int]`: sorted staff that are seated, have equipment at their seat, and have `assigned_project_id == -1`.
  - `static func working_staff(state, project_id) -> Array[int]`: sorted staff assigned to the project, seated, with equipment at their seat.
  - `static func stage_count(p: Project) -> int`: 3 for GAME and CONTRACT_WORK, 1 for ENGINE.
  - `static func stage_weeks(p: Project, content, tuning) -> int`. GAME: `max(1, size.base_weeks / 3)`. ENGINE: `max(1, Σ feature.dev_weeks)`.
  - `static func min_staff(p: Project, content, tuning) -> int`. GAME: `size.min_staff`. ENGINE: `tuning.engine_min_staff`.
  - `static func engine_features(state, content, engine_id: int, licensed_id: StringName) -> Array[StringName]`
  - `static func engine_tech_cap(state, content, p: Project) -> int`. Built engine: `engines[engine_id].tech_cap`. Licensed: `licensed_engines[config.engine].tech_cap`.
  - `static func licensed_engine_available(state, content, company_id, licensed_id, week, tuning) -> bool`. The def exists, `Calendar.year(week)` is in `[year_from, year_to]`, and either `fee == 0` or there is a contract with `kind == ENGINE_LICENSE`, `party_a == company_id` and `deliverable == licensed_id` (Ruling A7).
- `HireStaffCommand`:
  - `validate`: drops the `max_staff_default` check. Fails with `&"error.no_free_seat"` when `GameRules.free_seat(state, ContentDB.active(), company_id) == -1`.
  - `apply`: sets `seat_index` to that free seat, `hired_week` and `last_raise_week` to `state.week`, `level = JUNIOR`, and `exp` to 0 for each skill (sorted). The RNG draws stay in the M1 order.
- Remove `max_staff_default` from `TuningDef` and `data/tuning.tres`, and drop its line from `test_values_stay_in_range` (which already asserts `staff.size() == 2` from Task 6).

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_hire_staff_command.gd (replace the staff-limit test)
func test_hire_takes_the_free_garage_seat() -> void:
    var s := Fixtures.new_state(3); var t := Fixtures.tuning()
    var ctx := TickContext.new(s, t)
    HireStaffCommand.new(s.player_company_id, "Ada", 800).apply(ctx)
    var st: Staff = s.staff[s.next_id - 1]
    assert_eq(st.seat_index, 1)
    assert_eq(st.hired_week, 0)
    assert_eq(st.exp, {&"art": 0, &"audio": 0, &"design": 0, &"tech": 0})

func test_hire_rejected_when_no_free_seat() -> void:
    var s := Fixtures.new_state(3); var t := Fixtures.tuning()
    HireStaffCommand.new(s.player_company_id, "Ada", 800).apply(TickContext.new(s, t))
    assert_eq(HireStaffCommand.new(s.player_company_id, "Bo", 800).validate(s, t).reason_key, &"error.no_free_seat")
```

```gdscript
# tests/unit/test_game_rules.gd
extends GutTest
var db: ContentDB

func before_each() -> void:
    db = Fixtures.content()

func test_platform_status_timeline() -> void:
    var p: PlatformDef = db.platforms[&"platform_fx_console"]   # launch 20, end 60, rumor 8
    assert_eq(GameRules.platform_status(p, 11), GameRules.PlatformStatus.UNANNOUNCED)
    assert_eq(GameRules.platform_status(p, 12), GameRules.PlatformStatus.RUMORED)
    assert_eq(GameRules.platform_status(p, 20), GameRules.PlatformStatus.ON_SALE)
    assert_eq(GameRules.platform_status(p, 60), GameRules.PlatformStatus.RETIRED)

func test_free_dev_kit_counts_as_owned() -> void:
    var s := Fixtures.new_state(1)
    assert_true(GameRules.has_dev_kit(s, db, 1, &"platform_fx_micro"))
    assert_false(GameRules.has_dev_kit(s, db, 1, &"platform_fx_console"))

func test_free_workers_need_seat_and_equipment() -> void:
    var s := Fixtures.new_state(1)
    var unseated := Fixtures.add_staff(s)
    var seated_no_pc := Fixtures.add_staff(s, {"seat_index": 1})
    assert_eq(GameRules.free_workers(s, 1), [s.owner_staff_id()] as Array[int])
    Fixtures.add_equipment(s, {"seat_index": 1})
    assert_eq(GameRules.free_workers(s, 1), [s.owner_staff_id(), seated_no_pc] as Array[int])
    assert_false(GameRules.free_workers(s, 1).has(unseated))

func test_stage_weeks_and_min_staff() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    var g: Project = s.projects[Fixtures.add_project(s)]
    assert_eq(GameRules.stage_weeks(g, db, t), 6)
    assert_eq(GameRules.min_staff(g, db, t), 1)
    var e: Project = s.projects[Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "size_id": &"",
        "features": [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName]})]
    assert_eq(GameRules.stage_count(e), 1)
    assert_eq(GameRules.stage_weeks(e, db, t), 6)

func test_licensed_engine_needs_contract_unless_free() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    assert_true(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_homebrew", 0, t))
    assert_false(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_fx_pro", 0, t))
    var c := Contract.new(); c.id = s.alloc_id(); c.kind = Contract.Kind.ENGINE_LICENSE
    c.party_a = 1; c.party_b = 6; c.deliverable = &"lic_engine_fx_pro"; s.contracts[c.id] = c
    assert_true(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_fx_pro", 0, t))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.** That includes `test_debug_hud`: its Hire button takes the one free garage seat.
- [ ] **Step 5: Commit** `feat(core): add GameRules and seat-based hiring`.

---

### Task 10 (content task): Platforms, sizes, offices, equipment, levels, licensed engines and all M2a UI strings

**Agent:** `gd-content-author`. Read the `content-authoring` skill, but use this plan's field lists. Ints only.

**Files:**
- Create: `data/platforms/*.tres` (5), `data/sizes/*.tres` (2), `data/offices/*.tres` (2), `data/equipment/*.tres` (2), `data/levels/*.tres` (4), `data/licensed_engines/lic_engine_homebrew.tres`
- Modify: `locale/strings.csv`, `tests/unit/test_content_data.gd`, `tests/unit/test_localization.gd`

**Content (ids and pinned values are binding; fictional names, no real trademarks):**

| Id | Pinned values |
|---|---|
| `platform_nova8` (home micro) | launch_week −26, end_week 364, dev_kit_cost 0, rumor_weeks 0, tech_ceiling 35, install_curve starts with ≥ 40000 and has ≥ 12 quarters rising then flat, genre_fit_bp `{genre_action: 12000, genre_adventure: 11000}` |
| `platform_kestrel64` (home micro) | launch_week 104, end_week 572, dev_kit_cost 2000, rumor_weeks 13, tech_ceiling 50 |
| `platform_orbit_vs` (console) | launch_week 260, end_week 728, dev_kit_cost 8000, rumor_weeks 26, tech_ceiling 60 |
| `platform_arcadia` (arcade-cabinet licence) | launch_week −104, end_week 416, dev_kit_cost 4000, rumor_weeks 0, tech_ceiling 55, install_curve starts ≥ 15000, genre_fit_bp `{genre_action: 14000}` |
| `platform_pocketeer` (handheld, `handheld = true`) | launch_week 468, end_week 884, dev_kit_cost 5000, rumor_weeks 26, tech_ceiling 30 |
| `size_small` | base_weeks 18, min_staff 1, cost_multiplier_bp 10000, audience_bp 100, price 12, par_points 9000 |
| `size_medium` | base_weeks 30, min_staff 2, cost_multiplier_bp 18000, audience_bp 180, price 20, par_points 24000 |
| `office_garage` | seats 2, rent 0, electricity_base 20, moving_cost 0, desk_positions 2 entries |
| `office_small` | seats 5, rent 400, electricity_base 40, moving_cost 1500, desk_positions 5 entries |
| `equipment_micro_1980` | tier 1, price 1500, lease 60, power 10, speed_bp 10000, bug_bp 10000, recommended_until_year 1985 |
| `equipment_micro_1985` | tier 2, price 3000, lease 110, power 14, speed_bp 13000, bug_bp 8000, recommended_until_year 1990 |
| `level_junior` … `level_lead` | same numbers as the fixture levels (Task 2) |
| `lic_engine_homebrew` | year_from 1975, year_to 1999, fee 0, royalty_bp 0, tech_cap 35, features `[]` |

`scene_path` is `""` until M2d.

**Strings to add (EN given; write natural TH):**
- Each def's `name_key` (`content.<type>.<short>.name`).
- Company names (Ruling A2): `company.bank.name`, `company.lender.name`, `company.vendor_1.name`, `company.vendor_2.name`, `company.publisher_1.name`, `company.publisher_2.name`, `company.publisher_3.name` (fictional), plus `ui.default_owner_name`.
- Combo labels: `ui.combo.great` Great, `ui.combo.good` Good, `ui.combo.okay` Okay, `ui.combo.bad` Bad, `ui.combo.unknown` Unknown.
- Error keys:

| Key | EN |
|---|---|
| `error.no_free_seat` | No free desk. Move to a bigger office first. |
| `error.not_enough_money` | Not enough money. |
| `error.not_enough_rp` | Not enough research points. |
| `error.research_not_found` | Unknown research. |
| `error.research_done` | Already researched. |
| `error.research_locked` | Research the earlier topics first. |
| `error.platform_not_found` | Unknown platform. |
| `error.platform_not_on_sale` | That platform is not on sale. |
| `error.dev_kit_owned` | You already own this dev kit. |
| `error.no_dev_kit` | Buy the dev kit for this platform first. |
| `error.title_empty` | Give your project a title. |
| `error.size_not_found` | Unknown project size. |
| `error.topic_not_found` | Unknown topic. |
| `error.genre_not_found` | Unknown genre. |
| `error.feature_not_found` | Unknown engine feature. |
| `error.item_locked` | You have not researched this yet. |
| `error.engine_unavailable` | That engine is not available. |
| `error.feature_not_in_engine` | Your engine does not support that feature. |
| `error.no_features` | Pick at least one feature for the engine. |
| `error.not_enough_staff` | Not enough free staff at a desk with a computer. |
| `error.project_not_found` | Project not found. |
| `error.project_not_in_production` | This project is not in development. |
| `error.invalid_sliders` | Each stage's sliders must add up to 100%. |
| `error.past_stage_locked` | A finished stage cannot be changed. |
| `error.project_not_ready` | Finish development before release. |
| `error.save_content_missing` | This save needs game content that is missing. |

- [ ] **Step 1: Add pinned-value tests to `tests/unit/test_content_data.gd`:**

```gdscript
func test_m2a_platforms_sizes_offices() -> void:
    var db := ContentDB.load_dir()
    assert_eq(db.platforms.size(), 5)
    assert_eq(db.platforms[&"platform_nova8"].dev_kit_cost, 0)
    assert_gte(db.platforms[&"platform_nova8"].install_curve[0], 40000)
    assert_eq(db.sizes[&"size_small"].base_weeks, 18)
    assert_eq(db.offices[&"office_garage"].seats, 2)
    assert_eq(db.offices[&"office_small"].seats, 5)
    assert_eq(db.levels.size(), 4)
    assert_eq(db.licensed_engines[&"lic_engine_homebrew"].fee, 0)
    for id: StringName in GameState.sorted_names(db.platforms):
        assert_ne(tr(db.platforms[id].name_key), String(db.platforms[id].name_key))
```

Extend `test_every_error_key_has_en_and_th` in `test_localization.gd` with every key in the error table above.
- [ ] **Step 2: Write the `.tres` files and strings.** Run `godot --headless --import`.
- [ ] **Step 3: Run suite. Expected: all pass.**
- [ ] **Step 4: Commit** `feat(content): add 1980s platforms, sizes, offices, equipment, levels and engines`.

---

### Task 11 (content task): Genres, topics, engine features and research

**Agent:** `gd-content-author`. Ints only. `ideal_sliders` is 9 bp values, and each stage's 3 values sum to 10000.

**Files:**
- Create: `data/genres/*.tres` (6), `data/topics/*.tres` (20), `data/engine_features/*.tres` (5), `data/research/*.tres`, `data/licensed_engines/lic_engine_vector_kit.tres`, `lic_engine_sprite_works.tres`
- Modify: `locale/strings.csv`, `tests/unit/test_content_data.gd`

**Content:**
- **Genres:** `genre_action`, `genre_adventure`, `genre_rpg`, `genre_simulation`, `genre_strategy`, `genre_puzzle`. Pin `genre_action.ideal_sliders = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]`. The others are the author's choice, but each must differ from action in at least one stage by ≥ 2000 total.
- **Topics:** exactly 20, including `topic_space`, `topic_fantasy`, `topic_detective`, `topic_racing`, `topic_sports`, `topic_pirates`, `topic_ninja`, `topic_robots` and `topic_thai_ghost` (Thai folk ghost; EN "Thai Ghost", TH "ผีไทย"). Each has a `genre_fit_bp` entry for all 6 genres, in 5000–15000. Pin `topic_space.genre_fit_bp[genre_action] = 15000`. Exactly 14 topics are unlocked at start, including `topic_space` and `topic_sports` (Task 19 uses both). The other 6, `topic_thai_ghost` among them, are unlocked by research. Pin `topic_sports.genre_fit_bp[genre_action] >= 12000`.
- **Engine features** (`dev_weeks`, `tech_cap_add`): `feature_scrolling` (4, 10), `feature_save_game` (2, 5), `feature_sound_chip_music` (3, 6), `feature_colour_palette` (3, 8), `feature_sprite_animation` (4, 8). Each `research_id` is `research_<feature id without prefix>`, for example `research_scrolling`.
- **Research:**
  - One research per feature. Pin `research_scrolling.cost_rp = 200` with no prerequisites. The other feature research costs are 150–600.
  - `research_size_medium` (cost 500, unlocks `size_medium`).
  - `research_genre_rpg` (400, unlocks `genre_rpg`) and `research_genre_strategy` (400, unlocks `genre_strategy`).
  - Three topic research items covering the 6 locked topics, at 150–400 each.
  - At least one research has a prerequisite.
  - No research unlocks a marketing channel id; channels are added in M2c with their own research.
- **Licensed engines** (here because they reference features):
  - `lic_engine_vector_kit`: year_from 1982, year_to 1989, fee 4000, royalty_bp 500, tech_cap 55, features `[feature_scrolling, feature_save_game]`
  - `lic_engine_sprite_works`: year_from 1985, year_to 1989, fee 9000, royalty_bp 800, tech_cap 70, features `[feature_scrolling, feature_save_game, feature_sound_chip_music]`
- **Strings:** `name_key` for every def.

- [ ] **Step 1: Add pinned-value tests:**

```gdscript
func test_m2a_genres_topics_research() -> void:
    var db := ContentDB.load_dir()
    assert_eq(db.validate(), [] as Array[String])
    assert_eq(db.genres.size(), 6)
    assert_eq(db.topics.size(), 20)
    assert_true(db.topics.has(&"topic_thai_ghost"))
    assert_eq(db.topics[&"topic_space"].genre_fit_bp[&"genre_action"], 15000)
    assert_true(db.is_unlocked([], &"topic_space") and db.is_unlocked([], &"topic_sports"))
    assert_false(db.is_unlocked([], &"topic_thai_ghost"))
    assert_eq(db.research[&"research_scrolling"].cost_rp, 200)
    assert_eq(db.licensed_engines.size(), 3)
    assert_true(db.is_unlocked([], &"genre_action"))
    assert_false(db.is_unlocked([], &"genre_rpg"))
    assert_false(db.is_unlocked([], &"size_medium"))
    var open_topics := GameState.sorted_names(db.topics).filter(func(id: StringName) -> bool: return db.is_unlocked([], id))
    assert_eq(open_topics.size(), 14)
```

- [ ] **Step 2: Write the files and strings; `godot --headless --import`.**
- [ ] **Step 3: Run suite. Expected: all pass, including `test_real_content_loads_without_errors`.**
- [ ] **Step 4: Commit** `feat(content): add 1980s genres, topics, engine features and research`.

---

### Task 12 (content task): Review outlets and templates

**Agent:** `gd-content-author`.

**Files:**
- Create: `data/outlets/*.tres` (4), `data/review_templates/*.tres`
- Modify: `locale/strings.csv`, `tests/unit/test_content_data.gd`

**Content:**
- **Outlets:** four fictional 1980s magazines (`outlet_pixel_press`, `outlet_joystick_weekly`, `outlet_byte_review`, `outlet_arcade_ace`). Each has a different `weights_bp` over `ReviewOutletDef.DIMENSIONS`, with gameplay weight > 0 in all four. `bias_x10` is in −5..5, and the four biases are not all equal.
- **Templates:**
  - For each of the 10 dimensions, at least 2 strength templates (thresholds 70 and 85) and 2 weakness templates (thresholds 45 and 30).
  - Plus `review_tpl_generic_strong` (generic, strength, threshold 0) and `review_tpl_generic_weak` (generic, weakness, threshold 100).
  - `text_key` follows `review.<strong|weak>.<dimension>.<n>` and `review.<strong|weak>.generic`. Texts may use `{platform}` and `{genre}`.
  - Example EN: `review.weak.tech.1` "Sluggish on {platform}: the code cannot keep up."
- **Strings:** outlet `name_key`s and every template `text_key`.

- [ ] **Step 1: Add the test:**

```gdscript
func test_m2a_outlets_and_templates() -> void:
    var db := ContentDB.load_dir()
    assert_eq(db.outlets.size(), 4)
    for dim: StringName in ReviewOutletDef.DIMENSIONS:
        var strong := 0; var weak := 0
        for id: StringName in GameState.sorted_names(db.review_templates):
            var t: ReviewTemplateDef = db.review_templates[id]
            if t.dimension == dim:
                if t.is_strength: strong += 1
                else: weak += 1
        assert_gte(strong, 2, String(dim)); assert_gte(weak, 2, String(dim))
    for id: StringName in GameState.sorted_names(db.review_templates):
        var key: StringName = db.review_templates[id].text_key
        assert_ne(tr(key), String(key), String(key))
```

- [ ] **Step 2: Write the files and strings; `godot --headless --import`.**
- [ ] **Step 3: Run suite. Expected: all pass.**
- [ ] **Step 4: Commit** `feat(content): add review outlets and review templates`.

---

### Task 13: Platform system

**Files:**
- Modify: `src/systems/platform_system.gd`
- Test: `tests/unit/test_platform_system.gd`

**Interfaces:**
- Consumes: `GameRules.platform_status`, `ctx.content.platforms`, `Market.platform_install_base`.
- Produces:
  - `static func install_base(def: PlatformDef, week: int) -> int`. Returns 0 before launch. Otherwise it interpolates the curve with integers: `q = (week − launch_week) / 13`, `r = (week − launch_week) % 13`. When `q >= size − 1` it returns the last value. Otherwise it returns `curve[q] + (curve[q+1] − curve[q]) * r / 13`. `end_week` does not change the formula.
  - `tick(ctx)`: for each platform id (sorted), writes `market.platform_install_base[id] = install_base(def, week)` when `week >= launch_week`. It emits `platform_rumored` when `rumor_weeks > 0 and week == launch_week − rumor_weeks`, `platform_launched` when `week == launch_week`, and `platform_retired` when `week == end_week`. It draws no RNG.

- [ ] **Step 1: Write failing tests** (fixture `platform_fx_console`: launch 20, end 60, rumor 8, curve `[0, 13000, 26000]`).

```gdscript
func test_install_base_interpolates_and_holds_last_value() -> void:
    var p: PlatformDef = Fixtures.content().platforms[&"platform_fx_console"]
    assert_eq(PlatformSystem.install_base(p, 19), 0)
    assert_eq(PlatformSystem.install_base(p, 20), 0)
    assert_eq(PlatformSystem.install_base(p, 33), 13000)
    assert_eq(PlatformSystem.install_base(p, 39), 19000)   # 13000 + 13000*6/13
    assert_eq(PlatformSystem.install_base(p, 200), 26000)

func test_events_fire_on_exact_weeks() -> void:
    var s := Fixtures.new_state(1)
    var fired := {}
    for w: int in [12, 20, 60]:
        s.week = w
        var ctx := TickContext.new(s, Fixtures.tuning())
        PlatformSystem.tick(ctx)
        for e: Dictionary in ctx.events:
            if e["payload"].get("platform_id") == &"platform_fx_console":
                fired[w] = e["name"]
    assert_eq(fired, {12: &"platform_rumored", 20: &"platform_launched", 60: &"platform_retired"})

func test_writes_install_base_for_launched_platforms_only() -> void:
    var s := Fixtures.new_state(1); s.week = 0
    PlatformSystem.tick(TickContext.new(s, Fixtures.tuning()))
    assert_eq(s.market.platform_install_base[&"platform_fx_micro"], 70000)   # week 0 = quarter 4 since launch: last entry
    assert_false(s.market.platform_install_base.has(&"platform_fx_console"))
```
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add platform lifecycle and install base`.

---

### Task 14: Research system, BuyResearch and BuyDevKit

**Files:**
- Modify: `src/systems/research_system.gd`
- Create: `src/core/commands/buy_research_command.gd`, `buy_dev_kit_command.gd`
- Test: `tests/unit/test_research_system.gd`, `tests/unit/test_buy_research_command.gd`, `tests/unit/test_buy_dev_kit_command.gd`

**Interfaces:**
- Consumes: `Staff.week_points` (Ruling A4), `GameRules`, `ContentDB.active()`.
- Produces:
  - `ResearchSystem.tick(ctx)`: for each company (sorted), `research_points += Fixed.mul_bp(Σ week_points values of its staff, tuning.research_per_point_bp)`. It does not clear `week_points`; Production overwrites them.
  - `BuyResearchCommand.new(p_company_id: int, p_research_id: StringName)`.
    - Validate in this order: company exists (`error.company_not_found`); research exists (`error.research_not_found`); not already in `unlocked` (`error.research_done`); every prerequisite is in `unlocked` (`error.research_locked`); `research_points >= cost_rp` (`error.not_enough_rp`).
    - Apply: subtract the cost, append the id to `unlocked`, emit `research_done`.
  - `BuyDevKitCommand.new(p_company_id: int, p_platform_id: StringName)`.
    - Validate in this order: company exists; platform exists (`error.platform_not_found`); status ON_SALE (`error.platform_not_on_sale`); `has_dev_kit` is false (`error.dev_kit_owned`); `money >= dev_kit_cost` (`error.not_enough_money`).
    - Apply: subtract the cost, append to `dev_kits`, emit `money_changed`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_research_system.gd
func test_research_points_from_last_week_points() -> void:
    var s := Fixtures.new_state(1)
    s.staff[s.owner_staff_id()].week_points = {&"design": 300, &"tech": 200}
    ResearchSystem.tick(TickContext.new(s, Fixtures.tuning()))
    assert_eq(s.companies[1].research_points, 50)   # 500 * 1000bp
```

```gdscript
# tests/unit/test_buy_research_command.gd
func test_buy_unlocks_and_spends() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    s.companies[1].research_points = 60
    var cmd := BuyResearchCommand.new(1, &"research_fx_scroll")
    assert_true(cmd.validate(s, t).ok)
    var ctx := TickContext.new(s, t); cmd.apply(ctx)
    assert_eq(s.companies[1].research_points, 10)
    assert_has(s.companies[1].unlocked, &"research_fx_scroll")
    assert_eq(ctx.events[0]["name"], &"research_done")

func test_rejections() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    assert_eq(BuyResearchCommand.new(1, &"research_nope").validate(s, t).reason_key, &"error.research_not_found")
    assert_eq(BuyResearchCommand.new(1, &"research_fx_scroll").validate(s, t).reason_key, &"error.not_enough_rp")
    s.companies[1].research_points = 999
    assert_eq(BuyResearchCommand.new(1, &"research_fx_adventure").validate(s, t).reason_key, &"error.research_locked")
    s.companies[1].unlocked = [&"research_fx_scroll"]
    assert_eq(BuyResearchCommand.new(1, &"research_fx_scroll").validate(s, t).reason_key, &"error.research_done")
```

```gdscript
# tests/unit/test_buy_dev_kit_command.gd
func test_buy_console_kit_after_launch() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning(); s.week = 20
    var cmd := BuyDevKitCommand.new(1, &"platform_fx_console")
    assert_true(cmd.validate(s, t).ok)
    cmd.apply(TickContext.new(s, t))
    assert_eq(s.companies[1].money, 20000 - 3000)
    assert_true(GameRules.has_dev_kit(s, Fixtures.content(), 1, &"platform_fx_console"))
    assert_eq(cmd.validate(s, t).reason_key, &"error.dev_kit_owned")

func test_rejections() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    assert_eq(BuyDevKitCommand.new(1, &"platform_fx_console").validate(s, t).reason_key, &"error.platform_not_on_sale")
    assert_eq(BuyDevKitCommand.new(1, &"platform_fx_micro").validate(s, t).reason_key, &"error.dev_kit_owned")  # free kit
    s.week = 20; s.companies[1].money = 100
    assert_eq(BuyDevKitCommand.new(1, &"platform_fx_console").validate(s, t).reason_key, &"error.not_enough_money")
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add research points, BuyResearch and BuyDevKit`.

---

### Task 15: StartProject and SetSliders

**Files:**
- Create: `src/core/commands/start_project_command.gd`, `set_sliders_command.gd`
- Test: `tests/unit/test_start_project_command.gd`, `tests/unit/test_set_sliders_command.gd`

**Interfaces:**
- Consumes: `GameRules`, `ContentDB.active()`.
- Produces (spec §6.1, Rulings A10, A11, A14):
  - `StartProjectCommand` has fields `company_id, kind: Project.Kind, title: String, size_id, platform_id, topic_id, genre_id: StringName, engine_id: int, licensed_engine_id: StringName, features: Array[StringName]`.
  - `static func game(p_company_id: int, p_title: String, p_size_id: StringName, p_platform_id: StringName, p_topic_id: StringName, p_genre_id: StringName, p_engine_id: int, p_licensed_engine_id: StringName, p_features: Array[StringName]) -> StartProjectCommand`
  - `static func engine(p_company_id: int, p_title: String, p_features: Array[StringName]) -> StartProjectCommand`
  - GAME validation, in this order, first failure wins:
    - company exists;
    - title is not empty after `strip_edges` (`error.title_empty`);
    - the size exists (`error.size_not_found`) and is unlocked (`error.item_locked`);
    - the platform exists (`error.platform_not_found`) and is ON_SALE (`error.platform_not_on_sale`);
    - `has_dev_kit` (`error.no_dev_kit`);
    - the topic exists (`error.topic_not_found`) and is unlocked;
    - the genre exists (`error.genre_not_found`) and is unlocked;
    - the engine: `engine_id != -1` must be an engine of this company, otherwise `licensed_engine_available` (`error.engine_unavailable`);
    - each feature exists (`error.feature_not_found`), is unlocked, and is in `engine_features` (`error.feature_not_in_engine`);
    - `free_workers(...).size() >= size.min_staff` (`error.not_enough_staff`).
  - ENGINE validation: company and title as above; `features` not empty (`error.no_features`); each feature exists and is unlocked; at least `tuning.engine_min_staff` free workers.
  - Apply:
    - Create a new `Project` with `alloc_id()`, the given `kind`, `phase = PRODUCTION`, `stage_index = 0`, `stage_progress = 0`, the features, and `engine_id`.
    - GAME: `size_id`, `config` with `platform`, `genre`, `topic` and `engine` (the licensed id, or `&""` for a built engine), inserted in sorted order, and `focus = Project.DEFAULT_FOCUS`.
    - ENGINE: `size_id = &""`, empty `config`, `focus = GameRules.ENGINE_FOCUS`.
    - `deadline_week = week + stage_count × stage_weeks`.
    - Every free worker gets `assigned_project_id = id`.
    - Emit `project_phase_changed {project_id, phase: "PRODUCTION"}`.
  - `SetSlidersCommand.new(p_project_id: int, p_focus: Array[int])` (all 9 values).
    - Validation: the project exists (`error.project_not_found`); the kind is GAME and the phase is PRODUCTION (`error.project_not_in_production`); there are 9 values, each 0–10000, and each triple sums to 10000 (`error.invalid_sliders`); every stage before `stage_index` is unchanged (`error.past_stage_locked`).
    - Apply: copy the values and emit `project_changed {project_id}`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_start_project_command.gd
extends GutTest
var s: GameState; var t: TuningDef

func before_each() -> void:
    s = Fixtures.new_state(1); t = Fixtures.tuning()

func _game(overrides := {}) -> StartProjectCommand:
    var a := {"title": "Star Run", "size": &"size_small", "platform": &"platform_fx_micro", "topic": &"topic_fx_space",
        "genre": &"genre_fx_action", "engine_id": -1, "lic": &"lic_engine_homebrew", "features": [] as Array[StringName]}
    a.merge(overrides, true)
    return StartProjectCommand.game(1, a["title"], a["size"], a["platform"], a["topic"], a["genre"], a["engine_id"], a["lic"], a["features"])

func test_start_game_assigns_free_workers() -> void:
    var w := Fixtures.add_worker(s)
    var cmd := _game(); assert_true(cmd.validate(s, t).ok)
    cmd.apply(TickContext.new(s, t))
    var p: Project = s.projects[s.next_id - 1]
    assert_eq(p.phase, Project.Phase.PRODUCTION)
    assert_eq(p.config[&"engine"], &"lic_engine_homebrew")
    assert_eq(p.deadline_week, 18)
    assert_eq(s.staff[w].assigned_project_id, p.id)
    assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, p.id)

func test_second_project_has_no_free_staff() -> void:
    _game().apply(TickContext.new(s, t))
    assert_eq(_game().validate(s, t).reason_key, &"error.not_enough_staff")

func test_rejection_reasons() -> void:
    assert_eq(_game({"title": "  "}).validate(s, t).reason_key, &"error.title_empty")
    assert_eq(_game({"size": &"size_medium"}).validate(s, t).reason_key, &"error.item_locked")
    assert_eq(_game({"platform": &"platform_fx_console"}).validate(s, t).reason_key, &"error.platform_not_on_sale")
    assert_eq(_game({"genre": &"genre_fx_adventure"}).validate(s, t).reason_key, &"error.item_locked")
    assert_eq(_game({"lic": &"lic_engine_fx_pro"}).validate(s, t).reason_key, &"error.engine_unavailable")
    assert_eq(_game({"features": [&"feature_fx_scroll"] as Array[StringName]}).validate(s, t).reason_key, &"error.item_locked")
    s.week = 20
    assert_eq(_game({"platform": &"platform_fx_console"}).validate(s, t).reason_key, &"error.no_dev_kit")

func test_retired_platform_refused() -> void:
    s.week = 400
    assert_eq(_game().validate(s, t).reason_key, &"error.platform_not_on_sale")

func test_built_engine_features_allowed() -> void:
    var eid := Fixtures.add_engine(s, {"features": [&"feature_fx_save"] as Array[StringName]})
    assert_true(_game({"engine_id": eid, "lic": &"", "features": [&"feature_fx_save"] as Array[StringName]}).validate(s, t).ok)

func test_engine_project() -> void:
    s.companies[1].unlocked = [&"research_fx_scroll"]
    var cmd := StartProjectCommand.engine(1, "Engine 1", [&"feature_fx_scroll", &"feature_fx_save"] as Array[StringName])
    assert_true(cmd.validate(s, t).ok)
    cmd.apply(TickContext.new(s, t))
    var p: Project = s.projects[s.next_id - 1]
    assert_eq(p.kind, Project.Kind.ENGINE)
    assert_eq(p.focus, GameRules.ENGINE_FOCUS)
    assert_eq(p.deadline_week, 6)
    assert_eq(StartProjectCommand.engine(1, "E", [] as Array[StringName]).validate(s, t).reason_key, &"error.no_features")
```

```gdscript
# tests/unit/test_set_sliders_command.gd
func test_set_and_reject() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    var pid := Fixtures.add_project(s)
    var good: Array[int] = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]
    var cmd := SetSlidersCommand.new(pid, good); assert_true(cmd.validate(s, t).ok)
    cmd.apply(TickContext.new(s, t)); assert_eq(s.projects[pid].focus, good)
    var bad: Array[int] = [5000, 3000, 2001, 3000, 3000, 4000, 4000, 3000, 3000]
    assert_eq(SetSlidersCommand.new(pid, bad).validate(s, t).reason_key, &"error.invalid_sliders")
    s.projects[pid].stage_index = 1
    var past: Array[int] = [4000, 3000, 3000, 3000, 3000, 4000, 4000, 3000, 3000]
    assert_eq(SetSlidersCommand.new(pid, past).validate(s, t).reason_key, &"error.past_stage_locked")
    s.projects[pid].phase = Project.Phase.POLISH
    assert_eq(SetSlidersCommand.new(pid, good).validate(s, t).reason_key, &"error.project_not_in_production")
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(core): add StartProject and SetSliders commands`.

---

### Task 16: Production system

**Files:**
- Modify: `src/systems/production_system.gd`
- Test: `tests/unit/test_production_system.gd`

**Interfaces:**
- Consumes: `GameRules` (`working_staff`, `stage_count`, `stage_weeks`, `min_staff`, `SLIDER_TYPES`, `equipment_at_seat`), `ContentDB` (sizes, equipment, levels, licensed engines, features), `TuningDef` production fields.
- Produces (spec §6.3, §6.4, Rulings A4, A13, A14):
  - `static func chemistry_bp(_state: GameState, _project_id: int, _staff_id: int) -> int` returns `Fixed.ONE_BP`. This is the M2b hook for traits and leads.
  - `static func morale_bp(morale: int, t: TuningDef) -> int` = `min + (max − min) * morale / 100`.
  - `static func engine_age_bp(state, content, p: Project, t) -> int` is `Fixed.ONE_BP` for an ENGINE project. Otherwise it is `10000 + years × engine_age_bug_bp_per_year`. Years are counted from `built_week / 52` for a built engine, or from `year_from` for a licensed one, and are never negative.
  - `tick(ctx)`:
    1. Set `week_points = {}` on every staff member (sorted).
    2. For each project (sorted) with kind GAME or ENGINE and phase PRODUCTION or POLISH, take `ws = GameRules.working_staff(...)`. If `ws` is empty, skip the project: no progress, no events.
    3. PRODUCTION. For each staff in `ws`, for each of the 3 sliders of the current stage (`i = stage_index * 3 + j`), let `type = SLIDER_TYPES[i]` and compute:
       `amount = skill[type] * points_per_skill`, then `mul_bp` in turn by `focus[i]`, the equipment's `speed_bp`, `morale_bp`, `level_def(level).output_bp` (ONE_BP if null) and `chemistry_bp`.
       When `amount > 0`, add it to `p.points[type]` (insert missing keys in sorted order) and to `staff.week_points[type]`. Amounts of 0 create no keys. Emit `points_gained` once per type with a total > 0, in the order the types first appear for that stage.
    4. Bugs for each staff in `ws`: start from `bugs_per_staff_week_bp`, then `mul_bp` in turn by `crunch_bug_bp` (only if crunching), the equipment's `bug_bp`, `engine_age_bp` and `chemistry_bp`. The count is `n = b / 10000 + (1 if Fixed.roll_bp(rng, b % 10000) else 0)`. That is exactly one RNG draw per working staff per week. Add `n` to `p.bugs` and emit `bug_found` `n` times.
    5. Progress: `working = min(ws.size(), min_staff)`, `d = stage_weeks × min_staff`, `inc = ceil(10000 × working / d)`. If crunching, apply `mul_bp(inc, crunch_speed_bp)`. Add `inc` to `stage_progress`. At ≥ 10000, set `stage_progress = 0`, then:
       - if more stages remain: increment `stage_index` and emit `project_stage_changed`;
       - for a GAME at its last stage: `phase = POLISH`, emit `project_phase_changed`;
       - for an ENGINE: create a `GameEngine` (`alloc_id()`, `name = p.title`, `features = p.features`, `tech_cap = min(100, engine_base_tech_cap + Σ tech_cap_add)`, BUILT, `built_week = week`), set `phase = RETIRED`, unassign its staff, and emit `project_phase_changed {project_id, phase: "RETIRED", engine_id}`.
    6. POLISH: `p.bugs = max(0, p.bugs − polish_bugs_fixed_per_staff_week × ws.size())`. No points and no RNG.

- [ ] **Step 1: Write failing tests.** Use the fixture state. The owner (all skills 30, morale 70, JUNIOR, equipment `speed_bp` 10000) works on a `size_small` game, so stage weeks is 6 and min staff is 1. `morale_bp(70) = 6000 + 6000*70/100 = 10200`.

```gdscript
extends GutTest
var s: GameState; var t: TuningDef; var pid: int

func before_each() -> void:
    s = Fixtures.new_state(1); t = Fixtures.tuning()
    pid = Fixtures.add_project(s)
    s.staff[s.owner_staff_id()].assigned_project_id = pid

func _tick() -> TickContext:
    var ctx := TickContext.new(s, t); ProductionSystem.tick(ctx); return ctx

func test_stage_one_points_follow_sliders() -> void:
    _tick()
    # stage 1 sliders: Code 3334 -> tech, Design 3333 + Story 3333 -> design
    var tech := Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(300, 3334), 10000), 10200), 10000)
    var des := 2 * Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(300, 3333), 10000), 10200), 10000)
    assert_eq(s.projects[pid].points[&"tech"], tech)
    assert_eq(s.projects[pid].points[&"design"], des)
    assert_eq(s.staff[s.owner_staff_id()].week_points[&"design"], des)

func test_six_weeks_finish_stage_one() -> void:
    for i: int in 5: _tick()
    assert_eq(s.projects[pid].stage_index, 0)
    var ctx := _tick()
    assert_eq(s.projects[pid].stage_index, 1)
    assert_true(ctx.events.any(func(e: Dictionary) -> bool: return e["name"] == &"project_stage_changed"))

func test_game_moves_to_polish_after_18_weeks_and_polish_fixes_bugs() -> void:
    for i: int in 18: _tick()
    assert_eq(s.projects[pid].phase, Project.Phase.POLISH)
    s.projects[pid].bugs = 10
    var before: Dictionary = s.projects[pid].points.duplicate()
    _tick()
    assert_eq(s.projects[pid].bugs, 7)
    assert_eq(s.projects[pid].points, before)

func test_crunch_speeds_progress() -> void:
    s.projects[pid].crunch = true
    _tick()
    assert_eq(s.projects[pid].stage_progress, Fixed.mul_bp(1667, 15000))

func test_bugs_two_per_week_plus_one_roll() -> void:
    _tick()
    assert_between(s.projects[pid].bugs, 2, 3)

func test_no_workers_no_progress_no_events() -> void:
    Removal.remove_equipment(s, GameRules.equipment_at_seat(s, 1, 0))
    var ctx := _tick()
    assert_eq(s.projects[pid].stage_progress, 0)
    assert_eq(ctx.events.size(), 0)
    assert_eq(s.staff[s.owner_staff_id()].week_points, {})

func test_engine_project_builds_engine() -> void:
    var eid := Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "size_id": &"",
        "focus": GameRules.ENGINE_FOCUS, "features": [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName]})
    s.staff[s.owner_staff_id()].assigned_project_id = eid
    s.projects[pid].phase = Project.Phase.LIVE
    for i: int in 6: _tick()
    assert_eq(s.projects[eid].phase, Project.Phase.RETIRED)
    assert_eq(s.engines.size(), 1)
    var e: GameEngine = s.engines.values()[0]
    assert_eq(e.tech_cap, 45)   # 30 + 5 + 10
    assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, -1)
    assert_true(s.projects[eid].points[&"tech"] > 0)
    assert_eq(s.projects[eid].points.keys(), [&"tech"])

func test_same_seed_same_bugs() -> void:
    var a := Fixtures.new_state(9); var b := Fixtures.new_state(9)
    for st: GameState in [a, b]:
        var p := Fixtures.add_project(st); st.staff[st.owner_staff_id()].assigned_project_id = p
        for i: int in 18: ProductionSystem.tick(TickContext.new(st, t))
    assert_eq(StateHash.of(a), StateHash.of(b))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add production with sliders, bugs, stages and engines`.

---

### Task 17: Reviews, ReleaseProject and the combo label

**Files:**
- Create: `src/systems/review_system.gd`, `src/core/commands/release_project_command.gd`
- Modify: `src/core/state_queries.gd`
- Test: `tests/unit/test_review_system.gd`, `tests/unit/test_release_project_command.gd`, `tests/unit/test_state_queries_m2.gd`

**Interfaces:**
- Consumes: `GameRules`, `ContentDB`, `ReviewOutletDef.DIMENSIONS`, `TuningDef` review fields.
- Produces (spec §6.2, §6.6, foundation §7, Ruling A12). `class_name ReviewSystem extends RefCounted` is not in `SYSTEMS`; it is called by `ReleaseProjectCommand.apply`.
  - `static func match_bp(focus: Array[int], ideal: Array[int], stage: int) -> int` = `max(0, 10000 − Σ_{j<3} |focus[3s+j] − ideal[3s+j]|)`.
  - `static func fit_to_x10(fit_bp: int) -> int` = `clampi(10 + (fit_bp − 5000) * 90 / 10000, 10, 100)`. 10000 maps to 55 and 15000 to 100.
  - `static func quality_x10(points: int, par: int, t) -> int` = `clampi(Fixed.mul_bp(t.review_par_score_x10, points * 10000 / max(1, par)), 10, 100)`.
  - `static func par_for(type: StringName, size: ProjectSizeDef, genre: GenreDef) -> int` = `Fixed.mul_bp(size.par_points, share)`, where `share` = (Σ of `genre.ideal_sliders[i]` with `SLIDER_TYPES[i] == type`) / 3.
  - `static func dimension_scores(state, content, t, project_id) -> Dictionary[StringName, int]`. Keys in `DIMENSIONS` order, values in 10–100. `Q(type) = quality_x10(points.get(type, 0), par_for(type))`, and `M(s) = 10 + Fixed.mul_bp(90, match_bp(stage s))`.
    - `gameplay` = `(Q(design) + (M(0)+M(1)+M(2))/3) / 2`
    - `tech` = `min(Q(tech), max(10, GameRules.engine_tech_cap(...)))`
    - `graphics` = `Q(art)`; `audio` = `Q(audio)`
    - `story` = `(Q(design) + M(0)) / 2`
    - `innovation` = `clampi(innovation_base + features.size() × per_feature + (new_combo ? new_combo_bonus : 0), 10, 100)`. `new_combo` means no other GAME project of the company with phase ≥ RELEASED has the same topic and genre.
    - `bugs` = `clampi(100 − (bugs × 10000 / max(1, Σ points)) / review_bug_density_divisor, 10, 100)`
    - `platform_fit` = `fit_to_x10(platform.genre_fit_bp.get(genre, 10000))`
    - `market_fit` = `fit_to_x10(topic.genre_fit_bp.get(genre, 10000))`
    - `value` = `(gameplay + bugs) / 2`
  - `static func pick_template(content, dimension: StringName, is_strength: bool, score_x10: int) -> StringName`.
    - Strength: among templates with that dimension and `is_strength` and `score_x10 >= threshold_x10`, return the `text_key` with the highest threshold.
    - Weakness: among templates with that dimension and not `is_strength` and `score_x10 <= threshold_x10`, return the one with the lowest threshold.
    - Ties go to the smaller id. With no match, fall back to the `&"generic"` template of the same polarity, then to `&"review.strong.generic"` / `&"review.weak.generic"`.
  - `static func outlet_review(dims: Dictionary[StringName, int], outlet: ReviewOutletDef, content, rng, t) -> ReviewResult`.
    - `score = clampi(Σ w·d / Σ w + bias_x10 + rng.randi_range(−review_noise_x10, review_noise_x10), 10, 100)`.
    - The strongest and weakest dimensions are taken over the dimensions with weight > 0, comparing raw `dims`. Ties go to the earlier dimension in `DIMENSIONS`.
    - Exactly one RNG draw per outlet. The noise never changes the strength or weakness (spec foundation §7.2).
  - `static func review_project(ctx: TickContext, project_id: int) -> void`: clears and fills `review_results` in sorted outlet order, sets `user_score` to the integer mean of `score_x10`, and emits `review_published {project_id}`.
  - `ReleaseProjectCommand.new(p_project_id: int)`. Validate: the project exists (`error.project_not_found`); kind GAME and phase POLISH (`error.project_not_ready`). Apply: `phase = RELEASED`, `release_week = week`, run `review_project`, unassign every staff of the project, and emit `project_phase_changed {project_id, phase: "RELEASED"}`.
  - `StateQueries.combo_label_key(state: GameState, company_id: int, topic_id: StringName, genre_id: StringName, t: TuningDef) -> StringName`. Takes the best `user_score` over the company's GAME projects with phase ≥ RELEASED and that topic and genre. Returns `&"ui.combo.great"` when ≥ `combo_great_x10`, `good` when ≥ `combo_good_x10`, `okay` when ≥ `combo_okay_x10`, otherwise `bad`, and `unknown` when no such project exists.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_review_system.gd
extends GutTest
var s: GameState; var t: TuningDef; var db: ContentDB

func before_each() -> void:
    s = Fixtures.new_state(1); t = Fixtures.tuning(); db = Fixtures.content()

func test_match_bp_per_stage() -> void:
    var ideal: Array[int] = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]
    assert_eq(ReviewSystem.match_bp(ideal, ideal, 0), 10000)
    var f: Array[int] = [3000, 3000, 4000, 3000, 3000, 4000, 4000, 3000, 3000]
    assert_eq(ReviewSystem.match_bp(f, ideal, 0), 6000)
    assert_eq(ReviewSystem.match_bp([10000, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int], [0, 0, 10000, 0, 0, 0, 0, 0, 0] as Array[int], 0), 0)

func test_fit_to_x10() -> void:
    assert_eq(ReviewSystem.fit_to_x10(5000), 10)
    assert_eq(ReviewSystem.fit_to_x10(10000), 55)
    assert_eq(ReviewSystem.fit_to_x10(15000), 100)

func test_reasons_match_strong_art_and_weak_tech() -> void:
    var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 30,
        "points": {&"art": 20000, &"audio": 1000, &"design": 3000, &"tech": 100}})
    var dims := ReviewSystem.dimension_scores(s, db, t, pid)
    # Worked values: gameplay 78, story 72, innovation 60, bugs 98, platform_fit 73, market_fit 100
    assert_eq(dims[&"graphics"], 100)
    assert_eq(dims[&"bugs"], 98)
    assert_eq(dims[&"tech"], 10)
    var r := ReviewSystem.outlet_review(dims, db.outlets[&"outlet_fx_b"], db, s.rng, t)
    assert_eq(r.strength_key, &"review.strong.graphics")
    assert_eq(r.weakness_key, &"review.weak.tech")

func test_tech_capped_by_engine() -> void:
    var pid := Fixtures.add_project(s, {"points": {&"tech": 999999}})
    assert_eq(ReviewSystem.dimension_scores(s, db, t, pid)[&"tech"], 40)   # homebrew tech_cap 40

func test_empty_project_scores_clamp_and_still_has_reasons() -> void:
    var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 50})
    var dims := ReviewSystem.dimension_scores(s, db, t, pid)
    for d: StringName in ReviewOutletDef.DIMENSIONS:
        assert_between(dims[d], 10, 100, String(d))
    var r := ReviewSystem.outlet_review(dims, db.outlets[&"outlet_fx_a"], db, s.rng, t)
    assert_ne(r.strength_key, &""); assert_ne(r.weakness_key, &"")

func test_noise_within_three_and_one_draw_per_outlet() -> void:
    var pid := Fixtures.add_project(s, {"points": {&"art": 3000, &"audio": 1000, &"design": 3000, &"tech": 3000}})
    var dims := ReviewSystem.dimension_scores(s, db, t, pid)
    var o: ReviewOutletDef = db.outlets[&"outlet_fx_a"]
    var mean := 0
    for d: StringName in ReviewOutletDef.DIMENSIONS: mean += dims[d]
    mean /= 10
    var before := s.rng.state
    var r := ReviewSystem.outlet_review(dims, o, db, s.rng, t)
    assert_between(r.score_x10, mean - 3, mean + 3)
    var probe := RandomNumberGenerator.new(); probe.state = before; probe.randi_range(-3, 3)
    assert_eq(s.rng.state, probe.state)
```

```gdscript
# tests/unit/test_release_project_command.gd
func test_release_creates_four_reviews_and_frees_staff() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "points": {&"design": 3000, &"tech": 3000}})
    s.staff[s.owner_staff_id()].assigned_project_id = pid
    var cmd := ReleaseProjectCommand.new(pid); assert_true(cmd.validate(s, t).ok)
    var ctx := TickContext.new(s, t); cmd.apply(ctx)
    var p: Project = s.projects[pid]
    assert_eq(p.phase, Project.Phase.RELEASED)
    assert_eq(p.release_week, 0)
    assert_eq(p.review_results.size(), 4)
    assert_eq(p.review_results.map(func(r: ReviewResult) -> StringName: return r.outlet_id),
        [&"outlet_fx_a", &"outlet_fx_b", &"outlet_fx_c", &"outlet_fx_d"])
    assert_between(p.user_score, 10, 100)
    assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, -1)
    assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))

func test_release_allowed_after_platform_retires() -> void:
    var s := Fixtures.new_state(1); s.week = 400   # platform_fx_micro end_week 400
    var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
    assert_true(ReleaseProjectCommand.new(pid).validate(s, Fixtures.tuning()).ok)

func test_release_rejected_before_polish() -> void:
    var s := Fixtures.new_state(1)
    var pid := Fixtures.add_project(s)
    assert_eq(ReleaseProjectCommand.new(pid).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_ready")
    assert_eq(ReleaseProjectCommand.new(999).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_found")
```

```gdscript
# tests/unit/test_state_queries_m2.gd
func test_combo_label() -> void:
    var s := Fixtures.new_state(1); var t := Fixtures.tuning()
    assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.unknown")
    Fixtures.add_project(s, {"phase": Project.Phase.LIVE, "user_score": 66})
    assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.good")
    Fixtures.add_project(s, {"phase": Project.Phase.RETIRED, "user_score": 85})
    assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.great")
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** If `test_reasons_match_strong_art_and_weak_tech` picks a different dimension, recompute the expected dims by hand from the formulas above. Do not change the formulas to fit the test; report a mismatch as `NEEDS_DESIGN`.
- [ ] **Step 4: `godot --headless --import`, run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add reviews with reasons and ReleaseProject`.

---

### Task 18: Sales system

**Files:**
- Modify: `src/systems/sales_system.gd`
- Test: `tests/unit/test_sales_system.gd`

**Interfaces:**
- Consumes: `market.platform_install_base`, `ContentDB` (sizes, topics, platforms, licensed engines), `GameRules.platform_status`, `TuningDef` sales tables.
- Produces (spec §6.6, §6.7, Rulings A14, A17):
  - `static func table_bp(table: Array[int], score_or_hype: int) -> int` returns `table[clampi(score_or_hype / 10, 0, table.size() − 1)]`.
  - `static func launch_units(state, content, t, p: Project) -> int`: start from `install_base` (0 if the market has no entry), then `mul_bp` in turn by the topic `genre_fit_bp` (default 10000), the size's `audience_bp`, `table_bp(sales_hype_table_bp, hype)` and `table_bp(sales_review_table_bp, user_score)`.
  - `static func decay_bp(content, t, p: Project, week: int) -> int`: `table_bp(sales_decay_table_bp, user_score)`, or `max(0, 2·d − 10000)` when the platform is RETIRED at `week`.
  - `static func royalty_bp(state, content, p: Project) -> int`. 0 for a built engine. Otherwise the `royalty_bp` of the matching `ENGINE_LICENSE` contract if one exists, or else the licensed def's `royalty_bp`.
  - `tick(ctx)`: for each project (sorted) with kind GAME and phase RELEASED or LIVE:
    - `units` is `launch_units(...)` when `weekly_units` is empty (and the phase becomes LIVE, with `project_phase_changed`). Otherwise `units = mul_bp(weekly_units.back(), decay_bp(...))`.
    - If `units < sales_floor_units`, set `phase = RETIRED`, emit `project_phase_changed`, and continue.
    - Otherwise append `units` and, while `size > Project.WEEKLY_UNITS_CAP`, `remove_at(0)`. Then `units_sold += units` and `gross = units × size.price`.
    - `pub = gross × contract.revenue_share_pct / 100` when `contract_id != -1` and the contract is PUBLISHING; the publisher is `party_b`, which is credited with `pub`.
    - `roy = mul_bp(gross, royalty_bp)`, and `net = gross − pub − roy`.
    - Add `net` to `p.revenue` and to the company's `money`. Emit `sales_updated {project_id, units, revenue: net}` and `money_changed`.
    - No RNG.

- [ ] **Step 1: Write failing tests.** Fixture: `platform_fx_micro` install base 70000 at week 0, `topic_fx_space`×action fit 15000, `size_small` audience 100 and price 12.

```gdscript
extends GutTest
var s: GameState; var t: TuningDef

func before_each() -> void:
    s = Fixtures.new_state(1); t = Fixtures.tuning()
    s.market.platform_install_base[&"platform_fx_micro"] = 70000

func _released(overrides := {}) -> int:
    var o := {"phase": Project.Phase.RELEASED, "user_score": 60, "hype": 0}; o.merge(overrides, true)
    return Fixtures.add_project(s, o)

func _tick() -> TickContext:
    var ctx := TickContext.new(s, t); SalesSystem.tick(ctx); return ctx

func test_launch_week_units_and_revenue() -> void:
    var pid := _released()
    _tick()
    # 70000 * 1.5 * 0.01 * 1.0 (hype 0) * 1.0 (score 60 -> 10000) = 1050
    assert_eq(s.projects[pid].weekly_units, [1050] as Array[int])
    assert_eq(s.projects[pid].phase, Project.Phase.LIVE)
    assert_eq(s.projects[pid].revenue, 12600)
    assert_eq(s.companies[1].money, 20000 + 12600)

func test_weekly_decay_from_review_table() -> void:
    var pid := _released(); _tick(); _tick()
    assert_eq(s.projects[pid].weekly_units[1], Fixed.mul_bp(1050, 8600))

func test_retired_platform_doubles_decay() -> void:
    var pid := _released(); _tick()
    s.week = 400
    _tick()
    assert_eq(s.projects[pid].weekly_units[1], Fixed.mul_bp(1050, 7200))

func test_below_floor_retires() -> void:
    var pid := _released({"user_score": 10})
    s.market.platform_install_base[&"platform_fx_micro"] = 100
    _tick()
    assert_eq(s.projects[pid].phase, Project.Phase.RETIRED)
    assert_eq(s.projects[pid].weekly_units.size(), 0)

func test_history_capped_at_104() -> void:
    var pid := _released({"user_score": 100})
    s.market.platform_install_base[&"platform_fx_micro"] = 10000000
    for i: int in 110: _tick()
    assert_eq(s.projects[pid].weekly_units.size(), 104)

func test_publisher_share_and_royalty() -> void:
    var c := Contract.new(); c.id = s.alloc_id(); c.party_a = 1; c.party_b = 8; c.revenue_share_pct = 30
    s.contracts[c.id] = c
    var pid := _released({"contract_id": c.id})
    s.projects[pid].config[&"engine"] = &"lic_engine_fx_pro"   # royalty 1000bp
    _tick()
    # gross 12600; publisher 3780; royalty 1260; net 7560
    assert_eq(s.projects[pid].revenue, 7560)
    assert_eq(s.companies[8].money, 3780)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run suite. Expected: all pass.**
- [ ] **Step 5: Commit** `feat(systems): add launch sales, weekly decay and revenue split`.

---

### Task 19: M2a acceptance scenario and determinism

**Files:**
- Create: `tests/helpers/place_equipment_command.gd`, `tests/scenario/test_m2a_playthrough.gd`
- Modify: `tests/helpers/scenario.gd`

**Interfaces:**
- Consumes: everything above, plus the real content (Tasks 10–12).
- Produces:
  - `PlaceEquipmentCommand` (tests only, `class_name PlaceEquipmentCommand extends Command`), `_init(p_company_id: int, p_def_id: StringName, p_seat: int)`. Apply: a new BOUGHT `Equipment` at that seat, then emit `equipment_changed`. This stands in for M2b's `BuyEquipment`.
  - `Scenario` gains:
    - command specs `["place_equipment", def, seat]`, `["start_game", title, size, platform, topic, genre, engine, features]`, `["start_engine", title, features]`, `["sliders_ideal"]`, `["release"]`, `["buy_research", id]` and `["buy_dev_kit", platform]`;
    - `engine` is `"last_engine"` (the highest engine id) or a licensed id;
    - `sliders_ideal` submits `SetSlidersCommand.new(<latest GAME project id>, genre.ideal_sliders.duplicate())`, so the scenario exercises SetSliders;
    - `release` targets the latest GAME project in POLISH.
  - `Scenario.advance(state, script, weeks)` gains an optional `content: ContentDB = null`; when it is given, it calls `ContentDB.use(content)` first.
  - Script:

```gdscript
const SCRIPT_M2A: Dictionary = {
    0:  [["hire", "Ada", 800], ["place_equipment", "equipment_micro_1980", 1],
         ["start_game", "Star Run", "size_small", "platform_nova8", "topic_space", "genre_action", "lic_engine_homebrew", []],
         ["sliders_ideal"]],
    20: [["release"]],
    22: [["buy_research", "research_scrolling"], ["start_engine", "Scroll Engine", ["feature_scrolling"]]],
    28: [["buy_dev_kit", "platform_arcadia"],
         ["start_game", "Kick Arena", "size_small", "platform_arcadia", "topic_sports", "genre_action", "last_engine", ["feature_scrolling"]],
         ["sliders_ideal"]],
    48: [["release"]],
}
```

  Timeline: game 1 is in POLISH after week 18. The engine (4 dev weeks) finishes by week 26. Game 2 is in POLISH after week 46. If a command is rejected, `Scenario` fails loudly (existing behaviour). Report the reason key as `BLOCKED`; do not move the weeks without saying why.

- [ ] **Step 1: Write the scenario tests**

```gdscript
# tests/scenario/test_m2a_playthrough.gd
extends GutTest
const WEEKS := 80
var real: ContentDB

func before_all() -> void:
    real = ContentDB.load_dir()

func after_all() -> void:
    ContentDB.use(Fixtures.content())

func _run(seed: int, weeks: int = WEEKS) -> GameState:
    var s := Fixtures.new_state(seed)
    Scenario.advance(s, Scenario.SCRIPT_M2A, weeks, real)
    return s

func _games(s: GameState) -> Array[Project]:
    var out: Array[Project] = []
    for id: int in s.sorted_ids(s.projects):
        if s.projects[id].kind == Project.Kind.GAME: out.append(s.projects[id])
    return out

func test_playthrough_reaches_every_m2a_milestone() -> void:
    var s := _run(2026)
    assert_eq(s.staff.size(), 2)
    assert_has(s.companies[1].unlocked, &"research_scrolling")
    assert_has(s.companies[1].dev_kits, &"platform_arcadia")
    assert_eq(s.engines.size(), 1)
    var games := _games(s)
    assert_eq(games.size(), 2)
    for g: Project in games:
        assert_true(g.phase >= Project.Phase.RELEASED)
        assert_eq(g.review_results.size(), 4)
        for r: ReviewResult in g.review_results:
            assert_ne(tr(r.strength_key), String(r.strength_key))
            assert_ne(tr(r.weakness_key), String(r.weakness_key))
    assert_gte(games[0].weekly_units.size(), 20)
    assert_true(games[0].units_sold > 0 and games[1].units_sold > 0)
    assert_eq(games[1].engine_id, s.engines.keys()[0])
    assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
    assert_eq(real.missing_refs(s), [] as Array[String])

func test_review_reasons_match_dimensions() -> void:
    var s := _run(2026)
    for g: Project in _games(s):
        var dims := ReviewSystem.dimension_scores(s, real, Fixtures.tuning(), g.id)
        for r: ReviewResult in g.review_results:
            var o: ReviewOutletDef = real.outlets[r.outlet_id]
            var expect := ReviewSystem.outlet_review(dims, o, real, RandomNumberGenerator.new(), Fixtures.tuning())
            assert_eq(r.strength_key, expect.strength_key)
            assert_eq(r.weakness_key, expect.weakness_key)

func test_same_seed_same_hash() -> void:
    assert_eq(StateHash.of(_run(7)), StateHash.of(_run(7)))

func test_different_seed_different_hash() -> void:
    assert_ne(StateHash.of(_run(7)), StateHash.of(_run(8)))

## 0 and 28 are command weeks, 13 and 26 are quarter starts, 20 is a release week, 50 is during sales.
func test_save_load_continue_matches_uninterrupted() -> void:
    var full := StateHash.of(_run(7))
    for save_week: int in [0, 13, 20, 28, 50]:
        var s := Fixtures.new_state(7)
        Scenario.advance(s, Scenario.SCRIPT_M2A, save_week, real)
        var loaded := SaveService.deserialize(SaveService.serialize(s))
        assert_true(loaded.ok, "load at %d" % save_week)
        Scenario.advance(loaded.state, Scenario.SCRIPT_M2A, WEEKS - save_week, real)
        assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)

func test_values_stay_in_range() -> void:
    var s := _run(7)
    for id: int in s.sorted_ids(s.staff):
        assert_between(s.staff[id].morale, 0, 100)
    for g: Project in _games(s):
        assert_between(g.user_score, 10, 100)
        assert_true(g.bugs >= 0)
```

- [ ] **Step 2: Implement `PlaceEquipmentCommand` and the `Scenario` additions.**
- [ ] **Step 3: `godot --headless --import`, run suite. Expected: all pass, including the M1 `test_determinism.gd`.** If a determinism test fails, stop and report `BLOCKED` with both hashes and the first save week that differs. Do not weaken the assertion. The usual cause is an unsorted Dictionary iteration or a StringName key inserted in a different order after load.
- [ ] **Step 4: Commit** `test: add M2a acceptance playthrough and determinism checks`.

---

### Task 20: Sync the specs with this plan's rulings

**Files:**
- Modify: `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md`, `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md`

M2 spec line 6 says a foundation section the M2 spec changes must be updated in the plan that implements the change.

- [ ] **Step 1: Foundation spec.**
  - §3.3: Staff, Project and Contract list the M2 fields, or point to M2 §4.
  - §3.4: the content table gains the §4.7 classes and the PlatformDef, ProjectSizeDef and TopicDef fields as built.
  - §4.2: replace the order with "see M2 spec §5".
  - §5.2: add the §10 signals.
  - §6.2: replace the tech-vs-creative focus with the 9 sliders.
- [ ] **Step 2: M2 spec.** Write in the rulings that change its text:
  - A6: `target_points` is a dictionary.
  - A8: all 15 systems are listed in M2a.
  - A13: `stage_progress` is in bp.
  - A15: `price` and `par_points` on ProjectSizeDef, and `genre_fit_bp` on PlatformDef.
  - A4 and A5: `Staff.week_points` and `hired_week`.
- [ ] **Step 3: Commit** `docs: sync specs with M2a rulings`. Docs only; no test run needed beyond confirming the suite is still green.

---

## Spec coverage (self-review)

| Spec item | Task |
|---|---|
| §3 numbers rule, TuningDef initial values | 1 (table), all tasks |
| §4.1 GameState additions | 6 |
| §4.2 Company additions, new kinds, AI companies at new game | 4, 6 |
| §4.3 Staff additions; §7.2a `level`, `title` | 4 |
| §4.4 new entities | 3 |
| §4.5 Project changes | 5 |
| §4.6 Contract changes | 4 (A6, A7) |
| §4.7 content classes incl. LevelDef, PlatformDef additions | 1 |
| §4.8 Removal + rule test | 7 |
| §4.9 decision detection | 8 |
| §5 tick order | 8 (A8) |
| §6.1 concept / StartProject | 15 |
| §6.2 topic+genre fit, best-review label | 11 (data), 17 (`combo_label_key`) |
| §6.3 production, slider match, bugs, bubbles | 16, 17 (match) |
| §6.4 engine projects | 15, 16 |
| §6.5 research | 14, 11 |
| §6.6 reviews, sales, revenue | 17, 18 |
| §6.7 platforms | 10, 13, 18 |
| §7.2 seat rule for HireStaff | 9 |
| §9 M2a commands (StartProject, SetSliders, ReleaseProject, BuyResearch, BuyDevKit) | 14, 15, 17 |
| §10 events | 8 |
| §12 validator per field | 4, 5, 6 |
| §13 acceptance scenario (M2a part) and determinism | 19 |
| §13 rule tests | 7 |
| M2 spec line 6: foundation sync | 20 |

Left for later plans on purpose: owner xp and perks, staff economy, candidate refresh, equipment buy, lease and sell, office moves, rent and electricity, loans, contract work, bankruptcy (M2b); marketing, promotions, patches, DLC, forum, mod tools and awards (M2c); scene and panels (M2d). Their data shapes and stubs exist after Tasks 1–8.
