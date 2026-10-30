extends Node
# WaveManager (W1): mengatur 10 wave × 3 sub-wave dan memunculkan musuh.
#
# Alur satu wave:
#   "Wave n" (2 dtk, tanpa musuh) → sub-wave 1 (20 dtk) → jeda "Sub-wave 2" (2 dtk)
#   → sub-wave 2 → jeda → sub-wave 3 → wave_cleared(n).
# Main mendengarkan wave_cleared untuk bonus skor dan layar akhir wave,
# lalu memanggil start_wave(n + 1) saat pemain memilih "Lanjut".
# Setelah wave terakhir (max_wave) yang dipancarkan adalah game_won.
#
# Semua Timer di sini ikut berhenti saat game di-pause (process_mode Inherit dari Main).

signal wave_started(wave)              # awal wave, sebelum musuh muncul
signal subwave_started(wave, subwave)  # awal tiap sub-wave (termasuk sub-wave 1)
signal wave_cleared(wave)              # sub-wave terakhir selesai
signal game_won                        # wave terakhir selesai

@export var max_wave = 10
@export var subwave_count = 3
@export var subwave_duration = 20.0   # detik per sub-wave
@export var intro_time = 2.0          # pesan "Wave n" sebelum sub-wave 1
@export var break_time = 2.0          # jeda "Sub-wave n" di antara sub-wave

# Rumus kesulitan (w = nomor wave, mulai 1):
#   interval spawn = base_interval × interval_factor^(w-1)
#   kecepatan      = [speed_min, speed_max] × (1 + speed_step × (w-1))
#   batas musuh    = max_mobs_base + max_mobs_per_wave × (w-1)   (musuh di layar sekaligus)
# Wave 1: tiap 1,0 dtk, 150–250, maks 5 · wave 5: ±0,69 dtk, 180–300, maks 9
# wave 10: ±0,43 dtk, 218–363, maks 14. Hasil simulasi: rata-rata ±3 musuh di layar di wave 1,
# ±4 di wave 3, ±6 di wave 10. Semua angka bisa diubah di Inspector untuk balancing.
@export var base_interval = 1.0
@export var interval_factor = 0.91
@export var speed_min = 150.0
@export var speed_max = 250.0
@export var speed_step = 0.05
@export var max_mobs_base = 5
@export var max_mobs_per_wave = 1

@export var spawn_location: PathFollow2D  # titik acak di MobPath (mengelilingi layar)

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

var wave = 0
var subwave = 0
var running = false   # true selama wave berjalan (termasuk pesan awal dan jeda)
var spawning = false  # true hanya saat sub-wave aktif (musuh sedang dimunculkan)

var _mix = {}         # komposisi sub-wave yang sedang berjalan
var _rng = RandomNumberGenerator.new()
var _phase_timer: Timer   # pesan awal, durasi sub-wave, dan jeda
var _spawn_timer: Timer


func _ready():
	_rng.randomize()
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timeout)
	_spawn_timer = Timer.new()
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(spawn_mob)


# Memulai wave `w` dari awal (dipakai game baru, "Lanjut", dan "Lanjutkan" dari simpanan).
func start_wave(w):
	wave = clampi(w, 1, max_wave)
	subwave = 0
	running = true
	spawning = false
	_spawn_timer.stop()
	wave_started.emit(wave)
	_begin_subwave(intro_time)


# Menghentikan semua timer (game over, keluar ke menu).
func stop():
	running = false
	spawning = false
	_phase_timer.stop()
	_spawn_timer.stop()


# Sub-wave berikutnya diumumkan dulu (`delay` detik tanpa musuh baru), baru musuh muncul.
func _begin_subwave(delay):
	subwave += 1
	spawning = false
	_spawn_timer.stop()
	_mix = get_mix(wave, subwave)
	subwave_started.emit(wave, subwave)
	_phase_timer.start(delay)


func _on_phase_timeout():
	if not spawning:
		# Pesan awal / jeda selesai: sub-wave mulai.
		spawning = true
		_spawn_timer.start(get_spawn_interval(wave, _mix))
		_phase_timer.start(subwave_duration)
	elif subwave < subwave_count:
		_begin_subwave(break_time)
	else:
		_finish_wave()


func _finish_wave():
	stop()
	wave_cleared.emit(wave)
	if wave >= max_wave:
		game_won.emit()


# Mode debug (W3): F2 langsung menyelesaikan wave yang sedang berjalan.
# Hanya aktif di build debug (dijalankan dari editor atau APK debug), tidak di APK release.
func _unhandled_input(event):
	if not OS.is_debug_build() or not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		_finish_wave()


# ---------------- Data dan rumus ----------------

func get_mix(w, s):
	if w <= WAVES.size():
		return WAVES[w - 1][s - 1]
	return _random_mix()


# Wave 5–10: semua jenis muncul dengan bobot acak; Walker dan Swimmer tetap paling sering.
func _random_mix():
	var mix = {}
	for kind in ENEMY_SCENES:
		mix[kind] = _rng.randf_range(0.5, 1.0)
	mix["walker"] = 2.0
	mix["swimmer"] = _rng.randf_range(1.0, 1.5)
	return mix


func get_spawn_interval(w, mix = {}):
	return base_interval * pow(interval_factor, w - 1) * mix.get("interval", 1.0)


# Jumlah musuh di dalam layar (ditambah tepi 50 px untuk musuh yang baru muncul).
func count_mobs_on_screen():
	var area = get_viewport().get_visible_rect().grow(50)
	var count = 0
	for mob in get_tree().get_nodes_in_group(&"mobs"):
		if area.has_point(mob.position):
			count += 1
	return count


func get_max_mobs(w):
	return max_mobs_base + max_mobs_per_wave * (w - 1)


func get_speed_range(w):
	var factor = 1.0 + speed_step * (w - 1)
	return Vector2(speed_min * factor, speed_max * factor)


# Memilih jenis musuh sesuai bobot di komposisi.
func pick_kind(mix):
	var kinds = []
	var weights = PackedFloat32Array()
	for kind in mix:
		if ENEMY_SCENES.has(kind):
			kinds.append(kind)
			weights.append(mix[kind])
	return kinds[_rng.rand_weighted(weights)]


# ---------------- Spawn ----------------
# Sama seperti _on_MobTimer_timeout() lama di main.gd: titik acak di MobPath,
# arah tegak lurus jalur ±45°, kecepatan acak sesuai wave.

func spawn_mob():
	# Layar sudah cukup padat: lewati giliran ini (slime kecil hasil pecahan ikut dihitung).
	if count_mobs_on_screen() >= get_max_mobs(wave):
		return null
	var kind = pick_kind(_mix)
	var mob = ENEMY_SCENES[kind].instantiate()

	spawn_location.progress_ratio = _rng.randf()
	mob.position = spawn_location.position

	var direction = spawn_location.rotation + PI / 2
	direction += _rng.randf_range(-PI / 4, PI / 4)

	var speed = get_speed_range(wave)
	mob.linear_velocity = Vector2(_rng.randf_range(speed.x, speed.y), 0.0).rotated(direction)

	get_parent().add_child(mob)
	return mob
