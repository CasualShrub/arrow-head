extends MeshInstance3D

@export var target_scale: Vector3 = Vector3(2.0, 2.0, 2.0)
@export var start_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

var opaque_color = Color(0.0, 0.8, 1.0, 1.0)
var transparent_color = Color(0.0, 0.8, 1.0, 0.0)

func _ready():
	await get_tree().create_timer(2.0).timeout
	scale = start_scale
	trigger_bounce_effect()

func trigger_bounce_effect():
	var tween = create_tween()
	
	# Safely get the material assigned directly inside your TorusMesh slot
	var mat = get_active_material(0)
	if mat:
		mat.set_shader_parameter("ring_color", opaque_color)
	
	# shrink
	tween.tween_property(self, "scale", Vector3(0.1,0.1,0.1), 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	# expand
	tween.tween_property(self, "scale", Vector3(3,3,3), 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
		
	# Safely fade the material to transparent simultaneously
	if mat:
		tween.parallel().tween_property(mat, "shader_parameter/ring_color", transparent_color, 0.1)\
			.set_trans(Tween.TRANS_LINEAR)

	# Free the node from memory after everything finishes
	tween.tween_callback(queue_free)
