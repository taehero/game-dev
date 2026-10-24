# M2d-scene: Office Scene and Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The visual foundation of Studio Tycoon: CC0 pixel art, a Thai-capable theme, crisp 4× pixel scaling, a garage/small-office scene with desks, computers, posed staff and work bubbles, a bottom status bar and an empty tab bar, all in a new `main.tscn` with the M1 debug HUD behind F3.

**Architecture:** Everything lives in `src/ui/` and reads state only through `StateQueries` (new pure functions) and refreshes on `EventBus` signals. Art coordinates live in one file (`OfficeArt`), so art can be swapped without touching scene code. Rooms are `TileMapLayer`s painted at runtime from a room size, and the TileSet is built in code from `OfficeArt`. Tasks 1–9 use only M1 interfaces. Tasks 10–11 need M2a's data model and are marked **Blocked by M2a**.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), GUT 9.x, Kenney CC0 art, Noto Sans Thai (SIL OFL 1.1).

**Spec:** `docs/superpowers/specs/2026-10-24-m2-playable-garage-design.md` §1.1, §4, §10, §11.1–11.3, §13 (manual checklist). Foundation spec `docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md` §1.2 (art rules), §8 (UI rules). Panel contents, concept wizard, review popup and sales graph belong to the later M2d-panels plan.

## Global Constraints

- Godot 4.7.2 at `/Users/chanapols/homebrew/bin/godot`. The project path has a leading space, so always quote `"/Users/chanapols/Projects/ game-dev"`.
- Static typing everywhere. Run `godot --headless --import` after adding any `class_name`, image or font, then run `godot --headless -s addons/gut/gut_cmdln.gd -gexit`. Judge the run by its exit code.
- UI reads state only via `StateQueries` static functions and acts only via `GameRunner.submit()` / `GameRunner.set_speed()`. UI never keeps a `GameState` or entity reference across frames. It re-reads `GameRunner.session.state` on every refresh, because load and new game replace the session.
- **Rule-test trap:** `test_no_direct_state_writes_in_ui` flags any identifier ending in `state` followed by `.field =` in `src/ui/`. Never name a UI variable `*state` (use `pose`, `look` or `view`).
- Every player-facing string goes through `tr()` with a key in `locale/strings.csv` (`keys,en,th`). Task 2 adds every key this plan needs. Node names and content ids are not display text.
- Art: CC0 only. Every pack's `License.txt` is committed next to its sheet and listed in `assets/CREDITS.md`. The font is the single OFL exception, with `OFL.txt` next to it.
- Fictional names only. No Game Dev Tycoon art, text or names.
- Pixel art: 16 px tiles. Every art pixel is exactly 4 screen pixels at 1280×720 (Ruling 1). Textures import lossless with no mipmaps. The canvas texture filter is Nearest.
- Do not add M2a's signals, entity fields or content classes yourself. If a blocked task's M2a interface is missing, report `BLOCKED` and name it.
- Commit after each task (Conventional Commits) with the agent's `Co-Authored-By` line. Stage files by explicit path.

## Rulings made in this plan

1. **Display: logical viewport 640×360, `canvas_items` stretch, `integer` scale, office node at scale 2.** Art pixels are 4 screen pixels at 1280×720 (spec §11.1). The window is 2× at 720p, 3× at 1080p (art 6×) and 4× at 1440p (art 8×), so it fills common Steam resolutions with integer scaling. UI text is laid out in 640×360 units and oversampled, so Thai stays sharp. A 320×180 base would make Thai text tiny, and a 1280×720 base letterboxes a 1080p screen at 1×. *Cost if wrong:* re-tune theme font sizes and bar heights (Tasks 2, 7–9). That is cheap now and expensive after the panels plan.
2. **Font: the Google Fonts build of Noto Sans Thai** (`github.com/google/fonts/ofl/notosansthai`, variable `NotoSansThai[wdth,wght].ttf`). Its subsets include Latin (U+0000–00FF) as well as Thai, so one font is the theme's default font and needs no fallback chain. The file is renamed `NotoSansThai-Variable.ttf`, because brackets in `res://` paths are fragile. The OFL restricts reusing the Reserved Font Name for modified fonts, not file names. System font fallback is off, so a missing glyph shows in tests instead of being hidden by the OS. *Cost if wrong:* if the Latin subset is missing, Task 2's `has_char(65)` test fails, and a Latin OFL font has to be added as primary (a second licence row).
3. **`OfficeDef.desk_positions` are tile coordinates** in the room's `Floor` layer, converted with `map_to_local()`. Seat *i* is `desk_positions[i]`. The staff sprite sits one tile south (`cell + Vector2i(0, 1)`), facing the desk. This plan owns the room layouts and publishes the desk cells for the office content: Garage `[(3,3), (7,3)]`, Small Office `[(3,3), (7,3), (11,3), (3,6), (7,6)]`. Task 11's consistency test checks the real `data/offices/*.tres` against the rooms. *Cost if wrong:* desks float over walls. Task 11's test catches this.
4. **Rooms are painted at runtime** from `size_tiles`, and the TileSet is built in code from `OfficeArt`. No hand-edited tile data. If a designer later paints a room in the editor, painting is skipped when `Floor` already has cells. *Cost if wrong:* low. Hand-painted rooms remain possible.
5. **Content lookup is isolated.** `OfficeScene.configure(offices, equipment_defs)` takes plain typed dictionaries. Only `Main._office_content()` (Task 11) calls M2a's `ContentDB.active()`. Tests pass fixture-built defs. *Cost if wrong:* M2a's ContentDB API differs, which means one function to edit.
6. **Staff pose rule** (`StateQueries.staff_pose`), in order: `BURNED_OUT` if `burnout >= tuning.resign_burnout_threshold`. Otherwise `CRUNCHING` if assigned to a project in `PRODUCTION` or `POLISH` with `crunch == true`. Otherwise `WORKING` if assigned to such a project. Otherwise `IDLE`. In the office view, a seated staff member whose seat has no computer is shown `IDLE`, because spec §7.3 gives them 0 points. *Cost if wrong:* a visual mismatch only.
7. **Active project** = the player company's lowest-id project in phase `PRODUCTION` or `POLISH`. Returns -1 if there is none. *Cost if wrong:* the status bar shows the wrong project until the panels plan adds selection.
8. **Date, money and speed buttons live on the right side of the status bar.** Spec §11.3 lists only project fields, but with the debug HUD hidden the player needs the foundation §8.1 HUD items somewhere. *Cost if wrong:* moving three controls later.
9. **Bubbles:** at most 24 live (the oldest is freed first). Each rises 12 art px over 1.2 s and fades out over the last 0.4 s. Colours: design `#22c55e`, tech `#3b82f6`, art `#f59e0b`, audio `#a855f7`, bug `#ef4444`. Unknown kinds are ignored with a warning. *Cost if wrong:* cosmetic only.
10. **Panel shell API:** `PanelHost.set_panel(tab: StringName, panel: Control)` lets the panels plan plug in contents without editing the shell.
11. **Scene test helpers go in `tests/helpers/office_fixtures.gd`** (`class_name OfficeFixtures`), never in `fixtures.gd`, which M2a edits heavily.
12. **All new locale keys are added in Task 2**, so later tasks never edit `locale/strings.csv` in parallel, and the Thai glyph test covers every new string.

## M2a interfaces this plan consumes

The names come from spec §4 and §10. They are checked against the M2a plan draft `docs/superpowers/plans/2026-10-24-m2a-game-loop.md` (still uncommitted when this plan was written). Before starting Task 10 or 11, re-read M2a's code. If a name differs, M2a wins: update only the files in Tasks 10–11, and say so in the report.

| Interface | M2a task | Used in |
|---|---|---|
| `OfficeDef`: `id`, `seats: int`, `desk_positions: Array[Vector2i]`, `scene_path: String`; `EquipmentDef`: `id`, `tier: int` | Task 1 | Tasks 10, 11 |
| `ContentDB.active()` with `offices: Dictionary[StringName, OfficeDef]` and `equipment: Dictionary[StringName, EquipmentDef]`; `Fixtures.content()` (`equipment_micro_1980` tier 1, `equipment_fx_fast` tier 2); `Fixtures.new_state()` installs it | Task 2 | Tasks 10, 11 |
| `Equipment` entity: `id`, `company_id`, `def_id: StringName`, `seat_index: int` (-1 = storage) | Task 3 | Task 10 |
| `Company.office_id: StringName`, `Staff.seat_index: int` (-1 = none) | Task 4 | Task 10 |
| `GameState.equipment: Dictionary[int, Equipment]`; `new_game` seats the owner (`state.owner.staff_id`) at seat 0 with starter equipment `equipment_micro_1980` in `office_garage` (M2a Ruling A2); `Fixtures.add_equipment(state, overrides)`, `Fixtures.add_worker(state, overrides)` | Task 6 | Tasks 10, 12 |
| `Removal.remove_staff(state, id)` | Task 7 | Task 10 test |
| `EventBus` signals `points_gained {staff_id, project_id, type: StringName, amount}`, `bug_found {staff_id, project_id}`, `staff_fired`, `equipment_changed`, `game_loaded {}` | Task 8 | Task 11 |
| `Project.stage_progress` in bp 0–10000 (M2a Ruling A13) | Task 5 | Task 7 (already written for bp) |
| `data/offices/office_garage.tres`, `office_small.tres` (`desk_positions`, `scene_path`) | Task 10 (content) | Task 11 |
| `StartProjectCommand.game(...)` | Task 15 | Task 11 debug button |
| Production emits `points_gained` / `bug_found` | Task 16 | Task 12 |

**Hand-off to M2a Task 10 (content):** set `office_garage.desk_positions = [(3,3), (7,3)]`, `scene_path = "res://src/ui/office/rooms/garage_room.tscn"`, `office_small.desk_positions = [(3,3), (7,3), (11,3), (3,6), (7,6)]`, `scene_path = "res://src/ui/office/rooms/small_office_room.tscn"` (Ruling 3). M2a's in-memory fixture garage cells `[(2,2), (5,2)]` also lie on the garage floor, so they need no change.

## Review Focus

1. **Event for a staff member who is not shown** (unseated, removed between tick and flush, another company's staff, or a stale id after load): no bubble, no error. Test in Task 11 (`test_event_for_unshown_staff_spawns_nothing`).
2. **Bad seat data** (`seat_index` ≥ `office.seats`, two staff or two machines on one seat, equipment in storage with `seat_index = -1`): the scene ignores the out-of-range entries, the lowest id wins a seat, and nothing crashes. Tests in Task 10.
3. **Bubble flood** (4× speed, 5 staff, catch-up of `max_ticks_per_frame` ticks in one frame): live bubbles never exceed 24. Test in Task 6.
4. **Session replaced** (load or new game while the scene is open): the scene re-reads `GameRunner.session` on every refresh and rebuilds on `game_loaded`, with no stale sprites. Tests in Tasks 7 and 11.
5. **Long or Thai text in fixed bars** (a long project title, Thai labels without spaces): labels clip with an ellipsis instead of wrapping or pushing the bar wider, and every Thai string has glyphs in the font. Tests in Tasks 2 and 7.

---

## File map

```
assets/art/<pack-slug>/            Task 1  CC0 sheet(s) + License.txt (+ .png.import)
assets/CREDITS.md                  Task 1  art rows + font row
src/ui/office/office_art.gd        Task 1  OfficeArt: sheet path, atlas cells, TileSet builder
tests/unit/test_assets.gd          Task 1
assets/fonts/NotoSansThai-Variable.ttf, assets/fonts/OFL.txt   Task 2
src/ui/theme/main_theme.tres       Task 2
locale/strings.csv                 Task 2  all new keys
tests/unit/test_theme.gd           Task 2
project.godot                      Task 3 (display, filter), Task 9 (theme, input action)
tests/unit/test_display_settings.gd  Task 3
src/ui/office/office_room.gd       Task 4  OfficeRoom
src/ui/office/rooms/garage_room.tscn, small_office_room.tscn   Task 4
tests/unit/test_office_room.gd     Task 4
src/core/state_queries.gd          Task 5 (staff_pose), Task 7 (active project), Task 10 (seat views)
src/ui/office/staff_sprite.gd/.tscn, desk_sprite.gd/.tscn      Task 5
tests/unit/test_office_sprites.gd  Task 5
src/ui/office/bubble.gd, bubble_layer.gd                       Task 6
tests/unit/test_bubbles.gd         Task 6
src/ui/hud/status_bar.gd/.tscn     Task 7
tests/unit/test_status_bar.gd      Task 7
src/ui/hud/tab_bar_shell.gd/.tscn, src/ui/panels/panel_host.gd/.tscn   Task 8
tests/unit/test_tab_bar.gd         Task 8
src/ui/main.tscn, src/ui/main.gd   Task 9, Task 11
tests/unit/test_main_scene.gd      Task 9, Task 11
tests/unit/test_debug_hud.gd       Task 9 (node path update)
src/core/seat_view.gd              Task 10  SeatView
src/ui/office/office_scene.gd/.tscn  Task 10, Task 11
tests/helpers/office_fixtures.gd   Task 10
tests/unit/test_office_scene.gd    Task 10, Task 11
src/ui/debug_hud.gd/.tscn          Task 11  test-project button
```

---

### Task 1: Choose, verify and import the CC0 art pack

**Files:**
- Create: `assets/art/<pack-slug>/` (sheet PNGs, `License.txt`, `.png.import`), `assets/CREDITS.md`, `src/ui/office/office_art.gd`
- Test: `tests/unit/test_assets.gd`

**Interfaces:**
- Produces `class_name OfficeArt extends RefCounted` (constants filled from the chosen sheet):
  - `const TILE: int = 16`, `const SHEET_PATH: String`, `const MARGIN: Vector2i`, `const SEPARATION: Vector2i`
  - `const FLOORS: Dictionary[StringName, Vector2i]` with keys `&"concrete"` (garage) and `&"wood"` (small office)
  - `const WALL_TOP: Vector2i`, `const WALL_FACE: Vector2i`, `const WALL_SIDE: Vector2i`, `const WALL_BOTTOM: Vector2i`
  - `const DESK: Vector2i`, `const COMPUTERS: Array[Vector2i]` (index 0 = tier 1, at least 1 entry), `const STAFF_BODIES: Array[Vector2i]` (at least 2)
  - `static func region(cell: Vector2i) -> Rect2i` (`MARGIN + cell * (TILE + SEPARATION)`, size `TILE`)
  - `static func atlas(cell: Vector2i) -> AtlasTexture`
  - `static func computer_cell(tier: int) -> Vector2i` returns `COMPUTERS[clampi(tier, 1, COMPUTERS.size()) - 1]`
  - `static func body_cell(staff_id: int) -> Vector2i` returns `STAFF_BODIES[absi(staff_id) % STAFF_BODIES.size()]`
  - `static func all_cells() -> Array[Vector2i]` returns every cell named above
  - `static func tileset() -> TileSet`: tile size 16, one `TileSetAtlasSource` (source id 0) over `SHEET_PATH` with `MARGIN`/`SEPARATION`, and a tile created for every floor and wall cell. Built once and cached in a `static var`.

- [ ] **Step 1: Download candidates into a fresh scratch directory.** Make a new empty directory per pack inside the session scratchpad, for example `"$SCRATCH/kenney_<slug>"`. Download the zip from the pack's kenney.nl page and `unzip` it there. Treat the contents as untrusted: open nothing except `License.txt` and the PNGs, and run nothing. Candidates, in order:
  1. Kenney **1-Bit Pack** (https://kenney.nl/assets/1-bit-pack, 16×16, one style for interior, items and characters; use the *colored packed* sheet).
  2. Kenney **Roguelike Indoors** (https://kenney.nl/assets/roguelike-indoors) plus **Roguelike Characters** (https://kenney.nl/assets/roguelike-characters). Two packs, each with its own licence check and `CREDITS.md` row.

- [ ] **Step 2: Licence gate (before anything is copied into the project).** For each pack, run `grep -iE "CC0|Creative Commons Zero" "<dir>/License.txt"`. Expected: a match. No `License.txt`, or no match: discard the pack and try the next candidate. If no candidate passes, stop and report `BLOCKED`. Quote the matched line in the report.

- [ ] **Step 3: Acceptance check of the chosen sheet.** Run `sips -g pixelWidth -g pixelHeight <sheet>.png` and open the sheet image. Confirm and record all of the following:
  - Tiles are 16×16, and you know the margin and separation (a packed sheet has 0/0, a spaced sheet usually has separation 1).
  - The view is top-down or 3/4.
  - The sheet has two distinct floor tiles, wall pieces (top, face, side, bottom), a desk or table, at least one computer/monitor sprite, and at least two human characters.
  
  If something is missing, try the next candidate. If computers come in only one look, `COMPUTERS` has one entry and every tier uses it. Record this in the report.

- [ ] **Step 4: Copy only what is used** into `assets/art/<pack-slug>/` (lower-case slug, e.g. `kenney_1bit`): the sheet PNG(s) and `License.txt`, unchanged. Do not copy the rest of the zip.

- [ ] **Step 5: Write `assets/CREDITS.md`**: a table with columns `Asset | Files | Source | Author | Licence`. Add one row per art pack (pack name, `assets/art/<slug>/…`, kenney.nl URL, Kenney, `CC0 1.0`). Add the font row now, so Task 2 does not edit this file in parallel: `Noto Sans Thai | assets/fonts/NotoSansThai-Variable.ttf | https://github.com/google/fonts/tree/main/ofl/notosansthai | Google / Noto project | SIL Open Font License 1.1 (assets/fonts/OFL.txt)`. Add a final line: "Release exports must include `assets/**/*.txt` and `assets/CREDITS.md` (export filter for non-resource files)."

- [ ] **Step 6: Import as pixel art.** Run `godot --headless --import`. In each `assets/art/**/*.png.import`, set `compress/mode=0` (lossless) and `mipmaps/generate=false` under `[params]`, then re-import. Commit the `.png.import` files (`.godot/` is gitignored).

- [ ] **Step 7: Write the failing tests** `tests/unit/test_assets.gd`:

```gdscript
extends GutTest

func _pack_dirs() -> Array[String]:
    var out: Array[String] = []
    for d: String in DirAccess.get_directories_at("res://assets/art"):
        out.append("res://assets/art".path_join(d))
    return out

func test_at_least_one_art_pack() -> void:
    assert_gt(_pack_dirs().size(), 0)

func test_every_art_pack_has_cc0_license() -> void:
    for dir: String in _pack_dirs():
        var path := dir.path_join("License.txt")
        assert_true(FileAccess.file_exists(path), path)
        assert_string_contains(FileAccess.get_file_as_string(path).to_upper(), "CC0", false)

func test_credits_lists_every_pack_and_the_font() -> void:
    var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
    for dir: String in _pack_dirs():
        assert_string_contains(credits, dir.get_file())
    assert_string_contains(credits, "NotoSansThai-Variable.ttf")
    assert_string_contains(credits, "SIL Open Font License 1.1")

func test_pixel_textures_import_lossless_without_mipmaps() -> void:
    for dir: String in _pack_dirs():
        for f: String in DirAccess.get_files_at(dir):
            if f.ends_with(".png.import"):
                var cfg := ConfigFile.new()
                assert_eq(cfg.load(dir.path_join(f)), OK)
                assert_eq(int(cfg.get_value("params", "compress/mode")), 0, f)
                assert_false(bool(cfg.get_value("params", "mipmaps/generate")), f)

func test_office_art_cells_inside_sheet() -> void:
    var size: Vector2i = (load(OfficeArt.SHEET_PATH) as Texture2D).get_size()
    for cell: Vector2i in OfficeArt.all_cells():
        assert_true(Rect2i(Vector2i.ZERO, size).encloses(OfficeArt.region(cell)), str(cell))

func test_computer_cell_clamps_tier() -> void:
    assert_eq(OfficeArt.computer_cell(0), OfficeArt.COMPUTERS[0])
    assert_eq(OfficeArt.computer_cell(99), OfficeArt.COMPUTERS[OfficeArt.COMPUTERS.size() - 1])

func test_tileset_has_floor_and_wall_tiles() -> void:
    var src := OfficeArt.tileset().get_source(0) as TileSetAtlasSource
    assert_eq(OfficeArt.tileset().tile_size, Vector2i(16, 16))
    for cell: Vector2i in [OfficeArt.FLOORS[&"concrete"], OfficeArt.FLOORS[&"wood"], OfficeArt.WALL_FACE]:
        assert_true(src.has_tile(cell), str(cell))
```

- [ ] **Step 8: Implement `OfficeArt`** with the cells recorded in Step 3.
- [ ] **Step 9: Run** `godot --headless --import`, then the suite. Expected: all pass.
- [ ] **Step 10: Commit** `feat(ui): import CC0 office art pack with credits`. Stage `assets/art/`, `assets/CREDITS.md`, `src/ui/office/office_art.gd`, `tests/unit/test_assets.gd` (plus `.uid` files) by path.

---

### Task 2: Noto Sans Thai, the main Theme and all new strings

**Files:**
- Create: `assets/fonts/NotoSansThai-Variable.ttf`, `assets/fonts/OFL.txt`, `src/ui/theme/main_theme.tres`
- Modify: `locale/strings.csv`
- Test: `tests/unit/test_theme.gd`

**Interfaces:**
- Produces `res://src/ui/theme/main_theme.tres` (`Theme`):
  - `default_font` = an embedded `FontVariation` whose `base_font` is the TTF, weight `400` (`variation_opentype` `wght`).
  - `default_font_size = 12` (logical px; 24 screen px at 1280×720).
  - Type variations `LabelSmall` (base `Label`, font size `10`) and `ButtonSmall` (base `Button`, font size `10`).
  - `Button` and `PanelContainer` StyleBoxFlat: dark panel `#1e1b2e` at alpha 0.92, button normal `#2d2a40`, hover `#3d3956`, pressed `#5b4fc4`, content margins left/right `6` and top/bottom `1`, corner radius `2`. These keep a 12 px Thai line plus margins within the 22 px bars.
- Produces locale keys (EN / TH):

| key | en | th |
|---|---|---|
| `ui.tab.project` | Project | โปรเจกต์ |
| `ui.tab.team` | Team | ทีม |
| `ui.tab.equipment` | Equipment | อุปกรณ์ |
| `ui.tab.finance` | Finance | การเงิน |
| `ui.tab.market` | Market | ตลาด |
| `ui.status.no_project` | No game in development | ยังไม่มีเกมที่กำลังพัฒนา |
| `ui.status.stage` | Stage {stage}/{count} · {progress}% | ขั้นที่ {stage}/{count} · {progress}% |
| `ui.status.points` | D {design}  T {tech}  A {art}  S {audio} | ออกแบบ {design}  เทค {tech}  ภาพ {art}  เสียง {audio} |
| `ui.status.bugs` | Bugs {bugs} | บั๊ก {bugs} |
| `ui.status.hype` | Hype {hype} | กระแส {hype} |
| `ui.debug.test_project` | Test project | โปรเจกต์ทดสอบ |

- [ ] **Step 1: Download into a fresh scratch directory** `NotoSansThai[wdth,wght].ttf` and `OFL.txt` from `https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/` (URL-encode the brackets as `%5B`/`%2C`/`%5D`). Check that `OFL.txt` contains `SIL OPEN FONT LICENSE Version 1.1` (`grep -i`). Copy them to `assets/fonts/NotoSansThai-Variable.ttf` and `assets/fonts/OFL.txt`.
- [ ] **Step 2: Import.** Run `godot --headless --import`. In `NotoSansThai-Variable.ttf.import`, set `allow_system_fallback=false` and keep `antialiasing=1`, then re-import.
- [ ] **Step 3: Add the locale keys** above to `locale/strings.csv` (keep existing rows; quote cells that contain commas).
- [ ] **Step 4: Write the failing tests** `tests/unit/test_theme.gd`:

```gdscript
extends GutTest

const THEME_PATH := "res://src/ui/theme/main_theme.tres"

func _font() -> Font:
    return (load(THEME_PATH) as Theme).default_font

func test_theme_font_has_thai_and_latin() -> void:
    var f := _font()
    assert_not_null(f)
    assert_true(f.has_char(0x0E01), "ก")
    assert_true(f.has_char(0x0E48), "tone mark")
    assert_true(f.has_char("A".unicode_at(0)))
    assert_true(f.has_char("9".unicode_at(0)))

func test_theme_default_size() -> void:
    assert_eq((load(THEME_PATH) as Theme).default_font_size, 12)

func test_every_thai_string_has_glyphs() -> void:
    var f := _font()
    var csv := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
    var header := csv.get_csv_line()
    var th_col := header.find("th")
    assert_gt(th_col, 0)
    while not csv.eof_reached():
        var row := csv.get_csv_line()
        if row.size() <= th_col:
            continue
        for i: int in row[th_col].length():
            var c: int = row[th_col].unicode_at(i)
            assert_true(f.has_char(c), "%s: U+%04X" % [row[0], c])

func test_new_tab_keys_translated_in_both_locales() -> void:
    for key: String in ["ui.tab.project", "ui.tab.team", "ui.tab.equipment", "ui.tab.finance",
            "ui.tab.market", "ui.status.no_project", "ui.status.stage", "ui.status.points",
            "ui.status.bugs", "ui.status.hype", "ui.debug.test_project"]:
        for loc: String in ["en", "th"]:
            TranslationServer.set_locale(loc)
            assert_ne(tr(key), key, "%s/%s" % [loc, key])
    TranslationServer.set_locale("en")

func test_ofl_ships_next_to_font() -> void:
    assert_string_contains(FileAccess.get_file_as_string("res://assets/fonts/OFL.txt").to_upper(),
        "SIL OPEN FONT LICENSE")
```

- [ ] **Step 5: Create `main_theme.tres`** with the values above (embedded `FontVariation` sub-resource).
- [ ] **Step 6: Run** the import, then the suite. Expected: all pass. If `has_char(65)` fails, stop and report `BLOCKED` (Ruling 2 does not hold).
- [ ] **Step 7: Commit** `feat(ui): add Noto Sans Thai theme and M2d strings`.

---

### Task 3: Display and pixel settings

**Files:**
- Modify: `project.godot`
- Test: `tests/unit/test_display_settings.gd`

**Interfaces:**
- Produces the project settings (Ruling 1):
  - `display/window/size/viewport_width=640`, `viewport_height=360`
  - `display/window/size/window_width_override=1280`, `window_height_override=720`
  - `display/window/stretch/mode="canvas_items"`, `stretch/aspect="keep"`, `stretch/scale_mode="integer"`
  - `rendering/textures/canvas_textures/default_texture_filter=0` (Nearest)
  - `rendering/2d/snap/snap_2d_transforms_to_pixel=true`

- [ ] **Step 1: Write the failing test**:

```gdscript
extends GutTest

func _s(key: String) -> Variant:
    return ProjectSettings.get_setting(key)

func test_logical_viewport_is_640x360() -> void:
    assert_eq(int(_s("display/window/size/viewport_width")), 640)
    assert_eq(int(_s("display/window/size/viewport_height")), 360)

func test_window_opens_at_1280x720() -> void:
    assert_eq(int(_s("display/window/size/window_width_override")), 1280)
    assert_eq(int(_s("display/window/size/window_height_override")), 720)

func test_integer_canvas_items_stretch() -> void:
    assert_eq(String(_s("display/window/stretch/mode")), "canvas_items")
    assert_eq(String(_s("display/window/stretch/aspect")), "keep")
    assert_eq(String(_s("display/window/stretch/scale_mode")), "integer")

func test_pixel_filter_and_snap() -> void:
    assert_eq(int(_s("rendering/textures/canvas_textures/default_texture_filter")), 0)
    assert_true(bool(_s("rendering/2d/snap/snap_2d_transforms_to_pixel")))
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Add the settings** to `project.godot`.
- [ ] **Step 4: Run the suite. Expected: all pass.** The M1 debug HUD (`offset_right = 480`) still fits inside 640.
- [ ] **Step 5: Commit** `feat(ui): set 640x360 integer pixel display`.

---

### Task 4: Office rooms (TileMapLayer)

**Files:**
- Create: `src/ui/office/office_room.gd`, `src/ui/office/rooms/garage_room.tscn`, `src/ui/office/rooms/small_office_room.tscn`
- Test: `tests/unit/test_office_room.gd`

**Interfaces:**
- Consumes: `OfficeArt.tileset()`, `OfficeArt.FLOORS`, `OfficeArt.WALL_*` (Task 1).
- Produces `class_name OfficeRoom extends Node2D`, with children `Floor: TileMapLayer` and `Walls: TileMapLayer`:
  - `@export var size_tiles: Vector2i`, `@export var floor_style: StringName`
  - Layout, painted in `_ready()` only when `Floor` has no used cells. Row 0 is `WALL_TOP`; row 1 is `WALL_FACE` (3/4 wall); column 0 and column `w-1` from row 2 to `h-2` are `WALL_SIDE`; row `h-1` is `WALL_BOTTOM`; floor is `x ∈ [1, w-2]`, `y ∈ [2, h-2]` with `FLOORS[floor_style]`.
  - `func is_floor(cell: Vector2i) -> bool`
  - `func cell_to_local(cell: Vector2i) -> Vector2` (`Floor.map_to_local(cell)`, the tile centre)
  - `func pixel_size() -> Vector2i` (`size_tiles * 16`)
  - `const GARAGE_DESKS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 3)]`
  - `const SMALL_OFFICE_DESKS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 3), Vector2i(11, 3), Vector2i(3, 6), Vector2i(7, 6)]` (Ruling 3; published for the office content)
- Room scenes: `garage_room.tscn` has `size_tiles = (12, 8)` and `floor_style = &"concrete"`. `small_office_room.tscn` has `(18, 9)` and `&"wood"`. At office scale 2, they fill 384×256 and 576×288 logical px inside the 640×316 office area.

- [ ] **Step 1: Write the failing tests**:

```gdscript
extends GutTest

func _room(path: String) -> OfficeRoom:
    return add_child_autofree(load(path).instantiate()) as OfficeRoom

func test_garage_size_and_floor_rect() -> void:
    var r := _room("res://src/ui/office/rooms/garage_room.tscn")
    assert_eq(r.size_tiles, Vector2i(12, 8))
    assert_eq(r.pixel_size(), Vector2i(192, 128))
    assert_eq(r.get_node("Floor").get_used_cells().size(), 10 * 5)
    assert_true(r.is_floor(Vector2i(1, 2)))
    assert_false(r.is_floor(Vector2i(0, 2)))
    assert_false(r.is_floor(Vector2i(5, 1)))

func test_small_office_size() -> void:
    var r := _room("res://src/ui/office/rooms/small_office_room.tscn")
    assert_eq(r.size_tiles, Vector2i(18, 9))
    assert_eq(r.get_node("Floor").get_used_cells().size(), 16 * 6)

func test_published_desks_and_chairs_are_on_floor() -> void:
    for pair: Array in [["res://src/ui/office/rooms/garage_room.tscn", OfficeRoom.GARAGE_DESKS],
            ["res://src/ui/office/rooms/small_office_room.tscn", OfficeRoom.SMALL_OFFICE_DESKS]]:
        var r := _room(pair[0])
        for cell: Vector2i in pair[1]:
            assert_true(r.is_floor(cell), "desk %s" % cell)
            assert_true(r.is_floor(cell + Vector2i(0, 1)), "chair %s" % cell)

func test_cell_to_local_is_tile_centre() -> void:
    var r := _room("res://src/ui/office/rooms/garage_room.tscn")
    assert_eq(r.cell_to_local(Vector2i(3, 3)), Vector2(56, 56))

func test_prepainted_floor_is_kept() -> void:
    var r: OfficeRoom = load("res://src/ui/office/rooms/garage_room.tscn").instantiate()
    (r.get_node("Floor") as TileMapLayer).tile_set = OfficeArt.tileset()
    (r.get_node("Floor") as TileMapLayer).set_cell(Vector2i(1, 2), 0, OfficeArt.FLOORS[&"wood"])
    add_child_autofree(r)
    assert_eq(r.get_node("Floor").get_used_cells().size(), 1)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `OfficeRoom` and the two scenes.** Assign `OfficeArt.tileset()` to both layers in `_ready()` when their `tile_set` is null.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat(ui): add garage and small office tile rooms`.

---

### Task 5: Staff pose query, staff sprite and desk sprite

**Files:**
- Modify: `src/core/state_queries.gd`
- Create: `src/ui/office/staff_sprite.gd/.tscn`, `src/ui/office/desk_sprite.gd/.tscn`
- Test: `tests/unit/test_state_queries_pose.gd`, `tests/unit/test_office_sprites.gd`

**Interfaces:**
- Consumes: `OfficeArt.atlas()`, `OfficeArt.DESK`, `OfficeArt.computer_cell()`, `OfficeArt.body_cell()` (Task 1); M1 `Staff`, `Project`, `TuningDef.resign_burnout_threshold`.
- Produces:
  - In `StateQueries`: `enum StaffPose { IDLE, WORKING, CRUNCHING, BURNED_OUT }`
  - `static func staff_pose(state: GameState, staff_id: int, t: TuningDef) -> StaffPose` (Ruling 6; a missing staff id returns `IDLE`)
  - `class_name StaffSprite extends Node2D`, child `Body: Sprite2D`. `var pose: StateQueries.StaffPose` (read-only to callers), `func set_pose(p: StateQueries.StaffPose) -> void`, `func set_look(staff_id: int) -> void` (texture = `OfficeArt.atlas(OfficeArt.body_cell(staff_id))`), `func is_bobbing() -> bool`. Pose visuals:
    - `IDLE`: modulate white, no bob
    - `WORKING`: white, bob `Body.position.y` 0 → -1 → 0, period 0.5 s, looping tween
    - `CRUNCHING`: `Color(1, 0.8, 0.8)`, bob period 0.25 s
    - `BURNED_OUT`: `Color(0.6, 0.6, 0.7)`, no bob
    
    `set_pose` kills the previous tween.
  - `class_name DeskSprite extends Node2D`, children `Desk: Sprite2D` and `Computer: Sprite2D`. `func set_computer_tier(tier: int) -> void`: tier ≤ 0 hides `Computer`; otherwise shows `OfficeArt.atlas(OfficeArt.computer_cell(tier))`. `var computer_tier: int`.

- [ ] **Step 1: Write the failing tests** `tests/unit/test_state_queries_pose.gd`:

```gdscript
extends GutTest

var t := Fixtures.tuning()

func _prod(state: GameState, crunch: bool) -> int:
    var pid := Fixtures.add_project(state)
    state.projects[pid].phase = Project.Phase.PRODUCTION
    state.projects[pid].crunch = crunch
    return pid

func test_unassigned_staff_is_idle() -> void:
    var s := Fixtures.new_state(1)
    var id := Fixtures.add_staff(s)
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)

func test_staff_on_production_project_is_working() -> void:
    var s := Fixtures.new_state(1)
    var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, false)})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.WORKING)

func test_polish_counts_as_working() -> void:
    var s := Fixtures.new_state(1)
    var pid := _prod(s, false)
    s.projects[pid].phase = Project.Phase.POLISH
    var id := Fixtures.add_staff(s, {"assigned_project_id": pid})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.WORKING)

func test_crunch_project_gives_crunching() -> void:
    var s := Fixtures.new_state(1)
    var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, true)})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.CRUNCHING)

func test_burnout_at_threshold_overrides_crunch() -> void:
    var s := Fixtures.new_state(1)
    var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, true), "burnout": t.resign_burnout_threshold})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.BURNED_OUT)

func test_released_project_gives_idle() -> void:
    var s := Fixtures.new_state(1)
    var pid := _prod(s, false)
    s.projects[pid].phase = Project.Phase.RELEASED
    var id := Fixtures.add_staff(s, {"assigned_project_id": pid})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)

func test_dangling_project_id_and_missing_staff_are_idle() -> void:
    var s := Fixtures.new_state(1)
    var id := Fixtures.add_staff(s, {"assigned_project_id": 999})
    assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)
    assert_eq(StateQueries.staff_pose(s, 12345, t), StateQueries.StaffPose.IDLE)
```

`tests/unit/test_office_sprites.gd`:
  - `test_staff_sprite_pose_sets_modulate_and_bob`: for each pose, `set_pose`, then assert `pose`, `Body.modulate` (the values above) and `is_bobbing()` (true only for WORKING and CRUNCHING).
  - `test_staff_look_is_stable_per_id`: `set_look(7)` twice gives the same `Body.texture.region`, equal to `OfficeArt.region(OfficeArt.body_cell(7))`.
  - `test_desk_tier_zero_hides_computer`: `set_computer_tier(0)` sets `Computer.visible == false` and `computer_tier == 0`.
  - `test_desk_tier_picks_computer_cell`: `set_computer_tier(2)` sets `Computer.visible` and `Computer.texture.region == OfficeArt.region(OfficeArt.computer_cell(2))`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `staff_pose`, `StaffSprite` and `DeskSprite` (`Desk` texture = `OfficeArt.atlas(OfficeArt.DESK)`; `Computer` offset 4 px up so it sits on the desk).
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass, including `test_rules.gd`.
- [ ] **Step 5: Commit** `feat(ui): add staff pose query and office sprites`.

---

### Task 6: Work bubbles (standalone)

**Files:**
- Create: `src/ui/office/bubble.gd`, `src/ui/office/bubble_layer.gd`
- Test: `tests/unit/test_bubbles.gd`

**Interfaces:**
- Produces:
  - `class_name Bubble extends Node2D`, with `const COLORS: Dictionary[StringName, Color]` set to the Ruling 9 colours, keyed `&"design"`, `&"tech"`, `&"art"`, `&"audio"`, `&"bug"`. `var kind: StringName`. Draws a filled circle of radius 3 in its colour with a 1 px darker outline (`_draw`). On `_ready` it tweens `position.y` by `-RISE_PX` over `LIFETIME_S` and `modulate.a` to 0 over the last `FADE_S`, then calls `queue_free()`. `const RISE_PX := 12`, `const LIFETIME_S := 1.2`, `const FADE_S := 0.4`.
  - `class_name BubbleLayer extends Node2D`: `const MAX_BUBBLES := 24`, `func spawn(at: Vector2, kind: StringName) -> Bubble` (returns null and calls `push_warning` for an unknown kind; when `MAX_BUBBLES` are live, the oldest child is freed first), `func live_count() -> int`. Successive spawns shift x by `((n % 3) - 1) * 3` px so stacked bubbles do not overlap. This is deterministic, with no RNG.

- [ ] **Step 1: Write the failing tests**:

```gdscript
extends GutTest

func _layer() -> BubbleLayer:
    return add_child_autofree(BubbleLayer.new())

func test_spawn_adds_coloured_bubble() -> void:
    var l := _layer()
    var b := l.spawn(Vector2(10, 10), &"tech")
    assert_not_null(b)
    assert_eq(b.kind, &"tech")
    assert_eq(l.live_count(), 1)

func test_unknown_kind_spawns_nothing() -> void:
    var l := _layer()
    assert_null(l.spawn(Vector2.ZERO, &"juggling"))
    assert_eq(l.live_count(), 0)

func test_bubble_count_is_capped() -> void:
    var l := _layer()
    for i: int in 30:
        l.spawn(Vector2.ZERO, &"design")
    await wait_process_frames(1)
    assert_eq(l.live_count(), BubbleLayer.MAX_BUBBLES)

func test_bubble_rises_and_frees_itself() -> void:
    var l := _layer()
    l.spawn(Vector2(0, 50), &"bug")
    await wait_seconds(Bubble.LIFETIME_S + 0.2)
    assert_eq(l.live_count(), 0)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** `live_count()` counts children that are not `is_queued_for_deletion()`.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat(ui): add floating work bubbles`.

---

### Task 7: Bottom status bar

**Files:**
- Modify: `src/core/state_queries.gd`
- Create: `src/ui/hud/status_bar.gd`, `src/ui/hud/status_bar.tscn`
- Test: `tests/unit/test_status_bar.gd`

**Interfaces:**
- Consumes: `StateQueries.date_text`, `player_money` (M1); locale keys (Task 2).
- Produces:
  - `static func active_project_id(state: GameState) -> int` (Ruling 7)
  - `const STAGE_COUNT: int = 3` (spec §6.3)
  - `static func project_status(state: GameState, project_id: int) -> Dictionary` with keys `title: String`, `stage: int` (`stage_index + 1`), `progress: int` (percent = `stage_progress / 100`, because `stage_progress` is bp per M2a Ruling A13), `design`, `tech`, `art`, `audio`, `bugs`, `hype` (ints; a missing point key gives 0). An unknown id returns `{}`.
  - `class_name StatusBar extends PanelContainer`, 22 px tall. Left side: unique-name labels `%Title`, `%Stage`, `%Points`, `%Bugs`, `%Hype` (`LabelSmall`). Right side: `%Date`, `%Money`, `ButtonSmall` buttons `%Pause`, `%Speed1x`, `%Speed2x`, `%Speed4x` (text as in the M1 debug HUD keys `ui.hud.*`). `func refresh(state: GameState, t: TuningDef) -> void`. With no active project, `%Title` = `tr("ui.status.no_project")` and the other project labels are hidden. Every label has `clip_text = true` and `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS`; `%Title` has `custom_minimum_size.x = 120` and `size_flags_horizontal = SIZE_EXPAND_FILL`. Connects `week_ticked`, `money_changed`, `project_changed` and `project_phase_changed` to `_on_event`, which calls `refresh(GameRunner.session.state, GameRunner.session.tuning)` when the session is not null. Disconnects in `_exit_tree`, as in `debug_hud.gd`.

- [ ] **Step 1: Write the failing tests** (`before_each` sets `GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())`; `after_each` sets it to null and the locale to `en`):
  - `test_no_project_shows_placeholder`: after refresh, `%Title.text == tr("ui.status.no_project")` and `%Stage.visible == false`.
  - `test_active_project_is_lowest_id_in_production_or_polish`: add a CONCEPT project, then a PRODUCTION project (A), then a POLISH project (B). `active_project_id == A`. Set A to `RELEASED`: the result is B.
  - `test_other_company_project_is_not_active`: a PRODUCTION project with `company_id = 999` gives `-1`.
  - `test_shows_title_stage_points_bugs_hype`: PRODUCTION project titled "Moon Rally" with `stage_index = 1`, `stage_progress = 4000` (bp, M2a Ruling A13), `points = {design: 12, tech: 7, art: 3, audio: 1}` (set entries directly), `bugs = 5`, `hype = 30`. After refresh, `%Title.text == "Moon Rally"`, `%Stage.text == tr("ui.status.stage").format({"stage": 2, "count": 3, "progress": 40})`, `%Points.text == tr("ui.status.points").format({"design": 12, "tech": 7, "art": 3, "audio": 1})`, `%Bugs.text == tr("ui.status.bugs").format({"bugs": 5})`, `%Hype.text == tr("ui.status.hype").format({"hype": 30})`.
  - `test_refreshes_on_project_changed`: instantiate the bar, add a project to `GameRunner.session.state`, `EventBus.dispatch(&"project_changed", {})`, and assert the title changed.
  - `test_refresh_reads_replaced_session`: replace `GameRunner.session` with a new session whose state has a different project, dispatch `week_ticked`, and assert the new title is shown.
  - `test_long_title_is_clipped`: a 200-character title leaves `%Title.clip_text == true`, `%Title.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS`, and `bar.size.y <= 22` after one frame.
  - `test_speed_buttons_set_speed`: `%Speed2x.pressed.emit()` sets `GameRunner.session.speed == 2`, and `%Pause` sets 0.
  - `test_date_and_money_labels`: `%Date.text == StateQueries.date_text(...)`, and `%Money.text == tr("ui.hud.money").format({"money": StateQueries.player_money(st)})`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the queries and the bar.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass, including `test_rules.gd`.
- [ ] **Step 5: Commit** `feat(ui): add bottom status bar`.

---

### Task 8: Tab bar shell and panel host

**Files:**
- Create: `src/ui/hud/tab_bar_shell.gd/.tscn`, `src/ui/panels/panel_host.gd/.tscn`
- Test: `tests/unit/test_tab_bar.gd`

**Interfaces:**
- Produces:
  - `class_name TabBarShell extends HBoxContainer`, 22 px tall. `const TABS: Array[StringName] = [&"project", &"team", &"equipment", &"finance", &"market"]`. One toggle `Button` per tab, named `Tab_<id>` and sharing a `ButtonGroup` with `allow_unpress = true`, text `tr("ui.tab.<id>")`. `signal tab_changed(tab: StringName)` (`&""` = all closed). `func open_tab() -> StringName` returns the pressed tab, or `&""` when none is open. Every button's `toggled` signal calls one `_sync()`, which emits `tab_changed(open_tab())` only when the value differs from the last one emitted. The ButtonGroup may emit `toggled(false)` and `toggled(true)` in either order, and this keeps the final emission correct.
  - `class_name PanelHost extends Control`: `func show_tab(tab: StringName) -> void` (sets `%PanelTitle.text = tr("ui.tab.%s" % tab)`, shows the panel registered for `tab`, hides the others, and slides up: tween `position.y` from `SLIDE_FROM` to its rest position over `SLIDE_S = 0.15`), `func hide_panel() -> void`, `func set_panel(tab: StringName, panel: Control) -> void` (reparents `panel` under `%Content`, hidden until its tab opens), `func current_tab() -> StringName`. Rest rect: `x 8–632`, `y 40–314` (logical px, above the tab bar). `SLIDE_FROM = 316`.

- [ ] **Step 1: Write the failing tests**:
  - `test_five_tabs_in_order_with_translated_text`: the children `Tab_project` … `Tab_market` in `TABS` order, each with `text == tr("ui.tab.<id>")`.
  - `test_pressing_tab_emits_open`: `watch_signals(bar)`, `Tab_team.button_pressed = true` gives `assert_signal_emitted_with_parameters(bar, "tab_changed", [&"team"])` and `open_tab() == &"team"`.
  - `test_pressing_open_tab_again_closes`: then `Tab_team.button_pressed = false` gives a last emission of `[&""]` and `open_tab() == &""`.
  - `test_switching_tabs_keeps_one_open`: team, then `Tab_market.button_pressed = true`, gives `open_tab() == &"market"`, `Tab_team.button_pressed == false`, and a last emission of `[&"market"]`.
  - `test_panel_host_shows_title_and_registered_panel`: `set_panel(&"finance", Label.new())`, then `show_tab(&"finance")`. The host is visible, the title is `tr("ui.tab.finance")`, and the label is visible. `show_tab(&"team")` hides the label, and `current_tab() == &"team"`.
  - `test_hide_panel`: `hide_panel()` gives `visible == false` and `current_tab() == &""`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** The tab bar does not know the host. Task 9 wires `tab_changed` to the host.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat(ui): add tab bar shell and sliding panel host`.

---

### Task 9: New main scene, debug HUD behind F3

**Files:**
- Modify: `src/ui/main.tscn`, `src/ui/main.gd`, `project.godot`, `tests/unit/test_debug_hud.gd` (one node path)
- Test: `tests/unit/test_main_scene.gd`

**Interfaces:**
- Consumes: `StatusBar` (Task 7), `TabBarShell`, `PanelHost` (Task 8), theme (Task 2).
- Produces:
  - `project.godot`: `gui/theme/custom="res://src/ui/theme/main_theme.tres"`. Input action `debug_toggle_hud` bound to an `InputEventKey` with `keycode = KEY_F3`.
  - `main.tscn` tree (root `Main: Control`, full rect, 640×360):
    - `OfficeSlot: Node2D` (Task 11 mounts the office here)
    - `PanelHost`
    - `TabBarShell` (anchored bottom, `y 316–338`)
    - `StatusBar` (anchored bottom, `y 338–360`)
    - `DebugLayer: CanvasLayer` (`layer = 10`) with child `DebugHud` (the M1 scene), hidden at start.
  - `main.gd` constants: `const OFFICE_SCALE: int = 2`, `const OFFICE_AREA := Rect2i(0, 0, 640, 316)`. `static func office_origin(room_px: Vector2i) -> Vector2i` returns `OFFICE_AREA.position + (OFFICE_AREA.size - room_px * OFFICE_SCALE) / 2`. `func toggle_debug_hud() -> void`. `_unhandled_input(event)` calls `toggle_debug_hud()` on `event.is_action_pressed(&"debug_toggle_hud")`. `TabBarShell.tab_changed` is wired to `PanelHost.show_tab(tab)`, or to `hide_panel()` when `tab == &""`. It keeps M1's `_enter_tree` new-game start.

- [ ] **Step 1: Write the failing tests** `tests/unit/test_main_scene.gd` (`after_each` sets `GameRunner.session = null`):

```gdscript
extends GutTest

func _main() -> Control:
    return add_child_autofree(load("res://src/ui/main.tscn").instantiate())

func test_main_has_bars_and_hidden_debug_hud() -> void:
    var m := _main()
    assert_not_null(m.get_node("StatusBar"))
    assert_not_null(m.get_node("TabBarShell"))
    assert_not_null(m.get_node("OfficeSlot"))
    assert_false(m.get_node("DebugLayer/DebugHud").visible)

func test_f3_toggles_debug_hud() -> void:
    var m := _main()
    var ev := InputEventKey.new()
    ev.keycode = KEY_F3
    ev.pressed = true
    m._unhandled_input(ev)
    assert_true(m.get_node("DebugLayer/DebugHud").visible)
    m._unhandled_input(ev)
    assert_false(m.get_node("DebugLayer/DebugHud").visible)

func test_office_origin_centres_rooms() -> void:
    var main_script: GDScript = load("res://src/ui/main.gd")
    assert_eq(main_script.office_origin(Vector2i(192, 128)), Vector2i(128, 30))
    assert_eq(main_script.office_origin(Vector2i(288, 144)), Vector2i(32, 14))

func test_tab_opens_panel_host() -> void:
    var m := _main()
    m.get_node("TabBarShell/Tab_market").button_pressed = true
    assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"market")

func test_project_theme_is_main_theme() -> void:
    assert_eq(String(ProjectSettings.get_setting("gui/theme/custom")), "res://src/ui/theme/main_theme.tres")

func test_status_bar_filled_at_launch() -> void:
    var m := _main()
    var st: GameState = GameRunner.session.state
    assert_eq(m.get_node("StatusBar").get_node("%Date").text,
        StateQueries.date_text(st, GameRunner.session.tuning))
```

- [ ] **Step 2: Update** `test_main_scene_fills_labels_at_launch` in `tests/unit/test_debug_hud.gd`: change the node path `"DebugHud/Box/DateLabel"` to `"DebugLayer/DebugHud/Box/DateLabel"`. Change nothing else.
- [ ] **Step 3: Run, expect FAIL.**
- [ ] **Step 4: Implement** the scene, script and project settings.
- [ ] **Step 5: Run** the import, then the suite. Expected: all pass, including every M1 debug HUD test.
- [ ] **Step 6: Commit** `feat(ui): new main scene with status bar, tabs and F3 debug HUD`.

---

### Task 10: Office scene from OfficeDef, seats and equipment

**Blocked by M2a Tasks 1–4, 6 and 7:** `OfficeDef` (`seats`, `desk_positions`, `scene_path`) and `EquipmentDef.tier` (Task 1), `Fixtures.content()` (Task 2), `Equipment` (Task 3), `Company.office_id` and `Staff.seat_index` (Task 4), `GameState.equipment`, the seated owner and `Fixtures.add_equipment` (Task 6), and `Removal.remove_staff` (Task 7).

**Files:**
- Create: `src/core/seat_view.gd`, `src/ui/office/office_scene.gd/.tscn`, `tests/helpers/office_fixtures.gd`
- Modify: `src/core/state_queries.gd`
- Test: `tests/unit/test_state_queries_office.gd`, `tests/unit/test_office_scene.gd`

**Interfaces:**
- Consumes: `OfficeRoom` (Task 4), `StaffSprite`, `DeskSprite`, `StateQueries.staff_pose` (Task 5), `BubbleLayer` (Task 6).
- Produces:
  - `class_name SeatView extends RefCounted`: `seat_index: int`, `desk_cell: Vector2i`, `staff_id: int = -1`, `computer_tier: int = 0`, `pose: StateQueries.StaffPose = IDLE`.
  - `static func player_office_id(state: GameState) -> StringName` (`&""` if the player company is missing).
  - `static func seat_views(state: GameState, office: OfficeDef, equipment_defs: Dictionary[StringName, EquipmentDef], t: TuningDef) -> Array[SeatView]`. It returns one view per seat `0 .. office.seats - 1` (and never more than `desk_positions.size()`), considering only player-company staff and equipment. A `seat_index` outside the range is ignored. On a shared seat, the lowest id wins. The tier comes from `equipment_defs[def_id].tier`, and an unknown `def_id` gives tier 0. The pose is `staff_pose(...)`, forced to `IDLE` when `computer_tier == 0` (Ruling 6).
  - `class_name OfficeScene extends Node2D`, with children `RoomSlot: Node2D`, `Desks: Node2D`, `Staff: Node2D`, `Bubbles: BubbleLayer`:
    - `func configure(offices: Dictionary[StringName, OfficeDef], equipment_defs: Dictionary[StringName, EquipmentDef]) -> void`
    - `func refresh(state: GameState, t: TuningDef) -> void`: rebuilds the room only when the office id changed (instantiating `office.scene_path` into `RoomSlot`). It reconciles desks with the seat views and keeps staff sprites keyed by `staff_id`: it frees sprites for staff no longer seated and moves or creates the rest at `room.cell_to_local(desk_cell + Vector2i(0, 1))`.
    - `func room() -> OfficeRoom`, `func desk_count() -> int`, `func desk_at(seat_index: int) -> DeskSprite`, `func staff_sprite(staff_id: int) -> StaffSprite` (null if not shown)
    - `func spawn_bubble(staff_id: int, kind: StringName) -> bool`: spawns at the sprite position + `Vector2(0, -12)`, or returns false when the sprite is not shown.
    - An unknown office id leaves the scene empty, with a `push_warning`.
  - `class_name OfficeFixtures` (`tests/helpers/office_fixtures.gd`):
    - `static func garage() -> OfficeDef` (id `&"office_garage"`, seats 2, `OfficeRoom.GARAGE_DESKS`, garage room path)
    - `static func small_office() -> OfficeDef` (`&"office_small"`, 5, `SMALL_OFFICE_DESKS`, small room path)
    - `static func offices() -> Dictionary[StringName, OfficeDef]`
    - `static func equipment_defs() -> Dictionary[StringName, EquipmentDef]` returns `Fixtures.content().equipment` (`equipment_micro_1980` tier 1, `equipment_fx_fast` tier 2)
    - `static func set_office(state: GameState, office_id: StringName) -> void`
    - Equipment and workers come from M2a's `Fixtures.add_equipment(state, {"seat_index": n, "def_id": id})` and `Fixtures.add_worker(state, overrides)`.

- [ ] **Step 1: Write the failing tests** `tests/unit/test_state_queries_office.gd`. Each test starts from `Fixtures.new_state(1)` plus `OfficeFixtures.set_office(s, &"office_garage")`. Seat 0 already holds the owner with `equipment_micro_1980` (M2a Ruling A2), so the tests use seat 1 unless they say otherwise.
  - `test_one_view_per_seat_with_desk_cells`: `seat_views(...)` has size 2, and `desk_cell`s equal `OfficeRoom.GARAGE_DESKS`.
  - `test_owner_on_seat_zero`: `views[0].staff_id == s.owner.staff_id` and `views[0].computer_tier == 1`. `views[1].staff_id == -1` and `views[1].computer_tier == 0`.
  - `test_seated_staff_and_computer_tier`: staff with `seat_index = 1` and `equipment_fx_fast` on seat 1 gives `views[1].staff_id == id` and `views[1].computer_tier == 2`.
  - `test_seat_without_computer_forces_idle`: staff on seat 1, assigned to a PRODUCTION project, with no equipment, gives `pose == IDLE`. Adding `equipment_micro_1980` on seat 1 gives `WORKING`.
  - `test_out_of_range_seat_ignored`: `seat_index = 7` appears in no view, and nothing errors.
  - `test_shared_seat_lowest_id_wins`: two extra staff on seat 1 give the lower id. This state is invalid per M2a's validator; it is built directly to prove the scene does not crash.
  - `test_storage_and_other_company_equipment_ignored`: equipment with `seat_index = -1`, or on seat 1 for `company_id = 999`, gives `views[1].computer_tier == 0`.
  - `test_unknown_def_id_gives_tier_zero`.

  `tests/unit/test_office_scene.gd` (scene from `office_scene.tscn`, `configure(OfficeFixtures.offices(), OfficeFixtures.equipment_defs())`, then `refresh(state, Fixtures.tuning())`):
  - `test_builds_room_from_office_def`: `room().size_tiles == Vector2i(12, 8)`.
  - `test_desks_match_office_seats_and_positions`: `desk_count() == 2`, and for each i, `desk_at(i).position == room().cell_to_local(GARAGE_DESKS[i])`.
  - `test_computer_sprite_per_equipment_tier`: `desk_at(0).computer_tier == 1` (starter) and `desk_at(1).computer_tier == 0`. After adding `equipment_fx_fast` on seat 1 and refreshing, `desk_at(1).computer_tier == 2`.
  - `test_seated_staff_sprite_has_pose`: a worker on seat 1 (`Fixtures.add_worker`) assigned to a crunching PRODUCTION project gives `staff_sprite(id).pose == CRUNCHING` at `room().cell_to_local(GARAGE_DESKS[1] + Vector2i(0, 1))`.
  - `test_unseated_staff_has_no_sprite`.
  - `test_removed_staff_sprite_freed_on_refresh`: remove the staff with M2a's `Removal.remove_staff(state, id)` (spec §4.8; never `.erase`), refresh, and `staff_sprite(id) == null`.
  - `test_office_change_rebuilds_room`: `set_office(s, &"office_small")`, refresh, and `room().size_tiles == Vector2i(18, 9)` and `desk_count() == 5`.
  - `test_unknown_office_leaves_scene_empty`: `desk_count() == 0` and no crash.
  - `test_spawn_bubble_for_seated_staff_only`: true for a seated id; false for an unseated id and for `-1`.
- [ ] **Step 2: Run, expect FAIL.** If the M2a names in the table are missing, stop and report `BLOCKED` with the missing name.
- [ ] **Step 3: Implement** `SeatView`, the queries, `OfficeFixtures` and `OfficeScene`.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass, including `test_rules.gd`.
- [ ] **Step 5: Commit** `feat(ui): render office seats, computers and staff from state`.

---

### Task 11: Wire the office into main: events, content, load

**Blocked by M2a Tasks 2, 8, 10 and 15:** `ContentDB.active()` (Task 2); the EventBus signals `points_gained`, `bug_found`, `staff_fired`, `equipment_changed` and `game_loaded` (Task 8); `data/offices/*.tres` (Task 10); and `StartProjectCommand.game(...)` (Task 15).

**Files:**
- Modify: `src/ui/office/office_scene.gd`, `src/ui/main.gd`, `src/ui/main.tscn`, `src/ui/hud/status_bar.gd` (add `game_loaded`), `src/ui/debug_hud.gd/.tscn`
- Test: `tests/unit/test_office_scene.gd`, `tests/unit/test_main_scene.gd`

**Interfaces:**
- Produces:
  - `OfficeScene` connects in `_ready` (and disconnects in `_exit_tree`):
    - `points_gained` → `spawn_bubble(payload["staff_id"], StringName(payload["type"]))`
    - `bug_found` → `spawn_bubble(payload["staff_id"], &"bug")`
    - `week_ticked`, `staff_hired`, `staff_resigned`, `staff_fired`, `equipment_changed`, `project_changed`, `project_phase_changed`, `game_loaded` → `refresh(GameRunner.session.state, GameRunner.session.tuning)` when the session is not null
    
    The payload is read with `.get()` and defaults; a missing `staff_id` spawns nothing.
  - `Main._office_content() -> Array` returns `[ContentDB.active().offices, ContentDB.active().equipment]` (Ruling 5, the only call site). `Main` instances `office_scene.tscn` into `OfficeSlot` with `scale = Vector2(OFFICE_SCALE, OFFICE_SCALE)` and `position = office_origin(scene.room().pixel_size())`. It re-centres after each refresh that changes the room.
  - `StatusBar` also refreshes on `game_loaded`.
  - Debug HUD button `%TestProject` (text `tr("ui.debug.test_project")`) submits `StartProjectCommand.game(...)` with the arguments of the first game in M2a's acceptance scenario (M2a Task 19). Debug only, for the manual bubble check.

- [ ] **Step 1: Write the failing tests**, added to `test_office_scene.gd`:
  - `test_points_gained_spawns_bubble_at_staff`: seated staff, `EventBus.dispatch(&"points_gained", {"staff_id": id, "type": &"design", "amount": 3})` gives `Bubbles.live_count() == 1`, and the bubble's `kind == &"design"`.
  - `test_bug_found_spawns_bug_bubble`.
  - `test_event_for_unshown_staff_spawns_nothing`: an unseated id, a removed id, another company's staff, and a payload `{}` all leave `live_count() == 0`, with no errors.
  - `test_game_loaded_rebuilds_from_new_session`: set `GameRunner.session` to a new session whose state has a different seated staff member, dispatch `game_loaded`, and only the new staff sprite exists.
  
  Added to `test_main_scene.gd`:
  - `test_office_mounted_and_centred`: `OfficeSlot` has an `OfficeScene` child with `scale == Vector2(2, 2)` and `position == Vector2(load("res://src/ui/main.gd").office_origin(room_px))` (`main.gd` has no `class_name`).
  - `test_office_data_desks_lie_on_room_floor`: for every `.tres` in `res://data/offices/`, load the `OfficeDef` and instantiate its `scene_path` as an `OfficeRoom`. Assert `desk_positions.size() == seats`, and that every desk cell and its `+ (0, 1)` chair cell satisfy `is_floor`. Also assert at least one office file exists. If the desk cells in the data disagree with Ruling 3's published cells, set them to those cells in this task (`Modify: data/offices/*.tres`, fields `desk_positions` and `scene_path` only; normally M2a Task 10 already set them from the hand-off above).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the wiring, `_office_content()` and the debug button.
- [ ] **Step 4: Run** the import, then the suite. Expected: all pass.
- [ ] **Step 5: Commit** `feat(ui): drive office scene and bubbles from game events`.

---

### Task 12: Manual Mac checklist

**Prerequisite:** Tasks 1–11 are done, and so are M2a Tasks 15–16 (StartProject, and production emitting `points_gained`/`bug_found`). M2a Ruling A2 already seats the owner with a starter computer at new game. If M2a production has not landed, run items 1, 2, 4, 5 and 6 now, report `DONE_WITH_CONCERNS` naming item 3, and rerun item 3 once it lands.

- [ ] **Step 1:** Run `godot --path "/Users/chanapols/Projects/ game-dev"`. Check each item and report what you saw for each:
  1. **Crisp 4× pixels.** The window opens at 1280×720. The office tiles show hard pixel edges with no blur, and every art pixel is square and the same size. Zoom a screenshot: each art pixel is 4×4 points, which is 8×8 physical pixels on a Retina display. Resize the window to about 1600×900: it stays at 2× with black bars. Resize to 1920×1080 or go fullscreen at 1080p: it fills exactly at 3× with no bars. Nothing is blurry at either size.
  2. **Thai renders.** Switch the locale to Thai (temporarily set `internationalization/locale/test="th"` in Project Settings, and do not commit the change). Tabs and the status bar show Thai with tone marks above and vowels below, not boxes, and the text is clipped with "…" when too long. Revert the setting.
  3. **Bubbles while developing.** Press F3, then Test project, then 1x. Coloured bubbles rise from the seated staff each week, and a red bubble appears when a bug is found. At 4× the screen does not fill with bubbles.
  4. **Tabs visible.** All five tabs show. Clicking one slides an empty panel up with its title, and clicking it again closes the panel.
  5. **Status bar.** It shows the date, money and speed buttons. The project fields fill once a project is in production.
  6. **F3** toggles the debug HUD, and Save / Load in it still work.
- [ ] **Step 2:** Run the full suite once more and quote the GUT totals line. No commit unless a fix was needed (a fix gets its own task-style commit).

---

## Parallel groups

Tasks in the same group touch disjoint files and can run at the same time. Groups run in order. Disjoint files are not enough on their own: every task runs `godot --headless --import` and the full suite. Run parallel tasks in separate worktrees (`isolation: "worktree"`), so they do not race on `.godot/` or `.git/index.lock` or see a sibling's red TDD step. Otherwise, each task runs only its own tests with `-gselect`, and the full suite runs once at the end of the group.

| Group | Tasks | Files (exclusive within the group) | Waits for |
|---|---|---|---|
| G1 | **1**, **2**, **3**, **6** | 1: `assets/art/`, `assets/CREDITS.md`, `office_art.gd`, `test_assets.gd` · 2: `assets/fonts/`, `src/ui/theme/`, `locale/strings.csv`, `test_theme.gd` · 3: `project.godot`, `test_display_settings.gd` · 6: `bubble*.gd`, `test_bubbles.gd` | — (can run alongside M2a, but see the shared files below) |
| G2 | **4**, **5**, **8** | 4: `office_room.gd`, `rooms/`, `test_office_room.gd` · 5: `state_queries.gd`, `staff_sprite.*`, `desk_sprite.*`, two tests · 8: `tab_bar_shell.*`, `panel_host.*`, `test_tab_bar.gd` | 4, 5 need Task 1; 8 needs Task 2 |
| G3 | **7** | `state_queries.gd`, `status_bar.*`, `test_status_bar.gd` | Task 5 (`state_queries.gd`) and Task 2 |
| G4 | **9** | `main.*`, `project.godot`, `test_main_scene.gd`, `test_debug_hud.gd` | Tasks 3, 7, 8 |
| G5 | **10** | `seat_view.gd`, `state_queries.gd`, `office_scene.*`, `office_fixtures.gd`, two tests | Tasks 4, 5, 6 **and M2a Tasks 1–4, 6, 7** |
| G6 | **11** → **12** | `office_scene.gd`, `main.*`, `status_bar.gd`, `debug_hud.*`, `data/offices/*.tres` (desk fields only) | Tasks 9, 10 **and M2a Tasks 2, 8, 10, 15** (Task 12 also needs M2a Task 16) |

**Shared with M2a** (do not edit in parallel with an M2a task that touches the same file; commit, then let the other side rebase): `locale/strings.csv` (Task 2), `project.godot` (Tasks 3, 9), `src/core/state_queries.gd` (Tasks 5, 7, 10), `data/offices/*.tres` (Task 11). This plan never edits `tests/helpers/fixtures.gd`, `src/core/event_bus.gd` or any entity or content class.
