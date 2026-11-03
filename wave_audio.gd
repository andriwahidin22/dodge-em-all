extends Node
# wave_audio.gd: Pengatur audio adaptif per wave dan efek suara transisi wave.
#
# Cakupan:
# 1. Musik adaptif: pitch_scale naik bertahap (1.0 -> 1.3) via Tween seiring naiknya nomor wave.
#    Mendukung tabel WAVE_MUSIC untuk opsi penggantian lagu per wave tertentu.
# 2. Efek suara wave (wave_start, subwave_start, wave_cleared, game_won).
# 3. Ikut berhenti saat pause (karena child dari Main/Pausable) dan dibersihkan saat stop().

const PATH_WAVE_START = "res://art/audio/wave_start.wav"
const PATH_SUBWAVE_START = "res://art/audio/subwave_start.wav"
const PATH_WAVE_CLEARED = "res://art/audio/wave_cleared.wav"
const PATH_GAME_WON = "res://art/audio/game_won.wav"

# Tabel opsional musik per wave: {nomor_wave: path_ogg}
# Lagu baru akan diputar dari nomor_wave tersebut hingga ada entri berikutnya.
# Jika kosong / tidak ada entri cocok, memakai musik default ($Music).
const WAVE_MUSIC = {
	# Contoh:
	# 5: "res://art/music_wave5.ogg",
}

const BASE_PITCH = 1.0
const MAX_PITCH = 1.3
const MAX_WAVES = 10

var _music_player: AudioStreamPlayer
var _default_music_stream: AudioStream
var _current_music_path = ""
var _music_tween: Tween

var _sfx_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer

var _sfx_wave_start: AudioStream
var _sfx_subwave_start: AudioStream
var _sfx_wave_cleared: AudioStream
var _sfx_game_won: AudioStream
var _current_wave = 1


func _init():
	_load_assets()


func _ready():
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "WaveSFXPlayer"
	add_child(_sfx_player)

	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.name = "WaveJinglePlayer"
	add_child(_jingle_player)


func _load_assets():
	if ResourceLoader.exists(PATH_WAVE_START):
		_sfx_wave_start = load(PATH_WAVE_START)
	if ResourceLoader.exists(PATH_SUBWAVE_START):
		_sfx_subwave_start = load(PATH_SUBWAVE_START)
	if ResourceLoader.exists(PATH_WAVE_CLEARED):
		_sfx_wave_cleared = load(PATH_WAVE_CLEARED)
	if ResourceLoader.exists(PATH_GAME_WON):
		_sfx_game_won = load(PATH_GAME_WON)


# Menghubungkan node AudioStreamPlayer musik utama dari Main.
func setup(music_player):
	_music_player = music_player
	if _music_player:
		_default_music_stream = _music_player.stream


# Dipanggil saat wave dimulai (sebelum musuh muncul).
func on_wave_started(wave):
	_current_wave = wave
	_apply_wave_music(wave)
	_apply_music_pitch(wave)

	# Mainkan efek suara awal wave dengan nada naik bertahap sesuai nomor wave
	if _sfx_wave_start and _sfx_player:
		_sfx_player.stream = _sfx_wave_start
		_sfx_player.pitch_scale = clampf(1.0 + (wave - 1) * 0.04, 0.8, 1.5)
		_sfx_player.play()


# Dipanggil saat sub-wave dimulai (termasuk sub-wave 1).
func on_subwave_started(wave, subwave):
	# Sub-wave 1 sudah dibunyikan oleh on_wave_started agar tidak bertumpuk
	if subwave > 1 and _sfx_subwave_start and _sfx_player:
		_sfx_player.stream = _sfx_subwave_start
		_sfx_player.pitch_scale = clampf(1.0 + (subwave - 1) * 0.1, 0.9, 1.4)
		_sfx_player.play()


# Dipanggil saat sub-wave terakhir selesai (wave cleared).
func on_wave_cleared(wave):
	if _sfx_wave_cleared and _jingle_player:
		_jingle_player.stream = _sfx_wave_cleared
		_jingle_player.pitch_scale = 1.0
		_jingle_player.play()


# Dipanggil saat wave terakhir (max_wave) selesai ditaklukkan.
func on_game_won():
	if _music_player:
		_music_player.stop()
	if _sfx_player:
		_sfx_player.stop()
	if _sfx_game_won and _jingle_player:
		_jingle_player.stream = _sfx_game_won
		_jingle_player.pitch_scale = 1.0
		_jingle_player.play()


# Menghentikan semua sfx, membatalkan tween, dan mereset musik ke kondisi awal.
func stop():
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if _music_player:
		_music_player.pitch_scale = BASE_PITCH
		if _default_music_stream and _music_player.stream != _default_music_stream:
			_music_player.stream = _default_music_stream
		_current_music_path = ""
	if _sfx_player:
		_sfx_player.stop()
	if _jingle_player:
		_jingle_player.stop()
	_current_wave = 1


func get_current_pitch():
	if _music_player:
		return _music_player.pitch_scale
	return BASE_PITCH


func _apply_music_pitch(wave):
	if not _music_player:
		return
	var target_pitch = clampf(BASE_PITCH + (wave - 1) * ((MAX_PITCH - BASE_PITCH) / (MAX_WAVES - 1.0)), BASE_PITCH, MAX_PITCH)
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "pitch_scale", target_pitch, 1.2)


func _apply_wave_music(wave):
	if not _music_player:
		return
	var selected_path = ""
	var max_match = -1
	for w in WAVE_MUSIC.keys():
		if wave >= w and w > max_match:
			max_match = w
			selected_path = WAVE_MUSIC[w]

	if selected_path == "":
		if _current_music_path != "":
			_current_music_path = ""
			if _default_music_stream:
				_music_player.stream = _default_music_stream
				if _music_player.playing:
					_music_player.play()
	elif selected_path != _current_music_path:
		if ResourceLoader.exists(selected_path):
			_current_music_path = selected_path
			var new_stream = load(selected_path)
			var was_playing = _music_player.playing
			_music_player.stream = new_stream
			if was_playing:
				_music_player.play()
