extends Status
class_name StatusBurn

@export var spin_speed := 24.0
@export var drift_speed := 7.2
@export var redrift := 0.14

var spin_dir := 1.0

func _init() -> void:
	lifetime = 2.5

func apply(target: Player) -> void:
	super(target)
	if randf() < 0.5:
		spin_dir = -1.0
	else:
		spin_dir = 1.0
	target.start_aim_spin(spin_speed * spin_dir)
	target.show_status_sprite(&"fire")

func remove() -> void:
	if is_instance_valid(owner):
		owner.stop_aim_spin()
		owner.hide_status_sprite()
