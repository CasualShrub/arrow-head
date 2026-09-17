extends Node
class_name AimCursor

const RETICLE_COLOR := Color(0.2, 0.8, 1.0)

static var _owner: AimCursor
static var _parked := Vector2.INF

var screen_position := Vector2.ZERO

var _capturing := false
var _reticle := Control.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.draw.connect(_draw_reticle)
	_reticle.hide()
	layer.add_child(_reticle)

func _process(_delta: float) -> void:
	var want := get_viewport() == get_window() and DisplayServer.window_is_focused() and not MenuOverlay.any_open(get_tree())
	if want and not _capturing:
		_capture()
	elif _capturing and not want:
		_release()
	if _capturing:
		_reticle.queue_redraw()

func _input(event: InputEvent) -> void:
	if _capturing and event is InputEventMouseMotion:
		var rect := get_viewport().get_visible_rect()
		screen_position = (screen_position + event.relative * SettingsManager.mouse_sensitivity).clamp(rect.position, rect.end)

func _notification(what: int) -> void:
	if not _capturing:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release(false)
	elif what == NOTIFICATION_EXIT_TREE:
		_release()

func aim_position() -> Vector2:
	return screen_position if _capturing else get_viewport().get_mouse_position()

func _capture() -> void:
	if is_instance_valid(_owner):
		screen_position = _owner.screen_position
	elif _parked.is_finite():
		screen_position = _parked
	else:
		screen_position = get_viewport().get_mouse_position()
	_owner = self
	_capturing = true
	_reticle.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release(warp := true) -> void:
	_capturing = false
	_reticle.hide()
	if _owner != self:
		return
	_owner = null
	_parked = screen_position
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if warp:
		get_viewport().warp_mouse(screen_position)

func _draw_reticle() -> void:
	_reticle.draw_arc(screen_position, 10.0, 0.0, TAU, 32, RETICLE_COLOR, 2.0, true)
	_reticle.draw_circle(screen_position, 2.0, RETICLE_COLOR)
