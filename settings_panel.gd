extends Control
class_name SettingsPanel

signal apply_settings(cols: int, rows: int, mine_count: int, cursor_color: Color)

var _col_spin: SpinBox
var _row_spin: SpinBox
var _mine_spin: SpinBox
var _color_btn: ColorPickerButton

func _ready() -> void:
	# 左半屏抽屉：宽=屏幕一半, 高=全屏, 贴左
	anchor_left   = 0.0
	anchor_right  = 0.5
	anchor_top    = 0.0
	anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0
	_build_ui()
	hide()

func _build_ui() -> void:
	# 灰色面板铺满自己(左半屏)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	# 内容：上到下排
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := 24.0
	vb.offset_left = m; vb.offset_top = m; vb.offset_right = -m; vb.offset_bottom = -m
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(title)

	_col_spin = _add_spin_row(vb, "列数", 30, 9, 40)
	_row_spin = _add_spin_row(vb, "行数", 16, 9, 24)
	_mine_spin = _add_spin_row(vb, "雷数", 60, 1, 999)

	var color_row := HBoxContainer.new()
	vb.add_child(color_row)
	var cl := Label.new(); cl.text = "光标颜色"; color_row.add_child(cl)
	_color_btn = ColorPickerButton.new()
	_color_btn.color = Color(1, 0.9, 0.3)
	_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(_color_btn)

	var btns := HBoxContainer.new()
	vb.add_child(btns)
	var apply := Button.new(); apply.text = "应用"; btns.add_child(apply)
	apply.pressed.connect(_on_apply)
	var close := Button.new(); close.text = "关闭"; btns.add_child(close)
	close.pressed.connect(_close)

func _add_spin_row(parent, label: String, val: int, vmin: int, vmax: int) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new(); l.text = label; row.add_child(l)
	var s := SpinBox.new()
	s.value = val; s.min_value = vmin; s.max_value = vmax
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	return s

# 从左边滑入，占到左半屏
func open() -> void:
	show()
	position.x = -get_viewport_rect().size.x * 0.5   # 先躲到左边外
	var t := create_tween()
	t.tween_property(self, "position:x", 0.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close() -> void:
	var t := create_tween()
	t.tween_property(self, "position:x", -get_viewport_rect().size.x * 0.5, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(hide)

func _on_apply() -> void:
	apply_settings.emit(
		int(_col_spin.value), int(_row_spin.value),
		int(_mine_spin.value), _color_btn.color)
	_close()
