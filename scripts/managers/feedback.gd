extends Node
## Sound and haptic hooks. Every sound is optional: paths come from
## data/audio.json (events) and switches.json (press_audio/release_audio).
## A missing file is a silent no-op, never an error.

enum Sound { KEY_DOWN, KEY_UP, CRIT, PERFECT_PRESS, HOT_STREAK, PURCHASE, UNLOCK, MASTERY }

const AUDIO_PATH := "res://data/audio.json"
const EVENT_KEYS := {
	Sound.CRIT: "crit",
	Sound.PERFECT_PRESS: "perfect_press",
	Sound.HOT_STREAK: "hot_streak",
	Sound.PURCHASE: "purchase",
	Sound.UNLOCK: "unlock",
	Sound.MASTERY: "mastery",
}
const EXTENSIONS := ["ogg", "wav", "mp3"]
const PLAYER_POOL_SIZE := 8
const HAPTIC_MS := {"tap": 8, "crit": 22, "perfect": 45, "purchase": 12, "unlock": 40}

var _event_paths: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _stream_cache: Dictionary = {} # base path -> AudioStream or null

func _ready() -> void:
	_event_paths = GameManager._load_json(AUDIO_PATH)
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)

func play(sound: Sound, pitch_jitter: float = 0.0) -> void:
	var stream := _get_stream(_path_for(sound))
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

func _path_for(sound: Sound) -> String:
	match sound:
		Sound.KEY_DOWN:
			return str(GameManager.get_equipped_switch_data().get("press_audio", ""))
		Sound.KEY_UP:
			return str(GameManager.get_equipped_switch_data().get("release_audio", ""))
		_:
			return str(_event_paths.get(EVENT_KEYS.get(sound, ""), ""))

func _get_stream(base: String) -> AudioStream:
	if base == "":
		return null
	if _stream_cache.has(base):
		return _stream_cache[base]
	var stream: AudioStream = null
	var candidates: Array = [base] if base.get_extension() in EXTENSIONS else EXTENSIONS.map(func(e): return "%s.%s" % [base, e])
	for path in candidates:
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_stream_cache[base] = stream
	return stream
