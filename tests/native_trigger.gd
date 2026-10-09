extends Node

func _ready() -> void:
	DisplayServer.window_move_to_foreground()
	await get_tree().create_timer(1.5).timeout
	var native: RefCounted = ControllerManager.adaptive._native
	if not native or not ControllerManager.adaptive.available or native.controller_count() != 1:
		print("SKIP: native trigger check needs macOS and one connected DualSense")
		get_tree().quit(2)
		return
	var failed := false
	native.bow(0.65)
	await get_tree().create_timer(0.3).timeout
	var mode: int = native.reported_mode()
	print("R2 feedback mode: ", mode)
	failed = failed or mode != 1
	native.bow(0.0)
	await get_tree().create_timer(0.3).timeout
	mode = native.reported_mode()
	print("R2 released mode: ", mode)
	failed = failed or mode != 0
	native.bow(0.65)
	await get_tree().create_timer(1.3).timeout
	mode = native.reported_mode()
	print("R2 watchdog mode: ", mode)
	failed = failed or mode != 0
	native.bow(0.0)
	print("FAIL: native trigger feedback" if failed else "PASS: DualSense reports feedback, release and watchdog reset")
	get_tree().quit(1 if failed else 0)
