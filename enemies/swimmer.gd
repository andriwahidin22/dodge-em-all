extends Mob
# Swimmer: maju sambil meliuk ke kiri-kanan (gerak sinus), seperti ikan berenang.

@export var wave_amplitude = 60.0  # seberapa jauh ikan menyimpang ke samping (piksel)
@export var wave_frequency = 1.5   # seberapa cepat ikan meliuk (radian/detik); 3.0 ≈ 1 liukan per 2 detik

var _base_velocity: Vector2  # arah dan kecepatan maju, diisi main.gd sebelum musuh muncul
var _time = 0.0


func _ready():
	super()  # jalankan Mob._ready() dulu: arah hadap awal + animasi
	_base_velocity = linear_velocity
	# Mulai dari fase acak supaya ikan-ikan tidak meliuk serempak.
	_time = randf() * TAU / wave_frequency


func _physics_process(delta):
	_time += delta
	# Arah samping = tegak lurus arah maju.
	var side = _base_velocity.orthogonal().normalized()
	# Posisi samping = amplitudo × sin(f·t); kecepatannya (turunan) = amplitudo × f × cos(f·t).
	var side_speed = wave_amplitude * wave_frequency * cos(_time * wave_frequency)
	linear_velocity = _base_velocity + side * side_speed
	face_direction(linear_velocity)  # ikan ikut menghadap arah liukan
