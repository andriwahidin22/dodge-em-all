class_name BackgroundBase
extends CanvasLayer
# Kelas dasar untuk semua latar belakang visual prosedural Dodge 'em All.
# Menyediakan antarmuka umum untuk event acak, transisi tema per wave,
# serta manajemen daur hidup visual (activate/deactivate) untuk performa optimal.

var is_active: bool = true
var is_round_active: bool = false
var current_wave: int = 1


func _ready() -> void:
	layer = -1


# Memulai event visual acak (saat gameplay berjalan atau pratinjau di layar Credits).
func start_events() -> void:
	is_round_active = true


# Menghentikan event visual acak.
func stop_events() -> void:
	is_round_active = false


# Menyesuaikan palet warna dan intensitas efek sesuai nomor wave.
# Tiga pita standar:
#   - Wave 1–3: Tenang (calm)
#   - Wave 4–7: Dramatis (dramatic)
#   - Wave 8–10: Bahaya (danger)
func set_wave_theme(_wave_num: int) -> void:
	pass


# Mengembalikan palet warna dan efek ke status awal / layar judul.
func reset_to_title_theme() -> void:
	current_wave = 1
	set_wave_theme(1)


# Mengaktifkan pemrosesan latar (saat tema ini dipilih dan ditampilkan).
func activate() -> void:
	is_active = true
	process_mode = Node.PROCESS_MODE_INHERIT
	show()


# Mematikan pemrosesan latar agar tidak memakan CPU saat digantikan/tidak aktif.
func deactivate() -> void:
	is_active = false
	is_round_active = false
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
