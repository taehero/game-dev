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
