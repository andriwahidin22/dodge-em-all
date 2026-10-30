extends ColorRect
# Layar Credits: kartu-kartu teks yang muncul perlahan, diam sebentar, lalu menghilang,
# seperti credit film. Ketuk layar (atau Esc / Back) untuk kembali ke menu.
#
# Ubah isi credit di CARDS. Setiap kartu punya judul kecil dan isi beberapa baris.

signal finished  # semua kartu selesai, atau pemain melewati credit

@export var fade_in_time = 1.0
@export var hold_time = 2.5
@export var fade_out_time = 1.0

const CARDS = [
	{"title": "Dodge 'em All", "body": "Tugas Pemrograman Game\nUNAS · 2026"},
	{"title": "Kelompok", "body": "[Nama Kelompok]"},
	{"title": "Anggota", "body": "[Nama Anggota A]\nPlayer & simpan progress\n\n[Nama Anggota B]\nMusuh & wave\n\n[Nama Anggota C]\nUI & sistem"},
	{"title": "Berdasarkan", "body": "Dodge the Creeps\ndemo resmi Godot Engine\n© 2017 KidsCanCode · lisensi MIT"},
	{"title": "Dibuat dengan", "body": "Godot Engine 4.7"},
	{"title": "Pemain & Musuh", "body": "Kenney Platformer Pack Redux\n\nKenney Platformer Art:\nMore Animations & Enemies\n\nCC0"},
	{"title": "Ikon", "body": "Kenney Game Icons · CC0\n\n25x25 Hearts oleh Min · CC0"},
	{"title": "Musik", "body": "\"House In a Forest Loop\"\noleh HorrorPen\nCC-BY 3.0"},
	{"title": "Font", "body": "Xolonium\noleh Severin Meyer\nSIL Open Font License 1.1"},
	{"title": "Terima kasih", "body": "telah bermain!"},
]

var _index = -1
var _tween: Tween


# Mulai dari kartu pertama.
func play():
	_index = -1
	show()
	_next_card()


# Berhenti di tengah jalan (pemain mengetuk layar, Esc, atau Back).
func skip():
	if visible:
		_finish()


func _next_card():
	_index += 1
	if _index >= CARDS.size():
		_finish()
		return
	$Card/Title.text = CARDS[_index].title
	$Card/Body.text = CARDS[_index].body
	$Card.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property($Card, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property($Card, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(_next_card)


func _finish():
	if _tween:
		_tween.kill()
	hide()
	finished.emit()


# Ketukan di layar (sentuh di Android masuk sebagai klik mouse) melewati credit.
func _gui_input(event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		skip()
