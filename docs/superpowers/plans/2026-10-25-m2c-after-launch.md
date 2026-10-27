# Milestone 2c: After Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The post-launch half of the loop, headless and deterministic: marketing channels and hype, promotions with fatigue, patches, DLC, a forum with replies and sentiment, mod tools, and a yearly game award.

**Architecture:** Task 1 is the only task that edits surfaces M2b also touches (TuningDef, content defs, `Project`/`Company`, validator, `ContentDB.missing_refs`, `Removal`, fixtures). After it, every code task stays inside M2c-owned files (`marketing_system.gd`, `live_ops_system.gd`, `awards_system.gd`, new commands), except Task 4 (`sales_system.gd`) and one guard line in `start_project_command.gd` (Task 7). Spending uses the existing company-cash path (`company.money -= cost`, emit `money_changed`), as `BuyDevKitCommand` does. No new EventBus signals, no tick-order change, no schema bump.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), GUT 9.x.

**Spec:** `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` §3, §4.5, §4.7, §5 steps 10–13, §8, §9, §12. Foundation `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md` §6.4–§6.5 and §7.4 still apply where M2 is silent.

## Global Constraints

- Godot at `/Users/chanapols/homebrew/bin/godot`. The path has a leading space: always quote `"/Users/chanapols/Projects/ game-dev"`.
- `CLAUDE.md` hard rules 1–10 apply to every task: `RefCounted` data, stateless systems, `ctx.rng` only, ids not references, `tr()` keys, JSON saves, tuning in `TuningDef`, no floats in state, sorted iteration.
- Numbers follow M2 spec §3. Use `int` everywhere. Hype and sentiment are points, `score_x10` runs 10–100, ratios are `_bp`. Use one `Fixed.mul_bp` step per tick. Chances use `Fixed.roll_bp(ctx.rng, chance_bp)`, which is exactly one draw. Noise uses `ctx.rng.randi_range(a, b)`.
- **Money path (Ruling C1).** A cost is checked in `validate` (`money < cost` → `error.not_enough_money`). `apply` then does `company.money -= cost` and emits `money_changed {company_id, money}`. Income from sales goes only through `SalesSystem.book_sale` (Task 4). Award prizes are added directly in `AwardsSystem` and also emit `money_changed`. Do not add a spend helper and do not edit `finance_system.gd`, which M2b owns.
- `schema_version` stays 1 (§12). New fields are added to `SCHEMA`, `to_dict`, `from_dict` and the validator in the same task.
- Iterate projects with `state.sorted_ids`, and content with `GameState.sorted_names`. Draw RNG only when something is eligible, and in the order each task states.
- Content ids are prefixed: `channel_`, `award_`, `size_`, `research_`. Fixture ids use the `_fx_` infix, except `size_dlc`. `size_dlc` is shared by the fixtures and the real data so that `tuning.dlc_size_id` works for both.
- Forum posts are deleted only through `Removal.remove_forum_post` (Task 1), never by `remove_at` elsewhere.
- Code tasks never edit `locale/strings.csv`. Task 2 (content) authors every M2c key. Code tests compare reason keys, not text.
- New tests go in **new** files (`*_m2c.gd` or per-command files). Do not append to M2a test files, because M2b appends to them too. One exception: Task 4 must update one line in `tests/unit/test_sales_system.gd`.
- `ContentDB.active()` is process-wide. Tests reach commands and systems through `Fixtures.new_state()`. Scenario tests install real content and restore `Fixtures.content()` in `after_all`.
- Commit once per task with Conventional Commits and the agent's `Co-Authored-By` line. Stage by explicit path. Run `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd -gexit`, judge by exit code and quote the totals line.

## Rulings made by this plan

| # | Ruling | Why |
|---|---|---|
| C1 | Spending (marketing, award entry) uses the existing cash path: validate `money >= cost`, then `company.money -= cost` and emit `money_changed`. Patches, DLC and mod tools cost staff time only, paid by the existing monthly payroll. | §8 says patches cost "staff weeks"; M2a `StartProject` charges no money either. M2b's loans and bankruptcy read the same `company.money`. |
| C2 | New `Project` fields: `parent_id: int = -1` (the DLC's original game), `enum LiveTask { NONE, PATCH, MOD_TOOLS }` with `live_task: LiveTask = NONE` and `live_task_left: int = 0` (staff-weeks left), `award_entry: StringName = &""` (an award id entered for the next ceremony), `sales_base_units: int = 0` (the un-boosted weekly units the decay chain runs on). New `Company.promo_fatigue: int = 0` (hype points, 0–100). | §4.5 has no field for the DLC link, post-launch tasks, award entries or the decay base. Without `sales_base_units`, promo and viral boosts written into `weekly_units` would compound into the tail. |
| C3 | `weekly_units` stays "units sold that week" (the graph). Decay and the retirement floor use `sales_base_units`. A promotion multiplies only that week's sold units and price. A DLC launch raises the parent's `sales_base_units` (a tail extension). A viral mod sells bonus units that week only. | §8: the promotion uplift, the DLC "tail extension" and the viral "spike". |
| C4 | `MarketingChannelDef` gains `weeks_in_year: Array[int]` (an empty array means any week). `ProjectSizeDef` gains `dlc: bool`. `StartProject.game` refuses a `dlc` size with `error.size_dlc_only`. | Trade shows have fixed dates. DLC needs a size def (production, reviews and sales read `content.sizes`), but that size must not appear as a normal game size. |
| C5 | Hype decays only for GAME projects in PRODUCTION or POLISH, by `hype_decay_bp` each week, whether or not a channel ran. A RELEASED project keeps its hype for the first sales tick (Marketing is step 10, before Sales at step 11). | §3 "one mul_bp step per tick". Foundation §6.4 says "when no action runs", but that needs a per-project last-run field for a negligible difference. |
| C6 | The channel `segment` is stored and shown but has no effect in M2, because there is no segment model in Sales yet. | There is no audience-segment math in M2a sales. M3's market owns it. |
| C7 | Promotion discount must be a multiple of `promo_discount_step_bp` (1000), from 1× to `promo_uplift_table_bp.size()`× (1000–5000). Uplift = `promo_uplift_table_bp[discount / step − 1]`. `promo_until_week` is the **last** sales week of the promotion (inclusive): `state.week + weeks` at apply time. Fatigue: when the company's latest `promo_until_week` (−1 = never) is within `promo_fatigue_window_weeks` (26) of the new promotion's start week, `promo_fatigue += promo_fatigue_hype` (cap 100). The launch hype factor uses `max(0, hype − promo_fatigue)`. Fatigue falls by `promo_fatigue_recovery_per_month` each month start. | §8 gives the 1000–5000 range and `PROMO_UPLIFT_TABLE[discount]`, but no index rule and no recovery. Fatigue that never recovers would be a permanent penalty. |
| C8 | Patch and mod tools reuse `Staff.assigned_project_id` pointing at the LIVE game. Each command assigns every free worker, like `StartProject`. LiveOps lowers `live_task_left` by 1 per working staff per week. On completion, or when the project is no longer LIVE, LiveOps clears the task and unassigns the staff. `StartPatch` requires `bugs > 0`. | Production ignores LIVE projects and `free_workers` already excludes assigned staff, so no new staffing model is needed. |
| C9 | A DLC is a GAME project with `parent_id` set and `size_id = tuning.dlc_size_id`. It copies the parent's config, `engine_id` and features, and is released with `ReleaseProject` (it gets its own reviews and sales). The parent must be LIVE and must not itself be a DLC, and only one DLC per parent can be in development at a time. On the DLC's first LIVE sales week, the parent (if LIVE) gets `sales_base_units = mul_bp(base, 10000 + max(0, dlc_tail_uplift_bp − (mod_dlc_penalty_bp if parent.mod_tools)))`. | §8 "small GAME project linked to the original; sales tail extension". |
| C10 | `Project.sentiment` is clamped to −100..100. Sales decay = review table + `mod_tail_bp` (if `mod_tools`) + `sentiment × sentiment_decay_bp_per_point`, clamped to `[0, sales_decay_max_bp]`. The retired-platform doubling (Ruling A17) applies after that clamp. | Foundation §7.4: the decay rate improves with positive sentiment. Without the clamp, high score + mod + sentiment exceeds 10000 and sales grow forever. |
| C11 | Forum posts are `ForumPost`s, not Decisions, so they never auto-pause the game. Each week, each LIVE GAME project draws one `roll_bp` at `min(max, base + bugs × per_bug)`. On a hit, the topic is `forum.post.bugs` (needs bugs > 0) or `forum.post.weakness` (needs reviews). One `randi_range(0, 1)` picks between them only when both are possible (0 = bugs). Post sentiment `forum_post_sentiment` is added to the project. The list is capped at `forum_posts_cap`, and the oldest post is dropped via `Removal`. Replies: `apologise` (+`forum_apologise_sentiment`), `promise_patch` (+`forum_promise_sentiment`, valid only while a PATCH task runs on that project) and `ignore` (0). Each post accepts one reply. | §8 lists the reply options but no numbers. A promise with nothing behind it would be free sentiment. |
| C12 | Mod viral: at each month start, each LIVE GAME project with `mod_tools` draws one `roll_bp(mod_viral_chance_bp)`. On a hit: `fan_count += mod_viral_fans`, a bonus sale of `mul_bp(sales_base_units, mod_viral_units_bp)` units through `book_sale` (also added to `weekly_units.back()`), and a `forum.post.mod_viral` post (sentiment `+mod_viral_sentiment`, `replied = true`). | §8: "fans + sales spike". It uses the forum feed, so no new signal is needed. |
| C13 | Award entries live in `Project.award_entry`. Eligible: kind GAME, `parent_id == -1`, `release_week >= 0`, has reviews, and `0 <= ceremony_week − release_week <= award_window_weeks`. The ceremony runs on the tick whose (already incremented) week has `week_in_year == def.week_in_year`. The entry score is the **average review `score_x10`** (not `user_score`, which patches raise) + `randi_range(0, award_bonus_max_x10)`. AI: `award_ai_entries` × `randi_range(award_ai_score_min_x10, award_ai_score_max_x10)`. The player wins only with a **strictly** higher score (ties go to the AI); between player entries, the lower project id wins ties. Prize: `money += prize`, `fan_count += fans`, `reputation += award_reputation` (cap 100), and the award id is appended to `company.awards`. All entries are cleared after the ceremony, and the fee for an ineligible entry is lost. | §8, plus the tie rule, the score source and the reputation amount it leaves open (`AwardDef` has no reputation field). |
| C14 | No new EventBus signals. Uses `project_changed`, `promotion_started`, `forum_post_created`, `award_result`, `money_changed`, `sales_updated` and `project_phase_changed`. | §10 fixes the signal list. M2b and M2d run in parallel. |
| C15 | Command-facing rule helpers live in the M2c system files (`MarketingSystem`, `LiveOpsSystem`, `AwardsSystem`, `SalesSystem`), not in `GameRules` or `StateQueries`. The M2d panels can call a command's `validate` (read-only) to grey out buttons. | Keeps M2c out of files M2b edits. |

---

## Review Focus

1. **The project stops being LIVE while a patch or mod-tools task runs** (sales fall below the floor). The task must clear and the staff must be freed, otherwise they are stuck forever because `free_workers` skips them. Test: Task 6 `test_task_cancelled_when_project_retires`.
2. **A promotion ends.** Sales must return to the un-boosted decay curve, not decay from the boosted week. Test: Task 4 `test_promo_boost_does_not_enter_tail`.
3. **Score 100 + mod tools + sentiment 100.** Decay must clamp at `sales_decay_max_bp`, so the game still retires eventually. Test: Task 4 `test_decay_clamped_at_max`.
4. **An award ceremony with no entries, or only ineligible ones.** No RNG may be drawn and no prize paid, and entries must still be cleared. Test: Task 9 `test_ceremony_without_eligible_entries_draws_no_rng`.
5. **The forum list hits its cap.** The oldest post goes through `Removal` and the state still validates. Save/load mid-promotion, mid-patch and on the award week must match an uninterrupted run. Tests: Task 8 `test_forum_cap_drops_oldest`, Task 10 `test_save_load_continue_matches_uninterrupted`.

---

## File map

```
src/content/tuning_def.gd, data/tuning.tres                         T1 (M2c block)
src/content/{marketing_channel_def,project_size_def}.gd             T1
src/core/entities/{project,company}.gd                              T1
src/core/state_validator.gd, src/core/content_db.gd (missing_refs)  T1
src/core/removal.gd                                                 T1
tests/helpers/fixtures.gd                                           T1 (one call + _m2c_defs())
data/{channels,awards}/, data/sizes/size_dlc.tres, data/research/research_tv_advertising.tres, locale/strings.csv   T2 (content)
src/systems/marketing_system.gd, src/core/commands/run_marketing_command.gd                       T3
src/systems/sales_system.gd (+1 line in tests/unit/test_sales_system.gd)                          T4
src/core/commands/start_promotion_command.gd                                                       T5
src/systems/live_ops_system.gd, src/core/commands/{start_patch,build_mod_tools}_command.gd         T6
src/core/commands/start_dlc_command.gd, start_project_command.gd (1 guard), live_ops_system.gd     T7
src/core/commands/reply_forum_command.gd, live_ops_system.gd                                       T8
src/systems/awards_system.gd, src/core/commands/enter_award_command.gd                             T9
tests/helpers/{scenario_m2c.gd, scenario.gd (1 line)}, tests/scenario/test_m2c_playthrough.gd     T10
docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md                                     T11 (docs)
```

## Parallel groups

| Group | Tasks | Depends on |
|---|---|---|
| P1 | 1 | — |
| P2 | 2 (content), 3, 4, 6, 9 | 1 (disjoint files); 3 also ← M2b T3 |
| P3 | 5, 7 | 5 ← 3, 4; 7 ← 4, 6 |
| P4 | 8 | 4, 7 (shares `live_ops_system.gd`) |
| P5 | 10 | 2, 3, 5, 8, 9 |
| P6 | 11 | 10 |

---

### Task 1: M2c data shapes (code, `gd-implementer`)

**Depends on:** none.

**Files:**
- Modify: `src/content/tuning_def.gd`, `data/tuning.tres`, `src/content/marketing_channel_def.gd`, `src/content/project_size_def.gd`, `src/core/entities/project.gd`, `src/core/entities/company.gd`, `src/core/state_validator.gd`, `src/core/content_db.gd`, `src/core/removal.gd`, `tests/helpers/fixtures.gd`
- Test: `tests/unit/test_entities_m2c.gd`, `tests/unit/test_state_validator_m2c.gd`

**Interfaces:**
- Produces:
  - `TuningDef` M2c block (append after `sales_floor_units`, under a `## M2c` comment; same values in `data/tuning.tres`; the existing `test_shipped_tuning_matches_script_defaults` enforces equality):

```
hype_decay_bp = 9500                     promo_discount_step_bp = 1000
promo_max_weeks = 4                      promo_uplift_table_bp: Array[int] = [13000, 16000, 19000, 22000, 25000]
promo_fatigue_window_weeks = 26          promo_fatigue_hype = 5
promo_fatigue_recovery_per_month = 1     patch_staff_weeks = 4
patch_bugs_per_staff_week = 5            patch_user_score_x10 = 3
patch_sentiment = 5                      mod_tools_staff_weeks = 8
mod_tail_bp = 300                        mod_dlc_penalty_bp = 2000
mod_viral_chance_bp = 500                mod_viral_fans = 2000
mod_viral_units_bp = 10000               mod_viral_sentiment = 10
dlc_size_id: StringName = &"size_dlc"    dlc_tail_uplift_bp = 5000
forum_post_base_chance_bp = 500          forum_post_chance_per_bug_bp = 50
forum_post_max_chance_bp = 3000          forum_post_sentiment = -5
forum_apologise_sentiment = 3            forum_promise_sentiment = 8
forum_posts_cap = 40                     sentiment_decay_bp_per_point = 5
sales_decay_max_bp = 9800                award_window_weeks = 52
award_bonus_max_x10 = 8                  award_ai_entries = 3
award_ai_score_min_x10 = 50              award_ai_score_max_x10 = 85
award_reputation = 5
```

  - `MarketingChannelDef.weeks_in_year: Array[int] = []` and `ProjectSizeDef.dlc: bool = false`.
  - `Project`: `enum LiveTask { NONE, PATCH, MOD_TOOLS }`. Fields as in Ruling C2. `SCHEMA` keys: `"parent_id": "int"`, `"live_task": "string"` (enum name), `"live_task_left": "int"`, `"award_entry": "string"`, `"sales_base_units": "int"`.
  - `Company.promo_fatigue: int = 0` (`SCHEMA` `"promo_fatigue": "int"`).
  - Validator:
    - `_project_ok` rejects an unknown `live_task` name, `live_task_left < 0`, `sales_base_units < 0` and `sentiment` outside −100..100.
    - The project reference loop rejects `parent_id` that is neither −1 nor an existing project id, and `parent_id == id`.
    - `_company_ok` rejects `promo_fatigue` outside 0..100.
  - `ContentDB.missing_refs`: `"project %d: unknown award %s"` when `award_entry != &""` and not in `awards`.
  - `Removal.remove_forum_post(state: GameState, post_id: int) -> bool`. It removes the post from `state.forum_posts` and calls `_drop_decisions_about(state, post_id)`. It returns false when no such post exists.
  - `Fixtures.content()`: add one line `for d: Resource in _m2c_defs(): db.add(d)` before `_content = db`, plus `static func _m2c_defs() -> Array[Resource]` at the end of the file, returning:
    - `channel_fx_ad`: years 1975–1999, cost 500, hype_gain 20, segment `&"core"`, any week.
    - `channel_fx_show`: years 1975–1999, cost 2000, hype 30, `weeks_in_year [10, 11]`.
    - `channel_fx_tv`: years 1975–1999, cost 4000, hype 40.
    - `channel_fx_old`: years 1970–1975, cost 100, hype 5.
    - `research_fx_tv`: cost 30, unlocks `[channel_fx_tv]`.
    - `award_fx`: `week_in_year` 50, `entry_fee` 1000, `prize` 10000, `fans` 500.
    - `size_dlc`: base_weeks 6, min_staff 1, cost_bp 5000, audience 40, price 6, par 3000, `dlc = true`.

- [ ] **Step 1: Write failing tests.**

```gdscript
# tests/unit/test_entities_m2c.gd
func test_project_m2c_fields_round_trip() -> void:
    var p := Project.new(); p.id = 5; p.company_id = 1; p.parent_id = 3
    p.live_task = Project.LiveTask.MOD_TOOLS; p.live_task_left = 6
    p.award_entry = &"award_fx"; p.sales_base_units = 777; p.sentiment = -40
    var back := Project.from_dict(Fixtures.json_round_trip(p.to_dict()))
    assert_eq([back.parent_id, back.live_task, back.live_task_left, back.award_entry, back.sales_base_units, back.sentiment],
        [3, Project.LiveTask.MOD_TOOLS, 6, &"award_fx", 777, -40])
func test_company_promo_fatigue_round_trip() -> void  # 12 survives
func test_remove_forum_post_keeps_state_valid() -> void:
    # state with one ForumPost (id alloc_id, project from Fixtures.add_project) + a Decision whose related_ids has the post id
    # Removal.remove_forum_post -> true; forum_posts empty; pending_decisions empty; validate_dict(json_round_trip) true
    # second call -> false
func test_missing_refs_flags_unknown_award_entry() -> void  # award_entry = &"award_gone" -> one message containing "award_gone"
func test_fixture_m2c_content() -> void  # channels.size() == 4, awards has award_fx, sizes[&"size_dlc"].dlc == true
```

```gdscript
# tests/unit/test_state_validator_m2c.gd  (pattern: build state, to_dict, json_round_trip, mutate, assert_false(validate_dict))
test_new_game_state_is_valid
test_rejects_unknown_parent_id          # parent_id = 9999
test_rejects_self_parent                # parent_id = own id
test_rejects_bad_live_task              # "live_task" = "REFUND"
test_rejects_negative_live_task_left
test_rejects_negative_sales_base_units
test_rejects_sentiment_out_of_range     # 101 and -101
test_rejects_promo_fatigue_out_of_range # 101 and -1
test_accepts_dlc_with_valid_parent      # parent_id = another project id
```

- [ ] **Step 2: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gexit -gselect=m2c`. **Expected:** FAIL (unknown members).
- [ ] **Step 3: Implement** the interfaces above. Serialize the enum with `LiveTask.keys()[live_task]` and read it back with `LiveTask[String(d["live_task"])]`, like `phase`.
- [ ] **Step 4: Run** `godot --headless --import`, then the full suite. **Expected:** all pass.
- [ ] **Step 5: Commit** `feat(core): add M2c project, company, tuning and content fields`.

---

### Task 2: M2c content and strings (content, `gd-content-author`)

**Depends on:** 1.

**Files:**
- Create: `data/channels/channel_magazine_ad.tres`, `channel_tv_spot.tres`, `channel_trade_show.tres`, `channel_mail_order.tres`; `data/awards/award_golden_cartridge.tres`; `data/sizes/size_dlc.tres`; `data/research/research_tv_advertising.tres`
- Modify: `locale/strings.csv` (append one `# M2c` block at the end)
- Test: `tests/unit/test_content_data_m2c.gd`, `tests/unit/test_localization_m2c.gd`

**Values** (all fictional; ints only):

| id | fields |
|---|---|
| `channel_magazine_ad` | name_key `content.channel.magazine_ad.name`, year 1975–1999, cost 800, hype_gain 25, segment `core`, weeks `[]` |
| `channel_mail_order` | `content.channel.mail_order.name`, 1975–1999, cost 400, hype 10, segment `casual`, `[]` |
| `channel_trade_show` | `content.channel.trade_show.name`, 1975–1999, cost 2500, hype 35, segment `core`, weeks `[22, 23, 24, 25]` |
| `channel_tv_spot` | `content.channel.tv_spot.name`, 1980–1999, cost 4000, hype 45, segment `casual`, `[]` |
| `research_tv_advertising` | `content.research.tv_advertising.name`, cost_rp 150, prerequisites `[]`, unlocks `[channel_tv_spot]` |
| `award_golden_cartridge` | `content.award.golden_cartridge.name` ("Golden Cartridge Awards"), week_in_year 50, entry_fee 500, prize 15000, fans 3000 |
| `size_dlc` | `content.size.dlc.name`, base_weeks 6, min_staff 1, cost_multiplier_bp 5000, audience_bp 40, price 6, par_points 3000, dlc true |

**Strings (EN + TH):**
- The 7 name keys above.
- `forum.post.bugs` ("Players report bugs in {title}.").
- `forum.post.weakness` ("Players agree with the critics about {title}: {reason}").
- `forum.post.mod_viral` ("A fan mod for {title} is going viral!").
- `forum.reply.apologise`, `forum.reply.promise_patch`, `forum.reply.ignore`.
- Error keys: `error.channel_not_found`, `error.channel_unavailable`, `error.project_not_marketable`, `error.project_not_live`, `error.promo_active`, `error.invalid_discount`, `error.invalid_promo_weeks`, `error.live_task_running`, `error.no_bugs`, `error.mod_tools_built`, `error.dlc_of_dlc`, `error.dlc_in_progress`, `error.size_dlc_only`, `error.post_not_found`, `error.post_replied`, `error.invalid_reply`, `error.no_patch_running`, `error.award_not_found`, `error.award_entered`, `error.award_not_eligible`.

- [ ] **Step 1: Write failing tests.**
  - `test_content_data_m2c.gd`:
    - `test_real_content_still_valid`: `errors` and `validate()` are both empty.
    - `test_m2c_channels_award_size`: 4 channels; `channel_trade_show.weeks_in_year == [22, 23, 24, 25]`; `award_golden_cartridge.week_in_year == 50`; `sizes[&"size_dlc"].dlc`.
    - `db.is_unlocked([], &"channel_magazine_ad")` is true and `db.is_unlocked([], &"channel_tv_spot")` is false.
    - Every channel and award `name_key` translates.
  - `test_localization_m2c.gd`: every key above has a non-key translation in `en` and in `th`. Reset the locale to `en` in `after_each`.
- [ ] **Step 2: Run** with `-gselect=m2c`. **Expected:** FAIL.
- [ ] **Step 3: Author** the files (see the `content-authoring` skill; the `.tres` header style follows `data/sizes/size_small.tres`).
- [ ] **Step 4: Run** `--import`, then the full suite. **Expected:** all pass.
- [ ] **Step 5: Commit** `feat(content): add 1980s marketing channels, award, DLC size and M2c strings`.

---

### Task 3: Marketing channels and hype (code, `gd-implementer`)

**Depends on:** 1, and M2b Task 3 (`PeopleRules.effect_bp`). Do not start before M2b Task 3 is merged.

**Files:**
- Modify: `src/systems/marketing_system.gd`
- Create: `src/core/commands/run_marketing_command.gd`
- Test: `tests/unit/test_marketing_m2c.gd`

**Interfaces:**
- Produces:
  - `MarketingSystem.channel_block_key(state: GameState, content: ContentDB, t: TuningDef, company_id: int, channel_id: StringName) -> StringName`. It returns `&""` when the channel can be booked now; otherwise it returns, in this order:
    - `error.channel_not_found`;
    - `error.item_locked` (`GameRules.is_unlocked`);
    - `error.channel_unavailable` when `Calendar.year(state.week, t)` is outside `year_from..year_to`, or when `weeks_in_year` is non-empty and does not contain `Calendar.week_in_year(state.week, t)`.
  - `MarketingSystem.hype_gain(state: GameState, content: ContentDB, channel: MarketingChannelDef) -> int`: `channel.hype_gain`. M2b's Promoter perk hook (M2b plan cross-plan contract): once `PeopleRules.effect_bp` exists (M2b Task 3), return `Fixed.mul_bp(channel.hype_gain, Fixed.ONE_BP + PeopleRules.effect_bp(state, content, &"hype_gain_bp"))`. `PeopleRules` is on the branch by then (see Depends on); no plain-value fallback.
  - `MarketingSystem.last_promo_end(state: GameState, company_id: int) -> int`: the max `promo_until_week` over the company's projects, or −1. Task 5 uses it.
  - `MarketingSystem.tick(ctx)`:
    1. For each GAME project in PRODUCTION or POLISH (sorted): `hype = mul_bp(hype, hype_decay_bp)`.
    2. On `Calendar.is_month_start`: each company (sorted) gets `promo_fatigue = max(0, promo_fatigue − promo_fatigue_recovery_per_month)`.
    - No RNG and no events.
  - `RunMarketingCommand._init(p_project_id: int, p_channel_id: StringName)`.
    - Validate, in order:
      - `error.project_not_found`;
      - `error.project_not_marketable` unless kind GAME and phase PRODUCTION or POLISH;
      - `channel_block_key` (for the project's company);
      - `error.not_enough_money` when `money < cost`.
    - Apply: pay the cost (Ruling C1), then `hype = mini(100, hype + MarketingSystem.hype_gain(...))`. Emit `money_changed` and `project_changed {project_id}`.

- [ ] **Step 1: Write failing tests** (fixture content from Task 1; `state.week = 0` is year 1980; start money 20000).

```gdscript
test_run_marketing_charges_and_adds_hype      # PRODUCTION project hype 10 + channel_fx_ad -> hype 30, money 19500
test_hype_caps_at_100                         # hype 95 -> 100
test_polish_project_can_market                # ok
test_released_project_rejected                # error.project_not_marketable
test_unknown_channel_rejected                 # error.channel_not_found
test_locked_channel_rejected                  # channel_fx_tv -> error.item_locked; after companies[1].unlocked.append(&"research_fx_tv") -> ok
test_out_of_era_channel_rejected              # channel_fx_old -> error.channel_unavailable
test_trade_show_only_on_its_weeks             # week 9 -> error.channel_unavailable; week 10 -> ok
test_not_enough_money_rejected                # money 499 -> error.not_enough_money; money 500 -> ok (exact cost allowed)
test_tick_decays_hype_in_development_only     # PRODUCTION hype 50 -> 47; RELEASED hype 50 -> 50
test_month_start_recovers_fatigue             # week 0 fatigue 3 -> 2; week 1 fatigue 3 -> 3; fatigue 0 stays 0
```

- [ ] **Step 2: Run** `-gselect=test_marketing_m2c`. **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** all pass.
- [ ] **Step 5: Commit** `feat(systems): add marketing channels and weekly hype decay`.

---

### Task 4: Sales base units, promotions, sentiment and mod tail (code, `gd-implementer`)

**Depends on:** 1.

**Files:**
- Modify: `src/systems/sales_system.gd`; one line in `tests/unit/test_sales_system.gd` (`test_below_floor_retires_after_launch`, or wherever line 76 sets `weekly_units[0] = 11`: also set `s.projects[pid].sales_base_units = 11`).
- Test: `tests/unit/test_sales_m2c.gd`

**Interfaces:**
- Produces (Rulings C3, C7, C10):
  - `SalesSystem.promo_active(p: Project, week: int) -> bool`: `p.promo_discount_bp > 0 and week <= p.promo_until_week`.
  - `SalesSystem.promo_uplift_bp(t: TuningDef, discount_bp: int) -> int`: `t.promo_uplift_table_bp[clampi(discount_bp / t.promo_discount_step_bp − 1, 0, size − 1)]`.
  - `SalesSystem.unit_price(content: ContentDB, p: Project, week: int) -> int`: `size.price`, or `mul_bp(size.price, 10000 − promo_discount_bp)` while `promo_active`.
  - `SalesSystem.book_sale(ctx: TickContext, p: Project, units: int, price: int) -> int`. This is the existing revenue block moved out unchanged: `units_sold += units`, `gross = units × price`, publisher share, royalty, `revenue += net`, company `money += net`, and `sales_updated` + `money_changed`. It returns `net`.
  - `launch_units(...)` uses `maxi(0, p.hype − company.promo_fatigue)` for the hype table, where company is `p.company_id`, with fatigue 0 if the company is missing.
  - `decay_bp(content, t, p, week)` per Ruling C10: `d = table + (mod_tail_bp if p.mod_tools) + p.sentiment × sentiment_decay_bp_per_point`, then `d = clampi(d, 0, t.sales_decay_max_bp)`, then retired-platform `max(0, 2d − 10000)`.
  - `tick(ctx)`, per GAME project in RELEASED or LIVE (sorted):
    - `base = launch_units(...)` on the first week (and the phase becomes LIVE, as today); otherwise `base = mul_bp(p.sales_base_units, decay_bp(...))`.
    - If `base < sales_floor_units`, the project RETIREs (as today).
    - Otherwise `p.sales_base_units = base`, and `units = mul_bp(base, promo_uplift_bp(t, p.promo_discount_bp))` if `promo_active(p, state.week)`, else `base`.
    - Append `units` to `weekly_units` (cap as today), then `book_sale(ctx, p, units, unit_price(content, p, state.week))`.
    - No RNG.

- [ ] **Step 1: Write failing tests.** Fixture as in `test_sales_system.gd`: install base 70000, fit 15000, `size_small` (audience 100, price 12). Launch = 1050 at hype 0 and score 60, and the score-60 decay is 8600.

```gdscript
func test_base_units_set_at_launch() -> void           # weekly_units [1050], sales_base_units 1050
func test_promo_boost_does_not_enter_tail() -> void:
    var pid := _released(); _tick()                      # week 0: 1050
    var p := s.projects[pid]; p.promo_discount_bp = 2000; p.promo_until_week = 0
    _tick()                                              # still week 0 -> promo active
    assert_eq(p.weekly_units[1], Fixed.mul_bp(903, 16000))   # base 903 = mul_bp(1050, 8600); 1444
    assert_eq(p.sales_base_units, 903)
    s.week = 1; _tick()                                  # promo over
    assert_eq(p.weekly_units[2], Fixed.mul_bp(903, 8600))    # 776, decays from base, not from 1444
func test_promo_price_discounted() -> void              # during the promo week revenue delta == 1444 * mul_bp(12, 8000)
func test_launch_hype_reduced_by_fatigue() -> void      # hype 50, companies[1].promo_fatigue 30 -> launch == mul_bp(1050, 12000) == 1260
func test_sentiment_moves_decay() -> void               # score 60: sentiment -100 -> decay_bp 8100; +40 -> 8800
func test_mod_tools_improve_decay() -> void             # score 60, mod_tools -> 8900
func test_decay_clamped_at_max() -> void                # score 100, mod_tools, sentiment 100 -> 9800
func test_floor_uses_base_units() -> void               # sales_base_units 11, weekly_units [11], promo active 5000 -> still RETIRED (mul_bp(11, 8600) = 9 < 10)
func test_book_sale_applies_share_and_royalty() -> void # book_sale(ctx, p, 100, 12) with 30% PUBLISHING contract + lic_engine_fx_pro -> returns 720 (gross 1200 - 360 - 120), publisher +360
```

- [ ] **Step 2: Run** `-gselect=sales`. **Expected:** the new tests FAIL. Existing `test_sales_system` passes after the one-line fixture fix.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** all pass, including `test_m2a_playthrough`.
- [ ] **Step 5: Commit** `feat(systems): track sales base units, promotions, sentiment and mod tail in sales`.

---

### Task 5: StartPromotion (code, `gd-implementer`)

**Depends on:** 4 (`SalesSystem.promo_active`, `promo_uplift_bp`); 3 (`MarketingSystem.last_promo_end`). If 3 is not merged yet, add `last_promo_end` here exactly as Task 3 defines it.

**Files:**
- Create: `src/core/commands/start_promotion_command.gd`
- Test: `tests/unit/test_start_promotion_command.gd`

**Interfaces:**
- `StartPromotionCommand._init(p_project_id: int, p_discount_bp: int, p_weeks: int)`.
- Validate, in order:
  - `error.project_not_found`;
  - `error.project_not_live` (kind GAME and phase LIVE);
  - `error.promo_active` if `SalesSystem.promo_active(p, state.week + 1)`;
  - `error.invalid_discount` unless `discount % step == 0` and `1 <= discount / step <= promo_uplift_table_bp.size()`;
  - `error.invalid_promo_weeks` unless `1 <= weeks <= promo_max_weeks`.
- Apply:
  - `last = MarketingSystem.last_promo_end(state, p.company_id)`. If `last >= 0 and state.week − last < promo_fatigue_window_weeks`, the company's `promo_fatigue = mini(100, promo_fatigue + promo_fatigue_hype)`.
  - Then `promo_discount_bp = discount` and `promo_until_week = state.week + weeks`.
  - Emit `promotion_started {project_id, discount_bp, until_week}`.

- [ ] **Step 1: Write failing tests.**

```gdscript
test_start_sets_window                 # week 5, LIVE, 2000 bp, 2 weeks -> promo_until_week 7, discount 2000, event promotion_started
test_exactly_n_discounted_sales_weeks  # apply at week 5, then for w in 6..8: s.week = w; SalesSystem.tick -> weeks 6,7 boosted, week 8 not
test_first_promotion_no_fatigue        # promo_fatigue stays 0
test_promotion_within_window_adds_fatigue   # other project promo_until_week 0, week 10 -> fatigue 5; week 26 with until 0 -> 0 added
test_rejects_not_live                  # POLISH -> error.project_not_live
test_rejects_running_promo             # promo_until_week = week + 1, discount 1000 -> error.promo_active; until == week -> ok
test_rejects_bad_discount              # 0, 1500, 6000 -> error.invalid_discount; 5000 ok
test_rejects_bad_weeks                 # 0, 5 -> error.invalid_promo_weeks
```

- [ ] **Step 2: Run.** **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** pass.
- [ ] **Step 5: Commit** `feat(core): add StartPromotion with promotion fatigue`.

---

### Task 6: Patches and mod tools as live tasks (code, `gd-implementer`)

**Depends on:** 1.

**Files:**
- Modify: `src/systems/live_ops_system.gd`
- Create: `src/core/commands/start_patch_command.gd`, `src/core/commands/build_mod_tools_command.gd`
- Test: `tests/unit/test_live_tasks_m2c.gd`

**Interfaces:**
- Produces:
  - `LiveOpsSystem.change_sentiment(p: Project, delta: int) -> void`: clamps to −100..100.
  - `LiveOpsSystem.release_task_staff(state: GameState, project_id: int) -> void`: sets `assigned_project_id = -1` on every staff assigned to it (sorted ids).
  - `LiveOpsSystem.live_task_block_key(state: GameState, project_id: int) -> StringName`, shared by both commands:
    - `error.project_not_found`;
    - `error.project_not_live` (GAME and LIVE);
    - `error.live_task_running` (`live_task != NONE`);
    - `error.not_enough_staff` (`GameRules.free_workers(state, company).is_empty()`);
    - otherwise `&""`.
  - `StartPatchCommand._init(p_project_id: int)`. Validate `live_task_block_key`, then `error.no_bugs` if `bugs == 0`. Apply: `live_task = PATCH`, `live_task_left = patch_staff_weeks`, assign every free worker, emit `project_changed`.
  - `BuildModToolsCommand._init(p_project_id: int)`. Validate `live_task_block_key`, then `error.mod_tools_built`. Apply: as above with `MOD_TOOLS` and `mod_tools_staff_weeks`.
  - `LiveOpsSystem.tick(ctx)` calls `_tick_tasks(ctx)` (Tasks 7 and 8 append further steps after it). For each project with `live_task != NONE` (sorted):
    - If the phase is not LIVE: clear the task (`NONE`, `left = 0`), call `release_task_staff`, emit `project_changed`, and continue.
    - Otherwise, for each `GameRules.working_staff(state, pid)`: a PATCH does `bugs = max(0, bugs − patch_bugs_per_staff_week)`. Either task does `live_task_left −= 1`.
    - When `left <= 0`:
      - PATCH: `user_score = mini(100, user_score + patch_user_score_x10)` and `change_sentiment(+patch_sentiment)`.
      - MOD_TOOLS: `mod_tools = true`.
      - Then clear the task, release the staff, and emit `project_changed {project_id, live_task_done: <enum name>}`.
    - No RNG.

- [ ] **Step 1: Write failing tests** (two workers via `Fixtures.add_worker`; LIVE project with `bugs` 20 and `user_score` 60).

```gdscript
test_start_patch_assigns_free_workers      # both workers assigned_project_id == pid; live_task PATCH; left 4
test_patch_runs_and_completes              # tick: bugs 10, left 2; tick: bugs 0, left 0 -> user_score 63, sentiment 5, NONE, workers free
test_patch_stalls_without_workers          # unseat both workers -> left stays 4
test_task_cancelled_when_project_retires   # after start, phase = RETIRED, tick -> NONE, left 0, workers free, bugs unchanged
test_build_mod_tools_completes             # 2 workers, 8 staff-weeks -> 4 ticks -> mod_tools true, workers free
test_rejects_not_live / test_rejects_task_running / test_rejects_no_free_workers / test_rejects_no_bugs / test_rejects_mod_tools_built
test_sentiment_clamped                     # change_sentiment(p, 500) -> 100; (p, -500) -> -100
```

- [ ] **Step 2: Run.** **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** pass.
- [ ] **Step 5: Commit** `feat(systems): add patches and mod tools as post-launch staff tasks`.

---

### Task 7: DLC (code, `gd-implementer`)

**Depends on:** 4 (`sales_base_units`), 6 (`live_ops_system.gd` structure).

**Files:**
- Create: `src/core/commands/start_dlc_command.gd`
- Modify: `src/systems/live_ops_system.gd`, `src/core/commands/start_project_command.gd` (one guard in `_validate_game`, right after `error.size_not_found`: `if content.sizes[size_id].dlc: return CommandResult.fail(&"error.size_dlc_only")`)
- Test: `tests/unit/test_dlc_m2c.gd`

**Interfaces:**
- `StartDLCCommand._init(p_parent_id: int, p_title: String)`. Validate, in order:
  - `error.project_not_found`;
  - `error.title_empty`;
  - `error.dlc_of_dlc` (`parent.parent_id != -1`);
  - `error.project_not_live` (parent GAME and LIVE);
  - `error.size_not_found` (`tuning.dlc_size_id` missing from content);
  - `error.dlc_in_progress` (any project with `parent_id == parent.id` in PRODUCTION or POLISH);
  - `error.not_enough_staff` (`free_workers.size() < size.min_staff`).
- Apply: a new Project with:
  - `alloc_id`, `company_id` of the parent, `kind` GAME, `parent_id`, `size_id = dlc_size_id`, phase PRODUCTION;
  - the parent's `config` copied key by key through `sorted_names`;
  - `engine_id` and `features.duplicate()` copied from the parent, and `focus = Project.DEFAULT_FOCUS.duplicate()`;
  - `deadline_week` as `StartProject` computes it.

  Then assign every free worker, set `parent.dlc_count += 1`, and emit `project_phase_changed {project_id, phase: "PRODUCTION"}`.
- `LiveOpsSystem._tick_dlc_launches(ctx)`, called after `_tick_tasks`. For each project (sorted) with `parent_id != -1`, phase LIVE and `weekly_units.size() == 1` (its first sales week, which Sales ran this tick): if the parent exists and is LIVE, `parent.sales_base_units = mul_bp(parent.sales_base_units, 10000 + maxi(0, dlc_tail_uplift_bp − (mod_dlc_penalty_bp if parent.mod_tools else 0)))` and emit `project_changed {project_id: parent.id}`. No RNG.

- [ ] **Step 1: Write failing tests.**

```gdscript
test_start_dlc_creates_linked_project   # parent LIVE; new project parent_id, size_dlc, same config/engine/features, PRODUCTION, workers assigned, parent.dlc_count 1
test_rejects_parent_not_live            # POLISH -> error.project_not_live
test_rejects_dlc_of_dlc                 # parent has parent_id -> error.dlc_of_dlc
test_rejects_second_dlc_in_progress     # -> error.dlc_in_progress; after the first is RELEASED -> ok
test_start_project_refuses_dlc_size     # StartProjectCommand.game(... &"size_dlc" ...) -> error.size_dlc_only
test_dlc_launch_extends_parent_tail     # parent LIVE base 1000; DLC LIVE weekly_units [50] -> tick -> parent base 1500
test_mod_tools_reduce_dlc_uplift        # parent.mod_tools -> 1300
test_no_uplift_for_retired_parent       # parent RETIRED -> base unchanged
test_uplift_only_on_launch_week         # DLC weekly_units [50, 40] -> unchanged
```

- [ ] **Step 2: Run.** **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** pass (`test_start_project_command` still green).
- [ ] **Step 5: Commit** `feat(core): add DLC projects and their tail extension`.

---

### Task 8: Forum, replies and viral mods (code, `gd-implementer`)

**Depends on:** 4 (`book_sale`, `unit_price`), 7 (`live_ops_system.gd`).

**Files:**
- Modify: `src/systems/live_ops_system.gd`
- Create: `src/core/commands/reply_forum_command.gd`
- Test: `tests/unit/test_forum_m2c.gd`

**Interfaces:**
- `LiveOpsSystem.forum_chance_bp(p: Project, t: TuningDef) -> int`: `mini(forum_post_max_chance_bp, forum_post_base_chance_bp + bugs × forum_post_chance_per_bug_bp)`.
- `LiveOpsSystem.add_forum_post(ctx: TickContext, project_id: int, topic_key: StringName, sentiment: int, replied: bool) -> int`:
  - Create a `ForumPost` (`id = alloc_id()`, `week = state.week`), append it, and call `change_sentiment(project, sentiment)`.
  - While `forum_posts.size() > forum_posts_cap`, call `Removal.remove_forum_post(state, forum_posts[0].id)`.
  - Emit `forum_post_created {post_id, project_id, topic_key}` and return the id.
- `_tick_forum(ctx)`, called after `_tick_dlc_launches`. For each GAME project in LIVE (sorted):
  - Draw one `Fixed.roll_bp(ctx.rng, forum_chance_bp)`. On a hit, pick the topic per Ruling C11.
  - The pick draw (`randi_range(0, 1)`) happens only when both topics are possible. When neither is, no post is made.
  - The post's sentiment is `forum_post_sentiment` and `replied` is false.
- `_tick_viral(ctx)`, called last, only when `Calendar.is_month_start`. For each GAME project in LIVE with `mod_tools` (sorted), draw one `roll_bp(mod_viral_chance_bp)`. On a hit:
  - `company.fan_count += mod_viral_fans`;
  - `extra = mul_bp(sales_base_units, mod_viral_units_bp)`; if `extra > 0` and `weekly_units` is non-empty: `weekly_units[-1] += extra` and `SalesSystem.book_sale(ctx, p, extra, SalesSystem.unit_price(ctx.content, p, state.week))`;
  - `add_forum_post(ctx, pid, &"forum.post.mod_viral", mod_viral_sentiment, true)`.
- `ReplyForumCommand._init(p_post_id: int, p_reply: StringName)`. `const REPLIES: Array[StringName] = [&"apologise", &"promise_patch", &"ignore"]`.
  - Validate, in order:
    - `error.invalid_reply`;
    - `error.post_not_found`;
    - `error.post_replied`;
    - `error.no_patch_running` (promise_patch only, when the post's project `live_task != PATCH`).
  - Apply: `replied = true`; `change_sentiment` by `forum_apologise_sentiment`, `forum_promise_sentiment` or 0; emit `project_changed`.

- [ ] **Step 1: Write failing tests.** To force posts, set `t.forum_post_base_chance_bp = 10000` on a local `Fixtures.tuning()`. Run `LiveOpsSystem.tick` directly.

```gdscript
test_forum_chance_formula               # bugs 10 -> 1000; bugs 1000 -> 3000
test_bug_post_when_only_bugs            # LIVE, bugs 5, no reviews -> one post forum.post.bugs, project.sentiment -5, forum_post_created emitted
test_weakness_post_when_only_reviews    # bugs 0, one ReviewResult -> forum.post.weakness
test_no_post_without_source             # bugs 0, no reviews -> none
test_no_post_for_released_or_retired    # RELEASED / RETIRED -> none; rng.state unchanged
test_forum_cap_drops_oldest             # cap 2, three ticks -> size 2, first id gone, validate_dict(json_round_trip) true
test_same_seed_same_posts               # two states seed 3, 10 ticks each -> equal forum_posts to_dict lists
test_viral_on_month_start               # week 0, bugs 0, no reviews (no same-tick forum post), mod_tools, base 1000, weekly_units [1000], chance 10000 -> fans +2000, weekly_units [2000], units_sold +1000, revenue +12000, post mod_viral replied true, sentiment 10
test_no_viral_off_month_start           # week 1, chance 10000 -> fans unchanged, no forum.post.mod_viral post
test_reply_apologise                    # +3, replied true
test_reply_promise_needs_patch          # -> error.no_patch_running; with live_task PATCH -> +8
test_reply_ignore                       # sentiment unchanged, replied true
test_reply_twice_rejected               # error.post_replied
test_reply_bad_inputs                   # &"shrug" -> error.invalid_reply; post 9999 -> error.post_not_found
```

- [ ] **Step 2: Run.** **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** pass. `test_m2a_playthrough` must stay green; if it fails on sales weeks (forum sentiment drag), report NEEDS_DESIGN with the measured numbers. Do not edit the M2a assertion.
- [ ] **Step 5: Commit** `feat(systems): add forum posts, forum replies and viral mods`.

---

### Task 9: Game awards (code, `gd-implementer`)

**Depends on:** 1.

**Files:**
- Modify: `src/systems/awards_system.gd`
- Create: `src/core/commands/enter_award_command.gd`
- Test: `tests/unit/test_awards_m2c.gd`

**Interfaces:**
- `AwardsSystem.next_ceremony_week(def: AwardDef, week: int, t: TuningDef) -> int`: the smallest `c > week` with `Calendar.week_in_year(c, t) == def.week_in_year`.
- `AwardsSystem.eligible(p: Project, ceremony_week: int, t: TuningDef) -> bool`, per Ruling C13.
- `AwardsSystem.entry_score_x10(p: Project) -> int`: the average `score_x10` of `review_results`, or 0 when there are none.
- `EnterAwardCommand._init(p_project_id: int, p_award_id: StringName)`.
  - Validate, in order:
    - `error.award_not_found`;
    - `error.project_not_found`;
    - `error.award_entered` (`award_entry != &""`);
    - `error.award_not_eligible` (`not eligible(p, next_ceremony_week(def, state.week, t), t)`);
    - `error.not_enough_money` (`entry_fee`).
  - Apply: pay the `entry_fee` (C1), set `award_entry = award_id`, emit `money_changed` and `project_changed`.
- `AwardsSystem.tick(ctx)`. For each award id (`sorted_names(content.awards)`) whose `week_in_year == Calendar.week_in_year(state.week)`:

```
entries := sorted project ids with award_entry == award_id      # none -> continue (no RNG, no event)
best_pid := -1; best := -1
for pid in entries:
    p.award_entry = &""
    if not eligible(p, state.week, t): continue
    score := entry_score_x10(p) + rng.randi_range(0, t.award_bonus_max_x10)
    if score > best: best = score; best_pid = pid
if best_pid == -1: emit award_result {award_id, project_id: -1, score_x10: 0, ai_best_x10: 0, won: false}; continue
ai_best := 0
repeat t.award_ai_entries: ai_best = max(ai_best, rng.randi_range(t.award_ai_score_min_x10, t.award_ai_score_max_x10))
won := best > ai_best
if won: pay prize, fans, reputation (cap 100), company.awards.append(award_id); emit money_changed
emit award_result {award_id, project_id: best_pid, score_x10: best, ai_best_x10: ai_best, won}
```

- [ ] **Step 1: Write failing tests** (`award_fx`: week 50, fee 1000, prize 10000, fans 500). `_reviewed(score)` builds a LIVE GAME project with 4 `ReviewResult`s of that score.

```gdscript
test_next_ceremony_week                 # (45) -> 50; (50) -> 102; (51) -> 102
test_enter_award_charges_fee            # release_week 40, week 45 -> money 19000, award_entry award_fx
test_rejects_old_game                   # week 100, release_week 45 -> ceremony 102 - 45 = 57 > 52 -> error.award_not_eligible
test_rejects_dlc_and_unreleased         # parent_id set -> not eligible; PRODUCTION (release_week -1) -> not eligible
test_rejects_unknown_award / test_rejects_double_entry / test_rejects_without_fee
test_ceremony_win                       # week 50, entry with reviews 100 -> money +10000, fans +500, reputation 5, awards [award_fx], entry cleared, award_result won true
test_ceremony_loss                      # reviews 10, t.award_ai_score_min_x10 = 90 -> no prize, entry cleared, won false
test_tie_goes_to_ai                     # reviews 70, bonus_max 0, ai min = max = 70 -> won false
test_ceremony_without_eligible_entries_draws_no_rng   # state.week 102, release_week 40 (62 > 52) -> entry cleared, rng.state unchanged, award_result project_id -1
test_no_entries_no_event                # week 50, no entries -> no award_result, rng.state unchanged
test_not_ceremony_week                  # week 49 with entry -> entry kept
```

- [ ] **Step 2: Run.** **Expected:** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full suite. **Expected:** pass.
- [ ] **Step 5: Commit** `feat(systems): add the yearly game award with entries and ceremony`.

---

### Task 10: M2c acceptance scenario and determinism (code, `gd-implementer`)

**Depends on:** 2, 3, 5, 8, 9 (all M2c code and content).

**Files:**
- Create: `tests/helpers/scenario_m2c.gd`, `tests/scenario/test_m2c_playthrough.gd`
- Modify: `tests/helpers/scenario.gd`. Add one fall-through in `_make_command`, before the final `push_error`: `var ext: Command = ScenarioM2C.make(state, spec)` / `if ext != null: return ext`.

**Interfaces:**
- `class_name ScenarioM2C`, with `static func make(state: GameState, spec: Array) -> Command` (null for unknown specs). Specs:
  - `["run_marketing", channel]` targets the latest GAME in PRODUCTION or POLISH.
  - `["enter_award", award]`, `["start_patch"]`, `["build_mod_tools"]`, `["start_dlc", title]` and `["start_promotion", discount, weeks]` target the **latest LIVE GAME with `parent_id == -1`**.
  - The existing `["release"]` (latest POLISH game) releases the DLC.
- `const SCRIPT_M2C: Dictionary` is `Scenario.SCRIPT_M2A`'s entries copied literally, plus:

```
15: [["run_marketing", "channel_magazine_ad"]]            # game 1 in development
49: [["enter_award", "award_golden_cartridge"], ["start_patch"]]   # game 2 LIVE since 49; ceremony on week 50
54: [["start_dlc", "Kick Arena: Extra Time"]]
62: [["release"]]                                          # DLC (6 dev weeks) in POLISH by ~60
64: [["build_mod_tools"]]
68: [["start_promotion", 2000, 2]]                         # until week 70
72: [["start_promotion", 3000, 1]]                         # within 26 weeks -> fatigue +5
```

  `WEEKS = 80`. Measured on the M2a code (seed 2026, real content and tuning): game 2 releases with 60 bugs and score 76, launches at 1774 units, and is still LIVE at week 80 (32 sales weeks). Game 1 sells for 41 weeks. Game 2 holds both workers from week 28 to 48, so every M2c staff task starts after 48. If a command is rejected (for example `error.no_bugs` because game 2 shipped bug-free), report `BLOCKED` with the reason key. Do not change rules to make the script pass.

- [ ] **Step 1: Write the scenario tests** (structure as in `test_m2a_playthrough.gd`: real content and `data/tuning.tres`, `GameState.new_game(seed, "Test Studio", tuning)`, restore fixture content in `after_all`).

```gdscript
func test_playthrough_reaches_every_m2c_milestone() -> void:
    var s := _run(2026)
    var g2: Project = <the second non-DLC game>
    var dlc: Project = <the project with parent_id == g2.id>
    assert_eq(g2.dlc_count, 1)
    assert_true(dlc.phase >= Project.Phase.RELEASED and dlc.review_results.size() == 4)
    assert_true(g2.mod_tools)
    assert_eq(g2.live_task, Project.LiveTask.NONE)
    assert_gt(g2.user_score, AwardsSystem.entry_score_x10(g2))      # the patch raised the user score
    assert_eq(g2.award_entry, &"")                                   # the ceremony ran
    assert_eq([g2.promo_discount_bp, g2.promo_until_week], [3000, 73])
    assert_gt(s.companies[s.player_company_id].promo_fatigue, 0)
    for sid: int in s.sorted_ids(s.staff): assert_eq(s.staff[sid].assigned_project_id, -1)
    assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
    assert_eq(real.missing_refs(s), [] as Array[String])

func test_marketing_raises_launch_sales() -> void:
    # same seed, SCRIPT_M2C vs a duplicate(true) with key 15 erased -> game 1 weekly_units[0] strictly greater with marketing

func test_same_seed_same_hash() / test_different_seed_different_hash()

## 15 marketing, 49 award entry pending, 50 ceremony + mid-patch, 56 mid-DLC, 69 mid-promotion, 73 after the fatigue promotion.
func test_save_load_continue_matches_uninterrupted() -> void   # save points [15, 49, 50, 56, 69, 73], as in M2a

func test_values_stay_in_range() -> void   # every project: hype 0..100, sentiment -100..100, sales_base_units >= 0; released games user_score 10..100
```

- [ ] **Step 2: Run** `-gselect=test_m2c_playthrough`. **Expected:** PASS once Tasks 2–9 are in. If it fails, debug the failing system; do not loosen assertions.
- [ ] **Step 3: Run** the full suite, including `test_m2a_playthrough` (M2c forum draws change its RNG stream, but its assertions are behavioural). **Expected:** all pass.
- [ ] **Step 4: Commit** `test(scenario): add M2c after-launch playthrough and determinism checks`.

---

### Task 11: Sync the spec with this plan's rulings (docs, `gd-implementer`)

**Depends on:** 10.

**Files:** Modify `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` only.

- [ ] **Step 1:** In §4.2, add `promo_fatigue`. In §4.5, add `parent_id`, `live_task`/`live_task_left`, `award_entry` and `sales_base_units`. In §4.7, add `MarketingChannelDef.weeks_in_year` and `ProjectSizeDef.dlc`. Under §8, add a "Rulings (M2c plan)" list summarising C3, C5–C13 in one line each. Point it at this plan.
- [ ] **Step 2:** `rtk proxy grep -n "promo_fatigue\|sales_base_units\|weeks_in_year" docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` shows each name.
- [ ] **Step 3: Commit** `docs(spec): record M2c after-launch rulings`.

---

## Shared surfaces with M2b (for the manager)

- **Edited by T1 only:** `tuning_def.gd`/`tuning.tres` (one appended `M2c` block), `project.gd`, `company.gd`, `state_validator.gd` (`_project_ok`, `_company_ok`, project ref loop), `content_db.gd` (`missing_refs`, one check), `removal.gd` (one new function), `fixtures.gd` (one line plus one function at the end), `marketing_channel_def.gd`, `project_size_def.gd`.
- **Edited by other M2c tasks:**
  - `sales_system.gd` (T4): M2b's Negotiator perk ("publisher share −") would land in `book_sale`.
  - `start_project_command.gd` (T7, one guard line).
  - `tests/helpers/scenario.gd` (T10, one line).
  - `tests/unit/test_sales_system.gd` (T4, one line).
- **Appended by T2:** `locale/strings.csv` (prefixes `content.channel.`, `content.award.`, `content.size.dlc`, `content.research.tv_advertising`, `forum.post.`, `forum.reply.`, and the `error.` keys listed in Task 2); new folders `data/channels/` and `data/awards/`; one file each in `data/sizes/` and `data/research/`.
- **RNG stream:** M2c draws in steps 12 (forum, viral) and 13 (awards), before M2b's Finance and Hiring (steps 14–15). Any M2b scenario hash taken before M2c merges will change. Behavioural assertions are unaffected.
- **Serialize with M2b** (its cross-plan contract): M2c T1 against M2b T1 (tuning block) and M2b T2 (fixtures, validator, `missing_refs`); M2c T2 against M2b T14 (`strings.csv`); M2c T11 against M2b T17 (spec sync). M2b does not edit `sales_system.gd`, `scenario.gd` or `start_project_command.gd`, and M2c does not edit `production_system.gd`.
- **Not touched:** `finance_system.gd`, `simulation.gd`, `event_bus.gd`, `game_rules.gd`, `state_queries.gd` (except the C4 `concept_options` dlc filter, Task 1), `game_state.gd`.
