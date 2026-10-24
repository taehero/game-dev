# Studio Tycoon

Game-studio tycoon game. Godot 4.7.2, GDScript (static typing everywhere), GUT for tests. Targets Steam on Windows and macOS.

- Design spec (binding authority): `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md`
- Plans: `docs/superpowers/plans/`

## Environment

- Project path has a LEADING SPACE: `/Users/chanapols/Projects/ game-dev`. Always quote it in shell commands.
- Godot binary: `/Users/chanapols/homebrew/bin/godot` (4.7.2.stable). Use `godot` in commands.
- Fresh checkout or new `class_name`: run `godot --headless --import` before tests, because the class cache lives in the gitignored `.godot/` folder.
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`. See the `gut-testing` skill.

## Hard rules (from the spec)

1. `GameState` and entities are pure data (`RefCounted`), never `Node`. All mutable runtime data lives in `GameState`.
2. Systems in `src/systems/` hold no state: static functions that take `(state, rng, week)` or a `TickContext`.
3. Only Commands and Systems change `GameState`. UI code in `src/ui/` only reads state via `StateQueries` and sends Commands through `GameRunner.submit()`.
4. No global `randi()`, `randf()`, `randomize()` or `randf_range()` in `src/core/` or `src/systems/`. Use the `RandomNumberGenerator` passed in.
5. Entities reference each other by id (int for runtime entities, `StringName` for content). Never by object reference.
6. Every player-facing string goes through `tr()` with a key in `locale/strings.csv` (columns `keys,en,th`). No literal display text.
7. Saves are JSON only via `to_dict()` / `from_dict()`. Never `ResourceSaver`/`ResourceLoader` for saves. Follow the JSON type rules in spec §9.1 (64-bit RNG values as strings, cast ints back, convert dictionary keys back, sorted keys).
8. Tuning numbers live in `data/tuning.tres` (`TuningDef`), not in code.
9. No `float` in `GameState` or entities. Ratios, multipliers and chances are `int` basis points with a `_bp` suffix (`Fixed.ONE_BP` = 10000 = 1.0). Simulation math uses `Fixed.mul_bp()` and `Fixed.roll_bp()`; no `pow`/`exp`/`log`/trig on simulation values in `src/core/` or `src/systems/`. Floats are allowed only in UI and real-time pacing (`seconds_per_week`).
10. Any iteration that changes state, draws RNG or breaks a tie iterates `GameState.sorted_ids()` / `sorted_names()`, never raw Dictionary order.

## Layout

```
src/core/      game_state.gd, entities/, commands/, event_bus.gd, game_runner.gd, save_service.gd, state_queries.gd
src/systems/   one file per system
src/content/   Resource class definitions
src/ui/        office/, hud/, panels/
data/          content .tres files
locale/        strings.csv
tests/         unit/, scenario/
tools/         balance_sim.gd
```

## Agents

Main session is the manager. Dispatch:

- `gd-implementer` (sonnet): one plan task, TDD, one commit.
- `gd-content-author` (sonnet): `.tres` content and EN/TH strings.
- `gd-reviewer` (opus): read-only review of a task or branch against spec and plan.
- `gd-architect` (opus): design questions, BLOCKED/NEEDS_DESIGN tasks, hard debugging, fix rounds 4+.

Subagents cannot spawn subagents. A sonnet agent that needs deeper design reports `NEEDS_DESIGN` and stops; the manager dispatches `gd-architect`.
