---
name: gdscript-conventions
description: Studio Tycoon GDScript and architecture conventions - templates for entities (to_dict/from_dict), stateless systems, commands, EventBus usage, typing, naming and JSON save rules. Use before writing or reviewing any GDScript in this project.
---

# GDScript conventions for Studio Tycoon

The binding rules are in `CLAUDE.md` and the spec. This skill shows how to follow them.

## General

- Godot 4.7. Static typing everywhere: variables, parameters, returns, typed arrays `Array[int]`, typed dictionaries `Dictionary[int, Staff]`.
- File names snake_case; `class_name` PascalCase; one class per file.
- Constants and enums UPPER_SNAKE. Signals past tense (`review_published`).
- No `@onready` or Node APIs in `src/core/` and `src/systems/`. Those folders must run headless without a scene tree.
- Integer money. No floats in state or simulation math: ratios are `_bp` ints (`Fixed.ONE_BP` = 10000), scaled with `Fixed.mul_bp()`, chances rolled with `Fixed.roll_bp()`.

## Entity template (`src/core/entities/`)

```gdscript
class_name Staff
extends RefCounted

var id: int
var company_id: int
var name: String
var skills: Dictionary[StringName, int] = {}
var traits: Array[StringName] = []
var morale: int = 70
var burnout: int = 0
var salary: int = 0

func to_dict() -> Dictionary:
    return {
        "id": id,
        "company_id": company_id,
        "name": name,
        "skills": skills.duplicate(),
        "traits": traits.map(func(t: StringName) -> String: return String(t)),
        "morale": morale,
        "burnout": burnout,
        "salary": salary,
    }

static func from_dict(d: Dictionary) -> Staff:
    var s := Staff.new()
    s.id = int(d["id"])
    s.company_id = int(d["company_id"])
    s.name = String(d["name"])
    for k: String in d["skills"]:
        s.skills[StringName(k)] = int(d["skills"][k])
    for t: String in d["traits"]:
        s.traits.append(StringName(t))
    s.morale = int(d["morale"])
    s.burnout = int(d["burnout"])
    s.salary = int(d["salary"])
    return s
```

JSON rules (spec §9.1): JSON numbers come back as float and keys as String. Cast every int with `int()`. Convert `Dictionary[int, …]` keys with `int(key)`. Convert StringName with `StringName()`. Store 64-bit RNG seed/state as decimal strings. Never store floats: Godot's JSON parser does not round-trip doubles exactly.

## System template (`src/systems/`)

```gdscript
class_name StaffSystem
extends RefCounted

static func tick(ctx: TickContext) -> void:
    var state: GameState = ctx.state
    var t: TuningDef = ctx.tuning
    for staff_id: int in state.sorted_ids(state.staff):
        var s: Staff = state.staff[staff_id]
        # ... uses ctx.rng, never global randf()
        ctx.emit(&"staff_resigned", {"staff_id": staff_id})
```

- No member variables. Everything comes from `ctx` (`ctx.state`, `ctx.rng`, `ctx.tuning`).
- Iterate in sorted id order when the order changes state or RNG draws (determinism).
- Push events through `ctx.emit()`. `GameRunner` flushes them to `EventBus` after the tick.

## Command template (`src/core/commands/`)

```gdscript
class_name SetCrunchCommand
extends Command

var project_id: int
var enabled: bool

func _init(p_project_id: int, p_enabled: bool) -> void:
    project_id = p_project_id
    enabled = p_enabled

func validate(state: GameState, tuning: TuningDef) -> CommandResult:
    if not state.projects.has(project_id):
        return CommandResult.fail(&"error.project_not_found")
    return CommandResult.success()

func apply(ctx: TickContext) -> void:
    ctx.state.projects[project_id].crunch = enabled
    ctx.emit(&"project_changed", {"project_id": project_id})
```

Rejection reasons are `tr()` keys.

## UI

- UI scripts read through `StateQueries` static functions and send `GameRunner.submit(SomeCommand.new(...))`.
- Refresh on `EventBus` signals, not in `_process`.
- All text: `tr(&"key")` or `tr(&"key").format({...})`.
