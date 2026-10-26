class_name UiBuild
extends RefCounted
## Small node factories shared by the dock panels.


static func label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	return l


## A pill tag holding one label (the label is the chip's first child).
static func chip(text: String, variation: StringName = &"TagPanel") -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = variation
	c.add_child(label(text))
	return c
