class_name WaveManager
extends Node
# Pengatur sistem wave minimal untuk Dodge 'em All.
# Mengatur 10 wave, 3 sub-wave per wave, interval spawn dinamis,
# dan komposisi musuh (Walker, Swimmer, Chaser, Dasher, Splitter) per sub-wave.

signal wave_started(wave)
signal subwave_started(wave, subwave)
signal subwave_ended(wave, subwave)
signal wave_cleared(wave)
signal game_won

# Konstanta aturan permainan
const MAX_WAVES = 10
const SUBWAVES_PER_WAVE = 3
const SUBWAVE_DURATION = 20.0       # durasi aktif musuh muncul per sub-wave (detik)
const SUBWAVE_REST_DURATION = 2.0  # jeda istirahat antar sub-wave (detik)
const WAVE_TRANSITION_DELAY = 2.0  # jeda pengumuman wave baru / selesai (detik)

# Batas musuh di layar sekaligus = MAX_MOBS_BASE + MAX_MOBS_PER_WAVE × (wave−1)
# (wave 1: 5, wave 10: 14). Giliran spawn dilewati kalau layar sudah sepadat ini,
# supaya wave tinggi (interval spawn ±0,23 dtk + Splitter yang pecah) tetap bisa dimainkan.
const MAX_MOBS_BASE = 5
const MAX_MOBS_PER_WAVE = 1

# Scene musuh per jenis
const ENEMY_SCENES = {
	"walker": preload("res://enemies/walker.tscn"),
	"swimmer": preload("res://enemies/swimmer.tscn"),
	"chaser": preload("res://enemies/chaser.tscn"),
	"dasher": preload("res://enemies/dasher.tscn"),
	"splitter": preload("res://enemies/splitter.tscn"),
}

# Komposisi musuh wave 1–4: satu kamus per sub-wave, isinya bobot tiap jenis.
# Pola: jenis baru diperkenalkan berdua dengan Walker dulu, baru dicampur di sub-wave berikutnya.
# Musuh khusus (Chaser, Dasher, Splitter) lebih berbahaya daripada Walker karena mengejar,
# melesat, atau pecah jadi dua, jadi bobotnya dibuat lebih kecil supaya tidak menumpuk.
# Kunci khusus "interval" = pengali interval spawn (0.85 = 15% lebih padat).
# Wave 5–10 memakai campuran acak dari semua jenis (lihat _random_mix()).
const WAVES = [
	[{"walker": 1.0}, {"walker": 0.7, "swimmer": 0.3}, {"walker": 0.5, "swimmer": 0.5}],
	[{"walker": 0.5, "swimmer": 0.5}, {"walker": 0.75, "chaser": 0.25}, {"walker": 2.0, "swimmer": 1.5, "chaser": 1.0}],
	[{"walker": 2.0, "swimmer": 1.5, "chaser": 1.0}, {"walker": 0.75, "dasher": 0.25},
		{"walker": 2.0, "swimmer": 1.5, "chaser": 1.0, "dasher": 1.0}],
	[{"walker": 0.75, "splitter": 0.25}, {"walker": 2.0, "swimmer": 1.5, "chaser": 1.0, "dasher": 1.0, "splitter": 1.0},
		{"walker": 2.0, "swimmer": 1.5, "chaser": 1.0, "dasher": 1.0, "splitter": 1.0, "interval": 0.85}],
]

var wave = 1
var max_wave = MAX_WAVES
var subwave = 1
var is_running = false

# Internal state: "idle", "wave_prepare", "subwave_active", "subwave_rest", "wave_cleared", "game_won"
var _state = "idle"
var _timer = 0.0
var _mix = {}  # komposisi sub-wave yang sedang berjalan
var _rng = RandomNumberGenerator.new()  # seed acak otomatis saat dibuat


# Memulai rangkaian wave dari `start_wave` (bawaan 1).
# Nilai lain dipakai untuk melanjutkan dari simpanan progress atau untuk pengujian.
func start_waves(start_wave = 1):
	wave = clampi(start_wave, 1, MAX_WAVES)
	subwave = 1
	is_running = true
	_prepare_wave()


func stop():
	is_running = false
	_state = "idle"
	_timer = 0.0


func _prepare_wave():
	_state = "wave_prepare"
	_timer = WAVE_TRANSITION_DELAY
	wave_started.emit(wave)


func _process(delta):
	if not is_running:
		return

	_timer -= delta
	if _timer <= 0:
		_on_timer_finished()


func _on_timer_finished():
	match _state:
		"wave_prepare":
			_start_subwave(1)
		"subwave_active":
			subwave_ended.emit(wave, subwave)
			if subwave < SUBWAVES_PER_WAVE:
				_state = "subwave_rest"
				_timer = SUBWAVE_REST_DURATION
			else:
				_state = "wave_cleared"
				_timer = WAVE_TRANSITION_DELAY
				wave_cleared.emit(wave)
		"subwave_rest":
			subwave += 1
			_start_subwave(subwave)
		"wave_cleared":
			if wave < MAX_WAVES:
				wave += 1
				subwave = 1
				_prepare_wave()
			else:
				_state = "game_won"
				is_running = false
				game_won.emit()


func _finish_wave():
	if _state == "subwave_active" or _state == "subwave_rest":
		subwave_ended.emit(wave, subwave)
	subwave = SUBWAVES_PER_WAVE
	_state = "wave_cleared"
	_timer = WAVE_TRANSITION_DELAY
	wave_cleared.emit(wave)


# Mode debug: F2 langsung menyelesaikan wave yang sedang berjalan (lompat ke wave berikutnya).
# Hanya aktif di build debug (dijalankan dari editor atau APK debug), tidak di APK release.
func _unhandled_input(event):
	if not OS.is_debug_build() or not is_running:
		return
	if _state == "wave_cleared" or _state == "game_won":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		_finish_wave()


func _start_subwave(sw):
	subwave = sw
	_mix = get_mix(wave, subwave)
	_state = "subwave_active"
	_timer = SUBWAVE_DURATION
	subwave_started.emit(wave, subwave)


# Interval spawn = max(0,2; 0,6 × 0,9^(wave−1)) detik, dikali pengali "interval" sub-wave (bila ada)
func get_spawn_interval() -> float:
	return max(0.2, 0.6 * pow(0.9, wave - 1) * _mix.get("interval", 1.0))


# Kecepatan musuh = acak(150, 250) × (1 + 0,1 × (wave−1))
func get_enemy_speed() -> float:
	var base_speed = randf_range(150.0, 250.0)
	var multiplier = 1.0 + 0.1 * (wave - 1)
	return base_speed * multiplier


func get_mix(w, s) -> Dictionary:
	if w <= WAVES.size():
		return WAVES[w - 1][s - 1]
	return _random_mix()


# Wave 5–10: semua jenis muncul dengan bobot acak; Walker dan Swimmer tetap paling sering.
func _random_mix() -> Dictionary:
	var mix = {}
	for kind in ENEMY_SCENES:
		mix[kind] = randf_range(0.5, 1.0)
	mix["walker"] = 2.0
	mix["swimmer"] = randf_range(1.0, 1.5)
	return mix


# Memilih jenis musuh sesuai bobot di komposisi sub-wave.
func pick_kind(mix: Dictionary) -> String:
	var kinds = []
	var weights = PackedFloat32Array()
	for kind in mix:
		if ENEMY_SCENES.has(kind):
			kinds.append(kind)
			weights.append(mix[kind])
	if kinds.is_empty():
		return "walker"
	return kinds[_rng.rand_weighted(weights)]


func get_max_mobs() -> int:
	return MAX_MOBS_BASE + MAX_MOBS_PER_WAVE * (wave - 1)


# Jumlah musuh di dalam layar (ditambah tepi 50 px untuk musuh yang baru muncul).
# Slime kecil hasil pecahan Splitter ikut dihitung.
func count_mobs_on_screen() -> int:
	var area = get_viewport().get_visible_rect().grow(50)
	var count = 0
	for mob in get_tree().get_nodes_in_group(&"mobs"):
		if area.has_point(mob.position):
			count += 1
	return count


# Membuat instance musuh sesuai komposisi sub-wave yang sedang berjalan.
# Mengembalikan null kalau layar sudah penuh (giliran spawn ini dilewati).
func create_enemy() -> Mob:
	if count_mobs_on_screen() >= get_max_mobs():
		return null
	if _mix.is_empty():
		_mix = get_mix(wave, subwave)
	return ENEMY_SCENES[pick_kind(_mix)].instantiate()
