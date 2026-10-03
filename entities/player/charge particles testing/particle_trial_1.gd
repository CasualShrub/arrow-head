extends Node3D

# References to the particle nodes
@onready var first_particles: GPUParticles3D = $"stove fire"
@onready var second_particles: GPUParticles3D = $"stove fire2"

func _ready() -> void:
	play_particle_sequence()
	
	

func play_particle_sequence() -> void:
	# 1. Ensure the first particle system is set up correctly
	await get_tree().create_timer(2.0).timeout
	first_particles.one_shot = true
	first_particles.lifetime = 0.2
	
	# 2. Emit the first particle burst
	first_particles.emitting = true
	
	# 3. Wait for the 0.2-second lifetime to finish
	await get_tree().create_timer(first_particles.lifetime).timeout
	
	# 4. Trigger the sibling particles
	second_particles.emitting = true
