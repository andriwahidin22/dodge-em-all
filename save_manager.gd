extends Node


var highest_score = 0
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_high_score()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func load_high_score():
	var config = ConfigFile.new()
	# Load data from a file.
	var err = config.load("user://save.cfg")
	# If the file didn't load, ignore it.
	if err != OK:
		return

	# Iterate over all sections.
	var high_score = config.get_value("scores", "high_score", 0)
	highest_score = high_score

func save_high_score(value):
	var config = ConfigFile.new()
	# Store some values.
	config.set_value("scores", "high_score", value)
	highest_score = value

	# Save it to a file (overwrite if already exists).
	config.save("user://save.cfg")
