class_name ProgressStore
extends RefCounted
## Experience per player, kept by whoever runs the match. On a VPS that is the server, so
## a player cannot raise their own level by editing a file on their computer.
## Players are told apart by a random token their client keeps in its settings.

var _cfg := ConfigFile.new()
var _path := ""
var _dirty := false


func _init() -> void:
	_path = Settings.arg("progress-file", "user://progress.cfg")
	_cfg.load(_path)


func xp(token: String) -> int:
	return int(_cfg.get_value("xp", token, 0))


func add(token: String, amount: int) -> int:
	var total := xp(token) + amount
	_cfg.set_value("xp", token, total)
	_dirty = true
	return total


func save() -> void:
	if _dirty:
		_cfg.save(_path)
		_dirty = false
