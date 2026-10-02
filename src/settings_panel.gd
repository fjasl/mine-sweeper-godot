extends Control
class_name SettingsPanel

signal apply_settings(spec: BoardSpec, cursor_color: Color)
## 面板请求关闭(应用后用 / 关闭按钮 / 手柄 B)
## 开关的意图归 main 的 _menu_open，面板只提请求、不自己改
signal close_requested

var _col_spin: SpinBox
var _row_spin: SpinBox
var _mine_spin: SpinBox
var _color_swatch: ColorRect
var _color_btn: ColorPickerButton
var _apply_btn: Button
var _restart_btn: Button
var _close_btn: Button
var _controls: Array = []
var _sel := 0
var _color_idx := 0
var _color := Color(1, 0.9, 0.3)   # 当前光标颜色(预设或自定义共用)

# "该不该开着"的意图归 main(_menu_open)，面板不持有 —— 它只提 close_requested。
# 这里留动画句柄：重开前必须先 kill，否则旧的 hide 回调会把面板藏起来
var _tween: Tween

var restart_func: Callable = Callable()



# 预设光标颜色（手柄左右循环）
const PALETTE := [
	Color(1, 0.9, 0.3),     # 黄
	Color(1, 0.75, 0.2),    # 橙
	Color(1, 0.5, 0.2),     # 橙红
	Color(1, 0.3, 0.3),     # 红
	Color(1, 0.35, 0.6),    # 玫红
	Color(1, 0.4, 1),       # 品红
	Color(0.8, 0.4, 1),     # 紫
	Color(0.55, 0.4, 1),    # 蓝紫
	Color(0.35, 0.5, 1),    # 蓝
	Color(0.3, 0.75, 1),    # 天蓝
	Color(0.3, 1, 1),       # 青
	Color(0.2, 0.9, 0.6),   # 蓝绿
	Color(0.3, 1, 0.4),     # 绿
	Color(0.65, 1, 0.3),    # 黄绿
	Color(1, 1, 1),         # 白
	Color(0.8, 0.8, 0.8),   # 浅灰
	Color(0.5, 0.5, 0.5),   # 中灰
	Color(0.25, 0.25, 0.25),# 深灰
]

func set_restart_func(callback: Callable):
	restart_func = callback

func _ready() -> void:
	# 左半屏抽屉：宽=屏幕一半, 高=全屏, 贴左
	anchor_left   = 0.0
	anchor_right  = 0.5
	anchor_top    = 0.0
	anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0
	# 本节点覆盖左半屏(高=全屏)，自身也是 Control，默认 STOP 会吃掉这半屏的事件，
	# 事件到不了 _unhandled_input —— 表现就是"抽屉一打开，指针就推不动"。
	# 放行本节点，只让里面的控件吃事件。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()

func _build_ui() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 铺满全屏的容器必须放行输入：
	# Control 的 mouse_filter 默认是 STOP，会把覆盖区域的鼠标/触摸事件全部吃掉，
	# 事件到不了 _unhandled_input —— 表现就是"面板一出现，触控板指针就推不动"。
	# 用 IGNORE：本容器不参与命中测试，但按钮/滑条等子控件各自仍是 STOP，照常可用。
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := 24.0
	vb.offset_left = m; vb.offset_top = m; vb.offset_right = -m; vb.offset_bottom = -m
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(title)

	# 范围从 BoardSpec 的常量取，避免规则出现第二份副本
	_col_spin = _add_spin_row(vb, "列数", 30, BoardSpec.MIN_COLS, BoardSpec.MAX_COLS)
	_row_spin = _add_spin_row(vb, "行数", 16, BoardSpec.MIN_ROWS, BoardSpec.MAX_ROWS)
	_mine_spin = _add_spin_row(vb, "雷数", 60, 1, 999)
	_col_spin.value_changed.connect(_sync_mine_max)
	_row_spin.value_changed.connect(_sync_mine_max)
	_sync_mine_max(0.0)

	var color_row := HBoxContainer.new()
	vb.add_child(color_row)
	var cl := Label.new(); cl.text = "光标颜色"; color_row.add_child(cl)
	_color_swatch = ColorRect.new()
	_color_swatch.custom_minimum_size = Vector2(44, 22)
	_color_swatch.color = _color
	_color_swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_swatch.size_flags_stretch_ratio = 9   # ← 占 9 份
	color_row.add_child(_color_swatch)
	_color_btn = ColorPickerButton.new()
	_color_btn.color = _color
	_color_btn.custom_minimum_size = Vector2(80, 28)   # ← 设置最小尺寸
	_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ← 可选：让它也扩展
	_color_btn.size_flags_stretch_ratio = 1    # ← 占 1 份
	color_row.add_child(_color_btn)
	_color_btn.color_changed.connect(_set_color)   # 自定义颜色(鼠标/手柄弹窗)

	var btns := HBoxContainer.new()
	vb.add_child(btns)
	_apply_btn = Button.new(); _apply_btn.text = "应用"; btns.add_child(_apply_btn)
	_apply_btn.pressed.connect(_on_apply)
	_restart_btn = Button.new(); _restart_btn.text = "重启"; btns.add_child(_restart_btn)
	_restart_btn.pressed.connect(restart)
	_close_btn = Button.new(); _close_btn.text = "关闭"; btns.add_child(_close_btn)
	_close_btn.pressed.connect(func(): close_requested.emit())

	# 手柄可聚焦项
	_controls = [_col_spin, _row_spin, _mine_spin, _color_swatch, _color_btn, _apply_btn, _close_btn]
	for c in _controls:
		c.focus_mode = Control.FOCUS_ALL

func _add_spin_row(parent, label: String, val: int, vmin: int, vmax: int) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new(); l.text = label; row.add_child(l)
	var s := SpinBox.new()
	s.value = val; s.min_value = vmin; s.max_value = vmax
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	return s

# 雷数上限跟着 列×行 走，让面板不可能提出非法值(雷不能占满整盘)
func _sync_mine_max(_v: float) -> void:
	_mine_spin.max_value = int(_col_spin.value) * int(_row_spin.value) - 1

# 从左边滑入，占到左半屏(纯表现：开关意图在 main)
func open() -> void:
	_kill_tween()
	show()
	position.x = -get_viewport_rect().size.x * 0.5   # 先躲到左边外
	_tween = create_tween()
	_tween.tween_property(self, "position:x", 0.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_goto(0)   # 聚焦第一项

func close() -> void:
	_kill_tween()
	# **在隐藏前还回焦点**：本面板 open() 时会 _goto(0) 抓住某个控件，
	# 而隐藏的 Control 不会自动释放焦点 —— 留着的话手柄 A(内置 ui_accept)
	# 会一直被那个隐形控件吃掉，棋盘的 action_a 永远收不到。
	_release_focus()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", -get_viewport_rect().size.x * 0.5, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)

# 把焦点从本面板的控件上摘掉(还回给 GUI 层)。
# (局部变量不叫 owner：会遮蔽 Node.owner)
func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()

# 重开前必须停掉上一个动画：它在 close() 尾部挂的 hide 回调会在面板重新
# 打开之后把它藏起来 —— 这是"点两次才打开"的另一半原因(kill 会一并取消回调)
func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
func restart() -> void:
	restart_func.call()

func _on_apply() -> void:
	# 把面板上的三个数值攒成一个规格值对象再发出去，接收端只需 2 个参数
	var spec := BoardSpec.make(
		int(_col_spin.value), int(_row_spin.value), int(_mine_spin.value))
	apply_settings.emit(spec, _color)
	close_requested.emit()

func _set_color(c: Color) -> void:
	_color = c
	_color_swatch.color = c

# ---- 手柄导航 ----
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("move_down"):
		_goto(_sel + 1)
	elif event.is_action_pressed("move_up"):
		_goto(_sel - 1)
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("action_a"):
		_activate()
	elif event.is_action_pressed("action_b"):
		close_requested.emit()

func _goto(i: int) -> void:
	_sel = wrapi(i, 0, _controls.size())
	_controls[_sel].grab_focus()

func _adjust(dir: int) -> void:
	var c = _controls[_sel]
	if c is SpinBox:
		c.value += dir
	elif c == _color_swatch or c == _color_btn:
		_color_idx = wrapi(_color_idx + dir, 0, PALETTE.size())
		_set_color(PALETTE[_color_idx])

func _activate() -> void:
	var c = _controls[_sel]
	if c == _apply_btn:
		_on_apply()
	elif c == _close_btn:
		close_requested.emit()
	elif c == _color_btn:
		c.get_popup().popup()   # 手柄按 A 弹完整调色板
