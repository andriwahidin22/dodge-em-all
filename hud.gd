extends CanvasLayer

signal start_game     # Start / Main Baru → Main.new_game()
signal continue_game  # Lanjutkan dari simpanan → Main.continue_game()
signal quit_to_menu   # "Keluar ke menu" (pause) atau "Keluar" (akhir wave)
signal next_wave      # "Lanjut" di layar akhir wave
signal save_and_quit  # "Simpan & Keluar" di layar akhir wave
signal revive_passed  # kuis hidup lagi dijawab benar → Main.
signal revive_failed  # kuis dijawab salah / waktu habis → game over

# HUD memakai process_mode Always supaya tombol-tombolnya tetap bisa dipakai saat
# game di-pause. MessageTimer sengaja diset Pausable di scene supaya pesan ikut berhenti.
var playing = false  # true selama ronde berjalan (pause hanya boleh saat bermain)
var _message_was_visible = false
const TITLE_TEXT = "Dodge 'em\nAll"
const QuizPanelScript = preload("res://quiz_panel.gd")
var quiz_panel  # panel kuis hidup lagi (dibuat lewat kode di _ready)

# Ikon nyawa (fitur 3) diambil dari satu lembar gambar 50x125 berisi hati 25x25:
# hati penuh di kiri atas, hati kosong di kiri bawah.
const HEARTS_SHEET = preload("res://art/hearts/heartsupdated.png")
const HEART_SIZE = 40
var heart_full: AtlasTexture
var heart_empty: AtlasTexture

func _ready():
	# Saat game dibuka, tampilkan high score yang tersimpan di layar judul.
	update_high_score(SaveManager.highest_score)
	heart_full = _heart_from_sheet(Rect2(0, 0, 25, 25))
	heart_empty = _heart_from_sheet(Rect2(0, 100, 25, 25))
	$LivesBox.hide()
	$WaveLabel.hide()
	$MessageLabel.text = TITLE_TEXT
	_show_title_buttons()

	# Panel kuis ditambahkan paling akhir supaya tampil di atas semua panel lain.
	quiz_panel = QuizPanelScript.new()
	add_child(quiz_panel)
	quiz_panel.quiz_passed.connect(_on_quiz_passed)
	quiz_panel.quiz_failed.connect(_on_quiz_failed)


func _heart_from_sheet(region):
	var atlas = AtlasTexture.new()
	atlas.atlas = HEARTS_SHEET
	atlas.region = region
	return atlas


# Menampilkan hati penuh sebanyak `lives` dan hati kosong untuk sisanya.
func update_lives(lives, max_lives):
	while $LivesBox.get_child_count() < max_lives:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art tetap tajam
		$LivesBox.add_child(icon)
	for i in $LivesBox.get_child_count():
		$LivesBox.get_child(i).texture = heart_full if i < lives else heart_empty


# Pesan di tengah layar, hilang sendiri setelah `duration` detik.
func show_message(text, duration = 1.0):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start(duration)


func show_game_over(new_record = false, reason = ""):
	playing = false
	$PauseButton.hide()
	var text = "High Score\nBaru!" if new_record else "Game Over"
	if not reason.is_empty():
		text = reason + "\n" + text
	show_message(text)
	await $MessageTimer.timeout
	show_title()


# Layar judul: judul game, high score, lalu tombol Start
# (atau Lanjutkan + Main Baru kalau ada simpanan).
func show_title():
	playing = false
	$PauseButton.hide()
	$WaveLabel.hide()
	$WaveEndPanel.hide()
	$ConfirmPanel.hide()
	$WinPanel.hide()
	quiz_panel.hide()
	$CreditsButton.hide()  # tampil lagi bersama tombol judul lain setelah jeda 1 detik
	$MessageTimer.stop()
	$MessageLabel.text = TITLE_TEXT
	$MessageLabel.show()
	$HighScoreLabel.show()  # tampil lagi di layar judul
	$LivesBox.hide()
	await get_tree().create_timer(1).timeout
	if not playing:  # pemain belum memulai ronde lain selama jeda 1 detik
		_show_title_buttons()


# W6: tombol layar judul tergantung ada atau tidaknya simpanan progress.
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


# W2: "Wave 2/10 · 1/3" di bawah skor, dan pesan di awal tiap sub-wave.
func show_subwave(wave, subwave, max_wave, subwave_count = 3):
	$WaveLabel.text = "Wave %d/%d · %d/%d" % [wave, max_wave, subwave, subwave_count]
	$WaveLabel.show()
	show_message("Wave %d" % wave if subwave == 1 else "Sub-wave %d" % subwave, 2.0)


# Semua tombol yang memulai ronde (Start, Lanjutkan, Ya mulai baru) lewat sini.
func _begin_round():
	$StartButton.hide()
	$CreditsButton.hide()
	$TitleMenu.hide()
	$ConfirmPanel.hide()
	$HighScoreLabel.hide()  # sembunyikan selama bermain supaya layar bersih
	$MessageLabel.hide()
	$LivesBox.show()
	$PauseButton.show()
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
	$MessageLabel.hide()  # judul disembunyikan supaya tidak bertumpuk dengan teks konfirmasi
	$ConfirmPanel.show()


func _on_ConfirmYesButton_pressed():
	SaveManager.clear_progress()
	_begin_round()
	start_game.emit()


func _on_ConfirmCancelButton_pressed():
	$ConfirmPanel.hide()
	$MessageLabel.show()
	$TitleMenu.show()


# ---------------- Credits ----------------
# Isi credit dan animasinya ada di credits.gd (node CreditsPanel).

func _on_CreditsButton_pressed():
	$StartButton.hide()
	$TitleMenu.hide()
	$CreditsButton.hide()
	$CreditsPanel.play()


func _on_credits_finished():
	_show_title_buttons()


func _on_MessageTimer_timeout():
	$MessageLabel.hide()


# ---------------- Layar akhir wave (W4) ----------------
# Game di-pause selama layar ini tampil; ketiga tombol melepas pause lalu memberi tahu Main.

func show_wave_end(wave, max_wave, score, bonus, lives):
	get_tree().paused = true
	$PauseButton.hide()
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
	save_and_quit.emit()  # Main menyimpan lalu kembali ke layar judul


func _on_WaveQuitButton_pressed():
	_close_wave_end()
	quit_to_menu.emit()


# ---------------- Kuis hidup lagi ----------------
# Game di-pause selama kuis tampil. Main yang memutuskan kapan kuis ditawarkan
# (lihat Main._on_player_died); HUD hanya menampilkan dan melaporkan hasilnya.

func show_revive_quiz(wave):
	get_tree().paused = true
	$PauseButton.hide()
	$MessageLabel.hide()
	quiz_panel.show_quiz(wave)


func _on_quiz_passed():
	get_tree().paused = false
	if playing:
		$PauseButton.show()
	revive_passed.emit()


func _on_quiz_failed():
	get_tree().paused = false  # harus dilepas dulu supaya pesan Game Over (timer pausable) jalan
	revive_failed.emit()


# ---------------- Layar menang (W7) ----------------

func show_win(max_wave, score, new_record):
	playing = false
	$PauseButton.hide()
	$WaveLabel.hide()
	$LivesBox.hide()
	$MessageTimer.stop()
	$MessageLabel.hide()
	$WinPanel/Menu/WinLabel.text = "Kamu bertahan\n%d wave!" % max_wave
	var text = "Skor: %d\nBest: %d" % [score, SaveManager.highest_score]
	if new_record:
		text += "\nHigh Score Baru!"
	$WinPanel/Menu/WinScoreLabel.text = text
	$WinPanel.show()


func _on_WinMenuButton_pressed():
	$WinPanel.hide()
	show_title()


# ---------------- Pause (fitur 2) ----------------
# get_tree().paused menghentikan semua node yang Pausable: Player, musuh, timer di Main
# dan WaveManager, item nyawa, dan musik. Panel pause tetap jalan karena HUD diset Always.
func pause_game():
	# Saat layar akhir wave tampil game sudah di-pause; panel pause tidak dibuka di atasnya.
	if not playing or get_tree().paused:
		return
	get_tree().paused = true
	_message_was_visible = $MessageLabel.visible
	$MessageLabel.hide()
	$PausePanel.show()
	$PauseButton.hide()


func resume_game():
	if not $PausePanel.visible:
		return  # pause berasal dari layar akhir wave: hanya tombol di layar itu yang melanjutkan
	get_tree().paused = false
	$PausePanel.hide()
	if playing:
		$PauseButton.show()
		$MessageLabel.visible = _message_was_visible


func _on_QuitButton_pressed():
	resume_game()
	quit_to_menu.emit()  # Main menghentikan ronde lalu memanggil show_title()


func _toggle_pause():
	if $PausePanel.visible:
		resume_game()
	else:
		pause_game()


func _unhandled_input(event):
	# Esc (keyboard) atau tombol Start (gamepad): pause / lanjut.
	if event.is_action_pressed(&"pause"):
		if $CreditsPanel.visible:
			$CreditsPanel.skip()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Tombol Back Android. (project.godot: quit_on_go_back = false, supaya Back tidak langsung menutup game.)
		if $CreditsPanel.visible:
			$CreditsPanel.skip()
		elif quiz_panel.visible or $WaveEndPanel.visible:
			pass  # pemain harus memilih salah satu tombol / menjawab kuis
		elif $ConfirmPanel.visible:
			_on_ConfirmCancelButton_pressed()
		elif $WinPanel.visible:
			_on_WinMenuButton_pressed()
		elif playing:
			_toggle_pause()  # saat bermain = pause/lanjut
		else:
			get_tree().quit()  # di layar judul = keluar aplikasi
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Aplikasi ditinggalkan (pindah aplikasi, layar dimatikan): pause otomatis.
		pause_game()
