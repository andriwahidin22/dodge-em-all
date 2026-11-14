extends CanvasLayer

const SpaceTheme = preload("res://space_theme.gd")
const QuizPanel = preload("res://quiz_panel.gd")

signal start_game      # Start / Main Baru -> Main.new_game()
signal continue_game   # Lanjutkan dari simpanan -> Main.continue_game()
signal revive_passed
signal revive_failed
signal game_resumed
signal quit_to_menu    # "Keluar ke menu" (pause) atau "Keluar" (akhir wave)
signal next_wave       # "Lanjut" di layar akhir wave
signal save_and_quit   # "Simpan & Keluar" di layar akhir wave
signal credits_opened
signal credits_closed
signal theme_selected(theme_id)
signal volume_changed(bus_name, value)

const TITLE_TEXT = "Dodge 'em\nAll"

# Elemen UI yang dibuat via kode
var wave_label: Label
var revive_star: TextureRect
var quiz_panel: QuizPanel
var lives_box: HBoxContainer

# Ikon nyawa (fitur 3): pixel-art 60x60 buatan tools/generate_hearts.py.
const HEART_FULL = preload("res://art/hearts/heart_full.png")
const HEART_EMPTY = preload("res://art/hearts/heart_empty.png")
const HEART_SIZE = 32

var playing = false
var _message_was_visible = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$MessageTimer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_wave_label()
	_setup_revive_indicator()
	_setup_lives_box()
	_apply_space_theme()
	_setup_quiz_panel()
	$CreditsPanel.theme_changed_requested.connect(func(theme_id): theme_selected.emit(theme_id))
	$CreditsPanel.volume_changed_requested.connect(func(bus_name, val): volume_changed.emit(bus_name, val))
	# Saat game dibuka, tampilkan high score yang tersimpan di layar judul.
	update_high_score(SaveManager.highest_score)
	$PauseButton.hide()
	$PausePanel.hide()
	$CreditsPanel.hide()
	$WaveEndPanel.hide()
	$ConfirmPanel.hide()
	_show_title_buttons()


func _setup_wave_label():
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.offset_left = 20.0
	wave_label.offset_top = 20.0
	wave_label.offset_right = 200.0
	wave_label.offset_bottom = 60.0
	wave_label.add_theme_font_override("font", preload("res://fonts/Xolonium-Regular.ttf"))
	wave_label.add_theme_font_size_override("font_size", 24)
	wave_label.hide()
	add_child(wave_label)


func _setup_revive_indicator():
	revive_star = TextureRect.new()
	revive_star.name = "ReviveIndicator"
	revive_star.texture = preload("res://art/ui/star.png")
	revive_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	revive_star.custom_minimum_size = Vector2(28, 28)
	revive_star.size = Vector2(28, 28)
	revive_star.offset_left = 185.0
	revive_star.offset_top = 22.0
	revive_star.modulate = SpaceTheme.COLOR_GOLD
	revive_star.hide()
	add_child(revive_star)


# Deretan hati di bawah label wave (kiri atas).
func _setup_lives_box():
	lives_box = HBoxContainer.new()
	lives_box.name = "LivesBox"
	lives_box.offset_left = 20.0
	lives_box.offset_top = 62.0
	lives_box.add_theme_constant_override("separation", 6)
	lives_box.hide()
	add_child(lives_box)


# Menampilkan hati penuh sebanyak `lives` dan hati kosong untuk sisanya.
func update_lives(lives, max_lives):
	while lives_box.get_child_count() < max_lives:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art tetap tajam
		lives_box.add_child(icon)
	for i in lives_box.get_child_count():
		lives_box.get_child(i).texture = HEART_FULL if i < lives else HEART_EMPTY


func _setup_quiz_panel():
	quiz_panel = QuizPanel.new()
	quiz_panel.name = "QuizPanel"
	quiz_panel.quiz_passed.connect(func(): revive_passed.emit())
	quiz_panel.quiz_failed.connect(func(): revive_failed.emit())
	add_child(quiz_panel)


func _apply_space_theme():
	# Styling ScoreLabel
	$ScoreLabel.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)
	$ScoreLabel.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$ScoreLabel.add_theme_constant_override("outline_size", 4)
	$ScoreLabel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	$ScoreLabel.add_theme_constant_override("shadow_offset_y", 3)

	# Styling MessageLabel (Emas ber-outline untuk judul / sorotan)
	$MessageLabel.add_theme_color_override("font_color", SpaceTheme.COLOR_GOLD)
	$MessageLabel.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$MessageLabel.add_theme_constant_override("outline_size", 6)
	$MessageLabel.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.0, 0.5))
	$MessageLabel.add_theme_constant_override("shadow_offset_y", 4)

	# Styling HighScoreLabel
	$HighScoreLabel.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_MUTED)
	$HighScoreLabel.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$HighScoreLabel.add_theme_constant_override("outline_size", 2)

	# Styling WaveLabel
	if wave_label:
		wave_label.add_theme_color_override("font_color", SpaceTheme.COLOR_ACCENT_CYAN)
		wave_label.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
		wave_label.add_theme_constant_override("outline_size", 3)

	# Styling StartButton (bergaya luar angkasa: gelap semi-transparan + border cyan neon)
	var btn_normal = SpaceTheme.create_button_style(Color(0.08, 0.12, 0.22, 0.85), SpaceTheme.COLOR_ACCENT_CYAN, 14, 2)
	var btn_hover = SpaceTheme.create_button_style(Color(0.12, 0.20, 0.35, 0.95), SpaceTheme.COLOR_ACCENT_CYAN, 14, 2)
	var btn_pressed = SpaceTheme.create_button_style(Color(0.05, 0.35, 0.45, 0.98), SpaceTheme.COLOR_ACCENT_CYAN, 14, 3)

	# Tombol layar judul, akhir wave, dan konfirmasi memakai gaya yang sama dengan Start.
	for btn in [$StartButton, $TitleMenu/ContinueButton, $TitleMenu/NewGameButton,
			$WaveEndPanel/Menu/NextWaveButton, $WaveEndPanel/Menu/SaveQuitButton,
			$WaveEndPanel/Menu/WaveQuitButton, $ConfirmPanel/Menu/ConfirmYesButton,
			$ConfirmPanel/Menu/ConfirmCancelButton]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_stylebox_override("focus", btn_hover)
		btn.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", SpaceTheme.COLOR_GOLD)
		btn.add_theme_color_override("font_pressed_color", SpaceTheme.COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
		btn.add_theme_constant_override("outline_size", 3)

	# Judul panel akhir wave dan konfirmasi: emas seperti judul game.
	for label in [$WaveEndPanel/Menu/WaveEndTitle, $ConfirmPanel/Menu/ConfirmLabel]:
		label.add_theme_color_override("font_color", SpaceTheme.COLOR_GOLD)
		label.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
		label.add_theme_constant_override("outline_size", 4)
	$WaveEndPanel/Menu/SummaryLabel.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)


func show_revive_quiz(wave_number: int):
	get_tree().paused = true
	quiz_panel.show_quiz(wave_number)


func update_revive_indicator(available: bool):
	if is_instance_valid(revive_star):
		if available:
			revive_star.modulate = SpaceTheme.COLOR_GOLD
		else:
			revive_star.modulate = Color(0.35, 0.38, 0.45, 0.5)


func update_wave(current_wave, max_wave = 10):
	if current_wave > 0:
		wave_label.text = "Wave %d/%d" % [current_wave, max_wave]
		wave_label.show()
		if is_instance_valid(revive_star):
			revive_star.show()
	else:
		wave_label.hide()
		if is_instance_valid(revive_star):
			revive_star.hide()


func show_message(text, duration = 1.0):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start(duration)


func show_game_over(new_record = false):
	update_wave(0)
	lives_box.hide()
	playing = false
	$PauseButton.hide()
	$PausePanel.hide()
	show_message("High Score\nBaru!" if new_record else "Game Over")
	await $MessageTimer.timeout
	show_title()


func show_title():
	playing = false
	update_wave(0)
	lives_box.hide()
	$PauseButton.hide()
	$PausePanel.hide()
	$CreditsPanel.hide()
	$WaveEndPanel.hide()
	$ConfirmPanel.hide()
	$MessageTimer.stop()
	$MessageLabel.text = TITLE_TEXT
	$MessageLabel.show()
	$HighScoreLabel.show()  # tampil lagi di layar judul
	$CreditsButton.hide()
	await get_tree().create_timer(1, false).timeout
	if not playing:
		_show_title_buttons()


# Tombol layar judul tergantung ada atau tidaknya simpanan progress:
# tanpa simpanan = Start, dengan simpanan = Lanjutkan + Main Baru.
func _show_title_buttons():
	var progress = SaveManager.load_progress()
	$CreditsButton.show()
	if progress.is_empty():
		$TitleMenu.hide()
		$StartButton.show()
	else:
		$StartButton.hide()
		$TitleMenu/ContinueButton.text = "Lanjutkan\nWave %d · Skor %d" % [progress.next_wave, progress.score]
		$TitleMenu.show()


func update_score(score):
	$ScoreLabel.text = str(score)


func update_high_score(value):
	$HighScoreLabel.text = "Best: %d" % value


# Semua tombol yang memulai ronde (Start, Lanjutkan, Ya mulai baru) lewat sini.
func _begin_round():
	$StartButton.hide()
	$CreditsButton.hide()
	$TitleMenu.hide()
	$ConfirmPanel.hide()
	$HighScoreLabel.hide()  # sembunyikan selama bermain supaya layar bersih
	$PauseButton.show()
	lives_box.show()
	playing = true


func _on_StartButton_pressed():
	_begin_round()
	start_game.emit()


func _on_ContinueButton_pressed():
	_begin_round()
	continue_game.emit()


# "Main Baru" saat ada simpanan: minta konfirmasi dulu, simpanan baru dihapus kalau pemain memilih Ya.
func _on_NewGameButton_pressed():
	var progress = SaveManager.load_progress()
	$ConfirmPanel/Menu/ConfirmLabel.text = "Mulai baru?\nProgress Wave %d akan dihapus." % progress.get("next_wave", 1)
	$TitleMenu.hide()
	$CreditsButton.hide()
	$MessageLabel.hide()  # judul disembunyikan supaya tidak bertumpuk dengan teks konfirmasi
	$ConfirmPanel.show()


func _on_ConfirmYesButton_pressed():
	SaveManager.clear_progress()
	_begin_round()
	start_game.emit()


func _on_ConfirmCancelButton_pressed():
	$ConfirmPanel.hide()
	$MessageLabel.show()
	_show_title_buttons()


func _on_CreditsButton_pressed():
	$StartButton.hide()
	$TitleMenu.hide()
	$CreditsButton.hide()
	$HighScoreLabel.hide()
	$MessageLabel.hide()
	credits_opened.emit()
	$CreditsPanel.play()


func _on_credits_finished():
	credits_closed.emit()
	if not playing:
		$MessageLabel.show()
		$HighScoreLabel.show()
		_show_title_buttons()


func _on_MessageTimer_timeout():
	$MessageLabel.hide()


# ---------------- Layar akhir wave ----------------
# Game di-pause selama layar ini tampil; ketiga tombol melepas pause lalu memberi tahu Main.

func show_wave_end(wave, max_wave, score, bonus, lives):
	get_tree().paused = true
	$PauseButton.hide()
	$PausePanel.hide()
	$MessageLabel.hide()
	$WaveEndPanel/Menu/WaveEndTitle.text = "Wave %d selesai!" % wave
	$WaveEndPanel/Menu/SummaryLabel.text = "Skor: %d\nBonus wave: +%d\nNyawa: %d" % [score, bonus, lives]
	$WaveEndPanel/Menu/NextWaveButton.text = "Lanjut ke Wave %d" % mini(wave + 1, max_wave)
	$WaveEndPanel.show()


func _close_wave_end():
	get_tree().paused = false
	$WaveEndPanel.hide()


func _on_NextWaveButton_pressed():
	_close_wave_end()
	$PauseButton.show()
	next_wave.emit()


func _on_SaveQuitButton_pressed():
	_close_wave_end()
	playing = false
	save_and_quit.emit()  # Main menyimpan lalu kembali ke layar judul


func _on_WaveQuitButton_pressed():
	_close_wave_end()
	playing = false
	quit_to_menu.emit()


# ---------------- Pause ----------------
func pause_game():
	if not playing or get_tree().paused or $CreditsPanel.visible:
		return
	get_tree().paused = true
	_message_was_visible = $MessageLabel.visible
	$MessageLabel.hide()
	$PauseButton.hide()
	$PausePanel.show()


func resume_game():
	if not $PausePanel.visible:
		return
	get_tree().paused = false
	$PausePanel.hide()
	if playing:
		$PauseButton.show()
		$MessageLabel.visible = _message_was_visible
	game_resumed.emit()


func _toggle_pause():
	if $PausePanel.visible:
		resume_game()
	else:
		pause_game()


func _on_pause_button_pressed():
	pause_game()


func _on_resume_button_pressed():
	resume_game()


func _on_quit_button_pressed():
	get_tree().paused = false
	$PausePanel.hide()
	playing = false
	quit_to_menu.emit()


func _unhandled_input(event):
	# Esc (keyboard) atau tombol Start (gamepad): pause / lanjut / tutup credit.
	if event.is_action_pressed(&"pause"):
		if $CreditsPanel.visible:
			$CreditsPanel.skip()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Tombol Back Android:
		if $CreditsPanel.visible:
			$CreditsPanel.skip()
		elif get_tree().paused:
			resume_game()
		elif playing:
			pause_game()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Pause otomatis saat aplikasi kehilangan fokus.
		pause_game()
