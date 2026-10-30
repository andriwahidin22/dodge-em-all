extends Node
# Autoload SaveManager: menyimpan dan memuat data permanen game di user://save.cfg.
#
# Isi file:
#   [scores]   high_score
#   [progress] next_wave, score, lives, saved_at   (hanya ada kalau pemain menyimpan, W5)

const SAVE_PATH = "user://save.cfg"

var highest_score = 0


func _ready() -> void:
	load_high_score()


func load_high_score():
	var config = ConfigFile.new()
	# Kalau file belum ada (game pertama kali dibuka), nilai tetap 0.
	if config.load(SAVE_PATH) != OK:
		return
	highest_score = config.get_value("scores", "high_score", 0)


func save_high_score(value):
	highest_score = value
	var config = _load_config()
	config.set_value("scores", "high_score", value)
	config.save(SAVE_PATH)


# ---------------- Simpan progress (W5) ----------------
# Hanya ada satu slot. Disimpan di akhir wave, dihapus saat game over, menang,
# atau pemain mengonfirmasi "Main Baru".

# `next_wave`: wave yang dimainkan saat dilanjutkan.
func save_progress(next_wave, score, lives):
	var config = _load_config()
	config.set_value("progress", "next_wave", next_wave)
	config.set_value("progress", "score", score)
	config.set_value("progress", "lives", lives)
	# Contoh: "2026-11-02T20:15" (detik dibuang).
	config.set_value("progress", "saved_at", Time.get_datetime_string_from_system().left(16))
	config.save(SAVE_PATH)


func has_progress():
	return _load_config().has_section("progress")


# Mengembalikan {"next_wave", "score", "lives", "saved_at"}, atau {} kalau tidak ada simpanan.
func load_progress() -> Dictionary:
	var config = _load_config()
	if not config.has_section("progress"):
		return {}
	return {
		"next_wave": config.get_value("progress", "next_wave", 1),
		"score": config.get_value("progress", "score", 0),
		"lives": config.get_value("progress", "lives", 3),
		"saved_at": config.get_value("progress", "saved_at", ""),
	}


func clear_progress():
	var config = _load_config()
	if config.has_section("progress"):
		config.erase_section("progress")
		config.save(SAVE_PATH)


# Memuat isi file yang sudah ada supaya bagian lain (misalnya high score dan progress)
# tidak ikut terhapus saat satu nilai disimpan. Kalau file belum ada, config kosong.
func _load_config() -> ConfigFile:
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	return config
