extends TouchGesture

## 拖动（单指/双指共用，手指数由 fingers 参数告诉调用方）。
##
## 转移表：
##   idle     ──按下──► pending
##   pending  ──重心位移超 drag_slop──► dragging（发 drag_began）
##   dragging ──每帧──► 发 drag_changed(delta, total, fingers)
##   dragging ──全部抬起──► 发 drag_ended(total, fingers)，回 idle
##
## 约定：
##  - delta 是"上一次 update 到现在的重心位移"，total 是"相对起点的总位移"。
##    要"跟着手走"就累加 delta；要"从起点算偏移"就用 total。
##  - **手指数变化（加指/减指）时必须重设基准**，否则重心会跳变、画面会闪。
##    这是多指拖动最容易出的 bug：第二根手指一落下，重心立刻偏移半格，
##    不重设基准就会看到画面猛地一跳。
##  - 用**重心**而不是某一根手指，多指才有一致语义。

signal drag_began(pos: Vector2, fingers: int)
signal drag_changed(delta: Vector2, total: Vector2, fingers: int)
signal drag_ended(total: Vector2, fingers: int)

var _pending := false          ## 按下但还没到达拖动阈值
var _dragging := false         ## 已经在拖
var _fingers := 0
var _last_centroid := Vector2.ZERO    ## 上一次 update 时的重心(算 delta)
var _start_centroid := Vector2.ZERO   ## 本段基准重心(算 total 与判 slop)
var _total := Vector2.ZERO            ## 累计位移(手指数变化时保留，保证连续)

func _init() -> void:
	id = &"drag"

func reset() -> void:
	super()
	_pending = false
	_dragging = false
	_fingers = 0
	_last_centroid = Vector2.ZERO
	_start_centroid = Vector2.ZERO
	_total = Vector2.ZERO

func on_touch_began(_point: TouchPoint) -> void:
	if tracker.count() == 1:
		# 从 0 指到 1 指：开一段新的拖动候选
		_pending = true
		_dragging = false
		_fingers = 1
		_start_centroid = tracker.centroid()
		_last_centroid = _start_centroid
		_total = Vector2.ZERO
	else:
		_rebase()

func on_touch_ended(_point: TouchPoint) -> void:
	if tracker.count() == 0:
		if _dragging:
			drag_ended.emit(_total, _fingers)
		reset()
		return
	_rebase()

## 把基准挪到当前重心：手指数变化后必须做，否则重心跳变会被当成一次位移
func _rebase() -> void:
	_start_centroid = tracker.centroid()
	_last_centroid = _start_centroid
	_fingers = maxi(1, tracker.count())

func update(_delta: float) -> void:
	if tracker.count() == 0:
		return
	# 兜底：万一某次加/减指没走到钩子里
	if _fingers != tracker.count():
		_rebase()

	var c := tracker.centroid()
	var step := c - _last_centroid
	_last_centroid = c

	if not _dragging:
		if not _pending:
			return
		if _start_centroid.distance_to(c) < config.px(config.drag_slop_ratio):
			return
		# 越过阈值：正式开始拖
		_dragging = true
		active = true
		_total = c - _start_centroid
		drag_began.emit(c, _fingers)
		return                                  # 本帧不再发 changed，避免同一位移算两遍

	_total += step
	drag_changed.emit(step, _total, _fingers)
