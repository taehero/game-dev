---
name: gut-testing
description: How to write and run GUT tests for Studio Tycoon (Godot 4.7, headless on macOS) - setup, commands, unit and scenario test patterns, determinism and save round-trip checks. Use before writing or running any test in this project.
---

# GUT testing in Studio Tycoon

## Setup (once per project)

- GUT is vendored in `addons/gut/` and committed. Use the newest GUT 9.x release from https://github.com/bitwes/Gut whose release notes support the installed Godot (4.7.2). Do not assume a version; check the release notes.
- Enable the plugin in `project.godot` (`[editor_plugins]`).
- `.gutconfig.json` in the project root:

```json
{
  "dirs": ["res://tests/unit", "res://tests/scenario"],
  "include_subdirs": true,
  "prefix": "test_",
  "suffix": ".gd",
  "should_exit": true,
  "log_level": 1
}
```

## Commands

Project path has a leading space. Always quote it.

```bash
cd "/Users/chanapols/Projects/ game-dev"
godot --headless --import                                  # needed after a fresh checkout or a new class_name
godot --headless -s addons/gut/gut_cmdln.gd -gexit         # all tests (uses .gutconfig.json)
godot --headless -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/test_calendar_system.gd   # one file
```

Judge a run by the exit code: the post-run hook fails the run if any test script failed to load, even though the summary may still say All tests passed.

The exit code is non-zero when any test fails. Quote the GUT totals line in every report. If GUT reports "Could not find class" or a parse error for a `class_name`, run the import command and retry once before debugging.

## File conventions

- `tests/unit/test_<unit>.gd` for one system, command, entity or service.
- `tests/scenario/test_<scenario>.gd` for multi-week runs.
- Every test file: `extends GutTest`. Test functions: `func test_<behaviour>() -> void:`.
- Build state with the shared helper `tests/helpers/fixtures.gd` (`Fixtures.new_state(seed)`, `Fixtures.tuning()`, `Fixtures.add_staff()`, `Fixtures.add_project()`), not by hand in each test.
- `.gutconfig.json` must not scan `tests/helpers/` (helpers are not test files).

## Unit test pattern

```gdscript
extends GutTest

func test_crunch_raises_burnout_each_week() -> void:
    var state: GameState = Fixtures.new_state(42)
    var project_id: int = Fixtures.add_project(state, {"crunch": true})
    var staff_id: int = Fixtures.add_staff(state, {"burnout": 10, "assigned_project_id": project_id})

    StaffSystem.tick(TickContext.new(state, Fixtures.tuning()))

    assert_eq(state.staff[staff_id].burnout, 16, "crunch adds TuningDef.crunch_burnout_per_week")
```

Rules:
- Seeded RNG only. Never call `randomize()` in tests.
- Assert behaviour (state after the call), not private internals.
- Read expected tuning numbers from the `TuningDef` used by the fixture, so tuning changes do not break tests silently.

## Scenario and determinism pattern

```gdscript
func test_same_seed_same_hash() -> void:
    var a: String = Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
    var b: String = Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
    assert_eq(a, b)

func test_save_load_continue_matches_uninterrupted() -> void:
    var full: String = Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
    var state: GameState = Fixtures.new_state(7)
    Scenario.advance(state, Scenario.SCRIPT_BASIC, 260)
    var json: String = SaveService.serialize(state)
    var loaded: GameState = SaveService.deserialize(json).state
    Scenario.advance(loaded, Scenario.SCRIPT_BASIC, 260)
    assert_eq(StateHash.of(loaded), full)
```

`StateHash.of(state)` = `JSON.stringify(state.to_dict(), "", true, true).sha256_text()` (spec §9.1).

## Rule tests

`tests/unit/test_rules.gd` scans source text and fails on:
- `randi(`, `randf(`, `randomize(`, `randf_range(`, `randi_range(` not preceded by `rng.` in `src/core/` and `src/systems/`
- `ResourceSaver.save(` or `ResourceLoader.load(` in `src/core/save_service.gd`
- assignments to `state.` fields in `src/ui/`
