extends Node3D

@export var player: Player
@export var offset := 5.0

func _process(_delta: float) -> void:
	global_position = player.global_position + Vector3.UP * offset

func _ready() -> void:
	if not player: player = %Player
