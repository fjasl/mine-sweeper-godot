extends RefCounted

## 单根手指的状态。由 TouchTracker 持有。
##
## 纯数据对象：不依赖场景树、不读 InputEvent、不发信号。
## 所有位置都是**视口逻辑坐标**。
##
## 为什么把 moved_max / held_sec 记在这里而不是各手势自己算：
## 判定"是不是轻点"要用到"这次按下期间离起点最远走了多少"，
## 每个手势各算一遍必然写出不一样的 bug。

var index := -1                  ## 手指编号（来自 InputEventScreenTouch.index）
var start_pos := Vector2.ZERO    ## 按下时的位置
var pos := Vector2.ZERO          ## 当前位置
var delta := Vector2.ZERO        ## 相对上一次 move_to 的位移
var moved_max := 0.0             ## 相对起点的最大位移（判定轻点用）
var start_ms := 0                ## 按下时刻（Time.get_ticks_msec()）
var active := false              ## 是否还按着

func begin(i: int, p: Vector2, now_ms: int) -> void:
	index = i
	start_pos = p
	pos = p
	delta = Vector2.ZERO
	moved_max = 0.0
	start_ms = now_ms
	active = true

## 更新位置。delta 与 moved_max 都在这里维护，手势不用自己算。
func move_to(p: Vector2) -> void:
	delta = p - pos
	pos = p
	moved_max = maxf(moved_max, start_pos.distance_to(p))

func end() -> void:
	active = false
	delta = Vector2.ZERO

## 从按下到现在过了多少秒（now_ms 由调用方传入，方便测试时喂假时间）
func held_sec(now_ms: int) -> float:
	return float(now_ms - start_ms) / 1000.0
