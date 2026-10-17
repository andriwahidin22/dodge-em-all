extends Node

@export var mob_scene: PackedScene
var score


func _ready():
	# Layar penuh: ukuran area permainan mengikuti layar perangkat (stretch aspect "expand"),
	# jadi jalur spawn musuh dan posisi awal pemain dihitung ulang setiap ukuran layar berubah.
	get_viewport().size_changed.connect(_update_play_area)
	_update_play_area()


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

func game_over():
	$ScoreTimer.stop()
	$MobTimer.stop()
	var new_record = score > SaveManager.highest_score
	if new_record:
		SaveManager.save_high_score(score)
	$HUD.update_high_score(SaveManager.highest_score)
	$HUD.show_game_over(new_record)
	$Music.stop()
	$DeathSound.play()


func new_game():
	get_tree().call_group(&"mobs", &"queue_free")
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	$Music.play()


func _on_MobTimer_timeout():
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()

	# Choose a random location on Path2D.
	var mob_spawn_location = get_node(^"MobPath/MobSpawnLocation")
	mob_spawn_location.progress_ratio = randf()

	# Set the mob's position to a random location.
	mob.position = mob_spawn_location.position

	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2

	# Add some randomness to the direction.
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction

	# Choose the velocity for the mob.
	var velocity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)


func _on_ScoreTimer_timeout():
	score += 1
	$HUD.update_score(score)


func _on_StartTimer_timeout():
	$MobTimer.start()
	$ScoreTimer.start()
