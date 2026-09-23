extends Node
## Original, pre-rendered score and a bounded SFX mixer. No runtime synthesis.
## Add once to the floor, then call play("slash") or set_state("boss").
## Music and SFX bus volumes belong to SettingsManager; this node never changes them.

const AUDIO_PATH := "res://assets/audio/"
const MAX_VOICES := 10
const EVENTS := ["slash", "hit", "hurt", "death", "dash", "pickup", "level_up", "gate", "boss_warning", "boss_slam", "victory", "defeat", "ui", "step"]
const EVENT_DB := {
	"slash": -10.0, "hit": -8.0, "hurt": -5.0, "death": -10.0,
	"dash": -8.0, "pickup": -17.0, "level_up": -7.0, "gate": -9.0,
	"boss_warning": -7.0, "boss_slam": -6.0, "victory": -7.0,
	"defeat": -8.0, "ui": -10.0, "step": -22.0
}
const COOLDOWNS := {"hit": 0.045, "death": 0.07, "pickup": 0.10, "step": 0.17, "slash": 0.06}
const IMPORTANT := ["hurt", "level_up", "boss_warning", "boss_slam", "victory", "defeat"]
var state := ""
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _last_played: Dictionary = {}
var _ambient_target := 0.0
var _combat_target := 0.0
var _ambient_gain := 0.0
var _combat_gain := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for event in EVENTS:
		_streams[event] = load(AUDIO_PATH + event + ".wav")
	for index in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)
	_ambient = _make_loop("ambient")
	_combat = _make_loop("combat")
	set_state("menu")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func _make_loop(file_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = file_name.capitalize()
	player.bus = "Music"
	var stream: AudioStreamWAV = load(AUDIO_PATH + file_name + ".wav")
	# Duplication keeps loop flags local, independent of editor import defaults.
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	player.play()
	return player

func set_state(next_state: String) -> void:
	if state == next_state:
		return
	state = next_state
	match state:
		"menu":
			_ambient_target = db_to_linear(-9.0)
			_combat_target = 0.0
		"playing":
			_ambient_target = db_to_linear(-12.0)
			_combat_target = db_to_linear(-20.0)
		"boss":
			_ambient_target = db_to_linear(-13.0)
			_combat_target = db_to_linear(-8.0)
		"pause", "upgrade", "settings":
			_ambient_target = db_to_linear(-17.0)
			_combat_target = 0.0
		"victory", "defeat":
			_ambient_target = db_to_linear(-20.0)
			_combat_target = 0.0
		_:
			_ambient_target = db_to_linear(-12.0)
			_combat_target = 0.0

func _process(delta: float) -> void:
	_clock += delta
	# Linear-amplitude fades stay smooth when a silent layer joins the score.
	var weight := 1.0 - exp(-delta * 2.0)
	_ambient_gain = lerpf(_ambient_gain, _ambient_target, weight)
	_combat_gain = lerpf(_combat_gain, _combat_target, weight)
	_ambient.volume_db = linear_to_db(maxf(_ambient_gain, 0.0001))
	_combat.volume_db = linear_to_db(maxf(_combat_gain, 0.0001))

func play(event: String, position: Vector3 = Vector3.ZERO) -> void:
	if not _streams.has(event):
		return
	var cooldown: float = COOLDOWNS.get(event, 0.025)
	if _clock - float(_last_played.get(event, -100.0)) < cooldown:
		return
	var selected: AudioStreamPlayer
	for voice in _voices:
		if not voice.playing:
			selected = voice
			break
	# Important feedback may replace the oldest ordinary effect. A swarm cannot
	# create unbounded players or interrupt the victory/boss warning stinger.
	if not selected:
		if not IMPORTANT.has(event):
			return
		var oldest := INF
		for voice in _voices:
			if not IMPORTANT.has(str(voice.get_meta("event", ""))):
				var started: float = voice.get_meta("started", 0.0)
				if started < oldest:
					oldest = started
					selected = voice
	if not selected:
		return
	_last_played[event] = _clock
	selected.stop()
	selected.stream = _streams[event]
	selected.volume_db = EVENT_DB.get(event, -10.0)
	# Optional world distance attenuation keeps off-screen enemies unobtrusive.
	# Zero means UI/player-local; top-down camera height doesn't damp every hit.
	if position != Vector3.ZERO:
		var hero := get_tree().get_first_node_in_group("player") as Node3D
		if hero:
			var distance := Vector2(position.x - hero.global_position.x, position.z - hero.global_position.z).length()
			selected.volume_db -= minf(distance * 0.4, 16.0)
	selected.pitch_scale = 1.0 if IMPORTANT.has(event) else _rng.randf_range(0.94, 1.06)
	selected.set_meta("event", event)
	selected.set_meta("started", _clock)
	selected.play()
