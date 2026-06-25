extends Node
## Global one-shot SFX player (autoload). Call SoundManager.play("apple_death")
## from anywhere — sounds route through the "SFX" bus so their volume is
## independent of music. Level-agnostic: gameplay code fires events directly.
##
## Per-sound volume is layered, all in dB:
##   BASE_VOLUMES[key]      — the fixed mix level for each individual effect
## + set_volume(key, db)    — a runtime trim for the current scenario (level/phase)
## + play(key, volume_db)   — a one-off nudge for a single play

const _POOL_SIZE := 12
const _BUS := "SFX"

# event key -> stream. keys are the .wav basenames.
const SOUNDS := {
	"Q1_fill": preload("res://assets/audio/sfx/Q1_fill.wav"),
	"Q2_fill": preload("res://assets/audio/sfx/Q2_fill.wav"),
	"Q3_fill": preload("res://assets/audio/sfx/Q3_fill.wav"),
	"Q4_fill": preload("res://assets/audio/sfx/Q4_fill.wav"),
	"apple_damage1": preload("res://assets/audio/sfx/apple_damage1.wav"),
	"apple_damage2": preload("res://assets/audio/sfx/apple_damage2.wav"),
	"apple_death": preload("res://assets/audio/sfx/apple_death.wav"),
	"apple_shooting": preload("res://assets/audio/sfx/apple_shooting.wav"),
	"arrow_bounce": preload("res://assets/audio/sfx/arrow_bounce.wav"),
	"arrow_woosh": preload("res://assets/audio/sfx/arrow_woosh.wav"),
	"banana_death": preload("res://assets/audio/sfx/banana_death.wav"),
	"banana_shooting": preload("res://assets/audio/sfx/banana_shooting.wav"),
	"big_win_kill_boss_jingle": preload("res://assets/audio/sfx/big_win_kill_boss_jingle.wav"),
	"enemy_death_small_win_jingle": preload("res://assets/audio/sfx/enemy_death_small_win_jingle.wav"),
}

# per-asset base level in dB — balance the individual effects against each other
# here (0 = unchanged, negative = quieter, positive = louder).
const BASE_VOLUMES := {
	"Q1_fill": 0.0,
	"Q2_fill": 0.0,
	"Q3_fill": 0.0,
	"Q4_fill": 0.0,
	"apple_damage1": 0.0,
	"apple_damage2": 0.0,
	"apple_death": 0.0,
	"apple_shooting": 0.0,
	"arrow_bounce": 0.0,
	"banana_death": 0.0,
	"banana_shooting": 0.0,
	"big_win_kill_boss_jingle": 0.0,
	"enemy_death_small_win_jingle": 0.0,
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _overrides := {}  # key -> dB, per-scenario runtime trim on top of BASE_VOLUMES

func _ready() -> void:
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = _BUS
		add_child(p)
		_pool.append(p)

# fling a one-shot effect. volume_db nudges this single play; pitch_var > 0 jitters
# pitch +/- that amount so rapidly-repeated sounds (fills, bounces) don't fatigue.
func play(key: String, volume_db := 0.0, pitch_var := 0.0) -> void:
	if _pool.is_empty():
		return  # called before _ready built the pool — drop it rather than crash
	var stream: AudioStream = SOUNDS.get(key)
	if stream == null:
		push_warning("SoundManager: unknown sfx '%s'" % key)
		return
	var player := _take_player()
	player.stream = stream
	player.volume_db = _effective_volume(key) + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var) if pitch_var > 0.0 else 1.0
	player.play()

# a sound's level after applying any active scenario override.
func _effective_volume(key: String) -> float:
	return BASE_VOLUMES.get(key, 0.0) + _overrides.get(key, 0.0)

# scenario control: re-trim one sound for the current context (a level, a boss
# phase, a menu) without touching the call sites. Pair with clear_volume/reset.
func set_volume(key: String, db: float) -> void:
	_overrides[key] = db

func clear_volume(key: String) -> void:
	_overrides.erase(key)

func reset_volumes() -> void:
	_overrides.clear()

# prefer an idle player; otherwise steal the next in round-robin so nothing drops.
func _take_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	var stolen := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return stolen
