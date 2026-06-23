@tool
extends CharacterBody2D
class_name Player

@export var input: Node
@export var health: HealthComponent

@export var speed := 1.0
@export_group("arrows")
@export var arrows := []
@export var max_arrows := 10.0
@export_group("firing")
@export var fire_cooldown := 1.0
@export_group("skimming")
@export var skim_dist := 1.0
@export var skim_heal := 5

signal hit
signal fired
signal skimmed

func check_skim() -> void:
	for a in %SkimBox.get_overlapping_bodies():
		skim(a)

func skim(arrow: Node) -> void:
	health.heal(skim_heal)
	skimmed.emit(arrow)

func try_catch() -> void:
	for a in %CatchBox.get_overlapping_bodies():
		catch(a)

func catch(arrow: Node) -> void:
	arrows.append(arrow)

func get_hit(arrow: Node) -> void:
	hit.emit(arrow)

func move(dt: float) -> void:
	move_and_slide()

func _physics_process(delta: float) -> void:
	check_skim()
	move(delta)
