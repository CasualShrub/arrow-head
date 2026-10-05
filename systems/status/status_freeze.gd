extends Status
class_name StatusFreeze

@export var warn_time := 0.6
@export var blink_rate := 12.0

func _init() -> void:
	lifetime = 2.0

func apply(target: Player) -> void:
	super(target)
	target.freeze_aim()
	target.show_status_sprite(&"ice")

func tick(_delta: float) -> void:
	if not is_instance_valid(owner): return
	var time_left := lifetime - _elapsed
	if time_left < warn_time:
		owner.set_status_sprite_visible(fmod(time_left * blink_rate, 2.0) < 1.0)

func remove() -> void:
	if is_instance_valid(owner):
		owner.unfreeze_aim()
		owner.hide_status_sprite()
