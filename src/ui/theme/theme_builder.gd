class_name ThemeBuilder
extends RefCounted
## Builds the game Theme from UiPalette. tools/gen_theme.gd saves it to main_theme.tres.

const FONT_PATH := "res://assets/fonts/NotoSansThai-Variable.ttf"
const WGHT_TAG: int = 2003265652


static func _font(weight: int) -> FontVariation:
    var fv := FontVariation.new()
    fv.base_font = load(FONT_PATH) as Font
    fv.variation_opentype = {WGHT_TAG: weight}
    return fv


static func regular_font() -> FontVariation:
    return _font(400)


static func bold_font() -> FontVariation:
    return _font(700)


static func _box(bg: Color, radius: int, ml: float, mr: float, mt: float, mb: float,
        shadow: bool = false) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.set_corner_radius_all(radius)
    s.content_margin_left = ml
    s.content_margin_right = mr
    s.content_margin_top = mt
    s.content_margin_bottom = mb
    if shadow:
        s.shadow_color = UiPalette.SHADOW
        s.shadow_offset = UiPalette.SHADOW_OFFSET
        s.shadow_size = UiPalette.SHADOW_SIZE
    return s


static func _focus() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.draw_center = false
    s.set_border_width_all(1)
    s.border_color = UiPalette.ACCENT
    s.set_corner_radius_all(UiPalette.RADIUS_TILE)
    return s


static func _panel_var(t: Theme, name: StringName, bg: Color, radius: int, ml: float,
        mr: float, mt: float, mb: float, shadow: bool) -> void:
    t.set_type_variation(name, &"PanelContainer")
    t.set_stylebox(&"panel", name, _box(bg, radius, ml, mr, mt, mb, shadow))


static func _label_var(t: Theme, name: StringName, font: Font, size: int, color: Variant) -> void:
    t.set_type_variation(name, &"Label")
    t.set_font(&"font", name, font)
    t.set_font_size(&"font_size", name, size)
    if color != null:
        t.set_color(&"font_color", name, color as Color)


static func _button_var(t: Theme, name: StringName, font: Font, size: int, mx: float,
        my: float, icon_w: int) -> void:
    t.set_type_variation(name, &"Button")
    t.set_font(&"font", name, font)
    t.set_font_size(&"font_size", name, size)
    var clear := Color(0, 0, 0, 0)
    t.set_stylebox(&"normal", name, _box(clear, UiPalette.RADIUS_PILL, mx, mx, my, my))
    t.set_stylebox(&"hover", name,
        _box(Color(1, 1, 1, 0.08), UiPalette.RADIUS_PILL, mx, mx, my, my))
    t.set_stylebox(&"pressed", name,
        _box(UiPalette.ACCENT, UiPalette.RADIUS_PILL, mx, mx, my, my))
    t.set_stylebox(&"focus", name, _focus())
    t.set_color(&"font_color", name, UiPalette.DOCK_TEXT)
    t.set_color(&"font_hover_color", name, Color.WHITE)
    t.set_color(&"font_pressed_color", name, Color.WHITE)
    t.set_constant(&"icon_max_width", name, icon_w)
    t.set_constant(&"h_separation", name, 5)


static func build() -> Theme:
    var t := Theme.new()
    var regular := regular_font()
    var bold := bold_font()
    t.default_font = regular
    t.default_font_size = 12
    t.set_color(&"font_color", &"Label", UiPalette.TEXT)

    # Base styles: light colours with real padding; HUD widgets use their own variations.
    t.set_stylebox(&"panel", &"PanelContainer", _box(UiPalette.SURFACE, 6, 8, 8, 6, 6))
    t.set_stylebox(&"panel", &"Panel", _box(UiPalette.SURFACE, 6, 6, 6, 1, 1))
    t.set_stylebox(&"normal", &"Button", _box(UiPalette.SURFACE_ALT, 6, 10, 10, 6, 6))
    t.set_stylebox(&"hover", &"Button", _box(UiPalette.TRACK, 6, 10, 10, 6, 6))
    t.set_stylebox(&"pressed", &"Button", _box(UiPalette.ACCENT, 6, 10, 10, 6, 6))
    t.set_color(&"font_color", &"Button", UiPalette.TEXT)
    t.set_color(&"font_hover_color", &"Button", UiPalette.TEXT)
    t.set_color(&"font_pressed_color", &"Button", Color.WHITE)

    _panel_var(t, &"PillPanel", UiPalette.SURFACE, UiPalette.RADIUS_PILL, 3, 9, 1, 1, true)
    _panel_var(t, &"CardPanel", UiPalette.SURFACE, UiPalette.RADIUS_CARD, 6, 6, 6, 6, true)
    _panel_var(t, &"TilePanel", UiPalette.SURFACE_ALT, UiPalette.RADIUS_TILE, 0, 0, 1, 1, false)
    _panel_var(t, &"DockPanel", UiPalette.DOCK, UiPalette.RADIUS_DOCK, 3, 3, 3, 3, true)
    _panel_var(t, &"TrackPanel", UiPalette.DOCK, UiPalette.RADIUS_PILL, 2, 2, 2, 2, true)
    _panel_var(t, &"IconCircle", UiPalette.TEXT_MUTED, UiPalette.RADIUS_TILE, 3, 3, 3, 3, false)

    _label_var(t, &"PillLabel", regular, 12, UiPalette.TEXT)
    _label_var(t, &"NumberLarge", bold, 14, UiPalette.TEXT)
    _label_var(t, &"CardTitle", bold, 14, UiPalette.TEXT)
    _label_var(t, &"TileNumber", bold, 14, null)
    _label_var(t, &"TileLabel", regular, 10, UiPalette.TEXT_MUTED)
    _label_var(t, &"BubbleText", bold, 10, Color.WHITE)

    _button_var(t, &"DockButton", regular, 12, 6, 2, 12)
    _button_var(t, &"SegmentButton", bold, 10, 4, 1, 10)

    t.set_type_variation(&"LabelSmall", &"Label")
    t.set_font_size(&"font_size", &"LabelSmall", 10)
    t.set_type_variation(&"ButtonSmall", &"Button")
    t.set_font_size(&"font_size", &"ButtonSmall", 10)
    return t
