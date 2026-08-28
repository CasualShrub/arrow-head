extends RefCounted
class_name ArrowSet

var _dict: Dictionary[Arrow, bool] = {}

func has(value: Arrow) -> bool:
	return _dict.has(value)

func add(value: Arrow) -> void:
	_dict[value] = true

func remove(value: Arrow) -> void:
	_dict.erase(value)

func clear() -> void:
	_dict.clear()

func is_empty() -> bool:
	return _dict.is_empty()

func size() -> int:
	return _dict.size()

func to_array() -> Array[Arrow]:
	return _dict.keys()
