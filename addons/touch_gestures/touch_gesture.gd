extends RefCounted
class_name TouchGesture

## 所有手势识别器的基类，也是**给使用者扩展的接口**（自己加手势就继承它）。
##
## 照这些约定写，识别逻辑就能脱离场景树单测：
##  - 纯逻辑对象（RefCounted），不做任何场景树操作
##  - 只依赖 tracker（手指状态）与 config（阈值），**不读 InputEvent**
##  - 自己的信号自己声明，由 TouchGestures 负责驱动
##  - 所有状态必须能在 reset() 里一键清干净（手指全抬起 / 失焦 / 切后台）

const TouchPoint := preload("res://addons/touch_gestures/touch_point.gd")
const TouchTracker := preload("res://addons/touch_gestures/touch_tracker.gd")

## 唯一标识，供 TouchGestures.is_active(&"tap") 查询。子类在 _init() 里设置。
var id: StringName = &""

var tracker: TouchTracker
var config: TouchConfig

## 是否**正在进行中**。连续手势（drag/pinch）在 began 时置 true、ended 时置 false；
## 离散手势（tap/long_press）不用维护它 —— 它们没有"持续"这个状态。
## 调用方用它做互斥，例如"捏合进行中就不响应点击"。
var active := false

func setup(t: TouchTracker, c: TouchConfig) -> void:
	tracker = t
	config = c
	reset()

## 回到干净状态。子类覆写时**必须调用 super()**。
func reset() -> void:
	active = false

# ---- 以下钩子由 TouchGestures 驱动，按需覆写 ----

## 有手指按下。注意 tracker 此时**已经**包含这根手指。
func on_touch_began(_point: TouchPoint) -> void:
	pass

## 手指移动。tracker 状态已是最新。
func on_touch_moved(_point: TouchPoint) -> void:
	pass

## 手指抬起。此时 tracker **已经移除**这根手指（所以 count() == 0 表示全部抬起），
## 但 point 参数仍带着它最后的完整数据（起点 / 最大位移 / 按下时刻）——
## "是不是轻点"这类判定必须用这些数据，不能去 tracker 里找（已经没了）。
func on_touch_ended(_point: TouchPoint) -> void:
	pass

## 每帧一次。连续手势在这里发 changed；离散手势在这里做超时判定。
func update(_delta: float) -> void:
	pass

## 当前时间戳（毫秒）。抽成方法是为了测试时能覆写成假时间，让超时判定可确定复现。
func now_ms() -> int:
	return Time.get_ticks_msec()
