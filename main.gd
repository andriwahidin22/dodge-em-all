extends Node
# Main: menyatukan Player, WaveManager, HUD, dan SaveManager.
# Musuh dimunculkan oleh WaveManager (wave_manager.gd); Main mengurus skor, nyawa gratis,
# akhir wave (bonus, layar pilihan, simpan), game over, dan menang.

var score = 0

# Hidup lagi lewat kuis: saat nyawa habis, pemain ditawari kuis (logika / Python / JavaScript / HTML).
# Jawaban benar = lanjut main dengan REVIVE_LIVES nyawa; salah atau waktu habis = game over.
const MAX_REVIVES = 2    # jatah hidup lagi per ronde
const REVIVE_LIVES = 1   # nyawa yang didapat setelah hidup lagi
var revives_used = 0

# Item nyawa (fitur 3): muncul acak setiap 10-20 detik, hanya kalau nyawa belum penuh.
var life_pickup_scene = preload("res://life_pickup.tscn")
const LIFE_SPAWN_MIN = 10.0
const LIFE_SPAWN_MAX = 20.0
var life_timer: Timer

# Akhir wave: bonus skor 10 × nomor wave, lalu jeda singkat sebelum layar pilihan / layar menang
# supaya pesan bonus terbaca dan musuh yang tersisa sempat keluar layar.
const WAVE_BONUS_PER_WAVE = 10
const WAVE_END_DELAY = 2.0
var wave_end_timer: Timer
var _last_bonus = 0
var _won = false


func _ready():
	# Layar penuh: ukuran area permainan mengikuti layar perangkat (stretch aspect "expand"),
	# jadi jalur spawn musuh dan posisi awal pemain dihitung ulang setiap ukuran layar berubah.
	get_viewport().size_changed.connect(_update_play_area)
	_update_play_area()

	# Timer item nyawa dibuat lewat kode (sekali jalan, waktunya diacak tiap kali dimulai).
	life_timer = Timer.new()
	life_timer.one_shot = true
	add_child(life_timer)
	life_timer.timeout.connect(_on_LifeTimer_timeout)

	wave_end_timer = Timer.new()
	wave_end_timer.one_shot = true
	add_child(wave_end_timer)
	wave_end_timer.timeout.connect(_on_wave_end_timeout)

	# Tombol di HUD: panel pause, layar akhir wave, layar judul.
	$HUD.quit_to_menu.connect(quit_to_menu)
	$HUD.continue_game.connect(continue_game)
	$HUD.next_wave.connect(_on_next_wave)
	$HUD.save_and_quit.connect(_on_save_and_quit)
	$HUD.revive_passed.connect(_on_revive_passed)
	$HUD.revive_failed.connect(_game_over)

	# Sistem wave: HUD menampilkan "Wave n/10 · s/3" dan pesan tiap sub-wave.
	$WaveManager.subwave_started.connect(func(w, s): $HUD.show_subwave(w, s, $WaveManager.max_wave))
	$WaveManager.wave_started.connect(_on_wave_started)
	$WaveManager.wave_cleared.connect(_on_wave_cleared)
	$WaveManager.game_won.connect(func(): _won = true)

	# Jumlah nyawa Player ditampilkan oleh HUD.
	$Player.lives_changed.connect(func(lives): $HUD.update_lives(lives, $Player.max_lives))


func _update_play_area():
	var area = get_viewport().get_visible_rect()
	var left = area.position.x
	var right = area.end.x
	var top_edge = area.position.y
	var bottom = area.end.y

	# Jalur persegi mengelilingi layar, searah jarum jam (sama seperti jalur asli 480x720),
	# supaya arah "tegak lurus jalur" tetap mengarah ke dalam layar.
	var curve = Curve2D.new()
	curve.add_point(Vector2(left, top_edge))
	curve.add_point(Vector2(right, top_edge))
	curve.add_point(Vector2(right, bottom))
	curve.add_point(Vector2(left, bottom))
	curve.add_point(Vector2(left, top_edge))
	$MobPath.curve = curve

	# Posisi awal pemain: tengah horizontal, 62,5% dari atas (sama seperti (240, 450) di layar 480x720).
	$StartPosition.position = Vector2(left + area.size.x * 0.5, top_edge + area.size.y * 0.625)


# ---------------- Mulai ronde ----------------

# Game baru (tombol Start / Main Baru) memakai nilai bawaan.
# "Lanjutkan" dari simpanan memanggil fungsi ini dengan wave, skor, dan nyawa yang tersimpan.
func new_game(start_wave = 1, start_score = 0, start_lives = -1):
	_clear_field()
	score = start_score
	_won = false
	revives_used = 0
	$Player.start($StartPosition.position, start_lives)
	$HUD.update_score(score)
	$ScoreTimer.start()
	_restart_life_timer()
	$Music.play()
	$OceanBackground.start_round()
	$WaveManager.start_wave(start_wave)  # "Wave n" tampil 2 detik, lalu musuh mulai muncul


func _on_wave_started(wave):
	$OceanBackground.set_depth_theme(wave)


func continue_game():
	var progress = SaveManager.load_progress()
	if progress.is_empty():
		new_game()
		return
	new_game(progress.next_wave, progress.score, progress.lives)


# ---------------- Akhir wave ----------------

func _on_wave_cleared(wave):
	_last_bonus = WAVE_BONUS_PER_WAVE * wave
	score += _last_bonus
	$HUD.update_score(score)
	$HUD.show_message("+%d\nWave Bonus!" % _last_bonus, WAVE_END_DELAY)
	wave_end_timer.start(WAVE_END_DELAY)


func _on_wave_end_timeout():
	get_tree().call_group(&"mobs", &"queue_free")  # wave berikutnya mulai dari layar bersih
	if _won:
		_win()
	else:
		# Layar pilihan: Lanjut / Simpan & Keluar / Keluar. HUD mem-pause game selama tampil.
		$HUD.show_wave_end($WaveManager.wave, $WaveManager.max_wave, score, _last_bonus, $Player.lives)


func _on_next_wave():
	$WaveManager.start_wave($WaveManager.wave + 1)


func _on_save_and_quit():
	SaveManager.save_progress($WaveManager.wave + 1, score, $Player.lives)
	quit_to_menu()


# ---------------- Akhir ronde ----------------

# Dipanggil saat sinyal Player.died (nyawa habis): tawarkan kuis kalau jatah hidup lagi masih ada.
func _on_player_died():
	if revives_used < MAX_REVIVES:
		$HUD.show_revive_quiz(revives_used + 1, MAX_REVIVES)  # game di-pause oleh HUD
	else:
		_game_over()


# Kuis dijawab benar: musuh dibersihkan, Player kembali ke posisi awal dengan masa kebal.
func _on_revive_passed():
	revives_used += 1
	get_tree().call_group(&"mobs", &"queue_free")
	$Player.revive($StartPosition.position, REVIVE_LIVES)


func _game_over():
	var new_record = _end_round()
	SaveManager.clear_progress()  # simpanan dihapus supaya kekalahan tidak bisa "dibatalkan"
	$HUD.show_game_over(new_record)
	$DeathSound.play()


func _win():
	var new_record = _end_round()
	SaveManager.clear_progress()
	$Player.stop()
	$HUD.show_win($WaveManager.max_wave, score, new_record)


# Keluar ke menu (panel pause, atau Keluar / Simpan & Keluar di layar akhir wave).
# Skor tetap dihitung untuk high score. Simpanan yang sudah ada tidak diubah.
func quit_to_menu():
	_end_round()
	$OceanBackground.reset_to_shallow()
	$Player.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	$HUD.show_title()


# Menghentikan semua yang berjalan selama ronde, lalu memeriksa high score.
# Mengembalikan true kalau skor ronde ini menjadi high score baru.
func _end_round():
	$WaveManager.stop()
	$ScoreTimer.stop()
	life_timer.stop()
	wave_end_timer.stop()
	$OceanBackground.stop_round()
	get_tree().call_group(&"life_pickup", &"queue_free")
	$Music.stop()
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	return new_record


func _clear_field():
	get_tree().call_group(&"mobs", &"queue_free")
	get_tree().call_group(&"life_pickup", &"queue_free")


# ---------------- Skor dan nyawa gratis ----------------

func _on_ScoreTimer_timeout():
	score += 1
	$HUD.update_score(score)


func _restart_life_timer():
	life_timer.start(randf_range(LIFE_SPAWN_MIN, LIFE_SPAWN_MAX))


func _on_LifeTimer_timeout():
	var player = $Player
	var pickup_on_screen = not get_tree().get_nodes_in_group(&"life_pickup").is_empty()
	if player.lives > 0 and player.lives < player.max_lives and not pickup_on_screen:
		var pickup = life_pickup_scene.instantiate()
		pickup.position = _random_pickup_position()
		add_child(pickup)
	_restart_life_timer()


# Posisi acak yang aman: tidak terlalu dekat tepi layar (atas lebih lebar karena ada HUD)
# dan minimal 120 px dari pemain, supaya pemain harus bergerak untuk mengambilnya.
func _random_pickup_position():
	var area = get_viewport().get_visible_rect()
	var min_pos = area.position + Vector2(40, 100)
	var max_pos = area.end - Vector2(40, 40)
	for i in 20:
		var pos = Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))
		if pos.distance_to($Player.position) >= 120:
			return pos
	return area.get_center()
