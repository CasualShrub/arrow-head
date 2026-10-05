extends Resource
class_name ScreenEffect

@export var shader: Shader
@export var parameters: Dictionary[StringName, Variant] = {}
@export var intensity_parameter := &"intensity"
@export var fade_in_time := 0.25
@export var fade_out_time := 0.25
@export var layer := 5
