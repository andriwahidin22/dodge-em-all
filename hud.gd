extends CanvasLayer

signal start_game

func _ready():
	# Saat game dibuka, tampilkan high score yang tersimpan di layar judul.
	update_high_score(SaveManager.highest_score)

func show_message(text):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start()


func show_game_over(new_record = false):
	show_message("High Score\nBaru!" if new_record else "Game Over")
	await $MessageTimer.timeout
	$MessageLabel.text = "Dodge 'em\nAll"
	$MessageLabel.show()
	$HighScoreLabel.show()  # tampil lagi di layar judul
	await get_tree().create_timer(1).timeout
	$StartButton.show()


func update_score(score):
	$ScoreLabel.text = str(score)

func update_high_score(value):
	$HighScoreLabel.text = "Best: %d" % value

func _on_StartButton_pressed():
	$StartButton.hide()
	$HighScoreLabel.hide()  # sembunyikan selama bermain supaya layar bersih
	start_game.emit()


func _on_MessageTimer_timeout():
	$MessageLabel.hide()
