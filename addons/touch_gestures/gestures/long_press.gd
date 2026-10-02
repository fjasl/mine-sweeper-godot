extends TouchGesture

## 长按（单指/多指）。按住不动超过 long_press_sec 时发出**一次**。
##
## 转移表：
##   idle    ──第 1 指按下──► waiting（起计时）
##   waiting ──任意一指位移超 tap_slop，或全部抬起──► idle（不触发）
##   waiting ──按住到 long_press_sec 且位移未超限──► 发 long_pressed，转 fired
##   fired   ──全部抬起──► idle（不重复触发）
##
## 与 tap 的关系：两者都在"按下 → 抬起"这一段里判定，但**互不干扰** ——
## tap 只看"超没超时、动没动"，长按只看"按住够久且没动"。
## 同一段按下也可能两个都不发（比如按了很久之后才开始移动）。
##
## 注意：**long_press_sec 必须大于 tap_max_sec**（TouchConfig 里默认 0.5 > 0.35）。
## 否则同一个"按住"会先触发长按、再在抬手时被判成轻点，变成两个动作。

signal long_pressed(pos: Vector2, fingers: int)

var _waiting := false       ## 还在等"按住够久"
var _fired := false         ## 本次按下已经发过长按（不再重复发）
var _start_ms := 0
var _fingers := 0

func _init() -> void:
	id = &"long_press"

func reset() -> void:
	super()
	_waiting = false
	_fired = false
	_start_ms = 0
	_fingers = 0

func on_touch_began(_point: TouchPoint) -> void:
	if _fingers == 0:
		# 第 1 指按下：起算
		_start_ms = now_ms()
		_waiting = true
		_fired = false
	_fingers = maxi(_fingers, tracker.count())

func on_touch_moved(_point: TouchPoint) -> void:
	_cancel_if_moved()

func update(_delta: float) -> void:
	if not _waiting or _fired:
		return
	_cancel_if_moved()
	if not _waiting:
		return
	if now_ms() - _start_ms >= int(config.long_press_sec * 1000.0):
		_fired = true
		active = true          # "长按已触发、手指仍按住"——供调用方忽略后续移动
		long_pressed.emit(tracker.centroid(), _fingers)

func on_touch_ended(_point: TouchPoint) -> void:
	# 多指抬起是分次到达的：等全部抬起再清
	if tracker.count() > 0:
		return
	reset()

## 只要动了就作废（挪动手指说明用户想拖/滑，不是在长按）
func _cancel_if_moved() -> void:
	if _fired or not _waiting:
		return
	var slop := config.px(config.tap_slop_ratio)
	for i in tracker.indices():
		var p: TouchPoint = tracker.get_point(i)
		if p and p.moved_max > slop:
			_waiting = false
			return
