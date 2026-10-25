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

const TYPE_BASES: Dictionary[String, String] = {
    "PillLabel": "Label", "NumberLarge": "Label", "CardTitle": "Label", "TileNumber": "Label",
    "TileLabel": "Label", "BubbleText": "Label", "DockButton": "Button",
    "SegmentButton": "Button", "PillPanel": "PanelContainer", "CardPanel": "PanelContainer",
    "TilePanel": "PanelContainer", "DockPanel": "PanelContainer", "TrackPanel": "PanelContainer",
    "IconCircle": "PanelContainer",
}

func _panel(theme: Theme, type: StringName) -> StyleBoxFlat:
    return theme.get_stylebox(&"panel", type) as StyleBoxFlat

func test_palette_tokens_match_spec() -> void:
    assert_eq(UiPalette.ACCENT, Color("#F97316"))
    assert_eq(UiPalette.MONEY, Color("#22A06B"))
    assert_eq(UiPalette.FANS, Color("#E0457B"))
    assert_eq(UiPalette.HYPE, Color("#F2A93B"))
    assert_eq(UiPalette.DOCK, Color("#1F2937"))
    assert_eq(UiPalette.POINT_COLORS.size(), 5)
    assert_eq(UiPalette.POINT_COLORS[&"design"], Color("#22c55e"))
    assert_eq(UiPalette.POINT_COLORS[&"tech"], Color("#3b82f6"))
    assert_eq(UiPalette.POINT_COLORS[&"art"], Color("#f59e0b"))
    assert_eq(UiPalette.POINT_COLORS[&"audio"], Color("#a855f7"))
    assert_eq(UiPalette.POINT_COLORS[&"bug"], Color("#ef4444"))

func test_type_variations_exist() -> void:
    var theme := load(THEME_PATH) as Theme
    for name: String in TYPE_BASES:
        assert_eq(theme.get_type_variation_base(name), StringName(TYPE_BASES[name]), name)

func test_bold_font_weight_700_with_thai_and_latin() -> void:
    var f := (load(THEME_PATH) as Theme).get_font(&"font", &"NumberLarge")
    assert_true(f is FontVariation)
    var fv := f as FontVariation
    assert_eq(int(fv.variation_opentype[ThemeBuilder.WGHT_TAG]), 700)
    assert_true(f.has_char(0x0E01))
    assert_true(f.has_char(0x0E48))
    assert_true(f.has_char("A".unicode_at(0)))
    assert_true(f.has_char("9".unicode_at(0)))

func test_radii_and_shadow() -> void:
    var theme := load(THEME_PATH) as Theme
    assert_eq(_panel(theme, &"PillPanel").corner_radius_top_left, 12)
    assert_eq(_panel(theme, &"PillPanel").shadow_size, 4)
    assert_eq(_panel(theme, &"CardPanel").corner_radius_top_left, 10)
    assert_eq(_panel(theme, &"TilePanel").corner_radius_top_left, 8)
    assert_eq(_panel(theme, &"DockPanel").corner_radius_top_left, 14)

func test_base_margins_keep_old_bars_slim() -> void:
    var theme := load(THEME_PATH) as Theme
    assert_eq(_panel(theme, &"PanelContainer").content_margin_top, 1.0)
    assert_eq((theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat).content_margin_top, 1.0)

func test_committed_theme_matches_builder() -> void:
    var built := ThemeBuilder.build()
    var committed := load(THEME_PATH) as Theme
    for type: StringName in built.get_type_list():
        assert_eq(committed.get_type_variation_base(type), built.get_type_variation_base(type), type)
        for n: StringName in built.get_stylebox_list(type):
            var a := built.get_stylebox(n, type) as StyleBoxFlat
            var b := committed.get_stylebox(n, type) as StyleBoxFlat
            assert_not_null(b, "%s/%s" % [type, n])
            if b == null:
                continue
            var tag := "%s/%s" % [type, n]
            assert_eq(b.bg_color, a.bg_color, tag)
            assert_eq(b.corner_radius_top_left, a.corner_radius_top_left, tag)
            assert_eq(b.content_margin_left, a.content_margin_left, tag)
            assert_eq(b.content_margin_top, a.content_margin_top, tag)
        for n: StringName in built.get_font_size_list(type):
            assert_eq(committed.get_font_size(n, type), built.get_font_size(n, type), "%s/%s" % [type, n])
        for n: StringName in built.get_color_list(type):
            assert_eq(committed.get_color(n, type), built.get_color(n, type), "%s/%s" % [type, n])
        for n: StringName in built.get_constant_list(type):
            assert_eq(committed.get_constant(n, type), built.get_constant(n, type), "%s/%s" % [type, n])

func test_restyle_keys_translated_in_both_locales() -> void:
    for key: String in ["ui.pill.date", "ui.pill.money", "ui.pill.fans", "ui.pill.hype",
            "ui.pill.currency", "ui.point.design", "ui.point.tech", "ui.point.art",
            "ui.point.audio", "ui.point.bug", "ui.bubble.points", "ui.bubble.bug",
            "ui.card.subtitle", "ui.popup.close"]:
        for loc: String in ["en", "th"]:
            TranslationServer.set_locale(loc)
            assert_ne(tr(key), key, "%s/%s" % [loc, key])
    TranslationServer.set_locale("en")

func test_ui_fit_helper() -> void:
    var label := Label.new()
    label.theme = load(THEME_PATH) as Theme
    label.theme_type_variation = &"TileNumber"
    label.text = "9999"
    label.clip_text = true
    add_child_autofree(label)
    label.size = Vector2(38, 20)
    assert_true(UiFit.text_fits(label))
    label.size = Vector2(20, 20)
    assert_false(UiFit.text_fits(label))
