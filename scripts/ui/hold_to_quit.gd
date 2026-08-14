extends Button

# Hold the action down to trigger the button. A pale overlay sweeps across it
# while held and fills it completely at hold_time.

signal completed

@export var hold_time := 1.0
@export var key := KEY_TAB

@onready var _sweep: ColorRect = $Sweep

var _held := 0.0
var _armed := false      # needs a fresh press after the menu opens
var _last_ms := 0

func _ready() -> void:
	_last_ms = Time.get_ticks_msec()
	_reset()

func _reset() -> void:
	_held = 0.0
	if _sweep:
		_sweep.offset_right = 0.0

func _process(_delta: float) -> void:
	# wall clock, so slow motion and pausing don't stretch the hold
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_ms) / 1000.0
	_last_ms = now

	if not is_visible_in_tree() or disabled:
		_armed = false
		_reset()
		return
	if not Input.is_key_pressed(key):
		_armed = true
		if _held > 0.0:
			_reset()
		return
	if not _armed:
		return

	_held += dt
	if _sweep:
		_sweep.offset_right = size.x * clampf(_held / hold_time, 0.0, 1.0)
	if _held >= hold_time:
		_armed = false
		_reset()
		completed.emit()
