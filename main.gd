extends Node

const WaveAudio = preload("res://wave_audio.gd")

@export var mob_scene: PackedScene
var score
var _wave_audio

# Status jatah kuis hidup-lagi (hanya 1x per wave)
var revive_used_this_wave = false
var _is_processing_hit = false

# Item nyawa (fitur 3): muncul acak setiap 10-20 detik, hanya kalau nyawa belum penuh.
var life_pickup_scene = preload("res://life_pickup.tscn")
const LIFE_SPAWN_MIN = 10.0
const LIFE_SPAWN_MAX = 20.0
const REVIVE_LIVES = 1  # jumlah nyawa setelah lolos kuis hidup-lagi
var life_timer: Timer

# Akhir wave: bonus skor 10 × nomor wave, lalu layar pilihan Lanjut / Simpan & Keluar / Keluar.
const WAVE_BONUS_PER_WAVE = 10
var _last_bonus = 0
var _start_wave = 1  # wave pertama ronde ini (1, atau wave dari simpanan saat "Lanjutkan")


func _ready():
	# Layar penuh: ukuran area permainan mengikuti layar perangkat (stretch aspect "expand"),
	# jadi jalur spawn musuh dan posisi awal pemain dihitung ulang setiap ukuran layar berubah.
	get_viewport().size_changed.connect(_update_play_area)
	_update_play_area()
	$WaveManager.wave_started.connect(_on_wave_started)
	$WaveManager.subwave_started.connect(_on_subwave_started)
	$WaveManager.subwave_ended.connect(_on_subwave_ended)
	$WaveManager.wave_cleared.connect(_on_wave_cleared)
	$WaveManager.wave_break.connect(_on_wave_break)
	$WaveManager.game_won.connect(_on_game_won)
	$HUD.revive_passed.connect(_on_revive_passed)
	$HUD.revive_failed.connect(_on_revive_failed)
	$HUD.game_resumed.connect(_on_hud_game_resumed)
	$HUD.quit_to_menu.connect(_on_hud_quit_to_menu)
	$HUD.continue_game.connect(continue_game)
	$HUD.next_wave.connect(_on_next_wave)
	$HUD.save_and_quit.connect(_on_save_and_quit)
	$HUD.credits_opened.connect(_on_credits_opened)
	$HUD.credits_closed.connect(_on_credits_closed)
	$HUD.theme_selected.connect(_on_theme_selected)
	$HUD.volume_changed.connect(func(bus_name, val): $BackgroundManager.set_volume(bus_name, val))

	# Inisialisasi pengatur audio adaptif wave
	_wave_audio = WaveAudio.new()
	_wave_audio.name = "WaveAudio"
	add_child(_wave_audio)
	_wave_audio.setup($Music)

	# Terapkan musik tema yang tersimpan (untuk tema Angkasa = sound bawaan)
	_apply_theme_music($BackgroundManager.get_theme_id())

	# Timer item nyawa dibuat lewat kode (sekali jalan, waktunya diacak tiap kali dimulai).
	life_timer = Timer.new()
	life_timer.one_shot = true
	add_child(life_timer)
	life_timer.timeout.connect(_on_LifeTimer_timeout)

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


# Nyawa terakhir habis (sinyal `died` dari Player). Selama nyawa masih ada,
# Player sendiri yang mengurangi nyawa dan memberi masa kebal.
func _on_player_died():
	if _is_processing_hit:
		return
	_is_processing_hit = true

	# Bila jatah hidup-lagi wave ini belum dipakai, buka modal kuis
	if not revive_used_this_wave:
		$HUD.show_revive_quiz($WaveManager.wave)
	else:
		# Jika jatah sudah terpakai di wave yang sama, hentikan timer dan game over
		$MobTimer.stop()
		$ScoreTimer.stop()
		$HUD.show_message("Kesempatan wave ini\nsudah dipakai!")
		await get_tree().create_timer(1.2).timeout
		game_over()


func _on_revive_passed():
	_is_processing_hit = false
	revive_used_this_wave = true
	$HUD.update_revive_indicator(false)
	get_tree().call_group(&"mobs", &"queue_free")
	$Player.revive($StartPosition.position, REVIVE_LIVES)
	get_tree().paused = false


func _on_revive_failed():
	_is_processing_hit = false
	get_tree().paused = false
	game_over()


func game_over():
	_is_processing_hit = false
	$BackgroundManager.stop_events()
	$BackgroundManager.reset_to_title_theme()
	$BackgroundManager.stop_ambience()
	$WaveManager.stop()
	$ScoreTimer.stop()
	$MobTimer.stop()
	_stop_life_pickups()
	$HUD.update_revive_indicator(false)
	_wave_audio.stop()
	SaveManager.clear_progress()  # simpanan dihapus supaya kekalahan tidak bisa "dibatalkan"
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	$HUD.show_game_over(new_record)
	$Music.stop()
	$DeathSound.play()


# Game baru (Start / Main Baru) memakai nilai bawaan.
# "Lanjutkan" dari simpanan memanggil fungsi ini dengan wave, skor, dan nyawa yang tersimpan.
func new_game(start_wave = 1, start_score = 0, start_lives = -1):
	_is_processing_hit = false
	_start_wave = start_wave
	_apply_theme_music($BackgroundManager.get_theme_id())
	$BackgroundManager.start_events()
	$BackgroundManager.set_wave_theme(start_wave)
	$BackgroundManager.play_ambience()
	$WaveManager.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	_stop_life_pickups()
	score = start_score
	$Player.start($StartPosition.position, start_lives)
	_restart_life_timer()
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	_wave_audio.stop()
	$Music.play()


func _on_theme_selected(theme_id: String) -> void:
	$BackgroundManager.set_theme(theme_id, true)
	_apply_theme_music(theme_id)
	if $HUD/CreditsPanel.visible:
		$Music.stop()
		$Music.pitch_scale = 1.0
		$Music.play()


func _apply_theme_music(theme_id: String) -> void:
	var stream = $BackgroundManager.get_theme_music_stream(theme_id)
	if stream:
		$Music.stream = stream
		if is_instance_valid(_wave_audio):
			_wave_audio.set_default_music_stream(stream)


func _on_credits_opened() -> void:
	$BackgroundManager.start_credits_preview()
	$Music.pitch_scale = 1.0
	$Music.play()


func _on_credits_closed() -> void:
	$BackgroundManager.stop_credits_preview()
	$Music.stop()


func continue_game():
	var progress = SaveManager.load_progress()
	if progress.is_empty():
		new_game()
		return
	new_game(progress.next_wave, progress.score, progress.lives)


func _on_wave_started(wave):
	# Reset jatah kuis sekali per wave hanya di titik ini
	revive_used_this_wave = false
	$HUD.update_revive_indicator(true)
	$BackgroundManager.set_wave_theme(wave)
	$HUD.update_wave(wave, $WaveManager.max_wave)
	$HUD.show_message("Wave %d" % wave)
	_wave_audio.on_wave_started(wave)


func _on_subwave_started(wave, subwave):
	_wave_audio.on_subwave_started(wave, subwave)
	$MobTimer.wait_time = $WaveManager.get_spawn_interval()
	$MobTimer.start()
	$ScoreTimer.start()


func _on_subwave_ended(_wave, _subwave):
	$MobTimer.stop()


func _on_wave_cleared(wave):
	$MobTimer.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	_last_bonus = WAVE_BONUS_PER_WAVE * wave
	score += _last_bonus
	$HUD.update_score(score)
	$HUD.show_message("Wave %d Selesai!\n+%d" % [wave, _last_bonus])
	_wave_audio.on_wave_cleared(wave)


# Jeda akhir wave selesai (bukan wave terakhir): tampilkan layar pilihan.
# HUD mem-pause game selama layar ini tampil.
func _on_wave_break(wave):
	get_tree().call_group(&"mobs", &"queue_free")  # wave berikutnya mulai dari layar bersih
	get_tree().call_group(&"life_pickup", &"queue_free")
	$HUD.show_wave_end(wave, $WaveManager.max_wave, score, _last_bonus, $Player.lives)


func _on_next_wave():
	$WaveManager.continue_next_wave()


# Simpan wave berikutnya, skor, dan nyawa, lalu kembali ke layar judul.
func _on_save_and_quit():
	SaveManager.save_progress($WaveManager.wave + 1, score, $Player.lives)
	_on_hud_quit_to_menu()


func _on_game_won():
	$BackgroundManager.stop_events()
	$BackgroundManager.reset_to_title_theme()
	$BackgroundManager.stop_ambience()
	$WaveManager.stop()
	$MobTimer.stop()
	$ScoreTimer.stop()
	_stop_life_pickups()
	$HUD.update_revive_indicator(false)
	_wave_audio.on_game_won()
	get_tree().call_group(&"mobs", &"queue_free")
	SaveManager.clear_progress()
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	$HUD.show_message("Kamu Menang!")
	await get_tree().create_timer(3.0).timeout
	$HUD.show_game_over(new_record)
	$Music.stop()


func _on_MobTimer_timeout():
	# Membuat musuh sesuai variasi wave (Walker atau Swimmer)
	var mob = $WaveManager.create_enemy()
	if mob == null:
		return  # layar sudah penuh, lewati giliran spawn ini

	# Pilih titik acak di Path2D
	var mob_spawn_location = get_node(^"MobPath/MobSpawnLocation")
	mob_spawn_location.progress_ratio = randf()

	# Atur posisi musuh
	mob.position = mob_spawn_location.position

	# Atur arah musuh tegak lurus jalur dengan variasi ±45 derajat
	var direction = mob_spawn_location.rotation + PI / 2
	direction += randf_range(-PI / 4, PI / 4)

	# Tentukan kecepatan musuh berdasarkan wave
	var speed = $WaveManager.get_enemy_speed()
	var velocity = Vector2(speed, 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Munculkan musuh ke scene
	add_child(mob)


func _on_ScoreTimer_timeout():
	score += 1
	$HUD.update_score(score)


func _on_StartTimer_timeout():
	$WaveManager.start_waves(_start_wave)


func _on_hud_game_resumed():
	$Player.reset_touch()


func _on_hud_quit_to_menu():
	_is_processing_hit = false
	$BackgroundManager.stop_events()
	$BackgroundManager.reset_to_title_theme()
	$BackgroundManager.stop_ambience()
	$WaveManager.stop()
	$ScoreTimer.stop()
	$MobTimer.stop()
	$StartTimer.stop()
	_stop_life_pickups()
	$HUD.update_revive_indicator(false)
	$Music.stop()
	_wave_audio.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	$Player.hide()
	$Player.reset_touch()
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	$HUD.show_title()


# ---------------- Item nyawa ----------------

func _restart_life_timer():
	life_timer.start(randf_range(LIFE_SPAWN_MIN, LIFE_SPAWN_MAX))


# Menghentikan timer item nyawa dan menghapus item yang masih ada di layar.
func _stop_life_pickups():
	life_timer.stop()
	get_tree().call_group(&"life_pickup", &"queue_free")


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
	var min_pos = area.position + Vector2(40, 120)
	var max_pos = area.end - Vector2(40, 40)
	for i in 20:
		var pos = Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))
		if pos.distance_to($Player.position) >= 120:
			return pos
	return area.get_center()
