extends Control
class_name GameOverPanel

## 结算弹窗。**皮肤换成 UI 模板(res://ui/)，对外契约不变** ——
##   play_again / show_result(won) / hide_result() 一字不改，
##   所以 main.gd 与 ui.tscn 都不用动；要回退只要 git checkout 本文件。
##
## 与设置抽屉用同一套模板皮肤(ui/themes/base_theme.tres)与字体，
## 两个弹层不再一个新一个旧。

signal play_again

const UI_THEME := preload("res://ui/themes/base_theme.tres")

var _label: Label
## "再来一次"按钮。要留引用：隐藏时必须显式 release_focus()。
var _again_btn: Button
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 本节点是**铺满全屏**的 Control，而 Control 默认 mouse_filter = STOP，
	# 一个全屏 STOP 会把全屏的鼠标/触摸事件吃掉，事件到不了 _unhandled_input
	# —— 表现就是"失败弹窗一出，触控板指针就彻底不动"。
	# 放行本节点与下面所有纯容器，只让卡片和按钮吃事件。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI_THEME
	_build_ui()
	hide()


func _build_ui() -> void:
	# 半透明遮罩。必须是 IGNORE：它铺满整屏，默认的 STOP 会把全屏事件吃掉。
	# 遮罩上没有可点的东西，所以"点任意处关闭"本来就不提供 —— 只认卡片上的按钮。
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 居中容器同样铺满整屏，也要放行；只有内部的 PanelContainer 与按钮保持 STOP，
	# 于是"点卡片按钮"照常有效。
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 模板的面板样式(深紫 + 淡青描边 + 圆角 12 + 投影)，内边距 20 来自样式盒
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	vb.add_child(_label)

	_again_btn = Button.new()
	_again_btn.text = "再来一次"
	_again_btn.custom_minimum_size = Vector2(0, 42)
	_again_btn.focus_mode = Control.FOCUS_ALL
	_again_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vb.add_child(_again_btn)
	_again_btn.pressed.connect(func(): play_again.emit())


func show_result(won: bool) -> void:
	_label.text = "恭喜你赢了" if won else "输了"
	show()
	modulate.a = 0.0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)   # 渐变出现

	# 让"再来一次"拿到焦点，手柄 A 直接重开。
	# 注意反面：Button 默认 focus_mode = FOCUS_ALL，一旦持焦，A(内置 ui_accept)
	# 就会被 GUI 当成"按下这个按钮"并消费掉，永远到不了棋盘的 _unhandled_input
	# —— 表现就是"手柄 A 一直触发重开、翻不开格子"。所以隐藏时必须还回焦点。
	_again_btn.grab_focus()


func hide_result() -> void:
	# **必须先还焦点再隐藏**：隐藏的 Control 不会自动释放焦点，
	# 否则弹窗收起之后 A 仍被这个隐形按钮吃掉，棋盘永远收不到 action_a。
	if _again_btn != null and _again_btn.has_focus():
		_again_btn.release_focus()
	_kill_tween()
	hide()

## 反复 show_result 会叠出多个淡入 tween，它们同时改 modulate:a 会互相打断；
## 淡出中被 hide_result 收掉时也要停，否则回调在已隐藏状态下还会跑。
func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
