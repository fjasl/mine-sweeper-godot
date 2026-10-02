extends TouchGesture

## 轻点（单指/多指）。本文件是**其它手势的模板**，照它写就行。
##
## 转移表：
##   idle    ──第 1 指按下──► pending
##   pending ──任意一指位移超 tap_slop，或时长超 tap_max_sec──► canceled（等全部抬起后回 idle）
##   pending ──全部抬起且未被取消──► 发 tapped(pos, fingers)，回 idle
##
## 两个刻意的设计：
##  - **手指数由参数带出**，不写进手势名 —— 双指轻点也是 tapped(pos, 2)，
##    由调用方决定"双指轻点算插旗还是算别的"。写死手指数，将来三指就得改库。
##  - 长按不在这里发 —— 那是 long_press.gd 的活。本类只负责"没超时、没怎么动"。
##
## TODO: 双击。需要在 tapped 之后保留一个 double_tap_sec 的时间窗，
##       窗口内再来一次且位置相近才算 double_tapped。

signal tapped(pos: Vector2, fingers: int)

var _fingers := 0        ## 本次按下期间出现过的最大手指数
var _pending := false    ## 是否还处在"可能是轻点"的暧昧状态
var _start_ms := 0

func _init() -> void:
	id = &"tap"

func reset() -> void:
	super()
	_fingers = 0
	_pending = false
	_start_ms = 0

func on_touch_began(_point: TouchPoint) -> void:
	if _fingers == 0:
		_start_ms = now_ms()          # 第 1 指按下时起算
		_pending = true
	_fingers = maxi(_fingers, tracker.count())

func update(_delta: float) -> void:
	if not _pending:
		return
	# 超时 → 放弃（长按是 long_press.gd 的事）
	if now_ms() - _start_ms > int(config.tap_max_sec * 1000.0):
		_pending = false
		return
	# 任意一根手指位移超限 → 放弃（拖动/捏合接管）
	var slop := config.px(config.tap_slop_ratio)
	for i in tracker.indices():
		var p: TouchPoint = tracker.get_point(i)
		if p and p.moved_max > slop:
			_pending = false
			return

func on_touch_ended(point: TouchPoint) -> void:
	if tracker.count() > 0:
		return                        # 还有手指按着 —— 多指抬起是分次到达的，必须等全部抬起
	if _pending:
		tapped.emit(point.pos, _fingers)
	_fingers = 0
	_pending = false
