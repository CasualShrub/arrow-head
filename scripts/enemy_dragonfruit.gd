@tool
extends Enemy

@onready var _sectors: SectorsComponent = %Sectors

func get_hit() -> void:
	var pos = player.global_position
	var s = _sectors.get_sector_from_position(pos)
	if not _sectors.occupied([s]):
		_sectors.store([s], s)
	if _sectors.full():
		die()
