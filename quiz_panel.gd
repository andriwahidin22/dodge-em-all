extends ColorRect
# QuizPanel: layar kuis yang muncul saat nyawa habis.
# Jawab benar → pemain hidup lagi. Jawab salah / waktu habis → game over.
#
# Panel ini dibuat sepenuhnya lewat kode dan ditambahkan oleh hud.gd,
# jadi tidak ada node baru yang perlu dibuat manual di hud.tscn.
# process_mode diwarisi dari HUD (Always), sehingga tetap jalan saat game di-pause.

signal quiz_passed  # jawaban benar, pemain boleh hidup lagi
signal quiz_failed  # jawaban salah atau waktu habis

const QuizBank = preload("res://quiz_bank.gd")
const FONT = preload("res://fonts/Xolonium-Regular.ttf")

const TIME_LIMIT = 30.0   # detik untuk menjawab
const INPUT_LOCK = 0.8    # tombol baru aktif setelah jeda ini, supaya sentuhan saat
						  # karakter mati tidak langsung terhitung sebagai jawaban
const COLOR_OK = Color(0.55, 1.0, 0.55)
const COLOR_BAD = Color(1.0, 0.55, 0.55)

var _used = []            # indeks soal yang sudah keluar (reset otomatis kalau habis)
var _question = {}
var _correct_index = 0    # posisi jawaban benar setelah pilihan diacak
var _option_texts = []    # teks pilihan (tanpa nomor) sesudah diacak
var _answered = false
var _passed = false
var _time_left = 0.0
var _lock_left = 0.0

var _header_label: Label
var _timer_label: Label
var _question_label: Label
var _code_box: PanelContainer
var _code_label: Label
var _option_buttons: Array = []
var _result_label: Label
var _continue_button: Button


func _ready():
	hide()
	color = Color(0, 0, 0, 0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP  # sentuhan tidak tembus ke UI di belakang
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	set_process(false)


func _build_ui():
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	# ScrollContainer: kalau layar pendek, isi kuis tetap bisa digeser.
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var title = _make_label(30, Color(1, 0.85, 0.4))
	title.text = "Hidup lagi?\nJawab dengan benar!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var info_row = HBoxContainer.new()
	box.add_child(info_row)
	_header_label = _make_label(18, Color(1, 1, 1, 0.7))
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_header_label)
	_timer_label = _make_label(18, Color.WHITE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_timer_label)

	_question_label = _make_label(22, Color.WHITE)
	box.add_child(_question_label)

	# Kotak kode (monospace) supaya spasi dan indentasi terbaca jelas.
	_code_box = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_code_box.add_theme_stylebox_override("panel", style)
	box.add_child(_code_box)
	_code_label = _make_label(18, Color(0.75, 1.0, 0.85))
	var mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "Courier New", "monospace"])
	_code_label.add_theme_font_override("font", mono)
	_code_box.add_child(_code_label)

	for i in 4:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", 22)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_answer.bind(i))
		box.add_child(btn)
		_option_buttons.append(btn)

	_result_label = _make_label(20, Color.WHITE)
	box.add_child(_result_label)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0, 64)
	_continue_button.add_theme_font_override("font", FONT)
	_continue_button.add_theme_font_size_override("font_size", 26)
	_continue_button.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_button)


func _make_label(size, color) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# ---------------- Tampilkan kuis ----------------

# `number` = revive ke berapa (mulai 1), `max_number` = jatah revive per ronde.
func show_quiz(number, max_number):
	_question = _pick_question()
	_answered = false
	_passed = false
	_time_left = TIME_LIMIT
	_lock_left = INPUT_LOCK

	_header_label.text = "Kesempatan %d/%d · %s" % [number, max_number, _question.cat]
	_question_label.text = _question.q
	_code_box.visible = _question.has("code")
	if _question.has("code"):
		_code_label.text = _question.code

	# Acak urutan pilihan, lalu catat posisi jawaban yang benar.
	var options = _question.options.duplicate()
	var correct_text = options[_question.answer]
	options.shuffle()
	_correct_index = options.find(correct_text)
	_option_texts = options
	for i in _option_buttons.size():
		var btn = _option_buttons[i]
		btn.text = "%d. %s" % [i + 1, options[i]]
		btn.modulate = Color.WHITE
		btn.disabled = true  # aktif lagi setelah INPUT_LOCK

	_result_label.hide()
	_continue_button.hide()
	_update_timer_label()
	show()
	set_process(true)


# Soal tidak diulang sampai semua soal sudah keluar sekali.
func _pick_question():
	var total = QuizBank.QUESTIONS.size()
	if _used.size() >= total:
		_used.clear()
	var candidates = []
	for i in total:
		if not _used.has(i):
			candidates.append(i)
	var index = candidates.pick_random()
	_used.append(index)
	return QuizBank.QUESTIONS[index]


func _process(delta):
	if _answered:
		return
	if _lock_left > 0:
		_lock_left -= delta
		if _lock_left <= 0:
			for btn in _option_buttons:
				btn.disabled = false
	_time_left -= delta
	_update_timer_label()
	if _time_left <= 0:
		_answer(-1)  # waktu habis dihitung salah


func _update_timer_label():
	var secs = maxi(ceili(_time_left), 0)
	_timer_label.text = "Waktu: %d" % secs
	_timer_label.add_theme_color_override("font_color", COLOR_BAD if secs <= 5 else Color.WHITE)


# Pintasan keyboard: tombol 1-4 untuk memilih jawaban.
func _unhandled_key_input(event):
	if not visible or _answered or _lock_left > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n = event.keycode - KEY_1
		if n >= 0 and n < _option_buttons.size():
			_answer(n)
			get_viewport().set_input_as_handled()


# ---------------- Menjawab ----------------

func _answer(index):
	if _answered:
		return
	_answered = true
	_passed = index == _correct_index
	set_process(false)

	for btn in _option_buttons:
		btn.disabled = true
	_option_buttons[_correct_index].modulate = COLOR_OK
	if not _passed and index >= 0:
		_option_buttons[index].modulate = COLOR_BAD

	var correct_text = _option_texts[_correct_index]
	if _passed:
		_result_label.text = "Benar! Kamu hidup lagi.\n%s" % _question.explain
		_continue_button.text = "Lanjut main!"
	else:
		var prefix = "Waktu habis!" if index < 0 else "Salah."
		_result_label.text = "%s Jawaban benar: %s\n%s" % [prefix, correct_text, _question.explain]
		_continue_button.text = "Game Over"
	_result_label.add_theme_color_override("font_color", COLOR_OK if _passed else COLOR_BAD)
	_result_label.show()
	_continue_button.show()


func _on_continue_pressed():
	hide()
	if _passed:
		quiz_passed.emit()
	else:
		quiz_failed.emit()
