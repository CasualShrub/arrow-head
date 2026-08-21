extends RefCounted
class_name Set

var _dict: Dictionary[Variant, bool] = {}

func has(value: Variant) -> bool:
	return _dict.has(value)

func add(value: Variant) -> void:
	_dict[value] = true

func remove(value: Variant) -> void:
	_dict.erase(value)

func clear() -> void:
	_dict.clear()

func is_empty() -> bool:
	return _dict.is_empty()

func size() -> int:
	return _dict.size()

func to_array() -> Array[Variant]:
	return _dict.keys()
