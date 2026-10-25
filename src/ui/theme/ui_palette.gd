class_name UiPalette
extends RefCounted
## Design tokens for the Clean Modern Tycoon restyle (spec section 5).

const SURFACE := Color("#FFFFFF")
const SURFACE_ALT := Color("#F3F4F6")
const TRACK := Color("#E5E7EB")
const TEXT := Color("#1F2937")
const TEXT_MUTED := Color("#6B7280")
const DOCK := Color("#1F2937")
const DOCK_TEXT := Color("#D1D5DB")
const ACCENT := Color("#F97316")
const MONEY := Color("#22A06B")
const FANS := Color("#E0457B")
const HYPE := Color("#F2A93B")
const DATE := Color("#4B5563")
const SUCCESS := Color("#3BB27F")
const WARNING := Color("#F2B53B")
const DANGER := Color("#E5484D")
const BACKDROP := Color(0, 0, 0, 0.45)
const SHADOW := Color(0, 0, 0, 0.18)

const POINT_COLORS: Dictionary[StringName, Color] = {
    &"design": Color("#22c55e"),
    &"tech": Color("#3b82f6"),
    &"art": Color("#f59e0b"),
    &"audio": Color("#a855f7"),
    &"bug": Color("#ef4444"),
}

const RADIUS_PILL := 12
const RADIUS_CARD := 10
const RADIUS_TILE := 8
const RADIUS_DOCK := 14
const SHADOW_OFFSET := Vector2(0, 2)
const SHADOW_SIZE := 4


static func tint(c: Color) -> Color:
    return c.lerp(Color.WHITE, 0.85)


static func ink(c: Color) -> Color:
    return c.darkened(0.3)
