---
name: content-authoring
description: How to add Studio Tycoon content - .tres resources for eras, platforms, engines, genres, topics, art styles, business models, traits, world events, review outlets, review templates and tuning, plus EN/TH strings in locale/strings.csv. Use before creating or editing any file in data/ or locale/.
---

# Content authoring

## Where things go

| Content | Class (`src/content/`) | Folder |
|---|---|---|
| Era | `EraDef` | `data/eras/` |
| Platform | `PlatformDef` | `data/platforms/` |
| Engine | `EngineDef` | `data/engines/` |
| Genre | `GenreDef` | `data/genres/` |
| Topic | `TopicDef` | `data/topics/` |
| Art style | `ArtStyleDef` | `data/art_styles/` |
| Business model | `BusinessModelDef` | `data/business_models/` |
| Staff trait | `TraitDef` | `data/traits/` |
| World event | `WorldEventDef` | `data/events/` |
| Review outlet | `ReviewOutletDef` | `data/outlets/` |
| Review template | `ReviewTemplateDef` | `data/review_templates/` |
| Tuning numbers | `TuningDef` | `data/tuning.tres` |

File name = id without prefix duplication: `data/genres/genre_rpg.tres` with `id = &"genre_rpg"`.

## .tres format

Write text `.tres` files by hand with the script path of the class:

```
[gd_resource type="Resource" script_class="GenreDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/content/genre_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"genre_rpg"
name_key = &"content.genre.rpg.name"
desc_key = &"content.genre.rpg.desc"
base_audience = 0.8
ideal_focus = Array[int]([40, 70, 50])
```

Then run `godot --headless --import` so Godot accepts the file. If import rewrites the file (adds a `uid`), keep Godot's version.

`ContentDB` loads every `.tres` under `data/` at start and indexes by `id`. A duplicate id is an error.

## Strings (`locale/strings.csv`)

- Header: `keys,en,th`. One row per key. Quote values that contain commas.
- Key pattern: `content.<type>.<short>.<field>`, `review.<strong|weak>.<dimension>.<n>`, `ui.<screen>.<element>`, `error.<reason>`, `event.<id>.<field>`.
- Parameters use Godot format syntax: `"Gameplay is excellent, but performance is poor on {platform}."`
- Both `en` and `th` are required. Thai is natural game Thai. Keep common gaming terms (RPG, DLC, Patch, Bug, Hype) in English.
- Fictional names only: no real consoles, companies or trademarks (e.g. use "Nova 8" not a real 8-bit computer).

## Checklist before commit

1. Every `*_key` field in the new `.tres` exists in `strings.csv` with `en` and `th`.
2. Ids are unique and prefixed.
3. `godot --headless --import` then the content validation test (`tests/unit/test_content_db.gd`) pass.
