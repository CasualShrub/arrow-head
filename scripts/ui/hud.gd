# in-game overlay (ammo, enemy count) plus the per-level win/lose/pause flow
extends CanvasLayer
class_name Hud

var _player: Player
var _enemies: Array[Enemy] = []
var _ammo_label: Label
var _enemies_label: Label
var _pause_panel: Control
var _victory_panel: Control
var _defeat_panel: Control
var _ended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # stay responsive while the tree is paused
	_build_ui()
	_find_actors()
	_wire()
	_ammo_label.text = "arrows: 0"
	_refresh_enemies()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var bar := MarginContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.add_theme_constant_override("margin_left", 16)
	bar.add_theme_constant_override("margin_right", 16)
	bar.add_theme_constant_override("margin_top", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hb)

	_ammo_label = UiStyle.label("arrows: 0", 20)
	hb.add_child(_ammo_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)

	_enemies_label = UiStyle.label("enemies: 0", 20)
	hb.add_child(_enemies_label)

	_pause_panel = _make_overlay("Paused", [
		["Resume", _resume], ["Restart", _restart], ["Main menu", _to_menu]])
	_victory_panel = _make_overlay("Victory", [
		["Next level", _next], ["Restart", _restart], ["Main menu", _to_menu]], "press R to restart")
	_defeat_panel = _make_overlay("You got pierced", [
		["Restart", _restart], ["Main menu", _to_menu]], "press R to restart")
	for p in [_pause_panel, _victory_panel, _defeat_panel]:
		p.visible = false
		root.add_child(p)

func _make_overlay(title_text: String, buttons: Array, hint := "") -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	vb.add_child(UiStyle.title(title_text, 44))
	for entry in buttons:
		var b := UiStyle.button(entry[0])
		b.pressed.connect(entry[1])
		vb.add_child(b)
	if hint != "":
		var h := UiStyle.label(hint, 16, UiStyle.MUTED)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(h)
	return overlay

func _find_actors() -> void:
	var scene := owner if owner != null else get_tree().current_scene  # owner is the level root
	if not scene:
		return
	_player = _find_player(scene)
	_find_enemies(scene, _enemies)

func _find_player(node: Node) -> Player:
	for c in node.get_children():
		if c is Player:
			return c
		var found := _find_player(c)
		if found:
			return found
	return null

func _find_enemies(node: Node, out: Array[Enemy]) -> void:
	for c in node.get_children():
		if c is Enemy:
			out.append(c)
		_find_enemies(c, out)

func _wire() -> void:
	if _player:
		_player.ammo_changed.connect(_on_ammo_changed)
		_player.died.connect(_on_player_died)
	for e in _enemies:
		if e.health:
			e.health.changed.connect(_on_enemy_health_changed)

func _on_ammo_changed(count: int) -> void:
	# the shoot-back pool: arrows absorbed from a full set, ready to fire
	_ammo_label.text = "arrows: %d" % count

# an enemy counts as dead once its health drains; it isn't freed from the tree
func _enemies_alive() -> int:
	var n := 0
	for e in _enemies:
		if is_instance_valid(e) and e.health and e.health.current > 0:
			n += 1
	return n

func _refresh_enemies() -> void:
	_enemies_label.text = "enemies: %d" % _enemies_alive()

func _on_enemy_health_changed() -> void:
	_refresh_enemies()
	if not _ended and _enemies.size() > 0 and _enemies_alive() == 0:
		_win()

func _on_player_died() -> void:
	if not _ended:
		_lose()

func _win() -> void:
	_ended = true
	get_tree().paused = true
	_victory_panel.visible = true

func _lose() -> void:
	_ended = true
	get_tree().paused = true
	_defeat_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	# R restarts from anywhere (same action as the Restart button)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()
		return
	if _ended:
		return
	# Esc toggles pause
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _pause_panel.visible:
			_resume()
		else:
			_pause()

func _pause() -> void:
	get_tree().paused = true
	_pause_panel.visible = true

func _resume() -> void:
	_pause_panel.visible = false
	get_tree().paused = false

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _next() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
