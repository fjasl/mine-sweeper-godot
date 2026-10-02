extends RefCounted

## 活跃手指集合 —— 所有手势的共同地基。
##
## 手势只读这里的状态，不直接读 InputEvent。这样识别逻辑可以脱离场景树单测：
## 造几个 ScreenTouch/ScreenDrag 喂进 feed() 就能验证。
##
## centroid() / spread() 特意放在这里，而不是让"捏合""双指拖动""旋转"各算一遍 ——
## 几何查询只有一份实现，行为才一致。

const TouchPoint := preload("res://addons/touch_gestures/touch_point.gd")

## index → TouchPoint
var _points: Dictionary[int, TouchPoint] = {}
## 按下顺序（老 → 新）。用数组而不是靠字典顺序，保证"最早按下的那根"是确定的。
var _order: Array[int] = []

## 喂一个事件。返回 true 表示这是触摸事件、已被本层接管。
## 注意：本方法**只更新状态**，不通知手势 —— 通知由 TouchGestures 负责，
## 因为通知时机（先更新还是先通知）会影响到识别器读到什么。
func feed(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_begin(t.index, t.position)
		else:
			_end(t.index)
		return true
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_move(d.index, d.position)
		return true
	return false

func _begin(index: int, pos: Vector2) -> void:
	var p := TouchPoint.new()
	p.begin(index, pos, Time.get_ticks_msec())
	_points[index] = p
	if not _order.has(index):
		_order.append(index)

func _move(index: int, pos: Vector2) -> void:
	var p: TouchPoint = _points.get(index)
	if p:
		p.move_to(pos)

func _end(index: int) -> void:
	var p: TouchPoint = _points.get(index)
	if p:
		p.end()
	_points.erase(index)
	_order.erase(index)

## 一键清空（失焦 / 切后台 / 收到 canceled 时用）
## 不清的话，系统漏发抬起事件会让手指"永远按着"。
func clear() -> void:
	_points.clear()
	_order.clear()

func count() -> int:
	return _points.size()

func has(index: int) -> bool:
	return _points.has(index)

## 取某根手指；不存在返回 null
func get_point(index: int) -> TouchPoint:
	return _points.get(index)

## 按按下顺序返回所有活跃手指编号（老 → 新）
func indices() -> Array[int]:
	return _order.duplicate()

## 指定手指的当前位置；不存在返回 ZERO
func pos_of(index: int) -> Vector2:
	var p: TouchPoint = _points.get(index)
	return p.pos if p else Vector2.ZERO

## 所有活跃手指的重心。捏合中心、双指拖动都用它。
func centroid() -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for i in _order:
		sum += _points[i].pos
	return sum / float(_points.size())

## 所有手指到重心的**平均距离**。捏合用它当尺度。
## 用"平均半径"而不是"两指间距"，是为了将来三指也能用同一套公式。
func spread() -> float:
	if _points.size() < 2:
		return 0.0
	var c := centroid()
	var sum := 0.0
	for i in _order:
		sum += c.distance_to(_points[i].pos)
	return sum / float(_points.size())
