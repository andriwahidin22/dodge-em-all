extends ColorRect
# Layar Credits: kartu-kartu teks yang muncul perlahan, diam sebentar, lalu menghilang,
# seperti credit film. Ketuk layar (atau Esc / Back) untuk kembali ke menu judul.
#
# Ubah isi credit di konstanta CARDS di bawah.

signal finished

@export var fade_in_time = 1.0
@export var hold_time = 2.5
@export var fade_out_time = 1.0

const CARDS = [
	{
		"title": "Dodge 'em All",
		"body": "Tugas Pemrograman Game\nUNAS · 2026"
	},
	{
		"title": "Kelompok",
		"body": "[Kelompok 1]"
	},
	{
		"title": "Anggota & Peran",
		"body": "[Andri Wahidin (26316625027)]\n\n[Arshika Septia Ramadhani (25306622001)]\n\n[Jaka Ramdani (26316625052)]\n"
	},
	{
		"title": "Berdasarkan Demo",
		"body": "Dodge the Creeps\ndemo resmi Godot Engine\n(godotengine/godot-demo-projects)\n© 2017 KidsCanCode · Lisensi MIT"
	},
	{
		"title": "Game Engine",
		"body": "Godot Engine 4.7"
	},
	{
		"title": "Karakter & Musuh",
		"body": "Kenney Platformer Pack Redux\n&\nPlatformer Art More Animations & Enemies\n(CC0)"
	},
	{
		"title": "Ikon & Antarmuka",
		"body": "Kenney Game Icons & UI Pack (CC0)\n\n25x25 Hearts oleh Min (CC0)"
	},
	{
		"title": "Font",
		"body": "Xolonium oleh Severin Meyer\nSIL Open Font License 1.1"
	},
	{
		"title": "Musik",
		"body": "\"House In a Forest Loop\"\noleh HorrorPen\nCC-BY 3.0"
	},
	{
		"title": "Audio Wave",
		"body": "Efek suara sintetis (CC0)\nPlaceholder buatan sendiri via generator"
	},
	{
		"title": "Terima Kasih",
		"body": "telah memainkan\nDodge 'em All!"
	},
]

var _index = -1
var _tween: Tween


# Memulai tampilan credit dari kartu pertama.
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


# Ketukan di layar (sentuh di Android masuk sebagai event klik/touch) melewati credit.
func _gui_input(event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		skip()
