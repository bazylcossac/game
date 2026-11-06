class_name Scoreboard
extends Control
## Held-Tab score table.

var world: World
var _root: HBoxContainer
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(dim)
	add_child(dim)
	var m := MarginContainer.new()
	UiKit.fill(m)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 150)
	m.add_theme_constant_override("margin_right", 150)
	m.add_theme_constant_override("margin_top", 110)
	m.add_theme_constant_override("margin_bottom", 90)
	add_child(m)
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 20)
	m.add_child(_root)
	visibility_changed.connect(_refresh)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 0.5:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	if not visible or _root == null:
		return
	for c in _root.get_children():
		c.queue_free()
	if world.ffa:
		_root.add_child(Overlays.ranking(world))
		return
	_root.add_child(Overlays.team_column(world, 0))
	_root.add_child(Overlays.team_column(world, 1))
