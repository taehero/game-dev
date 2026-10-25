# Milestone 2b: People and Money Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the M2a stubs with spec §7: owner skill tree and focus, staff economy and levels, hiring pool, seats and equipment, office moves, monthly costs, engine licences, outsourcing, contract work, loans, repossession and bankruptcy.

**Architecture:** Two new static rule modules, `PeopleRules` and `MoneyRules`, hold every formula shared by systems, commands and UI, so M2a files change in few places. Systems fill the existing stubs in the fixed tick list (Staff 5, Owner 6, Contracts 9, Finance 14, Hiring 15). `production_system.gd` changes in one task only. Each new command is its own file. M2b never edits `Simulation.SYSTEMS`, `EventBus`, `sales_system.gd`, `game_rules.gd`, `removal.gd`, `start_project_command.gd` or `tests/helpers/scenario.gd`.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), GUT 9.x.

**Spec:** `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` (§3, §4, §5, §7, §9, §10, §12, §13). The foundation spec and `CLAUDE.md` rules 1–10 still apply.

## Global Constraints

- The project path has a leading space; always quote `"/Users/chanapols/Projects/ game-dev"`. Run `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd -gexit`. Judge by the exit code and quote the totals line.
- `CLAUDE.md` rules 1–10 apply: pure-data state, stateless systems, `ctx.rng` only, ids not references, `tr()` keys, JSON saves, tuning in `TuningDef`, no floats, sorted iteration.
- Everything is `int`. Ratios use `_bp` (10000 = 1.0), with one `Fixed.mul_bp` per factor and `Fixed.roll_bp` for chances. Clamp morale, burnout, reputation and skills to 0–100 after every change.
- **0–100 stat rule:** a bp effect on a 0–100 stat adds `Fixed.mul_bp(100, effect_bp)` points (500 bp adds 5).
- A `Dictionary[StringName, int]` written at runtime inserts keys in `GameState.sorted_names()` order. `GameRules.SKILL_ORDER` is the RNG draw order, not the storage order.
- Only `Removal.*` deletes entities: firing, resignation, repossession, loan payoff, candidate hire and expiry, contract removal, answered decisions.
- `schema_version` stays 1. The validator is extended in the same task that adds a field.
- Tests that reach commands or systems without `Fixtures.new_state()` call `ContentDB.use(Fixtures.content())` in `before_each`. Real-content tests restore fixture content in `after_all`.
- Code tasks never edit `locale/strings.csv`; Task 14 authors every key. Code tests compare keys.
- **`tests/scenario/test_m2a_playthrough.gd` must stay green after every task** (shipped tuning, 2 staff, at least 20 sales weeks, 7 save points). The tuning below keeps it solvent: about 830 per month in costs against 20000 cash. Nobody resigns without crunch or morale ≤ 15. Every verify step names it.
- One commit per task: Conventional Commits, the agent's `Co-Authored-By` line, files staged by explicit path.

## Cross-plan contract with M2c

| Surface | M2b | Rule for the manager |
|---|---|---|
| `tuning_def.gd` + `data/tuning.tres` | T1: one appended `## --- M2b people and money ---` block | Serialize against M2c T1. Field and value must land in one commit (`test_shipped_tuning_matches_script_defaults`). |
| `company.gd`, `state_validator.gd`, `content_db.gd`, `fixtures.gd` | T2 (T3 also edits `ContentDB.validate`) | M2c T1 edits the same files. Serialize T2 against M2c T1. |
| `locale/strings.csv` | T14; tests go in new `test_localization_m2b.gd` / `test_content_data_m2b.gd` | Serialize against M2c's strings task. |
| `production_system.gd`, `game_session.gd`, `state_queries.gd` | T4, T11, T16 (append-only) | M2c does not touch these. |
| **Promoter perk** | `PeopleRules.effect_bp(state: GameState, content: ContentDB, effect: StringName) -> int` (T3), already scaled by `10000 − focus_dev_bp`; effect id `&"hype_gain_bp"` | **Gap in M2c as written:** its `RunMarketing` adds `hype_gain` with no perk factor. Add `hype_gain = mul_bp(hype_gain, ONE_BP + PeopleRules.effect_bp(state, content, &"hype_gain_bp"))` to that task, after M2b T3. Otherwise Promoter does nothing. |
| §13 combined `test_m2_playthrough.gd` | Not here. M2b writes `test_m2b_playthrough.gd` on its own `scenario_m2b.gd` | The plan that finishes last writes it. |
| Spec sync | T17 edits §4 and §7 | Serialize against M2c's spec sync. |

## Rulings made by this plan

| # | Ruling |
|---|---|
| B1 | New fields: `Staff.raise_refusals: int = 0` ("refused twice"), `Company.last_missed_week: int = -1` (a 12-month bank memory that outlives a repaid loan), `Contract.features: Array[StringName]` (an outsourced engine's features), `EquipmentDef.year_from: int = 0` (availability; without it 1985 hardware sells in 1980). |
| B2 | `exp` is cumulative (LevelDef thresholds reach 12000). A skill gains 1 per multiple of 100 its exp crosses, up to 100. Levels compare Σexp. Owner `xp` works the same way: 1 skill point per multiple of `owner_xp_per_point` crossed. |
| B3 | A raise or promotion ask is a `Decision` (kind `&"raise_request"` or `&"promotion_request"`, `related_ids [staff_id]`, `deadline_week = week + raise_answer_weeks`, `option_keys [&"ui.decision.accept", &"ui.decision.refuse"]`), so it auto-pauses. `asking_raise` holds the salary asked for. One ask per staff at a time. When the deadline passes, the ask counts as refused. `AnswerRaise` answers both kinds. |
| B4 | **Raise ask:** on a hire anniversary (`week > hired_week` and `(week − hired_week) % weeks_per_year == 0`) when salary < `mul_bp(market, raise_threshold_bp)`. **Promotion ask:** when `promotion_eligible` and `week − last_raise_week >= promotion_ask_cooldown_weeks`; it takes precedence. Both ask for the market salary at the target level. `last_raise_week` is set at hire and on every answer. The owner never asks and self-promotes when eligible. |
| B5 | Market salary = `mul_bp(era_wage_base + Σskills × wage_per_skill_point, LevelDef.salary_bp)`. There is no EraDef, so `era_wage_base` is tuning. |
| B6 | Perk effects are bp per rank; the ids are in `PeopleRules.EFFECTS`. DEV `skill_<type>` raises the owner's skill once, on purchase, by the 0–100 rule. DEV effects are unscaled. BUSINESS effects are × `(10000 − focus_dev_bp)`. Owner point output is × `focus_dev_bp`. Engine Architect speeds ENGINE stage progress (`GameRules.stage_weeks` has no state). Negotiator's `publisher_share_bp` is unused: M2 has no publisher-deal command. |
| B7 | No TraitDef in M2, so candidates have no traits. Chemistry = `ONE_BP` + `lead_chemistry_bp` if another worker on the project is LEAD level + Leader `chemistry_bp` (non-owner only). The §7.2a lead-role rule and no-lead bug penalty are deferred to M3 (no role command). |
| B8 | Good chemistry lowers bugs: the bug factor becomes `maxi(0, 2 × ONE_BP − chem)` (M2a multiplied by `chem`). |
| B9 | Contract-work offers are CONTRACT_WORK contracts with `project_id == -1`. `delivery_week` = offer expiry; `deadline_week` = absolute work deadline. Targets cover all four types. Negotiator applies when the offer is made. `AcceptContractWork` creates the project and assigns every free worker (as A10). A settled job keeps its contract; the project is RETIRED with `revenue` = amount paid. |
| B10 | CONTRACT_WORK production splits each worker's output evenly over the target types: no bugs, no RNG, no stage progress. It stays at stage 0 in PRODUCTION until settled. |
| B11 | An outsourced part stores the *remaining* points in `target_points[deliverable]`. Each week it adds `ceil(remaining / max(1, delivery_week − week))` while the project is in PRODUCTION or POLISH. Anything left at release is lost. |
| B12 | `party_a` is the player in every M2b contract. The ENGINE_LICENSE `party_b` is the lowest-id VENDOR. M2b changes no AI company's money. |
| B13 | **Loans.** `payment_per_month = ceil(principal / loan_term_months)`. Each month start: `interest = mul_bp(balance, rate)`, `balance += interest`, `due = min(balance, payment_per_month + interest)`. If player money is below 0 after operating costs, every loan due is missed: nothing is paid, `missed_payments += 1`, `last_missed_week = week`. Otherwise every loan is paid, even into the negative. A payment resets `missed_payments` to 0 unless it has already reached `shark_seize_after_missed`; then it sticks until repaid. Repossessed equipment covers the missed `due`. Accountant lowers the rate at signing. |
| B14 | Bankruptcy is checked after all month-start charges. Game over stops `GameSession`: no ticks, `speed = 0`, every command rejected with `error.game_over`. |
| B15 | Buy and Lease need a seat in `0..seats−1` with no equipment (no storage placement). `MoveOffice` is refused (`error.office_too_small`) if any company staff or equipment sits at a seat ≥ the new office's seats. |
| B16 | Names are `tr()` keys: `staff_name.01`–`.24` for candidates, `ui.contract_work.title` for a contract-work project, `ui.engine.outsourced_name` for an outsourced engine. The UI shows `tr(name)`. |
| B17 | No new signals. `MoveOffice` emits `equipment_changed {company_id, office_id}`; the office scene already rebuilds on it. `SpendSkillPoint` and `SetOwnerFocus` emit nothing; panels refresh from the submit result. |
| B18 | `StateQueries.active_project_id` will return a CONTRACT_WORK project in PRODUCTION. That is left for M2d panels to present. |

---

## Review Focus

1. **The only worker on a contract job is fired:** the job stalls without a crash, the deadline pays 50%, and reputation drops. Task 12, `test_fired_worker_stalls_job_then_half_pay`.
2. **Equipment under a working staff member is sold or repossessed mid-project:** that person stops producing, and the state still validates. Task 8, `test_sell_equipment_under_worker_stops_output`; Task 11, repossession test.
3. **Money below 0 at a month start with two loans:** both are missed, neither is paid, interest accrues once, and `months_negative` resets on recovery. Task 10, `test_negative_money_misses_every_loan`; Task 11, `test_months_negative_resets`.
4. **Game over:** ticks stop, commands are rejected, and the save round-trips still over. Task 11, `test_game_over_stops_session`.
5. **Moving to a smaller office while someone sits beyond its seats:** refused. Task 8, `test_move_to_smaller_office_refused`.

## Dependency graph

| Group | Tasks (← depends on) |
|---|---|
| P1 | T1; T2 |
| P2 | T3 ← T1, T2; T8 ← T1, T2; T9 ← T1, T2; T14 ← T2 |
| P3 | T4, T5, T6, T7 ← T3; T10 ← T3, T9 |
| P4 | T11 ← T10; T12 ← T4, T7 (test uses FireStaff) |
| P5 | T13 ← T12; T16 ← T5, T10 |
| P6 | T15 ← T4–T14 |
| P7 | T17 ← T15 |

Tasks within one group touch disjoint files.

---

### Task 1: M2b tuning fields (gd-implementer)

**Depends on:** none. **Files:** modify `src/content/tuning_def.gd`, `data/tuning.tres`; test `tests/unit/test_tuning_def.gd`.

**Produces:** `@export var` fields (int unless typed) in one block headed `## --- M2b people and money ---`, with identical values appended to `tuning.tres`:

```
era_wage_base 200; wage_per_skill_point 6; raise_threshold_bp 9000; raise_answer_weeks 4
raise_refuse_morale -15; promotion_refuse_morale -10; promotion_ask_cooldown_weeks 26
severance_months 1; fire_morale_penalty -5; staff_exp_per_point_bp 1000
burnout_recovery_per_week 2; morale_baseline 70; morale_recovery_per_week 1
resign_morale_threshold 15; resign_chance_per_burnout_bp 100; resign_refusals_double 2; lead_chemistry_bp 500
candidates_per_month 3; candidate_expiry_weeks 8; candidate_name_count 24
candidate_level_weights: Array[int] [60, 30, 10, 0]; candidate_level_skill_bonus: Array[int] [0, 15, 30, 45]
candidate_salary_noise_min_pct -10; candidate_salary_noise_max_pct 15
owner_xp_per_point 3000; owner_xp_per_release 1500; owner_solo_limit 3; owner_neglect_focus_bp 7000; owner_neglect_morale -5
depreciation_bp_per_month 200; outdated_speed_bp 8000; outdated_bug_bp 13000
contract_offers_per_month 2; contract_offer_weeks 4; contract_points_min 150; contract_points_max 500
contract_weeks_min 6; contract_weeks_max 12; contract_pay_per_point 3; contract_miss_pay_bp 5000; contract_miss_reputation -3
outsource_engine_base_price 2000; outsource_price_per_feature_week 500; outsource_late_roll_below 30; outsource_max_late_weeks 4
outsource_low_quality_roll 40; outsource_low_quality_cap_penalty 10; outsource_part_price 1500; outsource_part_par_bp 2500
bank_limit_base 10000; bank_limit_per_rep 500; bank_rate_bp_per_month 100; bank_refuse_weeks 52
shark_limit 15000; shark_rate_bp_per_month 800; loan_term_months 24
shark_repossess_bp 15000; shark_seize_bp 2000; shark_seize_after_missed 3
repossess_reputation -5; repossess_morale -10; bankrupt_months 3
```

- [ ] **Step 1: Failing test** `test_m2b_tuning_values`: `load_default()` has `wage_per_skill_point == 6`, `candidates_per_month == 3`, both level arrays of size 4, `owner_xp_per_point == 3000`, `bank_rate_bp_per_month == 100`, `shark_rate_bp_per_month == 800`, `bankrupt_months == 3`.
- [ ] **Step 2: Run** `-gselect=test_tuning_def`. Expected: FAIL.
- [ ] **Step 3: Add both blocks.**
- [ ] **Step 4: Run the full suite.** Expected: exit 0.
- [ ] **Step 5: Commit** `feat(tuning): add M2b people and money tuning`.

---

### Task 2: New fields, validator, fixtures (gd-implementer)

**Depends on:** none (serialize against M2c T1). **Files:** modify `src/core/entities/{staff,company,contract}.gd`, `src/content/equipment_def.gd`, `src/core/state_validator.gd`, `src/core/content_db.gd` (`missing_refs`), `tests/helpers/fixtures.gd`. Test: new `tests/unit/test_entities_m2b.gd`; `test_state_validator_m2.gd`; `test_content_db.gd`.

**Produces:**
- **New fields** (ruling B1), each in `SCHEMA`/`to_dict`/`from_dict`: `Staff.raise_refusals`, `Company.last_missed_week`, `Contract.features`. Also `@export var year_from: int = 0` on `EquipmentDef`.
- **Validator:**
  - `raise_refusals >= 0`, `last_missed_week >= -1`, `features` all strings.
  - A new `_loan_ok` replaces `_always` for loans: principal, balance, rate, payment and missed are all ≥ 0.
  - `_equipment_ok` adds `value >= 0`.
- **`missing_refs`:** `"contract %d: unknown feature %s"`.
- **Fixtures:**
  - `company_of_kind(state, kind: Company.Kind) -> int`: lowest id, or -1.
  - `add_loan(state, overrides := {}) -> int`: from the BANK; principal and balance 5000, rate 100, payment 209.
  - `add_contract(state, overrides := {}) -> int`: CONTRACT_WORK, `party_a` = player, `party_b` = first AI_PUBLISHER.
  - Fixture content `equipment_fx_future`: `_equip(&"equipment_fx_future", 3, 5000, 200, 20, 20000, 7000, 1995)` with `year_from = 1990`.
  - Seven PerkDefs (`path &"DEV"|&"BUSINESS"`, `max_rank 3`):

    | Perk | Path | Effects per rank |
    |---|---|---|
    | `perk_coder` | DEV | `{skill_tech: 500}` |
    | `perk_engine_architect` | DEV | `{engine_speed_bp: 1500}` |
    | `perk_crunch_veteran` | DEV | `{owner_burnout_bp: -2500}` |
    | `perk_negotiator` | BUSINESS | `{contract_pay_bp: 1000, publisher_share_bp: -500}` |
    | `perk_recruiter` | BUSINESS | `{candidate_skill_bp: 1000, asking_salary_bp: -500}` |
    | `perk_accountant` | BUSINESS | `{loan_rate_bp: -1500}` |
    | `perk_leader` | BUSINESS | `{chemistry_bp: 500, morale_baseline_bp: 500}` |

- [ ] **Step 1: Failing tests**

```gdscript
func test_new_fields_round_trip() -> void
    # add_staff raise_refusals 2; company last_missed_week 30; add_contract OUTSOURCE features [&"feature_fx_save"]
    # GameState.from_dict(json_round_trip) keeps all three; StateHash equal
func test_rejects_bad_m2b_values() -> void   # each on a fresh round-tripped dict -> false:
    # raise_refusals -1; last_missed_week -2; features [3]; loan balance -1; equipment value -1
func test_missing_refs_reports_contract_feature() -> void   # features [&"feature_gone"] -> one message containing it
func test_fixture_perks_and_future_equipment() -> void      # perks.size() == 7; fx_future.year_from == 1990
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(core): add M2b entity fields, validator checks and fixtures`.

---

### Task 3: PeopleRules (gd-implementer)

**Depends on:** T1, T2. **Files:** create `src/core/people_rules.gd` (`class_name PeopleRules`; static, no RNG); modify `src/core/content_db.gd` (`validate`). Test: `tests/unit/test_people_rules.gd`, `test_content_db.gd`.

**Produces:**

```gdscript
const EFFECTS: Array[StringName] = [&"skill_design", &"skill_tech", &"skill_art", &"skill_audio",
    &"engine_speed_bp", &"owner_burnout_bp", &"contract_pay_bp", &"publisher_share_bp", &"candidate_skill_bp",
    &"asking_salary_bp", &"hype_gain_bp", &"loan_rate_bp", &"chemistry_bp", &"morale_baseline_bp"]
static func effect_bp(state: GameState, content: ContentDB, effect: StringName) -> int
static func market_salary(skills: Dictionary[StringName, int], level: int, content: ContentDB, t: TuningDef) -> int
static func promotion_eligible(s: Staff, content: ContentDB) -> bool
static func owner_point_bp(state: GameState, s: Staff) -> int
static func progress_bp(state: GameState, content: ContentDB, p: Project) -> int
static func chemistry_bp(state: GameState, content: ContentDB, t: TuningDef, project_id: int, staff_id: int) -> int
static func equipment_speed_bp(def: EquipmentDef, week: int, t: TuningDef) -> int
static func equipment_bug_bp(def: EquipmentDef, week: int, t: TuningDef) -> int
static func equipment_available(def: EquipmentDef, week: int, t: TuningDef) -> bool
static func morale_baseline(state: GameState, content: ContentDB, t: TuningDef) -> int
```

- **`effect_bp`:** Σ `rank × effects_bp_per_rank.get(effect, 0)` over `owner.perks` in `sorted_names` order. Unknown perks are skipped. BUSINESS terms are scaled (B6).
- **`owner_point_bp`:** the owner's `focus_dev_bp`; `ONE_BP` for anyone else.
- **`progress_bp`:** `ONE_BP + effect_bp(engine_speed_bp)` for ENGINE projects, else `ONE_BP`.
- **`chemistry_bp`:** ruling B7. A LEAD is `level == Staff.Level.LEAD` among `GameRules.working_staff(state, project_id)`, excluding `staff_id`.
- **Equipment:** outdated when `Calendar.year > recommended_until_year`. Speed and bug are then × `outdated_*_bp`. A null def gives `ONE_BP`. Available means `year >= year_from`.
- **`promotion_eligible`:** the next level `int(level) + 1 <= LEAD`, its LevelDef exists, best skill ≥ `min_best_skill`, and Σexp ≥ `min_total_exp`.
- **`morale_baseline`:** `clampi(t.morale_baseline + mul_bp(100, effect_bp(morale_baseline_bp)), 0, 100)`.
- **`ContentDB.validate`** flags a perk whose path is not DEV/BUSINESS, whose `max_rank < 1`, or whose effect key is not in `EFFECTS`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_market_salary() -> void        # skills all 20: level 0 -> 680, level 1 -> 884
func test_promotion_eligible() -> void   # design 40, Σexp 2000 -> true; Σexp 1999 -> false; level LEAD -> false
func test_effect_bp_scaling() -> void    # engine_architect 2 -> 3000 at any focus; accountant 1: focus 10000 -> 0, 0 -> -1500, 4000 -> -900
func test_owner_point_bp() -> void       # owner focus 5000 -> 5000; other staff -> 10000
func test_progress_bp() -> void          # ENGINE + engine_architect 1 -> 11500; GAME -> 10000
func test_chemistry_lead_and_leader() -> void
    # A (LEAD) and B both work the project: chem(B) 10500, chem(A) 10000; + leader 2 at focus 5000: chem(B) 11000, owner unchanged
func test_equipment_age_and_availability() -> void
    # micro_1980 week 0 -> 10000/10000, week 312 -> 8000/13000; fx_future unavailable week 0, available week 520
func test_morale_baseline_with_leader() -> void   # leader 1, focus 0 -> 75
func test_validate_reports_bad_perk() -> void     # fresh ContentDB with effect &"nope" -> one error
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(core): add PeopleRules for salary, perks, chemistry and equipment age`.

---

### Task 4: Production hooks and contract-work output (gd-implementer)

**Depends on:** T3. The only M2b edit to `src/systems/production_system.gd`. Test: `tests/unit/test_production_system.gd`.

**Changes:**
1. Delete the `ProductionSystem.chemistry_bp` stub. Its caller uses `PeopleRules.chemistry_bp(state, ctx.content, t, p.id, sid)`.
2. Equipment speed and bug come from `PeopleRules.equipment_*_bp(eq, state.week, t)`.
3. The **last** per-slider factor is `Fixed.mul_bp(amount, PeopleRules.owner_point_bp(state, st))`.
4. The chemistry bug factor is `maxi(0, 2 * Fixed.ONE_BP - chem)` (B8).
5. The progress increment is × `PeopleRules.progress_bp(...)` before crunch.
6. `tick` gets a new branch: CONTRACT_WORK in PRODUCTION → `_produce_contract(ctx, p)` (B10).
   - Per worker, in sorted order, and per type in `SKILL_ORDER` with `contract.target_points.get(type, 0) > 0`: `skill × points_per_skill`, then × (`ONE_BP / n_types`), speed, morale, level output, chemistry and owner point bp.
   - Add to `p.points` (sorted insert) and `week_points`, and emit `points_gained`.
   - A missing contract means no output. A shared private helper for the staff factors is fine.

- [ ] **Step 1: Failing tests**

```gdscript
func test_owner_focus_scales_owner_points() -> void
    # same seed, owner on a GAME at stage 0: tech week_points(focus 5000) == mul_bp(tech week_points(10000), 5000)
func test_outdated_equipment_lowers_points() -> void   # week 312 vs week 0: tech strictly lower
func test_engine_architect_speeds_engine_stage() -> void   # ENGINE [feature_fx_save], perk 1 -> stage_progress 5750
func test_contract_work_produces_points_without_rng() -> void
    # contract {design:100, tech:100}; owner (skills 30, morale 70) on it -> points == {design:153, tech:153},
    # no art key, bugs 0, rng.state unchanged, stage_progress 0
func test_contract_work_without_contract_is_idle() -> void   # contract_id -1 -> no points, no events
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite,** including `test_m2a_playthrough`. With focus 10000, no perks and 1980 equipment, M2a output is unchanged. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): owner focus, perks, chemistry and equipment age in production; contract-work output`.

---

### Task 5: StaffSystem and AnswerRaise (gd-implementer)

**Depends on:** T3. **Files:** modify `src/systems/staff_system.gd`; create `src/core/commands/answer_raise_command.gd`. Test: `tests/unit/test_staff_system.gd`, `test_answer_raise_command.gd`.

**Produces:**
- **`StaffSystem.tick(ctx)`.** First refuse every ask decision with `deadline_week <= week` (via `AnswerRaiseCommand.resolve`). Then, for each id in a snapshot of `sorted_ids(state.staff)`, skipping removed ids:
  1. **Exp and skills** (B2): `exp[k] += mul_bp(week_points[k], staff_exp_per_point_bp)` over `sorted_names(week_points)`.
  2. **Crunch.** A staff member is crunching when their project is in PRODUCTION with `crunch` and they are in `GameRules.working_staff`.
     - Crunching: `burnout += crunch_burnout_per_week` (the owner's gain is × `ONE_BP + effect_bp(owner_burnout_bp)`), and `morale += crunch_morale_per_week`.
     - Otherwise: `burnout -= burnout_recovery_per_week`, and morale moves `morale_recovery_per_week` toward `PeopleRules.morale_baseline`.
  3. **Asks** (B3/B4): for a non-owner with no pending ask, set `asking_raise`, add a Decision with `alloc_id()`, and emit `raise_requested {staff_id, amount, promotion}`. The owner does `level += 1` when eligible.
  4. **Resignation.** A non-owner is eligible when `burnout >= resign_burnout_threshold` or `morale <= resign_morale_threshold`. Chance = `resign_base_chance_bp + maxi(0, burnout − threshold) × resign_chance_per_burnout_bp`, × 2 when `raise_refusals >= resign_refusals_double`. Exactly one `roll_bp` per eligible staff in sorted order; this is the only RNG in the system. On success: `Removal.remove_staff` and emit `staff_resigned {staff_id}`.
- **`AnswerRaiseCommand.new(p_staff_id: int, p_accept: bool)`** plus `static func resolve(state: GameState, t: TuningDef, staff_id: int, accept: bool) -> void`.
  - Validate: `error.staff_not_found`; `error.no_raise_pending` (no ask decision for the staff).
  - Accept: `salary = asking_raise`; a promotion also does `level += 1`.
  - Refuse: morale `+= raise_refuse_morale` or `promotion_refuse_morale`, and `raise_refusals += 1`.
  - Both: `asking_raise = 0`, `last_raise_week = week`, `Removal.remove_decision`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_exp_raises_skill_on_hundreds() -> void   # week_points {tech:1050}, exp 50 -> exp 155, tech 20 -> 21; cap at 100
func test_crunch_and_recovery() -> void            # crunching: burnout 10->16, morale 70->66; idle: 10->8, morale 60->61, 80->79
func test_crunch_veteran_reduces_owner_burnout() -> void   # rank 1: owner burnout 0 -> 4
func test_raise_ask_on_anniversary() -> void
    # hired 0, salary 300, skills 20: week 52 -> asking 680, raise_request decision, promotion false; week 51 none; salary 650 none
func test_promotion_ask_after_cooldown() -> void   # design 40, Σexp 2000, last_raise 0: week 26 -> 1040 promotion_request; week 25 none
func test_owner_never_asks_and_self_promotes() -> void
func test_unanswered_ask_expires_as_refused() -> void   # morale -15, raise_refusals 1, decision gone
func test_resignation_rolls() -> void
    # base 10000 + burnout 90 -> removed + staff_resigned; owner at burnout 100 stays; base 5000 + refusals 2 + morale 10 -> removed
func test_no_rng_without_eligible_staff() -> void
func test_accept_raise / test_accept_promotion_levels_up / test_refuse_promotion_morale_minus_10 / test_answer_rejections
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): staff exp, morale, raise and promotion asks, resignation; AnswerRaise`.

---

### Task 6: OwnerSystem, SpendSkillPoint, SetOwnerFocus (gd-implementer)

**Depends on:** T3. **Files:** modify `src/systems/owner_system.gd`; create `src/core/commands/spend_skill_point_command.gd`, `set_owner_focus_command.gd`. Test: `tests/unit/test_owner_system.gd`, `test_owner_commands.gd`.

**Produces:**
- **`OwnerSystem.tick(ctx)`** (no RNG):
  - `xp += Σ owner week_points + owner_xp_per_release × (player GAME projects RELEASED with empty weekly_units)`. Sales makes them LIVE later in the tick, so each release counts once.
  - Skill points follow B2.
  - On a month start, if non-owner player staff > `owner_solo_limit` and `focus_dev_bp > owner_neglect_focus_bp`, every non-owner's morale changes by `owner_neglect_morale`.
- **`SpendSkillPointCommand.new(p_perk_id: StringName)`.**
  - Validate: `error.perk_not_found`; `skill_points >= 1` (`error.no_skill_points`); rank < `max_rank` (`error.perk_maxed`).
  - Apply: rank + 1 (sorted insert) and `skill_points -= 1`. Each `skill_<type>` effect raises the owner's skill by `mul_bp(100, v)`, capped at 100.
- **`SetOwnerFocusCommand.new(p_focus_dev_bp: int)`:** accepts 0–10000, else `error.invalid_focus`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_xp_from_owner_points() -> void   # week_points {design:600, tech:400}, xp 2500 -> 3500, skill_points 1
func test_xp_from_release_once() -> void   # RELEASED, empty weekly_units -> +1500; LIVE -> +0
func test_neglect_monthly() -> void        # 4 non-owner, focus 8000, week 4 -> morale 65; week 5 unchanged; focus 7000 none; 3 staff none
func test_spend_point_coder() -> void      # perks {perk_coder:1}, points 0, owner tech 30 -> 35
func test_spend_rejections() -> void       # perk_nope / 0 points / rank 3
func test_set_focus() -> void              # 5000 ok; -1 and 10001 -> error.invalid_focus
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite,** including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): owner xp and skill points; SpendSkillPoint and SetOwnerFocus`.

---

### Task 7: HiringSystem, HireCandidate, FireStaff (gd-implementer)

**Depends on:** T3. **Files:** modify `src/systems/hiring_system.gd`; create `src/core/commands/hire_candidate_command.gd`, `fire_staff_command.gd`. Test: `tests/unit/test_hiring_system.gd`, `test_hire_candidate_command.gd`, `test_fire_staff_command.gd`.

**Produces:**
- **`HiringSystem.tick(ctx)`:**
  - Every week: remove candidates with `expires_week <= week` (snapshot ids, `Removal.remove_candidate`).
  - On a month start: append `candidates_per_month` candidates (`alloc_id()`, `expires_week = week + candidate_expiry_weeks`, no traits).
  - **RNG order per candidate:**
    1. Name: `randi_range(1, candidate_name_count)` → `"staff_name.%02d"`.
    2. Level: `randi_range(0, Σweights − 1)` walked over `candidate_level_weights`.
    3. Four skills in `SKILL_ORDER`: `randi_range(hire_skill_min, hire_skill_max) + candidate_level_skill_bonus[level]`, then × `ONE_BP + effect_bp(candidate_skill_bp)`, clamped 1–100, stored sorted.
    4. Noise: `randi_range(noise_min_pct, noise_max_pct)`; `asking = mul_bp(mul_bp(market, ONE_BP + noise × 100), ONE_BP + effect_bp(asking_salary_bp))`.
- **`HireCandidateCommand.new(p_company_id: int, p_candidate_id: int)`.**
  - Validate: company; `error.candidate_not_found`; `error.no_free_seat`.
  - Apply: a Staff with the candidate's name, skills (`set_skills`), level, `salary = asking_salary`, the free seat, and `hired_week = last_raise_week = week`. Then `Removal.remove_candidate` and emit `staff_hired`. No RNG.
- **`FireStaffCommand.new(p_staff_id: int)`.**
  - Validate: `error.staff_not_found`; `error.cannot_fire_owner`.
  - Apply: `money -= salary × severance_months` (may go below 0), `Removal.remove_staff`, other company staff `morale += fire_morale_penalty`. Emit `staff_fired {staff_id}` and `money_changed`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_month_start_adds_candidates() -> void
    # week 4: 3 candidates, expires 12, level 0..2, skills in [10,70], name starts "staff_name.",
    # asking in [mul_bp(market,9000), mul_bp(market,11500)]; week 5: still 3
func test_candidates_expire() -> void          # removed on the tick at week 12
func test_same_seed_same_candidates() -> void
func test_recruiter_raises_skills() -> void    # same seed, recruiter 1, focus 0 -> Σskills >= baseline
func test_state_valid_after_hiring_ticks() -> void   # 30 ticks -> validate_dict(round trip)
func test_hire_candidate_seats_and_removes() -> void # seat 1, salary == asking, level kept, candidate gone, staff_hired
func test_hire_rejections() -> void            # unknown -> candidate_not_found; seat 1 taken -> no_free_seat
func test_fire_pays_severance_and_lowers_morale() -> void   # salary 600 -> money 19400; others' morale 65; staff_fired
func test_fire_rejections() -> void            # owner -> cannot_fire_owner; 999 -> staff_not_found
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough` (candidates now draw RNG and ids; it pins no hash). Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): monthly hiring pool, HireCandidate and FireStaff`.

---

### Task 8: Seat, equipment and office commands (gd-implementer)

**Depends on:** T1, T2. **Files:** create `src/core/commands/{assign_seat,buy_equipment,lease_equipment,sell_equipment,move_office}_command.gd`. Test: `tests/unit/test_equipment_commands.gd`, `test_move_office_command.gd`. Availability is inlined as `Calendar.year(week, t) >= def.year_from` (no T3 dependency).

**Produces:**
- **`AssignSeatCommand.new(p_staff_id: int, p_seat_index: int)`.**
  - Validate: `error.staff_not_found`; seat in `-1..seats−1` (`error.invalid_seat`); no other staff there (`error.seat_taken`).
  - Apply: set the seat; emit `equipment_changed {company_id}`.
- **`BuyEquipmentCommand.new(p_company_id: int, p_def_id: StringName, p_seat_index: int)`.**
  - Validate in this order: company; `error.equipment_not_found`; `error.equipment_not_available`; seat in `0..seats−1` (`error.invalid_seat`); `error.seat_has_equipment`; `error.not_enough_money`.
  - Apply: BOUGHT, `value = price`, `bought_week = week`, `money -= price`. Emit `equipment_changed {equipment_id}` and `money_changed`.
- **`LeaseEquipmentCommand.new(...)`:** same arguments and checks except money. Apply: LEASED, value 0, no money change.
- **`SellEquipmentCommand.new(p_equipment_id: int)`.**
  - Validate: exists and is the player's (`error.equipment_not_found`).
  - Apply: BOUGHT adds `value` to money; LEASED just ends the lease. Then `Removal.remove_equipment`. Emit `equipment_changed`, plus `money_changed` when sold.
- **`MoveOfficeCommand.new(p_company_id: int, p_office_id: StringName)`.**
  - Validate: `error.office_not_found`; `error.office_current`; money ≥ `moving_cost`; B15 (`error.office_too_small`).
  - Apply: pay, set `office_id`, emit `equipment_changed {company_id, office_id}` and `money_changed`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_buy_places_bought_equipment() -> void   # (1, micro_1980, 1): money 18500, BOUGHT, value 1500
func test_buy_rejections() -> void   # &"x"; fx_future in 1980; seat 2 and -1; seat 0 occupied; money 100
func test_lease_costs_nothing_now() -> void       # money 20000, LEASED, value 0
func test_sell_bought_and_leased() -> void        # starter -> money 20800, removed; leased -> money unchanged
func test_sell_equipment_under_worker_stops_output() -> void
    # owner on a PRODUCTION project; sell starter -> working_staff empty; validate_dict true
func test_assign_seat() -> void                   # unseat ok; taken -> seat_taken; seat 5 in garage -> invalid_seat
func test_move_to_small_office() -> void          # money 18500, office_seats 5
func test_move_to_smaller_office_refused() -> void   # office_small, staff at seat 3 -> office_too_small
func test_move_rejections() -> void               # unknown; garage (current); money 0
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(core): AssignSeat, Buy/Lease/SellEquipment and MoveOffice commands`.

---

### Task 9: MoneyRules costs and FinanceSystem operating costs (gd-implementer)

**Depends on:** T1, T2. **Files:** create `src/core/money_rules.gd` (`class_name MoneyRules`, static); modify `src/systems/finance_system.gd`. Test: `tests/unit/test_money_rules.gd`; update both tests in `test_finance_system.gd`.

**Produces:**
- **`MoneyRules.monthly_costs(state: GameState, content: ContentDB, company_id: int) -> Dictionary`** returns ints `{"salaries", "rent", "electricity", "leases", "total"}`.
  - Electricity = office base + `power_per_month` of the company's equipment with `seat_index >= 0`.
  - Leases = Σ `lease_per_month` of LEASED equipment.
  - A company with no known office pays salaries only.
- **`FinanceSystem.tick(ctx)`**, on a month start, for each company in sorted order (no RNG):
  1. **Lease upgrade:** each LEASED item moves to the available def (inline `Calendar.year(week, t) >= def.year_from`, as in T8; `PeopleRules` may not exist yet) with the highest tier (ties: first in `sorted_names`) if that tier is higher; emit `equipment_changed`.
  2. **Charge** `total`.
  3. **Depreciation:** BOUGHT `value = mul_bp(value, ONE_BP − depreciation_bp_per_month)`.
  4. Loans (T10), then bankruptcy (T11), slot in here.
  5. Emit one `money_changed` if money changed.

- [ ] **Step 1: Failing tests**

```gdscript
func test_monthly_costs_garage() -> void   # owner + add_staff(salary 500) -> {500, 0, 30, 0, total 530}
func test_monthly_costs_small_office_and_lease() -> void   # office_small + leased micro_1980 at seat 1 -> rent 400, electricity 60, leases 60
func test_storage_equipment_draws_no_power() -> void
func test_salaries_paid_on_month_start_only() -> void      # existing test updated: 20000 - 800 - 30, then unchanged at week 5
func test_ai_companies_get_no_money_event() -> void        # replaces the no-salary test: one money_changed, for the player
func test_depreciation() -> void          # starter 800 -> 784 at week 4
func test_lease_upgrade() -> void         # leased micro_1980: week 4 -> equipment_fx_fast; week 520 -> equipment_fx_future
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): rent, electricity, leases, lease upgrades and depreciation`.

---

### Task 10: Loans (gd-implementer)

**Depends on:** T3, T9. **Files:** modify `src/core/money_rules.gd`, `src/systems/finance_system.gd`; create `src/core/commands/take_loan_command.gd`, `repay_loan_command.gd`. Test: `test_money_rules.gd`, `test_loan_commands.gd`, `test_finance_loans.gd`.

**Produces:**

```gdscript
static func bank_refuses(state: GameState, company_id: int, t: TuningDef) -> bool   # last_missed >= 0 and week - last_missed < bank_refuse_weeks
static func credit_limit(state: GameState, company_id: int, lender_id: int, t: TuningDef) -> int
    # BANK: 0 if refused, else bank_limit_base + reputation * bank_limit_per_rep; LENDER: shark_limit; else 0
static func available_credit(state: GameState, company_id: int, lender_id: int, t: TuningDef) -> int   # maxi(0, limit - Σ balances with that lender)
static func has_credit(state: GameState, company_id: int, t: TuningDef) -> bool
static func loan_rate_bp(state: GameState, content: ContentDB, lender_id: int, t: TuningDef) -> int   # base × (ONE_BP + effect_bp(loan_rate_bp)), min 0
```

- **`TakeLoanCommand.new(p_company_id: int, p_lender_id: int, p_amount: int)`.**
  - Validate: `error.lender_not_found` (not BANK/LENDER); `error.invalid_amount` (≤ 0); `error.bank_refused`; `error.over_credit_limit`.
  - Apply: Loan with `principal = balance = amount`, `rate`, `payment_per_month = ceil(amount / loan_term_months)`, `taken_week`. `money += amount`. Emit `loan_taken {loan_id}` and `money_changed`.
- **`RepayLoanCommand.new(p_loan_id: int, p_amount: int)`.**
  - Validate: `error.loan_not_found` (missing or not the player's); `error.invalid_amount` (≤ 0 or > balance); `error.not_enough_money`.
  - Apply: pay; at balance 0, `Removal.remove_loan`.
- **Finance loan step** (after depreciation), loans in sorted id order, following B13. A miss emits `payment_missed {loan_id, amount: due}`. A loan at balance 0 is removed.

- [ ] **Step 1: Failing tests**

```gdscript
func test_credit_limits() -> void          # bank 10000 at rep 0, 15000 at rep 10; shark 15000; after a 4000 bank loan -> 6000
func test_bank_refuses_after_recent_miss() -> void   # last_missed week-10 -> refused; week-52 -> not
func test_accountant_lowers_rate() -> void           # accountant 1, focus 0 -> bank rate 85
func test_take_bank_loan() -> void         # 5000: money 25000, balance 5000, rate 100, payment 209, loan_taken
func test_take_loan_rejections() -> void   # player as lender; 0; 10001; refused bank (shark still ok)
func test_repay() -> void                  # 1000 -> balance 4000; full -> removed; 0 or > balance -> invalid_amount
func test_monthly_payment() -> void        # week 4, 5000/100/209 -> balance 4791, payment 259, missed 0
func test_final_payment_removes_loan() -> void   # balance 100 -> due 101 -> gone
func test_negative_money_misses_every_loan() -> void
    # money -100, two loans: both missed 1, balances + interest only, money unchanged by loans, last_missed_week 4, 2 payment_missed
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): bank and shark loans with monthly payments`.

---

### Task 11: Repossession, seizure, bankruptcy, game-over stop (gd-implementer)

**Depends on:** T10. **Files:** modify `src/systems/finance_system.gd`, `src/core/game_session.gd`. Test: `tests/unit/test_finance_bankruptcy.gd`, `test_game_session.gd`.

**Produces:**
- **Repossession** (on a missed LENDER payment):
  - Take the company's BOUGHT equipment sorted by `(bought_week, id)` until Σ value ≥ `mul_bp(due, shark_repossess_bp)`, through `Removal.remove_equipment`. If anything was taken, `balance -= mini(balance, due)`.
  - Penalties always apply: `reputation += repossess_reputation` and every company staff member's `morale += repossess_morale`.
  - Emit `repossessed {loan_id, equipment_ids: Array[int], value}`. LEASED items are never taken.
- **Seizure:** for a LENDER loan with `missed_payments >= shark_seize_after_missed` and money > 0 after payments, `seized = mini(balance, mul_bp(money, shark_seize_bp))` comes off both money and balance. At balance 0 the loan is removed.
- **Bankruptcy, last** (PLAYER only):
  - Money < 0 → `months_negative += 1`; otherwise reset it to 0.
  - When `months_negative >= bankrupt_months` and not `MoneyRules.has_credit`: `game_over = true` and emit `game_over {company_id}`.
- **GameSession:**
  - `submit` rejects every command while game over (`error.game_over`, plus `command_rejected`).
  - `step_once` returns at once while game over.
  - After `Simulation.step`, if game over, `speed = 0`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_repossession_takes_oldest_until_covered() -> void
    # shark balance 1000, rate 800, pay 42; money -500; starter (week 0) + bought (week 2, 1500); rep 10; morale 70
    # -> due 122, starter removed (value 784 after depreciation), other kept, balance 958, missed 1, rep 5, morale 60
func test_leased_never_repossessed() -> void
func test_seizure_after_three_misses() -> void   # missed 3, money 10000 -> pays due, then 20% of the rest; missed stays 3
func test_months_negative_resets() -> void       # -100 at week 4 -> 1; 50 at week 8 -> 0
func test_bankruptcy_with_no_credit() -> void
    # money -50000, shark loan at 15000, last_missed_week 0: no game over at week 8; game_over + one event at week 13
func test_shark_credit_prevents_game_over() -> void   # money -5000, bank refused, no shark loan: week 26 -> false
func test_game_over_stops_session() -> void
    # game_over: step_once keeps week; submit(BuyDevKitCommand.new(1, &"platform_fx_micro")) -> error.game_over
    # (checked before the command's own validate); save round trip keeps game_over
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough` (game_over stays false). Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): repossession, cash seizure, bankruptcy and game-over stop`.

---

### Task 12: Contract work (gd-implementer)

**Depends on:** T4, T7. **Files:** modify `src/systems/contracts_system.gd`; create `src/core/commands/accept_contract_work_command.gd`. Test: `tests/unit/test_contracts_system.gd`, `test_accept_contract_work_command.gd`.

**Produces:**
- **`ContractsSystem.tick(ctx)`:**
  - **(a) Settle** accepted CONTRACT_WORK contracts whose project is in PRODUCTION (snapshot of sorted ids).
    - Every target met (`points >= target`): pay `price`.
    - Else, at `week >= deadline_week`: pay `mul_bp(price, contract_miss_pay_bp)` and add `contract_miss_reputation`.
    - Then: money += paid; project RETIRED with `revenue = paid`; staff unassigned. Emit `contract_completed {contract_id, paid, met}`, `money_changed` and `project_phase_changed {project_id, phase: "RETIRED"}`.
  - **(b) Expire:** offers with `project_id == -1` and `week >= delivery_week` → `Removal.remove_contract`.
  - **(c) Offer:** on a month start, `contract_offers_per_month` offers.
    - RNG per offer: publisher `randi_range(0, n−1)` over sorted AI_PUBLISHER ids; four targets in `SKILL_ORDER` (`randi_range(points_min, max)`); weeks `randi_range(weeks_min, max)`.
    - `deadline_week = week + weeks`, `delivery_week = week + contract_offer_weeks`.
    - `price = mul_bp(Σtargets × contract_pay_per_point, ONE_BP + effect_bp(contract_pay_bp))`.
    - Emit `contract_offered {contract_id}`.
- **`AcceptContractWorkCommand.new(p_contract_id: int)`.**
  - Validate: `error.contract_not_found` (missing or wrong kind); `error.contract_taken`; `error.contract_expired` (`week >= delivery_week` or `week >= deadline_week`); `error.not_enough_staff` (no free worker).
  - Apply: Project (CONTRACT_WORK, PRODUCTION, `title "ui.contract_work.title"`, `contract_id`, the contract's `deadline_week`, `size_id &""`), `contract.project_id = pid`, every free worker assigned. Emit `project_phase_changed {project_id, phase: "PRODUCTION"}`.

- [ ] **Step 1: Failing tests**

```gdscript
func test_month_start_offers() -> void
    # week 4: 2 offers, party_b an AI_PUBLISHER, targets in [150,500], deadline in [10,16], delivery 8, price == Σ*3,
    # 2 contract_offered; week 5: none added
func test_negotiator_raises_offer_price() -> void   # negotiator 1, focus 0 -> mul_bp(Σ*3, 11000)
func test_unaccepted_offer_expires() -> void
func test_accept_creates_project() -> void     # CONTRACT_WORK, owner assigned, contract.project_id set, validate_dict true
func test_accept_rejections() -> void          # not_found, taken, expired, not_enough_staff
func test_met_target_pays_full() -> void       # +price, RETIRED, revenue == price, met true, owner unassigned
func test_missed_deadline_pays_half() -> void  # paid price/2, reputation 10 -> 7
func test_fired_worker_stalls_job_then_half_pay() -> void
    # owner busy elsewhere; one hired worker accepts; FireStaffCommand; tick to deadline -> half pay, no crash
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): contract-work offers, AcceptContractWork and settlement`.

---

### Task 13: Engine licences and outsourcing (gd-implementer)

**Depends on:** T12. **Files:** modify `src/systems/contracts_system.gd` (deliveries run before (a)); create `src/core/commands/sign_engine_license_command.gd`, `sign_outsource_command.gd`. Test: `test_sign_engine_license_command.gd`, `test_sign_outsource_command.gd`, `test_contracts_system.gd`.

**Produces:**
- **`SignEngineLicenseCommand.new(p_company_id: int, p_licensed_id: StringName)`.**
  - Validate: def exists and year in range (`error.engine_unavailable`); `fee > 0` (`error.license_not_needed`); no `GameRules.engine_license_contract` (`error.license_owned`); money.
  - Apply: ENGINE_LICENSE contract (`party_b` per B12, `price = fee`, `royalty_bp`, `deliverable = id`), `money -= fee`, emit `money_changed`. No RNG.
- **`SignOutsourceCommand.engine(p_company_id: int, p_vendor_id: int, p_features: Array[StringName]) -> SignOutsourceCommand`.**
  - Validate: `error.vendor_not_found`; the same feature checks and keys as `StartProjectCommand._validate_engine` (no staff check); money.
  - `price = outsource_engine_base_price + Σ dev_weeks × outsource_price_per_feature_week`.
  - RNG: `quality_roll = randi_range(0, 100)`, then only if `quality_roll < outsource_late_roll_below`, `late = randi_range(1, outsource_max_late_weeks)`.
  - `delivery_week = week + Σ dev_weeks + late`, `deliverable &"engine"`, features duplicated.
- **`SignOutsourceCommand.part(p_company_id: int, p_vendor_id: int, p_project_id: int, p_deliverable: StringName) -> SignOutsourceCommand`.**
  - Validate: vendor; company GAME (`error.project_not_found`); PRODUCTION (`error.project_not_in_production`); `[&"art", &"audio"]` (`error.invalid_deliverable`); no OUTSOURCE contract for this project and deliverable (`error.already_outsourced`); money.
  - `price = mul_bp(outsource_part_price, size.cost_multiplier_bp)`.
  - RNG: `quality_roll = randi_range(0, 100)`. `target_points[deliverable] = mul_bp(mul_bp(par_points, outsource_part_par_bp), 5000 + quality_roll × 100)`. `delivery_week = maxi(week + 1, project.deadline_week)`.
- Both constructors: `money -= price`, emit `money_changed`.
- **Deliveries:**
  - **Engine:** at `week >= delivery_week`, create a GameEngine: OUTSOURCED, `name "ui.engine.outsourced_name"`, the features, `built_week = week`, `tech_cap = clampi(mini(100, engine_base_tech_cap + Σ tech_cap_add) − (quality_roll < outsource_low_quality_roll ? outsource_low_quality_cap_penalty : 0), 0, 100)`. Emit `contract_completed {contract_id, engine_id}` and remove the contract.
  - **Part:** follows B11. Remove the contract when its project is gone or past POLISH. When it is fully delivered, emit `contract_completed` and remove it.

- [ ] **Step 1: Failing tests**

```gdscript
func test_sign_license_unlocks_engine() -> void   # lic_engine_fx_pro: money 15000; licensed_engine_available true
func test_license_rejections() -> void   # homebrew -> license_not_needed; twice -> license_owned; unknown -> engine_unavailable
func test_outsource_engine_price_and_delivery() -> void   # [feature_fx_save]: price 3000, delivery in [week+2, week+6]
func test_engine_delivered_with_quality_penalty() -> void # quality_roll 20, due now -> tech_cap 25, OUTSOURCED, contract gone
func test_outsource_part_delivers_over_weeks() -> void    # {art:100}, delivery week+4 -> +25 x4, contract_completed
func test_part_lost_when_released() -> void
func test_outsource_rejections() -> void   # player as vendor; &"tech"; second art; locked feature_fx_scroll -> item_locked; [] -> no_features
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat(systems): engine licences, outsourced engines and parts`.

---

### Task 14 (content task): Perks, equipment years, names, strings (gd-content-author)

**Depends on:** T2 (serialize against M2c's strings task). **Files:** create 11 files `data/perks/perk_*.tres`; set `year_from` to 1978 in `data/equipment/equipment_micro_1980.tres` and 1985 in `equipment_micro_1985.tres`; append to `locale/strings.csv`; new tests `tests/unit/test_content_data_m2b.gd`, `tests/unit/test_localization_m2b.gd`.

**Content:**
- **PerkDefs:** `max_rank 3`, `name_key content.perk.<short>.name`, with a `.desc` string.

| id | path | effects_bp_per_rank |
|---|---|---|
| perk_coder, perk_designer, perk_artist, perk_composer | DEV | `{skill_tech}`, `{skill_design}`, `{skill_art}`, `{skill_audio}`: 500 each |
| perk_engine_architect | DEV | `{engine_speed_bp: 1500}` |
| perk_crunch_veteran | DEV | `{owner_burnout_bp: -2500}` |
| perk_negotiator | BUSINESS | `{contract_pay_bp: 1000, publisher_share_bp: -500}` |
| perk_recruiter | BUSINESS | `{candidate_skill_bp: 1000, asking_salary_bp: -500}` |
| perk_promoter | BUSINESS | `{hype_gain_bp: 1500}` |
| perk_accountant | BUSINESS | `{loan_rate_bp: -1500}` |
| perk_leader | BUSINESS | `{chemistry_bp: 500, morale_baseline_bp: 500}` |

- **Strings** (EN and TH, fictional):
  - `staff_name.01`–`staff_name.24`: mixed first names, Thai transliterated.
  - The 22 perk name and desc keys.
  - `ui.decision.accept`, `ui.decision.refuse`, `ui.contract_work.title`, `ui.engine.outsourced_name`.
  - `M2B_ERROR_KEYS`: `error.` + `game_over, candidate_not_found, staff_not_found, cannot_fire_owner, no_raise_pending, invalid_seat, seat_taken, equipment_not_found, equipment_not_available, seat_has_equipment, office_not_found, office_current, office_too_small, license_not_needed, license_owned, vendor_not_found, invalid_deliverable, already_outsourced, contract_not_found, contract_taken, contract_expired, lender_not_found, invalid_amount, over_credit_limit, bank_refused, loan_not_found, perk_not_found, no_skill_points, perk_maxed, invalid_focus`.

- [ ] **Step 1: Failing tests.**
  - `test_content_data_m2b`: `perks.size() == 11`; every `tr(name_key) != name_key`; `perk_promoter.effects_bp_per_rank[&"hype_gain_bp"] == 1500`; micro_1985 `year_from == 1985`; `validate()` is empty.
  - `test_localization_m2b`: every M2B key, the names and the `ui.*` keys have non-empty EN and TH that differ from the key; reset the locale in `after_each`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Author the files.**
- [ ] **Step 4: Run** import, then the full suite. Expected: exit 0.
- [ ] **Step 5: Commit** `content: add M2b perks, equipment years, staff names and strings`.

---

### Task 15: M2b acceptance scenario (gd-implementer)

**Depends on:** T4–T14. **Files:** create `tests/helpers/scenario_m2b.gd` (`class_name ScenarioM2b`), `tests/scenario/test_m2b_playthrough.gd`.

**Interfaces:**
- `ScenarioM2b.advance(state, script: Dictionary, weeks: int, content: ContentDB, tuning: TuningDef) -> void` runs the same loop as `Scenario.advance`. Unknown specs delegate to `Scenario._make_command`. New specs:
  - `["take_loan", "BANK"|"LENDER", amount]`: lowest company of that kind.
  - `["repay_loan_all"]`: lowest player loan, full balance.
  - `["hire_candidate"]`: lowest candidate id.
  - `["buy_equipment", def, seat]`.
  - `["accept_contract_work"]`: lowest open offer.
  - `["spend_skill_point", perk]`.
  - `["set_owner_focus", bp]`.
- `SCRIPT_M2B` (commands run before the tick of that week):

```
0:  take_loan BANK 5000
4:  hire_candidate; buy_equipment equipment_micro_1980 1; accept_contract_work
16: start_game "Star Run" size_small platform_nova8 topic_space genre_action lic_engine_homebrew []; sliders_ideal
30: spend_skill_point perk_coder
36: release
40: repay_loan_all
```

If a command is rejected, move it to the nearest week where it is valid and say so in the commit. Never loosen assertions.

- [ ] **Step 1: Tests** (real content and shipped tuning, as `test_m2a_playthrough`; `WEEKS := 80`)

```gdscript
func test_playthrough_reaches_every_m2b_milestone() -> void
    # staff 2; equipment 2; loans empty; owner.perks[&"perk_coder"] == 1; game_over false
    # one CONTRACT_WORK project, RETIRED, revenue == its contract.price; one GAME with 4 reviews, weekly_units >= 20
    # all candidates expires_week > week; validate_dict(round trip) true; real.missing_refs(s) empty
func test_loan_open_mid_run() -> void          # 20 weeks -> one BANK loan, balance < 5000
func test_same_seed_same_hash() -> void
func test_different_seed_different_hash() -> void
func test_save_load_continue_matches_uninterrupted() -> void   # save weeks [0, 4, 13, 16, 30, 36, 40, 60]
func test_values_stay_in_range() -> void       # morale, burnout 0..100; skills 1..100; loan balances >= 0
func test_bankruptcy_path() -> void
    # money -40000; shark loan at shark_limit; last_missed_week 0; 30 weeks -> game_over; 5 more weeks -> week unchanged
func test_survival_with_shark_loan() -> void   # money -3000; {0: [["take_loan","LENDER",8000]]}; 20 weeks -> no game over, months_negative 0, money >= 0
```

- [ ] **Step 2: Run** `-gselect=test_m2b_playthrough`. Fix real defects only.
- [ ] **Step 3: Run** import, then the full suite, including `test_m2a_playthrough`. Expected: exit 0.
- [ ] **Step 4: Commit** `test(scenario): M2b playthrough, bankruptcy and survival`.

---

### Task 16: StateQueries views for M2d panels (gd-implementer)

**Depends on:** T5, T10. **Files:** append to `src/core/state_queries.gd`. Test: `tests/unit/test_state_queries_m2b.gd`.

**Produces:**

```gdscript
static func market_salary(state: GameState, staff_id: int, t: TuningDef) -> int     # 0 if missing
static func monthly_costs(state: GameState) -> Dictionary                            # player, ContentDB.active()
static func available_credit(state: GameState, lender_id: int, t: TuningDef) -> int
static func pending_ask(state: GameState, staff_id: int) -> Dictionary   # {} or {"amount", "promotion", "deadline_week"}
```

- [ ] **Step 1: Failing tests:** 680; total 530; 10000; an ask dictionary from a fixture decision.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: exit 0.
- [ ] **Step 5: Commit** `feat(ui): StateQueries views for salary, costs, credit and asks`.

---

### Task 17: Spec sync (gd-implementer, docs only)

**Depends on:** T15 (serialize against M2c's spec sync). **Files:** `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md`.

- [ ] **Step 1:** Write the rulings into the spec:
  - §4.2/4.3/4.6/4.7: B1 fields.
  - §7.1: B6.
  - §7.2: B2–B5.
  - §7.2a: B7.
  - §7.3: B15.
  - §7.5: B11.
  - §7.6: B9, B10.
  - §7.7: B13, B14.
  - §13: the combined playthrough is written by whichever of M2b and M2c merges last.
- [ ] **Step 2:** Confirm the suite is green. Commit `docs: sync M2 spec with M2b rulings`.

---

## Spec coverage (self-review)

| Spec | Tasks |
|---|---|
| §7.1 owner xp, points, perks, focus, neglect | T3, T4, T6, T14 |
| §7.2 salary, raises, refusals, seat-limited hiring, pool, severance | T3, T5, T7 |
| §7.2a levels, promotions (lead role deferred, B7) | T3, T5 |
| §7.3 seats, buy/lease/sell, depreciation, lease upgrade, outdated, electricity, office move (dev kits done in M2a) | T3, T4, T8, T9 |
| §7.4 and §7.5 licence, outsourced engine and parts | T13 |
| §7.6 contract work | T4, T12 |
| §7.7 loans, repossession, seizure, survival, bankruptcy | T7, T8, T10, T11, T12 |
| §9 the 13 M2b commands | T5–T13 |
| §10 events (all already on EventBus) | T5–T13 |
| §12 validator, missing_refs | T2 |
| §13 loan and contract job in the scenario, determinism, save/load | T15 |
