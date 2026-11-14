class_name BackgroundManager
extends Node
# Pengelola tema latar visual dan suara (ambience) untuk Dodge 'em All.
# Mengatur pemuatan lazy latar aktif, transisi visual halus via overlay,
# setup bus audio (Music & Ambience), serta pemutaran loop ambience.

signal theme_changed(theme_id: String)

# Daftar tema yang tersedia dalam game
const THEMES = {
	"space": {
		"name": "Angkasa",
		"scene": "res://space_background.tscn",
		"ambience": "res://art/audio/ambience/space.wav",
		"music": "res://art/House In a Forest Loop.ogg"
	},
	"planet": {
		"name": "Planet",
		"scene": "res://planet_background.tscn",
		"ambience": "res://art/audio/ambience/planet.wav",
		"music": "res://art/audio/music/planet_game_sound.wav"
	},
	"ocean": {
		"name": "Laut",
		"scene": "res://ocean_background.tscn",
		"ambience": "res://art/audio/ambience/ocean.wav",
		"music": "res://art/audio/music/ocean_game_sound.wav"
	},
	"city": {
		"name": "Kota",
		"scene": "res://city_background.tscn",
		"ambience": "res://art/audio/ambience/city.wav",
		"music": "res://art/audio/music/city_game_sound.wav"
	}
}

const DEFAULT_THEME = "space"
const TRANSITION_DURATION = 0.35 # durasi fade-in dan fade-out (total ~0.7 detik)
const AMBIENCE_FADE_DURATION = 0.6
const DEFAULT_MUSIC_VOLUME = 0.8
const DEFAULT_AMBIENCE_VOLUME = 0.7
# Volume ambience player (dB). Bus Ambience mengatur volume master keluaran;
# player volume dijaga tetap 0 dB agar tidak ada redaman ganda.
const AMBIENCE_ATTENUATION_DB = 0.0

var _current_theme_id: String = ""
var _current_bg: BackgroundBase = null
var _current_wave: int = 1
var _is_round_active: bool = false
var _is_credits_preview: bool = false

var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _transition_tween: Tween

var _ambience_player: AudioStreamPlayer
var _ambience_tween: Tween
var _ambience_target_volume_db: float = AMBIENCE_ATTENUATION_DB # = 0 dB; bus mengatur level keseluruhan
var _is_ambience_playing: bool = false


func _ready() -> void:
	_setup_audio_buses()
	_setup_ambience_player()
	_setup_transition_overlay()

	# Muat volume tersimpan dan terapkan ke bus audio
	var saved_music_vol = SaveManager.get_setting("music_volume", DEFAULT_MUSIC_VOLUME)
	var saved_ambience_vol = SaveManager.get_setting("ambience_volume", DEFAULT_AMBIENCE_VOLUME)
	if saved_ambience_vol == null or saved_ambience_vol <= 0.001:
		saved_ambience_vol = DEFAULT_AMBIENCE_VOLUME
	if saved_music_vol == null or saved_music_vol <= 0.001:
		saved_music_vol = DEFAULT_MUSIC_VOLUME
	set_volume("Music", saved_music_vol)
	set_volume("Ambience", saved_ambience_vol)

	# Muat tema tersimpan atau default
	var saved_theme = SaveManager.get_setting("background_theme", DEFAULT_THEME)
	set_theme(saved_theme, false)


# ---------------- Setup Audio Bus & Player ----------------

func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")

	if AudioServer.get_bus_index("Ambience") == -1:
		AudioServer.add_bus()
		var amb_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(amb_idx, "Ambience")
		AudioServer.set_bus_send(amb_idx, "Master")


func _setup_ambience_player() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = "Ambience"
	_ambience_player.volume_db = AMBIENCE_ATTENUATION_DB
	add_child(_ambience_player)


func _setup_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "TransitionLayer"
	_transition_layer.layer = -1 # Di atas latar belakang (-1), tetapi di bawah game (0)
	add_child(_transition_layer)

	_transition_rect = ColorRect.new()
	_transition_rect.name = "TransitionFadeRect"
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_rect)


# ---------------- Manajemen Tema Latar ----------------

func get_theme_id() -> String:
	return _current_theme_id


func get_theme_music_stream(theme_id: String = "") -> AudioStream:
	var tid = theme_id if theme_id != "" else _current_theme_id
	var info = THEMES.get(tid, THEMES[DEFAULT_THEME])
	var music_path: String = info.get("music", "")
	if not ResourceLoader.exists(music_path):
		music_path = THEMES[DEFAULT_THEME]["music"]

	var stream = load(music_path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels = 2 if stream.stereo else 1
		stream.loop_end = int(stream.data.size() / float(bytes_per_sample * channels))
	return stream


func set_theme(theme_id: String, animated: bool = true) -> void:
	if not THEMES.has(theme_id):
		theme_id = DEFAULT_THEME

	if theme_id == _current_theme_id and is_instance_valid(_current_bg):
		return

	_current_theme_id = theme_id
	SaveManager.set_setting("background_theme", theme_id)

	if animated and is_instance_valid(_current_bg):
		_transition_to_theme(theme_id)
	else:
		_instant_apply_theme(theme_id)

	theme_changed.emit(theme_id)


func _instant_apply_theme(theme_id: String) -> void:
	if _transition_tween:
		_transition_tween.kill()
	_transition_rect.color.a = 0.0

	var old_bg = _current_bg
	_current_bg = _instantiate_theme_bg(theme_id)

	if is_instance_valid(old_bg):
		old_bg.deactivate()
		old_bg.queue_free()

	_apply_current_state_to_bg()
	if _is_ambience_playing:
		_load_and_play_ambience_stream(theme_id, false)


func _transition_to_theme(theme_id: String) -> void:
	if _transition_tween:
		_transition_tween.kill()

	_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Fade to black (tutupi latar lama)
	_transition_tween.tween_property(_transition_rect, "color:a", 1.0, TRANSITION_DURATION)

	# Ganti instance latar di balik layar hitam
	_transition_tween.tween_callback(func():
		var old_bg = _current_bg
		_current_bg = _instantiate_theme_bg(theme_id)

		if is_instance_valid(old_bg):
			old_bg.deactivate()
			old_bg.queue_free()

		# Pastikan transition layer tetap berada di atas latar baru
		move_child(_transition_layer, -1)

		_apply_current_state_to_bg()
		if _is_ambience_playing:
			_load_and_play_ambience_stream(theme_id, true)
	)

	# Fade out black (tampilkan latar baru)
	_transition_tween.tween_property(_transition_rect, "color:a", 0.0, TRANSITION_DURATION)


func _instantiate_theme_bg(theme_id: String) -> BackgroundBase:
	var info = THEMES.get(theme_id, THEMES[DEFAULT_THEME])
	var scene_path: String = info["scene"]

	if not ResourceLoader.exists(scene_path):
		push_warning("Scene latar %s belum tersedia, memakai fallback space" % scene_path)
		scene_path = THEMES[DEFAULT_THEME]["scene"]

	var packed: PackedScene = load(scene_path)
	var bg_instance = packed.instantiate() as BackgroundBase
	bg_instance.name = "ActiveBackground"
	# Sisipkan latar sebelum transition layer
	add_child(bg_instance)
	move_child(bg_instance, 0)
	bg_instance.activate()
	return bg_instance


func _apply_current_state_to_bg() -> void:
	if not is_instance_valid(_current_bg):
		return

	if _is_round_active:
		_current_bg.set_wave_theme(_current_wave)
		_current_bg.start_events()
	elif _is_credits_preview:
		_current_bg.reset_to_title_theme()
		_current_bg.start_events()
	else:
		_current_bg.reset_to_title_theme()
		_current_bg.stop_events()


# ---------------- Penerusan Metode (API BackgroundBase) ----------------

func start_events() -> void:
	_is_round_active = true
	if is_instance_valid(_current_bg):
		_current_bg.start_events()


func stop_events() -> void:
	_is_round_active = false
	if is_instance_valid(_current_bg):
		_current_bg.stop_events()


func set_wave_theme(wave_num: int) -> void:
	_current_wave = wave_num
	if is_instance_valid(_current_bg):
		_current_bg.set_wave_theme(wave_num)


func reset_to_title_theme() -> void:
	_current_wave = 1
	_is_round_active = false
	if is_instance_valid(_current_bg):
		_current_bg.reset_to_title_theme()


# ---------------- Pratinjau di Layar Credits ----------------

func start_credits_preview() -> void:
	_is_credits_preview = true
	if is_instance_valid(_current_bg):
		_current_bg.start_events()
	play_ambience()


func stop_credits_preview() -> void:
	_is_credits_preview = false
	stop_ambience()
	if not _is_round_active and is_instance_valid(_current_bg):
		_current_bg.stop_events()
		_current_bg.reset_to_title_theme()


# ---------------- Pemutaran Ambience Loop ----------------

func play_ambience() -> void:
	_is_ambience_playing = true
	_load_and_play_ambience_stream(_current_theme_id, true)


func stop_ambience() -> void:
	_is_ambience_playing = false
	if not is_instance_valid(_ambience_player):
		return

	if _ambience_tween:
		_ambience_tween.kill()

	_ambience_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ambience_tween.tween_property(_ambience_player, "volume_db", -60.0, AMBIENCE_FADE_DURATION)
	_ambience_tween.tween_callback(func():
		_ambience_player.stop()
		_ambience_player.stream = null
	)


func _load_and_play_ambience_stream(theme_id: String, crossfade: bool) -> void:
	if not is_instance_valid(_ambience_player):
		return

	var info = THEMES.get(theme_id, THEMES[DEFAULT_THEME])
	var wav_path: String = info.get("ambience", "")
	if not ResourceLoader.exists(wav_path):
		# Jika file audio belum digenerate, biarkan hening tanpa error
		return

	var stream = load(wav_path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if stream.loop_end <= 0:
			var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels = 2 if stream.stereo else 1
			stream.loop_end = int(stream.data.size() / float(bytes_per_sample * channels))

	if crossfade and _ambience_player.playing:
		if _ambience_tween:
			_ambience_tween.kill()
		_ambience_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_ambience_tween.tween_property(_ambience_player, "volume_db", -60.0, AMBIENCE_FADE_DURATION * 0.5)
		_ambience_tween.tween_callback(func():
			_ambience_player.stream = stream
			_ambience_player.play()
		)
		_ambience_tween.tween_property(_ambience_player, "volume_db", _ambience_target_volume_db, AMBIENCE_FADE_DURATION * 0.5)
	else:
		_ambience_player.stream = stream
		_ambience_player.volume_db = _ambience_target_volume_db
		_ambience_player.play()


# ---------------- Kontrol Volume Bus ----------------

func set_volume(bus_name: String, linear_vol: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return

	linear_vol = clampf(linear_vol, 0.0, 1.0)
	if linear_vol <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))

	if bus_name == "Music":
		SaveManager.set_setting("music_volume", linear_vol)
	elif bus_name == "Ambience":
		SaveManager.set_setting("ambience_volume", linear_vol)
		# Pastikan player yang sedang bermain memperbarui volume jika bus di-mute/unmute
		# (volume player selalu AMBIENCE_ATTENUATION_DB = 0 dB; bus yang mengatur level keseluruhan)
		if is_instance_valid(_ambience_player) and _ambience_player.playing:
			_ambience_player.volume_db = AMBIENCE_ATTENUATION_DB


func get_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
