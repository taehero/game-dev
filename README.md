# Studio Tycoon

A game-studio tycoon game for Steam on Windows and macOS. A deterministic, seeded weekly simulation runs the studio, and the UI only reads state and submits commands.

- Engine: Godot 4.7.2 (GDScript, static typing)
- Tests: GUT 9.7.1 (vendored in `addons/gut/`)

## Commands

Run from the project root. The project path may contain a leading space, so quote it.

```bash
godot --headless --import                            # after a fresh checkout or a new class_name
godot --headless -s addons/gut/gut_cmdln.gd -gexit   # run all tests
godot --path "/Users/chanapols/Projects/ game-dev"   # run the game
```

The first `--import` on a fresh checkout prints `Cannot open file 'res://locale/strings.*.translation'` errors before it generates those files. This is expected.

## Docs

- [Design spec](docs/superpowers/specs/2026-10-24-studio-tycoon-foundation-design.md)
- [Project rules](CLAUDE.md)
