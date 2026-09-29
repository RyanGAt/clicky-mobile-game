extends Node
## Sound and haptic hooks. Every sound is optional: drop a file at one of the
## paths below and it plays; if none exists, the call is a silent no-op.

enum Sound { KEY_DOWN, KEY_UP, CRIT, PURCHASE, UNLOCK }

const SOUND_PATHS := {
	Sound.KEY_DOWN: "res://assets/audio/switches/%s_down",
	Sound.KEY_UP: "res://assets/audio/switches/%s_up",
	Sound.CRIT: "res://assets/audio/ui/crit",
	Sound.PURCHASE: "res://assets/audio/ui/purchase",
	Sound.UNLOCK: "res://assets/audio/ui/unlock",
}
const EXTENSIONS := ["ogg", "wav", "mp3"]
const PLAYER_POOL_SIZE := 8

const HAPTIC_MS := {"tap": 8, "crit": 22, "purchase": 12, "unlock": 40}

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
# Cache per resolved key; null means "looked it up, nothing there".
var _stream_cache: Dictionary = {}

func _ready() -> void:
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)

func play(sound: Sound, pitch_jitter: float = 0.0) -> void:
	var stream := _get_stream(sound)
	if stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()

func vibrate(kind: String) -> void:
	if not SaveManager.settings.get("vibration_enabled", true):
		return
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	Input.vibrate_handheld(HAPTIC_MS.get(kind, 10))

func _get_stream(sound: Sound) -> AudioStream:
	var base: String = SOUND_PATHS[sound]
	if base.contains("%s"):
		var category: String = GameManager.get_equipped_switch_data().get("sound_category", "default")
		base = base % category
	if _stream_cache.has(base):
		return _stream_cache[base]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_stream_cache[base] = stream
	return stream
