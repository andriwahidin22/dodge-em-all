extends CanvasLayer

const SpaceTheme = preload("res://space_theme.gd")
const QuizPanel = preload("res://quiz_panel.gd")

signal start_game
signal revive_passed
signal revive_failed
signal game_resumed
signal quit_to_menu

const TITLE_TEXT = "Dodge 'em\nAll"

# Elemen UI yang dibuat via kode
var wave_label: Label
var revive_star: TextureRect
var quiz_panel: QuizPanel

var playing = false
var _message_was_visible = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$MessageTimer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_wave_label()
	_setup_revive_indicator()
	_apply_space_theme()
	_setup_quiz_panel()
	# Saat game dibuka, tampilkan high score yang tersimpan di layar judul.
	update_high_score(SaveManager.highest_score)
	$PauseButton.hide()
	$PausePanel.hide()
	$CreditsPanel.hide()
	$CreditsButton.show()


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

	$StartButton.add_theme_stylebox_override("normal", btn_normal)
	$StartButton.add_theme_stylebox_override("hover", btn_hover)
	$StartButton.add_theme_stylebox_override("pressed", btn_pressed)
	$StartButton.add_theme_stylebox_override("focus", btn_hover)
	$StartButton.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)
	$StartButton.add_theme_color_override("font_hover_color", SpaceTheme.COLOR_GOLD)
	$StartButton.add_theme_color_override("font_pressed_color", SpaceTheme.COLOR_TEXT_PRIMARY)
	$StartButton.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$StartButton.add_theme_constant_override("outline_size", 3)


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
	playing = false
	$PauseButton.hide()
	$PausePanel.hide()
	show_message("High Score\nBaru!" if new_record else "Game Over")
	await $MessageTimer.timeout
	show_title()


func show_title():
	playing = false
	update_wave(0)
	$PauseButton.hide()
	$PausePanel.hide()
	$CreditsPanel.hide()
	$MessageTimer.stop()
	$MessageLabel.text = TITLE_TEXT
	$MessageLabel.show()
	$HighScoreLabel.show()  # tampil lagi di layar judul
	$CreditsButton.hide()
	await get_tree().create_timer(1, false).timeout
	if not playing:
		$StartButton.show()
		$CreditsButton.show()


func update_score(score):
	$ScoreLabel.text = str(score)


func update_high_score(value):
	$HighScoreLabel.text = "Best: %d" % value


func _on_StartButton_pressed():
	$StartButton.hide()
	$CreditsButton.hide()
	$HighScoreLabel.hide()  # sembunyikan selama bermain supaya layar bersih
	$PauseButton.show()
	playing = true
	start_game.emit()


func _on_CreditsButton_pressed():
	$StartButton.hide()
	$CreditsButton.hide()
	$HighScoreLabel.hide()
	$MessageLabel.hide()
	$CreditsPanel.play()


func _on_credits_finished():
	if not playing:
		$MessageLabel.show()
		$HighScoreLabel.show()
		$StartButton.show()
		$CreditsButton.show()


func _on_MessageTimer_timeout():
	$MessageLabel.hide()


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
