extends Resource
class_name ScreenShake

@export var stimulus_amount := 0.5
@export var decay := 2.0
@export var max_offset := 30.0

var intensity := 0.0

func trigger() -> void:
	add(stimulus_amount)

func add(amount: float) -> void:
	intensity = minf(intensity + amount, 1.0)

func poll(delta: float) -> Vector2:
	if intensity <= 0.0:
		return Vector2.ZERO
	intensity = maxf(intensity - decay * delta, 0.0)
	var falloff := intensity * intensity
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * falloff * max_offset
