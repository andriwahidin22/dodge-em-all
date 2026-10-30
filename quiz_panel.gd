extends ColorRect
# QuizPanel: dialog modal untuk kuis hidup lagi.
# Logika soal tetap sama; file ini hanya mengatur UI, timer, dan animasi pop-up.
# Panel mewarisi process_mode Always dari HUD supaya tetap berjalan saat game di-pause.

signal quiz_passed
signal quiz_failed

const QuizBank = preload("res://quiz_bank.gd")
const FONT = preload("res://fonts/Xolonium-Regular.ttf")

const TIME_LIMIT = 30.0 # Detik untuk menjawab.
const INPUT_LOCK = 0.8 # Jeda agar sentuhan saat karakter mati tidak menjadi jawaban.
const CARD_MAX_WIDTH = 420.0 # Lebar maksimum kartu dalam piksel.
const CARD_SIDE_MARGIN = 16.0 # Jarak minimum kartu dari tepi viewport.
const CARD_MAX_HEIGHT_RATIO = 0.88 # Batas tinggi kartu terhadap viewport.
const CARD_PADDING = 18.0 # Padding bagian dalam kartu.
const CARD_CORNER_RADIUS = 16 # Radius sudut kartu.
const DIM_ALPHA = 0.60 # Alpha latar gelap di belakang kartu.
const ANIM_IN_DIM = 0.15 # Durasi fade-in dim.
const ANIM_IN_CARD = 0.25 # Durasi scale/fade-in kartu.
const ANIM_OUT = 0.15 # Durasi penutupan kartu.
const ANIM_FEEDBACK = 0.24 # Durasi highlight jawaban benar.
const ANIM_SHAKE = 0.055 # Durasi satu arah getaran salah.

const COLOR_ACCENT = Color("37605F")
const COLOR_GOLD = Color("FFD966")
const COLOR_CARD = Color("102b35")
const COLOR_CARD_EDGE = Color("4a8580")
const COLOR_CODE = Color("07151d")
const COLOR_OK = Color("65d68a")
const COLOR_BAD = Color("ed6b70")
const COLOR_WARNING = Color("f1c75b")
const COLOR_TEXT = Color("f4fbf8")
const COLOR_MUTED = Color("b6d1cd")

var _used = []
var _question = {}
var _correct_index = 0
var _option_texts = []
var _answered = false
var _passed = false
var _closing = false
var _signal_sent = false
var _time_left = 0.0
var _lock_left = 0.0
var _card_width = CARD_MAX_WIDTH
var _card_origin_x = 0.0

var _center: CenterContainer
var _card: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _header_label: Label
var _category_chip: PanelContainer
var _category_label: Label
var _timer_label: Label
var _timer_bar: ProgressBar
var _question_label: Label
var _code_box: PanelContainer
var _code_label: Label
var _option_buttons: Array = []
var _result_label: Label
var _continue_button: Button
var _card_style: StyleBoxFlat
var _timer_fill_style: StyleBoxFlat
var _animation_tween: Tween
var _feedback_tween: Tween


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, DIM_ALPHA)
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_ui()
	hide()
	set_process(false)


func _build_ui():
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_style = _make_style(COLOR_CARD, COLOR_CARD_EDGE, 1, CARD_CORNER_RADIUS)
	_card_style.shadow_color = Color(0, 0, 0, 0.45)
	_card_style.shadow_size = 14
	_card_style.shadow_offset = Vector2(0, 5)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_card)

	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_PADDING)
	_card.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)

	_build_header()
	_build_timer()

	_question_label = _make_label(21, COLOR_TEXT)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_question_label)

	_code_box = PanelContainer.new()
	_code_box.add_theme_stylebox_override("panel", _make_style(COLOR_CODE, Color("28515b"), 1, 9))
	_code_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_code_box)
	_code_label = _make_label(16, Color("bcebd2"))
	_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "Courier New", "monospace"])
	_code_label.add_theme_font_override("font", mono)
	_code_box.add_child(_code_label)

	for i in 4:
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 17)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_answer.bind(i))
		_apply_button_style(button, COLOR_ACCENT, COLOR_GOLD)
		_content.add_child(button)
		_option_buttons.append(button)

	_result_label = _make_label(16, COLOR_TEXT)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_result_label)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0, 54)
	_continue_button.add_theme_font_override("font", FONT)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.pressed.connect(_on_continue_pressed)
	_apply_button_style(_continue_button, COLOR_ACCENT, COLOR_GOLD)
	_content.add_child(_continue_button)


func _build_header():
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var title = _make_label(24, COLOR_GOLD)
	title.text = "Hidup lagi?"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_category_chip = PanelContainer.new()
	_category_chip.custom_minimum_size = Vector2(82, 32)
	row.add_child(_category_chip)
	_category_label = _make_label(15, COLOR_TEXT)
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_category_chip.add_child(_category_label)

	_header_label = _make_label(15, COLOR_MUTED)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_header_label)


func _build_timer():
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.show_percentage = false
	_timer_bar.add_theme_stylebox_override("background", _make_style(Color("173943"), Color("28515b"), 1, 5))
	_timer_fill_style = _make_style(COLOR_OK, COLOR_OK, 0, 5)
	_timer_bar.add_theme_stylebox_override("fill", _timer_fill_style)
	row.add_child(_timer_bar)
	_timer_label = _make_label(15, COLOR_TEXT)
	_timer_label.custom_minimum_size = Vector2(38, 0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_timer_label)


func _make_label(size, font_color) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_style(background, border, border_width, radius) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10)
	return style


func _apply_button_style(button, background, border):
	button.add_theme_stylebox_override("normal", _make_style(background, border, 1, 9))
	button.add_theme_stylebox_override("hover", _make_style(background.lightened(0.12), border, 2, 9))
	button.add_theme_stylebox_override("pressed", _make_style(background.darkened(0.12), border, 2, 9))
	button.add_theme_stylebox_override("focus", _make_style(background.lightened(0.06), border, 2, 9))
	button.add_theme_stylebox_override("disabled", _make_style(background.darkened(0.32), Color("55706f"), 1, 9))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.75, 0.82, 0.8, 0.72))


func _category_color(category):
	match category:
		"Logika": return Color("4b7f83")
		"Python": return Color("547b54")
		"JavaScript": return Color("8b7340")
		"HTML": return Color("76505d")
	return COLOR_ACCENT


func _on_viewport_size_changed():
	if is_inside_tree():
		call_deferred("_fit_card")


func _fit_card():
	if not is_instance_valid(_card):
		return
	var area = get_viewport().get_visible_rect()
	_card_width = minf(CARD_MAX_WIDTH, maxf(0.0, area.size.x - CARD_SIDE_MARGIN * 2.0))
	_card.custom_minimum_size.x = _card_width
	var max_height = area.size.y * CARD_MAX_HEIGHT_RATIO
	var content_height = _content.get_combined_minimum_size().y + CARD_PADDING * 2.0
	var card_height = minf(max_height, content_height)
	_card.custom_minimum_size.y = maxf(0.0, card_height)
	_scroll.custom_minimum_size = Vector2(0, maxf(40.0, card_height - CARD_PADDING * 2.0))
	_card.pivot_offset = _card.size * 0.5
	_card_origin_x = _card.position.x


func _set_category_style(category):
	_category_label.text = category
	var category_color = _category_color(category)
	_category_chip.add_theme_stylebox_override("panel", _make_style(category_color, category_color.lightened(0.25), 1, 8))


# `number` = revive ke berapa; `max_number` = jatah revive per ronde.
func show_quiz(number, max_number):
	_kill_tweens()
	_question = _pick_question()
	_answered = false
	_passed = false
	_closing = false
	_signal_sent = false
	_time_left = TIME_LIMIT
	_lock_left = INPUT_LOCK

	_header_label.text = "Kesempatan %d/%d" % [number, max_number]
	_set_category_style(_question.cat)
	_question_label.text = _question.q
	_code_box.visible = _question.has("code")
	if _question.has("code"):
		_code_label.text = _question.code

	var options = _question.options.duplicate()
	var correct_text = options[_question.answer]
	options.shuffle()
	_correct_index = options.find(correct_text)
	_option_texts = options
	for i in _option_buttons.size():
		var button = _option_buttons[i]
		button.text = "%d. %s" % [i + 1, options[i]]
		button.disabled = true
		_apply_button_style(button, COLOR_ACCENT, COLOR_GOLD)

	_result_label.hide()
	_continue_button.hide()
	_timer_bar.value = 100.0
	_update_timer_display()
	show()
	modulate.a = 0.0
	_card.scale = Vector2(0.85, 0.85)
	call_deferred("_fit_card")
	set_process(true)
	call_deferred("_start_show_animation")


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
	if _answered or _closing:
		return
	if _lock_left > 0:
		_lock_left -= delta
		if _lock_left <= 0:
			for button in _option_buttons:
				button.disabled = false
	_time_left -= delta
	_update_timer_display()
	if _time_left <= 0:
		_answer(-1)


func _update_timer_display():
	var secs = maxi(ceili(_time_left), 0)
	_timer_label.text = "%d dtk" % secs
	_timer_bar.value = clampf(_time_left / TIME_LIMIT * 100.0, 0.0, 100.0)
	var timer_color = COLOR_OK
	if secs <= 5:
		timer_color = COLOR_BAD
	elif secs <= 10:
		timer_color = COLOR_WARNING
	_timer_fill_style.bg_color = timer_color
	_timer_fill_style.border_color = timer_color
	_timer_label.add_theme_color_override("font_color", timer_color)
	if secs <= 5 and not _answered and visible:
		_timer_label.modulate.a = 0.65 + (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.17
	else:
		_timer_label.modulate.a = 1.0


func _unhandled_key_input(event):
	if not visible or _answered or _lock_left > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n = event.keycode - KEY_1
		if n >= 0 and n < _option_buttons.size():
			_answer(n)
			get_viewport().set_input_as_handled()


func _answer(index):
	if _answered or _closing or _lock_left > 0:
		return
	_answered = true
	_passed = index == _correct_index
	set_process(false)
	for button in _option_buttons:
		button.disabled = true

	var correct_button = _option_buttons[_correct_index]
	_apply_button_style(correct_button, COLOR_OK.darkened(0.35), COLOR_OK)
	if not _passed and index >= 0:
		_apply_button_style(_option_buttons[index], COLOR_BAD.darkened(0.35), COLOR_BAD)

	var correct_text = _option_texts[_correct_index]
	if _passed:
		_result_label.text = "Benar! Kamu hidup lagi.\n%s" % _question.explain
		_continue_button.text = "Lanjut main!"
		_result_label.add_theme_color_override("font_color", COLOR_OK)
		_play_success_feedback()
	else:
		var prefix = "Waktu habis!" if index < 0 else "Salah."
		_result_label.text = "%s Jawaban benar: %s\n%s" % [prefix, correct_text, _question.explain]
		_continue_button.text = "Game Over"
		_result_label.add_theme_color_override("font_color", COLOR_BAD)
		_play_failure_feedback()
	_result_label.show()
	_continue_button.show()
	call_deferred("_fit_card")


func _start_show_animation():
	_fit_card()
	_animation_tween = _new_tween()
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(self, "modulate:a", 1.0, ANIM_IN_DIM)
	_animation_tween.tween_property(_card, "modulate:a", 1.0, ANIM_IN_CARD)
	_animation_tween.tween_property(_card, "scale", Vector2.ONE, ANIM_IN_CARD).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_success_feedback():
	_feedback_tween = _new_tween()
	_feedback_tween.tween_property(_card, "modulate", Color(0.78, 1.0, 0.86, 1.0), ANIM_FEEDBACK * 0.5)
	_feedback_tween.tween_property(_card, "modulate", Color.WHITE, ANIM_FEEDBACK * 0.5)


func _play_failure_feedback():
	var start_x = _card.position.x
	_feedback_tween = _new_tween()
	_feedback_tween.tween_property(_card, "position:x", start_x - 8.0, ANIM_SHAKE)
	_feedback_tween.tween_property(_card, "position:x", start_x + 8.0, ANIM_SHAKE * 2.0)
	_feedback_tween.tween_property(_card, "position:x", start_x, ANIM_SHAKE)


func _on_continue_pressed():
	if _closing or not _answered:
		return
	_closing = true
	set_process(false)
	_kill_tween(_feedback_tween)
	_animation_tween = _new_tween()
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(self, "modulate:a", 0.0, ANIM_OUT)
	_animation_tween.tween_property(_card, "scale", Vector2(0.94, 0.94), ANIM_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_animation_tween.finished.connect(_finish_close)


func _finish_close():
	hide()
	_card.scale = Vector2.ONE
	_card.position.x = _card_origin_x
	modulate.a = 1.0
	_closing = false
	if _signal_sent:
		return
	_signal_sent = true
	if _passed:
		quiz_passed.emit()
	else:
		quiz_failed.emit()


func _new_tween() -> Tween:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _kill_tween(tween):
	if tween:
		tween.kill()


func _kill_tweens():
	_kill_tween(_animation_tween)
	_kill_tween(_feedback_tween)
	_animation_tween = null
	_feedback_tween = null
