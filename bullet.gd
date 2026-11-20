extends Area2D
# Peluru pemain (fitur 7). Ditembakkan Player ke arah double tap saat karakter diam,
# terbang lurus, lalu hilang saat mengenai musuh pertama atau setelah `lifetime` habis.
# Peluru ada di collision layer 2 ("peluru") dan hanya memindai layer 1 (musuh),
# jadi tidak terdeteksi oleh Player maupun item hati.

signal mob_hit  # peluru mengenai musuh (Player meneruskannya ke Main untuk skor)

const CORE_COLOR = Color(1.0, 1.0, 0.85)
const GLOW_COLOR = Color(0.45, 0.95, 1.0, 0.45)

@export var speed = 700.0
@export var lifetime = 1.5  # detik; cukup untuk melintasi layar, lalu peluru dibuang
var direction = Vector2.RIGHT  # diisi Player sebelum peluru ditambahkan ke scene
var _spent = false  # sudah mengenai musuh (mencegah satu peluru mengenai dua musuh sekaligus)


func _ready():
	rotation = direction.angle()


func _physics_process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


# Peluru digambar lewat kode (tidak butuh aset): ekor bercahaya + inti terang, menghadap ke kanan.
func _draw():
	draw_line(Vector2(-14, 0), Vector2(0, 0), GLOW_COLOR, 6.0)
	draw_circle(Vector2.ZERO, 7.0, GLOW_COLOR)
	draw_circle(Vector2.ZERO, 3.5, CORE_COLOR)


func _on_body_entered(body):
	if _spent or not body is Mob or body.is_dead:
		return
	_spent = true
	body.take_hit()
	mob_hit.emit()
	queue_free()
