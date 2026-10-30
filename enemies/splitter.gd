extends Mob
# Splitter (slime): lambat dan besar; setelah beberapa detik pecah menjadi 2 slime kecil
# yang menyebar ke kiri-kanan arah geraknya. Slime kecil memakai script yang sama
# dengan can_split = false (lihat splitter_small.tscn).

@export var can_split = true
@export var speed_factor = 0.6      # kecepatan dibanding musuh biasa (slime kecil: 1.3)
@export var split_time = 2.0        # waktu sampai pecah (detik)
@export var split_angle = 30.0      # sudut sebaran tiap slime kecil (derajat)
@export var small_scene: PackedScene

var _time = 0.0


func _ready():
	linear_velocity *= speed_factor
	super()


# Slime adalah makhluk "darat": tidak diputar, cukup dibalik kiri-kanan.
func face_direction(velocity: Vector2):
	if velocity.x != 0:
		$AnimatedSprite2D.flip_h = velocity.x > 0


func _physics_process(delta):
	if not can_split or small_scene == null:
		return
	_time += delta
	if _time >= split_time:
		_split()


func _split():
	can_split = false
	for angle in [-split_angle, split_angle]:
		var small = small_scene.instantiate()
		small.position = position + linear_velocity.normalized().rotated(deg_to_rad(angle)) * 16
		# Kecepatan slime kecil dihitung dari arah slime besar; speed_factor-nya sendiri
		# (1.3) diterapkan di _ready() slime kecil.
		small.linear_velocity = linear_velocity.rotated(deg_to_rad(angle)) / speed_factor
		get_parent().add_child.call_deferred(small)
	queue_free()
