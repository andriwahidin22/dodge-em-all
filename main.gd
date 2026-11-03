extends Node

const WaveAudio = preload("res://wave_audio.gd")

@export var mob_scene: PackedScene
var score
var _wave_audio

# Status jatah kuis hidup-lagi (hanya 1x per wave)
var revive_used_this_wave = false
var _is_processing_hit = false


func _ready():
	# Layar penuh: ukuran area permainan mengikuti layar perangkat (stretch aspect "expand"),
	# jadi jalur spawn musuh dan posisi awal pemain dihitung ulang setiap ukuran layar berubah.
	get_viewport().size_changed.connect(_update_play_area)
	_update_play_area()
	$WaveManager.wave_started.connect(_on_wave_started)
	$WaveManager.subwave_started.connect(_on_subwave_started)
	$WaveManager.subwave_ended.connect(_on_subwave_ended)
	$WaveManager.wave_cleared.connect(_on_wave_cleared)
	$WaveManager.game_won.connect(_on_game_won)
	$HUD.revive_passed.connect(_on_revive_passed)
	$HUD.revive_failed.connect(_on_revive_failed)
	$HUD.game_resumed.connect(_on_hud_game_resumed)
	$HUD.quit_to_menu.connect(_on_hud_quit_to_menu)

	# Inisialisasi pengatur audio adaptif wave
	_wave_audio = WaveAudio.new()
	_wave_audio.name = "WaveAudio"
	add_child(_wave_audio)
	_wave_audio.setup($Music)


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


func _on_player_hit():
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
	$Player.revive($StartPosition.position)
	get_tree().paused = false


func _on_revive_failed():
	_is_processing_hit = false
	get_tree().paused = false
	game_over()


func game_over():
	_is_processing_hit = false
	$SpaceBackground.stop_events()
	$SpaceBackground.reset_to_title_theme()
	$WaveManager.stop()
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.update_revive_indicator(false)
	_wave_audio.stop()
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	$HUD.show_game_over(new_record)
	$Music.stop()
	$DeathSound.play()


func new_game():
	_is_processing_hit = false
	$SpaceBackground.start_events()
	$SpaceBackground.set_wave_theme(1)
	$WaveManager.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	_wave_audio.stop()
	$Music.play()


func _on_wave_started(wave):
	# Reset jatah kuis sekali per wave hanya di titik ini
	revive_used_this_wave = false
	$HUD.update_revive_indicator(true)
	$SpaceBackground.set_wave_theme(wave)
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
	var bonus = 10 * wave
	score += bonus
	$HUD.update_score(score)
	$HUD.show_message("Wave %d Selesai!\n+%d" % [wave, bonus])
	_wave_audio.on_wave_cleared(wave)


func _on_game_won():
	$SpaceBackground.stop_events()
	$SpaceBackground.reset_to_title_theme()
	$WaveManager.stop()
	$MobTimer.stop()
	$ScoreTimer.stop()
	$HUD.update_revive_indicator(false)
	_wave_audio.on_game_won()
	get_tree().call_group(&"mobs", &"queue_free")
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
	$WaveManager.start_waves()


func _on_hud_game_resumed():
	$Player.reset_touch()


func _on_hud_quit_to_menu():
	_is_processing_hit = false
	$SpaceBackground.stop_events()
	$SpaceBackground.reset_to_title_theme()
	$WaveManager.stop()
	$ScoreTimer.stop()
	$MobTimer.stop()
	$StartTimer.stop()
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
