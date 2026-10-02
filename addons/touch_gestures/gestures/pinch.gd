extends TouchGesture

## 捏合（≥2 指）。用 tracker.spread()（各手指到重心的平均距离）当尺度，
## 所以三指/四指天然可用，不需要另写一份公式。
##
## 转移表：
##   idle     ──手指数 ≥2 且 spread 有效──► pinching，发 pinch_began
##   pinching ──每帧──► factor 逐帧累乘，变化够大才发 pinch_changed
##   pinching ──手指数 < 2──► 发 pinch_ended(累计 factor)，回 idle
##
## 约定：
##  - **factor 是相对"本次捏合开始时"的累计比例**（1.0 = 没变），不是增量。
##    调用方一般写成 zoom = 起始缩放 * factor。
##  - factor 用**逐帧累乘**（factor *= 本次spread / 上次spread）而不是
##    "spread / 基准"：这样加指/减指导致基准失效时，比例仍然连续、不会跳。
##  - 用 spread 而不是"两指间距"：好处是多指通用；代价是它对"两指平行移动"不敏感
##    —— 那正是 drag 的活。两者**同时触发是正常的**（重心在动、间距没变时
##    drag 有输出而 factor 恒为 1），这正是地图类 App 的手感。

signal pinch_began(center: Vector2)
signal pinch_changed(factor: float, center: Vector2)
signal pinch_ended(total_factor: float)

var _factor := 1.0          ## 相对本次捏合开始的累计比例
var _last_spread := 0.0     ## 上一次采样到的 spread

func _init() -> void:
	id = &"pinch"

func reset() -> void:
	super()
	_factor = 1.0
	_last_spread = 0.0

func on_touch_began(_point: TouchPoint) -> void:
	if tracker.count() >= 2 and not active:
		_begin()
	# 已经有 2 指时再加指：只重设采样基准，比例保持连续（在 update 里做）

func on_touch_ended(_point: TouchPoint) -> void:
	if tracker.count() < 2:
		if active:
			active = false
			pinch_ended.emit(_factor)
		_factor = 1.0
		_last_spread = 0.0
		return
	# 仍然 ≥2 指（减指但没减到 1）→ 重设采样基准，比例继续
	_last_spread = tracker.spread()

func update(_delta: float) -> void:
	if tracker.count() < 2:
		return
	var s := tracker.spread()
	if s <= 0.0:
		return
	if not active:
		_begin()
		return
	# 死区：spread 相对**上次输出值**的变化不到阈值就当噪声，直接丢。
	# 关键在"不动基准" —— 旧写法把基准更新放在输出之后，噪声会累积到阈值
	# 再一次性放出去，表现就是双指平移时画面一点点抽缩放。
	# 用相对比例而不是绝对像素：噪声幅度与手指间距成正比。
	if absf(s - _last_spread) / _last_spread < config.pinch_deadzone_ratio:
		return
	_factor *= s / _last_spread              # 逐帧累乘 → 天然连续
	_last_spread = s
	pinch_changed.emit(_factor, tracker.centroid())

func _begin() -> void:
	_factor = 1.0
	_last_spread = tracker.spread()
	active = true
	pinch_began.emit(tracker.centroid())
