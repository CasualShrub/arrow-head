extends CanvasLayer
class_name LevelWipeTransition

signal slide_finished()

@export var duration := 0.4
@export var color := Color.BLACK

const MAX_STEP := 1.0 / 30.0

var _rect: ColorRect
var _direction := Vector2.RIGHT
var _covered := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _progress := 1.0

func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = color
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	set_process(false)

func is_covered() -> bool:
	return _covered

func cover(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_direction = direction.normalized()
	else:
		_direction = Vector2.RIGHT
	_rect.size = _screen_size()
	_rect.visible = true
	await _slide(-_offscreen_offset(), Vector2.ZERO)
	_covered = true

func reveal() -> void:
	if not _covered: return
	_covered = false
	await _slide(_rect.position, _offscreen_offset())
	if _progress >= 1.0:
		_rect.visible = false

func _slide(from: Vector2, to: Vector2) -> void:
	if _progress < 1.0:
		slide_finished.emit()
	_from = from
	_to = to
	_progress = 0.0
	_rect.position = from
	set_process(true)
	await slide_finished

func _process(delta: float) -> void:
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.001), MAX_STEP)
	_progress = minf(_progress + real_delta / duration, 1.0)
	_rect.position = _from.lerp(_to, ease(_progress, -2.4))
	if _progress >= 1.0:
		set_process(false)
		slide_finished.emit()

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _offscreen_offset() -> Vector2:
	return _direction * _screen_size() / maxf(absf(_direction.x), absf(_direction.y))
