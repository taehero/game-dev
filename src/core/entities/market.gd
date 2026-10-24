class_name Market
extends RefCounted

const SCHEMA: Dictionary = {
	"segment_size": "dict",
	"segment_growth_bp": "dict",
	"taste_bp": "dict",
	"platform_install_base": "dict",
	"focus_drift": "dict",
}

var segment_size: Dictionary[StringName, int] = {}
var segment_growth_bp: Dictionary[StringName, int] = {}  # basis points per year
var taste_bp: Dictionary[StringName, int] = {}  # 5000-15000, 10000 = neutral
var platform_install_base: Dictionary[StringName, int] = {}
var focus_drift: Dictionary[StringName, Array] = {}  # each value: 3 ints, -10..10


func to_dict() -> Dictionary:
	var size_out: Dictionary = {}
	for k: StringName in segment_size:
		size_out[String(k)] = segment_size[k]
	var growth_out: Dictionary = {}
	for k: StringName in segment_growth_bp:
		growth_out[String(k)] = segment_growth_bp[k]
	var taste_out: Dictionary = {}
	for k: StringName in taste_bp:
		taste_out[String(k)] = taste_bp[k]
	var base_out: Dictionary = {}
	for k: StringName in platform_install_base:
		base_out[String(k)] = platform_install_base[k]
	var drift_out: Dictionary = {}
	for k: StringName in focus_drift:
		var arr_out: Array = []
		for v: Variant in focus_drift[k]:
			arr_out.append(int(v))
		drift_out[String(k)] = arr_out
	return {
		"segment_size": size_out,
		"segment_growth_bp": growth_out,
		"taste_bp": taste_out,
		"platform_install_base": base_out,
		"focus_drift": drift_out,
	}


static func from_dict(d: Dictionary) -> Market:
	var m := Market.new()
	var size_in: Dictionary = d["segment_size"]
	for k: Variant in size_in:
		m.segment_size[StringName(String(k))] = int(size_in[k])
	var growth_in: Dictionary = d["segment_growth_bp"]
	for k: Variant in growth_in:
		m.segment_growth_bp[StringName(String(k))] = int(growth_in[k])
	var taste_in: Dictionary = d["taste_bp"]
	for k: Variant in taste_in:
		m.taste_bp[StringName(String(k))] = int(taste_in[k])
	var base_in: Dictionary = d["platform_install_base"]
	for k: Variant in base_in:
		m.platform_install_base[StringName(String(k))] = int(base_in[k])
	var drift_in: Dictionary = d["focus_drift"]
	for k: Variant in drift_in:
		var arr: Array = []
		for v: Variant in drift_in[k]:
			arr.append(int(v))
		m.focus_drift[StringName(String(k))] = arr
	return m
