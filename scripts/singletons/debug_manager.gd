extends Node

var enabled := true

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

func _process(_delta: float) -> void:
	if not enabled: return
	
	var player := GameManager.player
	if not player: return
	if Input.is_action_just_pressed("debug_arrow"):
		var arrow := Arrow.new()
		get_tree().current_scene.add_child(arrow)
		var vec := Vector3.RIGHT
		for i in range(player.arrows.slot_count):
			if not player.arrows.is_slot_occupied(i):
				vec = vec.rotated(Vector3.UP, -PI / 2 * i)
				break
		vec = vec.rotated(Vector3.UP, player._mouse_pivot.rotation.y)
		arrow.global_position = player._mouse_pivot.global_position + vec
		player.call_deferred("get_hit", arrow)
	if Input.is_action_just_pressed("debug_meter_full"):
		player.time.bar.regenerate(100000.0)
	if Input.is_action_just_pressed("debug_teleport"):
		var mouse_pos := player.get_camera().get_mouse_position()
		mouse_pos.y = player.global_position.y
		player.global_position = mouse_pos

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false
