extends CPUParticles3D


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.3).timeout
	queue_free()
