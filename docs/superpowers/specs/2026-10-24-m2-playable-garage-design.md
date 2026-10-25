# Milestone 2: Playable Garage (Design Spec)

- Date: 2026-10-24
- Status: Scope approved in brainstorming; pending written-spec review
- Builds on: Milestone 1 (branch `feat/m1-simulation-core`) and the foundation spec `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md`
- The foundation spec and `CLAUDE.md` hard rules 1–10 still apply. Where this spec changes a foundation section, this spec wins and the foundation section is updated in the same plan that implements the change.

## 1. Purpose

Turn the M1 simulation core into the first playable game: a 1980s garage studio with a visible office, a full Game-Dev-Tycoon-style loop, and the money and people pressure that make choices matter.

### 1.1 Decisions made in brainstorming

| Topic | Decision |
|---|---|
| Reference game | Copy Game Dev Tycoon's loop and feel. Never copy its art, text, names, numbers or formulas. All names in this game are fictional. |
| GDT mechanics in M2 | All of: topic + genre combos; 3 development stages with sliders; research points and unlocks; floating work bubbles; 4 review outlets with a 1–10 score and a sales graph; platforms that launch and die and need dev kits |
| Camera | Top-down 3/4 view, 16 px pixel art |
| Screen layout | Large office scene; bottom status bar for the active project; bottom tabs Project / Team / Equipment / Finance / Market that slide panels up |
| Computers | One workstation per seat; each machine has its own tier and age |
| Running out of money | Survival path before game over: bank loan, loan shark, contract work, sell equipment, lay off staff |
| Engines | Build in-house, outsource the build, or license someone else's |
| Owner | The player's character, with a Dev / Business skill tree and a focus slider |
| Art source | CC0 packs (Kenney first), one pixel scale. Font exception: Noto Sans Thai (SIL OFL 1.1), see §11.2 |

### 1.2 Out of scope (backlog, see §15)

Competitor studios, poaching, IP sales, investors and shares, selling the company, economy cycles and crises, genre trends (horror, Thai ghost), the AI track, Steam Workshop mods, eras after the 1980s, and selling engine licences.

## 2. Plan structure

M2 is one spec and four implementation plans:

| Plan | Content | Depends on |
|---|---|---|
| **M2a** Game loop | Content data for the 1980s, ContentDB, project lifecycle, production, research, engine projects, reviews, sales, platform lifecycle, scenario test | M1 |
| **M2b** People and money | Owner and skill tree, staff economy, hiring pool, seats and equipment, office levels, rent, electricity, engine licences, outsourcing, loans, contract work, bankruptcy | M2a interfaces (§4) |
| **M2c** After launch | Marketing channels, promotions, patches, DLC, forum, mod tools, game awards | M2a interfaces |
| **M2d** Office and UI | Art import, theme and font, office scene, bubbles, status bar, tabs and panels, concept wizard, review popup, sales graph | Scene: §4 shapes only. Panels: M2a–c |

**Order:** M2a and the M2d scene run in parallel. Then M2b and M2c run in parallel. M2d panels finish last. All entity shapes, signal names and the tick order in §4–§5 are fixed by this spec, so parallel plans agree.

## 3. Numbers rule (applies to every new value)

All state stays `int` (CLAUDE.md rule 9). New conventions:

| Quantity | Representation |
|---|---|
| Ratios, multipliers, chances, interest | basis points `_bp` (10000 = 1.0) |
| Review scores | int 10–100 meaning 1.0–10.0 (`score_x10`) |
| Hype, morale, burnout, reputation, quality | int 0–100 |
| Money | int whole currency units |
| Per-week decay or growth | one `Fixed.mul_bp(value, rate_bp)` step per tick; never `pow` or `exp` |
| Curves (install base, sales tail) | lookup tables of ints in content, indexed by week offset, linear interpolation in ints |
| Random noise | `ctx.rng.randi_range(a, b)` on ints |

Every tuning number named in this spec (UPPER_SNAKE names such as `WAGE_PER_SKILL_POINT`) becomes a `TuningDef` field or a content field. The plan that adds the field sets its initial value; values are tuned later without code changes.

## 4. Data model changes

### 4.1 GameState additions

| Field | Type | Notes |
|---|---|---|
| `owner` | `OwnerProfile` | One per game (the player's owner) |
| `equipment` | `Dictionary[int, Equipment]` | |
| `engines` | `Dictionary[int, GameEngine]` | Player-built or outsourced engines (licensed engines are content) |
| `loans` | `Dictionary[int, Loan]` | |
| `candidates` | `Array[Candidate]` | Hiring pool, refreshed monthly |
| `game_over` | `bool` | Set by bankruptcy |

`GameState.new_game` creates, in this id order: the player company, the owner `Staff` (`is_owner`, seat 0, all skills `owner_start_skill`, salary 0), one BOUGHT starter `Equipment` at seat 0, `OwnerProfile`, one BANK, one LENDER, two VENDORs and three AI_PUBLISHERs. The office is `tuning.start_office_id`. An AI company's `name` holds a `tr()` key; the UI shows `tr(company.name)`.

### 4.2 Company additions

`office_id: StringName` (content `OfficeDef`), `research_points: int`, `unlocked: Array[StringName]` (research ids done), `dev_kits: Array[StringName]` (platform ids), `months_negative: int`, `awards: Array[StringName]`.

New `Company.Kind` values: `BANK`, `LENDER` (loan shark), `VENDOR` (outsourcing studio). The game creates one bank, one lender, two vendors and three AI publishers at new game.

### 4.3 Staff additions

- `exp: Dictionary[StringName, int]` (same keys as `skills`); every 100 exp in a skill raises it by 1 (cap 100).
- `seat_index: int` (-1 = none); a staff member without a seat produces 0 points. Seats are derived: a seat is taken when a staff member of that company has that `seat_index`, and the seat count comes from `OfficeDef.seats`.
- A **worker** is a staff member who is seated, has equipment at the same seat index, and is assigned to the project. Only workers produce.
- `last_raise_week: int`, `asking_raise: int` (0 = none pending).
- `hired_week: int`, set by hiring. M2b uses it for the hire anniversary.
- `week_points: Dictionary[StringName, int]`: the points this staff member produced in the most recent Production step. Production clears it at the start of every tick, so Staff, Owner and Research (steps 5–7) read the previous tick's work.
- `is_owner: bool`. The owner is a Staff with `is_owner = true`: sits at a desk, produces points, cannot be fired, never resigns.

### 4.4 New entities

**OwnerProfile** — `staff_id: int`, `xp: int`, `skill_points: int`, `perks: Dictionary[StringName, int]` (perk id → rank), `focus_dev_bp: int` (0–10000; 10000 = fully hands-on).

**Equipment** — `id`, `company_id`, `def_id: StringName` (`EquipmentDef`), `ownership: {BOUGHT, LEASED}`, `seat_index: int` (-1 = in storage), `bought_week: int`, `value: int` (resale value, depreciates monthly).

**GameEngine** — `id`, `company_id`, `name: String`, `features: Array[StringName]` (`EngineFeatureDef` ids), `tech_cap: int` (0–100, the max tech score a game on it can reach), `source: {BUILT, OUTSOURCED}`, `built_week: int`.

**Loan** — `id`, `company_id`, `lender_id` (a BANK or LENDER company), `principal`, `balance`, `rate_bp_per_month`, `payment_per_month`, `missed_payments: int`, `taken_week`.

**Candidate** — `id`, `name: String`, `skills: Dictionary[StringName, int]`, `traits: Array[StringName]`, `level: int` (a `Staff.Level` value; the validator range-checks it), `asking_salary: int`, `expires_week: int`. Not a Staff until hired.

### 4.5 Project changes

- `kind: {GAME, ENGINE, CONTRACT_WORK}`.
- `size_id: StringName` (`ProjectSizeDef`: SMALL, MEDIUM in the 1980s).
- `focus` becomes `Array[int]` of 9 values: 3 sliders per stage, each stage's 3 values summing to 10000 (bp). Stage slider names: Stage 1 Code / Design / Story; Stage 2 Levels / Characters / AI; Stage 3 Graphics / Audio / Balance.
- `engine_id: int` (-1 = licensed engine named in `config.engine`).
- `stage_progress` is in bp (0–10000), not 0–100. Weekly progress uses ceiling division, so a 6-week stage ends in exactly 6 weeks.
- `features: Array[StringName]` chosen features for the game.
- `review_results: Array[ReviewResult]` (deferred from M1): each `outlet_id: StringName`, `score_x10: int`, `strength_key: StringName`, `weakness_key: StringName`.
- `weekly_units: Array[int]` (sales history for the graph, capped at 104 entries).
- `promo_until_week: int`, `promo_discount_bp: int`, `mod_tools: bool`, `dlc_count: int`.

### 4.6 Contract changes

`Contract.Kind` adds `OUTSOURCE` (we pay a vendor), `CONTRACT_WORK` (a publisher pays us), `ENGINE_LICENSE` (we pay a licensor). New typed fields: `price: int`, `royalty_bp: int`, `target_points: Dictionary[StringName, int]` (target per point type), `quality_roll: int` (0–100, fixed at signing from rng, hidden), `delivery_week: int`, `project_id: int` (-1 = none), `deliverable: StringName` (e.g. `art`, `audio`, `engine`). For `ENGINE_LICENSE`, `deliverable` holds the `LicensedEngineDef` id.

### 4.7 New content resources

| Class | Key fields |
|---|---|
| `OfficeDef` | id, name_key, seats, rent_per_month, electricity_base, moving_cost, `scene_path`, `desk_positions` (Array of Vector2i). `scene_path` and `desk_positions` of `office_garage` and `office_small` are owned by the M2d room layouts. |
| `EquipmentDef` | id, era tier, price, lease_per_month, power_per_month, speed_bp, bug_bp, recommended_until_year |
| `EngineFeatureDef` | id, research id required, tech_cap_add, dev_weeks |
| `LicensedEngineDef` | id, year_from, year_to, fee, royalty_bp, tech_cap, features |
| `ResearchDef` | id, cost_rp, prerequisites, unlocks (topic, genre, feature, size, channel ids) |
| `ProjectSizeDef` | id, base_weeks, min_staff, cost_multiplier_bp, audience_bp, `price` (per unit), `par_points` (points that score a par review) |
| `LevelDef` | level, min best skill, min total exp, salary_bp, output_bp |
| `PerkDef` | id, path (DEV/BUSINESS), max_rank, effects per rank (Dictionary of effect id → bp) |
| `MarketingChannelDef` | id, era years, cost, hype_gain, audience segment |
| `AwardDef` | id, fictional name key, week_in_year, entry_fee, prize, fans |

Existing `PlatformDef` gains: `dev_kit_cost`, `install_curve: Array[int]` (install base per quarter since launch), `rumor_weeks: int`, `genre_fit_bp: Dictionary[genre_id, int]` (platform-fit review dimension). Existing `TopicDef` gains `genre_fit_bp` (§6.2). `GenreDef` gains `ideal_sliders` (§6.3). All content values are ints, never floats.

### 4.8 Entity removal (one path for everything)

New `src/core/removal.gd` (`class_name Removal`) is the only code allowed to delete entities: `remove_staff`, `remove_equipment`, `remove_contract`, `remove_loan`, `remove_decision`, `remove_candidate`. Each scrubs every reference before deleting:

- `staff`: clear its seat; drop it from any project assignment; cancel decisions whose `related_ids` contain it. The owner cannot be removed.
- `equipment`: free the seat.
- `contract`: set `project.contract_id = -1` where referenced; cancel related decisions.
- Any removal of an id listed in a decision's `related_ids` removes that decision. This includes `remove_decision`: removing a decision also drops decisions whose `related_ids` contain its id.

Every removal type has a test that runs `GameState.validate_dict(state.to_dict())` afterwards and expects `true`. A rule test forbids `.erase(` on `state.staff/equipment/contracts/loans/projects` outside `removal.gd`.

### 4.9 Decisions

`GameSession` detects new decisions by snapshotting `state.next_id` before a step and treating any decision with `id >= snapshot` as new (the newest is the highest id). The paused command path also emits `decision_required` when a command adds a decision.

## 5. Tick order (replaces foundation §4.2)

1. Calendar
2. WorldEvent (stub in M2; award and platform-rumour events are scheduled by their own systems)
3. Market (stub in M2)
4. **Platform**: lifecycle phase, install base from curve, rumours, death
5. Staff: morale, burnout, exp gain, skill growth, yearly raise demands, resignation
6. **Owner**: xp from the week's work and events, skill points
7. **Research**: research points from work
8. Production: game, engine and contract-work projects
9. **Contracts**: outsource deliveries, contract-work deadlines and payment
10. Marketing: hype, channels
11. Sales: weekly units, promotions, royalties
12. LiveOps: patches, DLC, forum, mod tools
13. **Awards**: yearly ceremony
14. Finance: monthly salaries, rent, electricity, leases, loan payments, depreciation; repossession; bankruptcy check
15. **Hiring**: monthly candidate refresh and expiry

`Simulation.SYSTEMS` lists all 15 steps from M2a. Owner, Contracts, Hiring, Awards, Marketing and LiveOps are no-op stubs in M2a, and Staff and Finance keep their M1 behaviour (Staff is still a stub). M2b and M2c fill them in, so the two parallel plans never both edit the array. Each system is a file in `src/systems/`.

## 6. Game loop (M2a)

### 6.1 Concept

Commands: `StartProject` has two static constructors, `game(...)` and `engine(...)`. `engine_ref` is split into `engine_id: int` and `licensed_engine_id: StringName` (used when `engine_id == -1`). `StartProject` assigns every free worker of the company to the new project (there is no AssignStaff in M2).

Validation: platform on sale and dev kit owned; topic, genre, size and features unlocked; enough free seated staff for `min_staff`; engine available. A publisher deal (foundation §6.1) can attach at this point.

Unlock rule: an item (topic, genre, size, feature, channel) is unlocked when no `ResearchDef.unlocks` lists it, or when the company has done one research that lists it. A platform with `dev_kit_cost == 0` counts as owned. The built-in licensed engine `lic_engine_homebrew` (fee 0) needs no contract. Any other licensed engine needs an `ENGINE_LICENSE` contract (M2b).

Content access: `ContentDB.active()` is a process-wide instance (loaded lazily from `res://data`; `ContentDB.use(db)` replaces it). Commands read it in `validate`; `TickContext.content` carries it to systems. Tests install a small in-memory DB through `Fixtures.new_state()`.

### 6.2 Topic + genre fit

`TopicDef.genre_fit_bp: Dictionary[genre_id, int]` from 5000 (bad) to 15000 (great). Fit is fixed in M2 (M3 makes it move with the market). The player discovers fit through reviews; the game remembers the best review per combo and shows it in the concept wizard as "Great / Good / Okay / Bad / Unknown".

### 6.3 Production

- Three stages; each stage lasts `size.base_weeks / 3` weeks at full staffing. After the last stage a GAME goes to POLISH. An ENGINE project has one stage (its length is the sum of feature `dev_weeks`).
- Each Production step does, per project: (1) clear every `Staff.week_points` (always, first); (2) only in PRODUCTION: points, bug rolls and stage progress; (3) only in POLISH: bug fixing (no points). POLISH draws no RNG. In PRODUCTION there is one bug roll per working staff member, in sorted staff id order. Points and bug events are emitted per staff member, interleaved: A's points, then A's bugs, then B's. If all workers leave, the project stalls with no events.
- Weekly points per seated, assigned person: `skill × slider share × equipment speed_bp × morale factor × chemistry factor`, all via `Fixed.mul_bp`.
- Each slider maps to point types: Code/AI/Balance → tech; Design/Levels/Story → design; Characters/Graphics → art; Audio → audio.
- The genre has ideal slider weights per stage (`GenreDef.ideal_sliders: Array[int]` of 9 bp values). Match quality is computed per stage as `max(0, 10000 − Σ|focus − ideal|)` over that stage's 3 values; gameplay uses the average of the 3 stage matches. (Summing all nine at once would floor almost every real setting at 0.)
- Bugs per week: base rate × crunch × chemistry × equipment `bug_bp` × engine age.
- **Bubbles:** every point gain and every bug emits `points_gained {staff_id, type, amount}` / `bug_found {staff_id}` for the scene.

### 6.4 Engine projects

`kind = ENGINE`. The player picks features they have researched; dev time = sum of `dev_weeks`; result is a `GameEngine` with `tech_cap = base + sum(tech_cap_add)`. A game's tech score is capped at its engine's `tech_cap`.

### 6.5 Research

Every production week adds research points: `RESEARCH_PER_POINT_BP` of points produced. Research is bought from the Research list (`ResearchDef`), spending RP, instantly unlocking items. The 1980s list unlocks topics, genres, engine features (e.g. scrolling, save game, sound chip music, colour palette), the MEDIUM size and marketing channels.

### 6.6 Release, reviews and sales

- Reviews: dimension scores as foundation §7.1, stored ×10. Four fictional outlets with their own weights and an int bias (−5..+5). Noise `randi_range(-3, 3)`. Strength and weakness template keys come from the highest and lowest dimension. Scores clamp to 10–100; a missing template falls back to the generic key.
- **Known limitation:** strength and weakness are the argmax and argmin of the shared dimension scores, so every outlet gives the same reason keys for a game. Outlet weights only include or exclude a dimension. Per-outlet variety is left for a later milestone.
- Lifecycle: `ReleaseProject` is valid only in POLISH and sets RELEASED. The first sales tick sets LIVE; sales below the floor set RETIRED. An ENGINE project goes from its last stage straight to RETIRED and creates the `GameEngine`.
- Launch week units = `install_base(platform, week) × fit_bp × size.audience_bp × hype factor × review factor`, each factor an int table lookup or `mul_bp` step.
- Every later week: `units = mul_bp(units, decay_bp)`, where `decay_bp` comes from a table keyed by average review score. Sales stop below `SALES_FLOOR_UNITS`.
- Revenue = units × price, minus publisher share and engine royalty.

### 6.7 Platforms

Fictional 1980s platforms (5): two home micros, one console, one arcade-cabinet licence, one late-decade handheld. Each has a launch week, an install curve and an end week. `rumor_weeks` before launch, a `platform_rumored` event fires. After the end week, the platform leaves the concept wizard, its dev kit stops counting, and sales on it decay twice as fast. With `mul_bp` steps this is `decay_bp' = max(0, 2 × decay_bp − 10000)`. A project already in development on a retired platform can still be released; a new `StartProject` on it is refused.

## 7. People and money (M2b)

### 7.1 Owner

- Starts as the only staff, seated in the garage, all four skills 30.
- Gains xp from points produced and from releases; every `OWNER_XP_PER_POINT` xp gives one skill point.
- **Dev path** perks (rank 1–3 each): Coder, Designer, Artist, Composer (skill +), Engine Architect (engine dev weeks −), Crunch Veteran (owner burnout −).
- **Business path** perks: Negotiator (contract pay +, publisher share −), Recruiter (candidate skill +, asking salary −), Promoter (hype gain +), Accountant (loan rate −), Leader (team morale and chemistry +).
- **Focus slider** (`focus_dev_bp`): the owner's point output × focus; Business perk effects × (10000 − focus). With more than `OWNER_SOLO_LIMIT` staff and focus above 7000, team morale drops by `OWNER_NEGLECT_MORALE` per month.

### 7.2 Staff economy

- Market salary = `era_wage_base + sum(skills) × WAGE_PER_SKILL_POINT`.
- Each year on their hire anniversary, staff paid below 90% of market salary ask for a raise to market. Accept: salary rises. Refuse: morale −15; refused twice → resignation chance doubles.
- The M1 `max_staff_default` limit is removed from `TuningDef`. Hiring is limited by free seats: `HireStaffCommand` (and `HireCandidate`) require a free seat in the current office and fail with `error.no_free_seat`.
- Hiring pool: on each month start, `CANDIDATES_PER_MONTH` candidates appear with skills drawn by era, asking salary = market ± `randi_range(-10, 15)`%; each expires after 8 weeks. Hiring needs a free seat.
- Firing pays `SEVERANCE_MONTHS` of salary and lowers everyone's morale by 5.

### 7.2a Career levels

- `Staff.level: {JUNIOR, MID, SENIOR, LEAD}` (new field). Level sets the salary multiplier (`LEVEL_SALARY_BP`), output multiplier (`LEVEL_OUTPUT_BP`) and the chemistry effect of leading others.
- A staff member becomes eligible for promotion when their best skill and total exp pass the next level's thresholds (`LevelDef` content). Eligible staff ask for a promotion; the player accepts (salary rises to the new level's market rate) or refuses (morale −10, raise-demand rules apply).
- `LEAD` replaces the M1 `Role.LEAD_*` meaning: only a `LEAD` can take a lead role on a project; a project without a lead in a discipline gets that discipline's bug penalty.
- Candidates in the hiring pool come with a level; seniors ask more.
- **Managers and C-level (CTO, Creative Director, CFO, CMO, COO) are M3**, because they need offices bigger than the 1980s allow. M2 only reserves the enum values `MANAGER` and `EXECUTIVE` and the `Staff.title: StringName` field so M3 adds them without a schema change.

### 7.3 Seats and equipment

- Seats come from the office (`OfficeDef.seats`). The 1980s offices: Garage (2 seats, no rent, electricity only) and Small Office (5 seats, rent). Moving office is a command with a one-time moving cost.
- A seat needs an `Equipment` to produce points. Buy (price now, resale value depreciates `DEPRECIATION_BP_PER_MONTH`) or lease (monthly fee, upgraded free when a newer tier exists).
- Equipment older than its `recommended_until_year` applies `OUTDATED_SPEED_BP` and `OUTDATED_BUG_BP` penalties.
- Dev kits: buy once per platform (`dev_kit_cost`).
- Electricity per month = office base + sum of `power_per_month` of seated equipment.

### 7.4 Engines from others

- **Licence:** sign an `ENGINE_LICENSE` contract: `price` now, `royalty_bp` of every sale of games built on it.
- **Outsource build:** sign an `OUTSOURCE` contract with deliverable `engine` and a feature list; price scales with features; delivered on `delivery_week` (late by up to 4 weeks on a bad roll); `quality_roll` below 40 gives a `tech_cap` penalty.

### 7.5 Outsourcing parts of a game

`OUTSOURCE` contract with deliverable `art` or `audio` for a project: adds points of that type over the remaining weeks according to `quality_roll`; costs `price`.

### 7.6 Contract work

Monthly, AI publishers offer `CONTRACT_WORK` jobs: target points per type, deadline, pay. The player assigns staff to a `kind = CONTRACT_WORK` project. Meeting the target by the deadline pays in full; missing it pays 50% and costs reputation. Owner Negotiator perk raises pay.

### 7.7 Loans and bankruptcy

- **Bank:** limit = `BANK_LIMIT_BASE + reputation × BANK_LIMIT_PER_REP`; rate `BANK_RATE_BP_PER_MONTH`; refuses new loans when the player has missed any payment in the last 12 months.
- **Loan shark (fictional lender):** always lends up to `SHARK_LIMIT`; rate `SHARK_RATE_BP_PER_MONTH` (several times the bank's). A missed payment triggers repossession: the lender takes owned equipment (oldest first) until its value covers 150% of the missed payment, reputation −5, all staff morale −10. Three missed payments in a row: the lender also takes `SHARK_SEIZE_BP` of current cash each month until repaid.
- Payments are taken on the first week of each month. Money below 0 counts as a missed payment for every loan due.
- **Survival actions:** sell equipment (at current `value`), lay off staff, take contract work.
- **Bankruptcy:** money below 0 at three consecutive month starts with no unused bank or shark credit → `game_over = true`, event `game_over`, game stops ticking.

## 8. After launch (M2c)

- **Marketing channels (1980s):** magazine ad, TV spot, trade show (fixed dates), mail-order catalogue listing. Each costs money and adds hype for a segment. Later eras add channels (social media, streamers) as content only.
- **Promotions:** for a released game, set a discount (1000–5000 bp) for 1–4 weeks: weekly units × `PROMO_UPLIFT_TABLE[discount]`, price × (10000 − discount). Each promotion within 26 weeks of the previous one lowers future full-price launch hype by `PROMO_FATIGUE` (players learn to wait).
- **Patches:** a post-launch task that removes bugs and raises user score; costs staff weeks.
- **DLC:** a small `GAME` project linked to the original; sales tail extension.
- **Forum:** posts appear from bugs and review weaknesses; replies (apologise / promise patch / ignore) change sentiment.
- **Mod tools:** a post-launch task (fixed staff weeks). After release: sales `decay_bp` improves by `MOD_TAIL_BP`; DLC uplift falls by `MOD_DLC_PENALTY_BP`; each month a small chance of a "community mod goes viral" event (fans + sales spike).
- **Game awards:** one fictional yearly award. Entry costs `entry_fee`; eligible games are those released in the last 52 weeks. The winner is the entry with the highest average `score_x10` plus `randi_range(0, 8)`, compared with three AI entries rolled from era quality. Prize: money, fans, reputation, and the award id stored on the company.

## 9. Commands added in M2

`StartProject`, `SetSliders`, `ReleaseProject`, `BuyResearch`, `BuyDevKit`, `HireCandidate`, `FireStaff`, `AnswerRaise`, `AssignSeat`, `BuyEquipment`, `LeaseEquipment`, `SellEquipment`, `MoveOffice`, `SignEngineLicense`, `SignOutsource`, `AcceptContractWork`, `TakeLoan`, `RepayLoan`, `SpendSkillPoint`, `SetOwnerFocus`, `RunMarketing`, `StartPromotion`, `StartPatch`, `StartDLC`, `BuildModTools`, `ReplyForum`, `EnterAward`. Each validates and returns a `tr()` reason key on failure.

## 10. Events added in M2

`points_gained`, `bug_found`, `project_stage_changed`, `research_done`, `platform_rumored`, `platform_launched`, `platform_retired`, `raise_requested`, `staff_hired`, `staff_fired`, `equipment_changed`, `loan_taken`, `payment_missed`, `repossessed`, `contract_offered`, `contract_completed`, `award_result`, `promotion_started`, `game_over`, `game_loaded` (emitted by `GameRunner.load_game` and `GameRunner.start_new_game` so panels refresh). All of them exist on `EventBus` from M2a, because `dispatch` drops unknown names and the M2d scene runs in parallel.

## 11. Office scene and UI (M2d)

### 11.1 Scene

- `TileMapLayer` rooms per `OfficeDef`, 16 px tiles, integer scaling (window 1280×720 → 4×), pixel textures imported with filter off.
- Desk sprites at `OfficeDef.desk_positions`; computer sprite per equipment tier; staff sprite per seat with states idle / working / crunching / burned out.
- Bubbles rise from a staff sprite on `points_gained` (colour per type) and `bug_found`.
- The scene reads state only through `StateQueries` and refreshes on events; it works with seats and equipment from §4 even before M2b systems exist (fixtures place them).

> **Superseded visuals (2026-10-25):** the look of §11.1–11.3 (art packs, bottom status bar, flat tabs) is replaced by `docs/superpowers/specs/2026-10-25-ui-restyle-design.md` (direction C, "Clean Modern Tycoon"). Behaviour and data rules here still apply.

### 11.2 Art and font licensing

- Art: CC0 only. **M2d task 1 chooses a top-down 16 px Kenney pack, downloads it, and confirms the `License.txt` inside says CC0 before any file is committed.** Every asset is listed in `assets/CREDITS.md` with pack name, URL and licence.
- Font: Noto Sans Thai under the SIL Open Font License 1.1. This is the one non-CC0 asset, allowed because the OFL permits bundling in commercial games. Ship `OFL.txt` next to the font and list it in `assets/CREDITS.md`.
- Fictional names only for platforms, companies, outlets, awards, lenders.

### 11.3 Screens

- Bottom status bar: active project title, stage progress, D/T/A/S points, bugs, hype.
- Tabs: **Project** (sliders, staff assignment, release), **Team** (staff, candidates, owner tree, raises), **Equipment** (seats, buy/lease/sell, dev kits, office move, engines), **Finance** (cash, monthly costs, loans, contract work offers), **Market** (platforms, research list, marketing, promotions, awards).
- Concept wizard (multi-step popup), review popup (4 outlet cards with reason text), sales graph (from `weekly_units`).
- Theme: one Godot `Theme` resource with the Thai-capable font; all strings via `tr()`.
- The M1 debug HUD stays reachable behind a debug key (F3) for testing.

### 11.4 Free assets and addons

- Prefer free, ready-made assets and addons over writing new ones: Kenney UI Pack for popup frames and buttons, Kenney Interface Sounds / Audio for sound, Kenney Game Icons for icons (all CC0).
- Allowed licences: CC0, MIT, OFL. CC-BY only with a `CREDITS.md` row. No GPL or other copyleft code (closed-source Steam release).
- Godot addons go in `addons/` with their licence file. Addons may provide UI, tweens and popups only. Simulation code stays ours (determinism, ints, sorted iteration).

### 11.5 Mini-games and production events (M2d-panels)

Three small interactive moments, each a popup that pauses the game. All outcomes are decided by `Command`s and seeded RNG, so they stay deterministic and replayable.

- **Production events.** During PRODUCTION a project may roll an event (for example "a big bug appears", "a staff member has a bold idea"). The popup offers 2–3 choices; each choice applies fixed effects (points, bugs, hype, morale, weeks). Events are content (`.tres`), with EN/TH text.
- **Bug hunt.** During POLISH the player may start a short timed mini-game: catch bugs that pop up in the office scene. The result (bugs caught) is submitted as one command that removes up to that many bugs, capped by tuning. Skipping it is always allowed and costs nothing.
- **Publisher pitch.** When signing a publishing deal, the player answers 2–3 multiple-choice questions about the game. Good answers improve the deal terms within tuning limits.
- The real-time part of bug hunt lives in UI only. The simulation sees only the submitted result, validated by the command (never more bugs removed than exist, never more than the tuning cap).

## 12. Save compatibility

`schema_version` stays 1 until the first public build (M1 rule). M2 adds fields freely. The validator (`StateValidator`) is extended in the same task that adds each field, including reference checks for every new runtime int id field. Content-id references are not checked by the validator (it stays content-free). `ContentDB.missing_refs(state)` checks them at load time: company office, research, awards and dev kits; equipment defs; project size, platform, genre, topic, engine, feature and outlet ids; contract `locked_genre`, `locked_platform` and the `ENGINE_LICENSE` deliverable; owner perk keys; engine features. `GameRunner.load_game` refuses a save with missing refs using `error.save_content_missing` and leaves the current game untouched.

## 13. Testing

- Unit tests per system and command, as in M1.
- **M2 acceptance scenario** (`tests/scenario/test_m2_playthrough.gd`): a scripted headless run from 1980 that hires one staff member, buys equipment, researches one feature, builds an engine, makes and releases two games, receives four reviews with reason keys, sells for at least 20 weeks, takes and repays a bank loan, completes one contract job, and ends with valid state; plus the M1 determinism properties (same seed same hash; save/load/continue at five points) over this richer script.
- Rule tests: entity removal only in `removal.gd`; every new `.gd` under `src/core` and `src/systems` keeps the M1 bans.
- **Manual Mac checklist (M2d):** scene renders at 4× without blur; Thai text renders; bubbles appear while developing; each tab opens; concept wizard creates a game; review popup shows four outlets; sales graph draws.

### 13.1 Success criteria for M2

1. The acceptance scenario passes and is deterministic.
2. A player can start in the garage, make and sell games, hire, borrow, and go bankrupt, all through the UI.
3. Review reasons match the actual weak and strong dimensions.
4. Foundation criterion 4 ("no single configuration wins for the whole era") is **not** claimed for M2: topic/genre fit is fixed until M3's dynamic market.

## 14. Folder additions

```
src/core/removal.gd
src/core/entities/{owner_profile,equipment,game_engine,loan,candidate,review_result}.gd
src/systems/{platform,owner,research,contracts,awards,hiring}_system.gd
src/content/{office,equipment,engine_feature,licensed_engine,research,project_size,perk,marketing_channel,award}_def.gd
src/ui/office/, src/ui/panels/, src/ui/theme/
data/{offices,equipment,engine_features,licensed_engines,research,sizes,perks,channels,awards,topics,genres,platforms,outlets,review_templates}/
assets/ (art, fonts, CREDITS.md)
```

## 15. Backlog (agreed for later milestones)

| Milestone | Items |
|---|---|
| **M3** Economy and rivals | buying shares of rival studios (reaching 100% takes the rival over, with its staff, IPs and engine); Manager and C-level positions (CTO, Creative Director, CFO, CMO, COO): each takes over part of the owner's Business work, so the owner can keep a high dev focus in a big studio, and each has its own salary demands and poaching risk; AI competitor studios releasing games; poaching staff; offers to buy our games/IP; investors buying shares; a rival buying our company, then starting a new studio with the money and the owner's skills; economy cycles and era crises with fictional names (1980s market crash, dot-com bust, financial crisis, pandemic); genre trends such as a horror boom and the Thai ghost topic; dynamic market taste; selling our engine licence |
| **M4** AI track | AI per era with era-based cost (expert systems, middleware licences, in-house tools, cloud ML, generative AI); cloud subscription tiers with token overage vs local AI on GPU servers (electricity, ML engineer); vendor price hikes, outages, data leaks; AI art backlash and staff resistance; later selling our own AI subscription |
| **Grand Strategy** (late game) | Designing and manufacturing our own console (hardware specs, unit cost, launch price, install base, exclusive deals); own digital store; acting as a publisher for smaller studios (fund them, take a revenue share) and incubating sub-studios; our own subscription service (Game-Pass-style catalogue, monthly fee, paying other studios to join) and licensing our games into others' subscription services; cloud gaming service (streaming, server cost per player, no hardware needed) |
| **M5** Platform features | Steam Workshop mods for Studio Tycoon itself (data-only JSON, never `.tres` or scripts); Steamworks achievements and cloud saves |
| Era milestones | Content for the 1990s–2020s, including later marketing channels (websites, video, social media, streamers, short video); 2010s business models: Early Access (sell before release, player feedback shapes reviews, risk of never-finished backlash) and free-to-play mobile with microtransactions (store cut, whales vs fair monetization, monetization backlash); smartphone platforms; esports from the 2000s on (run tournaments for our games, sponsors, prize pools, hype and long-tail sales) |
