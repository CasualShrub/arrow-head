extends CharacterBody2D

@export var speed := 1.0
@export var health := 100.0
@export var max_health := 100.0
@export var arrows := 10
@export var skim_dist := 1.0

func move(dt: float) -> void:
	move_and_slide()

func _physics_process(delta: float) -> void:
	move(delta)
