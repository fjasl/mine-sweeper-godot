extends Node

## 桌面测试通道：把鼠标事件翻译成"假触摸"，直接喂给 TouchGestures。
##
## **为什么需要它**：没有这条通道，每加一个手势都要上真机验证，开发效率会崩。
## 建议在写第一个手势之前就把它跑通。
##
## 单指：鼠标左键 = 手指 0
## 双指：按住 second_finger_key（默认 Shift）时，额外造一根手指 1，
##       位置 = 鼠标位置 + second_finger_offset。
##       - 移动鼠标 → 两指重心跟着走 → 可验证**双指拖动**
##       - 按住 [ / ] → 实时改变两指间距 → 可验证**捏合**
##
## 挂载：和 TouchGestures 一起放在 Background 之后的兄弟位置，
##       这样它会先于 Board 拿到鼠标事件并消费掉，测试期间不干扰棋盘。
##
## 注意：本通道会 set_input_as_handled() 吃掉鼠标左键，所以**只在开发时启用**。

## 目标手势层；留空会自动在父节点的子节点里找第一个 TouchGestures
@export var gestures: TouchGestures
@export var enabled := true

@export_group("双指模拟")
## 按住它时额外造一根手指（用来测双指手势）
@export var second_finger_key: Key = KEY_SHIFT
## 两根手指的间距向量（长度可被 [ / ] 实时调整）
@export var second_finger_offset := Vector2(140, 0)
## 按住 [ / ] 时每秒改变多少像素间距
@export var offset_speed := 260.0

var _down := false
## index → 上一次的位置（用来填 InputEventScreenDrag.relative）
var _last := {}

func _ready() -> void:
	if gestures == null:
		gestures = _find_gestures()

func _find_gestures() -> TouchGestures:
	var parent := get_parent()
	if parent == null:
		return null
	for n in parent.get_children():
		if n is TouchGestures:
			return n
	return null

## [b]前提[/b]：目标 TouchGestures 必须已启用 —— 它默认按平台自动判定(只在移动平台为真)，
## 所以桌面上要用本通道，先在 Inspector 里把它的 enabled 显式勾上。
## 勾上只表示"允许手势层运行"；系统触摸事件的接收仍受平台影响，
## 而本通道是**直接调 feed_event**，因此不会让桌面的系统鼠标输入被抢走。
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or gestures == null or not gestures.enabled:
		return

	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return
		_down = b.pressed
		_emit_touch(0, b.position)
		if _two_fingers():
			_emit_touch(1, _finger1_pos())
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _down:
		var m := event as InputEventMouseMotion
		_emit_drag(0, m.position)
		if _two_fingers():
			_emit_drag(1, _finger1_pos())
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# 用 [ / ] 实时调两指间距来模拟捏合。
	# 调完必须立刻补发一次 drag，否则要等鼠标动一下才生效。
	if not enabled or gestures == null or not gestures.enabled or not _down or not _two_fingers():
		return
	var step := 0.0
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		step -= offset_speed * delta
	elif Input.is_key_pressed(KEY_BRACKETRIGHT):
		step += offset_speed * delta
	if is_zero_approx(step):
		return
	var length := clampf(second_finger_offset.length() + step, 16.0, 480.0)
	second_finger_offset = second_finger_offset.normalized() * length
	_emit_drag(1, _finger1_pos())

func _two_fingers() -> bool:
	return Input.is_key_pressed(second_finger_key)

## 手指 1 的位置 = 鼠标当前位置 + 间距向量
func _finger1_pos() -> Vector2:
	var base: Vector2 = _last.get(0, Vector2.ZERO)
	return base + second_finger_offset

func _emit_touch(index: int, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = _down
	_last[index] = pos
	gestures.feed_event(e)

func _emit_drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	var prev: Vector2 = _last.get(index, pos)
	e.relative = pos - prev
	e.velocity = Vector2.ZERO
	_last[index] = pos
	gestures.feed_event(e)
