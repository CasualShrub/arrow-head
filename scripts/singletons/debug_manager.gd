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
		var arrow: Arrow = (load("uid://bxgfy1nvmlb7v") as PackedScene).instantiate()
		get_tree().current_scene.add_child(arrow)
		var vec := (Vector3.FORWARD / 2).rotated(
			Vector3.LEFT,
			player.arrows.get_angle_from_slot(0)
		)
		for slot in range(player.arrows.slot_count):
			if player.arrows.get_state(slot) == player.arrows.SlotState.EMPTY:
				print("found empty: ", slot)
				vec = vec.rotated(
					Vector3.UP,
					player.arrows.get_angle_from_slot(slot)
				)
				break
		vec = vec.rotated(Vector3.UP, player._mouse_pivot.rotation.y)
		arrow.global_position = player.global_position + vec
		print("vec: ", vec)
		arrow.look_at(player.global_position)
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
