class_name UiFit
extends RefCounted
## Layout-fit assertions for UI tests (Ruling 19).


static func natural_width(label: Label) -> float:
    return label.get_theme_font(&"font").get_string_size(label.text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x


static func text_fits(label: Label) -> bool:
    return natural_width(label) <= label.size.x + 0.5


static func button_fits(b: Button) -> bool:
    return b.get_combined_minimum_size().x <= b.size.x + 0.5


static func inside_screen(c: Control) -> bool:
    return Rect2(0, 0, 640, 360).encloses(c.get_global_rect())


static func labels_under(root: Node) -> Array[Label]:
    var out: Array[Label] = []
    if root is Label and (root as Label).is_visible_in_tree():
        out.append(root as Label)
    for child: Node in root.get_children():
        out.append_array(labels_under(child))
    return out
