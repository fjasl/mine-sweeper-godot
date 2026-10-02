extends Control
class_name GameOverPanel

signal play_again

var _label: Label
## "再来一次"按钮。要留引用：隐藏时必须显式 release_focus()。
var _again_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 本节点是**铺满全屏**的 Control，而 Control 默认 mouse_filter = STOP，
	# 一个全屏 STOP 会把全屏的鼠标/触摸事件吃掉，事件到不了 _unhandled_input
	# —— 表现就是"失败弹窗一出，触控板指针就彻底不动"。
	# 放行本节点与下面所有纯容器，只让卡片和按钮吃事件。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()

func _build_ui() -> void:
	# 半透明遮罩。
	# 必须是 IGNORE：它铺满整屏，而 Control 默认的 STOP 会把全屏的鼠标/触摸事件
	# 全部吃掉，事件到不了 _unhandled_input —— 表现就是"一局结束后触控板指针推不动"。
	# 关掉它的 gui_input 之后，"点任意处关闭"也随之取消：本局已经结束，
	# 遮罩上没有任何可点的东西，所以改成只认面板上的"再来一次"按钮更合理
	# (想恢复"点任意处关闭"，见 hide_result 注释里的做法)。
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 居中面板。CenterContainer 同样铺满整屏，也要放行；只有它内部的
	# PanelContainer 与按钮保持 STOP，于是"点按钮"照常有效。
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	vb.add_child(_label)

	_again_btn = Button.new()
	_again_btn.text = "再来一次"
	vb.add_child(_again_btn)
	_again_btn.pressed.connect(func(): play_again.emit())

func show_result(won: bool) -> void:
	_label.text = "恭喜你赢了" if won else "输了"
	show()
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2)   # 渐变出现

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
	hide()
