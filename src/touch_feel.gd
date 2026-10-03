extends Resource
class_name TouchFeel

## 触屏手感的一组参数：**指针 / 轻点 / 拖动与捏合** 三路。
##
## 定位与 BoardSpec 完全一样：**跨模块传递的值对象，也是约束(范围)的唯一出处**。
## 真相在"当前生效的那一份"上 —— 也就是 TouchBindings 的那几个 @export 与
## TouchGestures.config 这个 TouchConfig 资源；本类只是过路的信使，不要存起来当状态。
##
## **默认值就是手感基线**：它同时是设置面板滑条的初值、以及「恢复默认」的去处。
## 开机时 main 会用这里默认值(或存档)覆盖一次 TouchConfig，所以
## **本文件是这几个参数的唯一出处** —— src/touch_config.tres 里那份手调值只是初始载体。
##
## 为什么不收这几个：
##   · TouchConfig.long_press_sec / TouchConfig.double_tap_sec —— 游戏里根本不读
##     (长按的处理函数整段被注释掉了、插件的 double_tap 手势未实现)，
##     收进来只会是"调了没反应"的假开关；
##   · TouchBindings.tap_at_touch_point —— 曾经在面板里有一栏「轻点落在手指处」，
##     那一栏已按需求去掉。它仍然留在 TouchBindings 上(@export)，
##     要改去 main.tscn 的 Inspector 改，本类的默认值不受它影响。

## 字段名清单：**存档读写**按它走(缺项用基线兜底)，加参数只要往这里加一项。
## 面板里滑条的**排列顺序不由它决定** —— 那是 settings_panel 的 TOUCH_GROUPS 管的，
## 两边都指向同一批字段名，所以加参数是"这里加一项 + 那边归个组"。
## 刻意不写 Array[StringName] 类型标注：常量数组带类型标注在部分 4.x 版本上会
## 解析失败，而这里除了遍历与 String(k) 之外不需要类型
const KEYS := [
	&"pointer_gain",
	&"pointer_accel",
	&"tap_slop_ratio",
	&"tap_max_sec",
	&"drag_slop_ratio",
	&"pinch_deadzone_ratio",
	&"double_tap_sec",
]

# 取值范围：面板滑条的 min/max 与 clamped() 都从这里取，界面不自带第二份副本
const GAIN_MIN := 0.5
const GAIN_MAX := 4.0
const ACCEL_MIN := 0.0
const ACCEL_MAX := 2.0
const TAP_SLOP_MIN := 0.010
const TAP_SLOP_MAX := 0.100
const TAP_SEC_MIN := 0.20
const TAP_SEC_MAX := 0.60
const DRAG_SLOP_MIN := 0.005
const DRAG_SLOP_MAX := 0.060
const PINCH_DEAD_MIN := 0.005
const PINCH_DEAD_MAX := 0.100
const DOUBLE_TAP_MIN := 0.15
const DOUBLE_TAP_MAX := 0.60

## 手指移动 1 像素 → 指针移动多少像素。**手感最吃这一个**
@export var pointer_gain: float = 1.6
## 加速强度：0 = 不加速；1 = 达到参考速度时增益翻倍
@export var pointer_accel: float = 0.8
## 轻点容差(屏幕短边的比例)：位移超过它就不算轻点，改判成拖动
@export var tap_slop_ratio: float = 0.045
## 轻点时长上限(秒)：按住超过它就不再是轻点
@export var tap_max_sec: float = 0.45
## 拖动与双指平移的起始阈值(屏幕短边的比例)
@export var drag_slop_ratio: float = 0.015
## 捏合噪声死区：两指间距相对上次输出值的变化小于它就丢掉
@export var pinch_deadzone_ratio: float = 0.03
## 双击后按住拖动的识别窗口(秒)
@export var double_tap_sec: float = 0.3


## 基线(就是各字段的声明默认值)。「恢复默认」与"没有存档时用什么"都走这里
static func defaults() -> TouchFeel:
	return TouchFeel.new()


## 夹到合法范围。跨字段约束也在这里：轻点时长不能盖过双击窗口的下限，
## 否则一次"双击的第一下"会被判成需要等太久
func clamped() -> TouchFeel:
	var f := TouchFeel.new()
	f.pointer_gain = clampf(pointer_gain, GAIN_MIN, GAIN_MAX)
	f.pointer_accel = clampf(pointer_accel, ACCEL_MIN, ACCEL_MAX)
	f.tap_slop_ratio = clampf(tap_slop_ratio, TAP_SLOP_MIN, TAP_SLOP_MAX)
	f.tap_max_sec = clampf(tap_max_sec, TAP_SEC_MIN, TAP_SEC_MAX)
	f.drag_slop_ratio = clampf(drag_slop_ratio, DRAG_SLOP_MIN, DRAG_SLOP_MAX)
	f.pinch_deadzone_ratio = clampf(pinch_deadzone_ratio, PINCH_DEAD_MIN, PINCH_DEAD_MAX)
	f.double_tap_sec = clampf(double_tap_sec, DOUBLE_TAP_MIN, DOUBLE_TAP_MAX)
	return f


## 是否与另一份相同(存档"没变就不落盘"的判据)。
## 逐项用 is_equal_approx：滑条是浮点，直接 == 会因为最后一位的抖动反复落盘
func equals(other: TouchFeel) -> bool:
	if other == null:
		return false
	return is_equal_approx(pointer_gain, other.pointer_gain) \
		and is_equal_approx(pointer_accel, other.pointer_accel) \
		and is_equal_approx(tap_slop_ratio, other.tap_slop_ratio) \
		and is_equal_approx(tap_max_sec, other.tap_max_sec) \
		and is_equal_approx(drag_slop_ratio, other.drag_slop_ratio) \
		and is_equal_approx(pinch_deadzone_ratio, other.pinch_deadzone_ratio) \
		and is_equal_approx(double_tap_sec, other.double_tap_sec)


## 给面板用的"范围表"：字段名 → [min, max, step, 小数位, 显示缩放, 标题, 后缀]。
## 界面据此建滑条，不再自己写一份范围/标题，改参数只改这一个字典。
static func row_specs() -> Array:
	return [
		# key, 标题, 后缀, min, max, step, 小数位, 显示缩放
		[&"pointer_gain", "灵敏度", "", GAIN_MIN, GAIN_MAX, 0.05, 2, 1.0],
		[&"pointer_accel", "加速", "", ACCEL_MIN, ACCEL_MAX, 0.05, 2, 1.0],
		[&"tap_slop_ratio", "轻点容差", " %", TAP_SLOP_MIN, TAP_SLOP_MAX, 0.005, 1, 100.0],
		[&"tap_max_sec", "轻点时长", " s", TAP_SEC_MIN, TAP_SEC_MAX, 0.01, 2, 1.0],
		[&"double_tap_sec", "双击窗口", " s", DOUBLE_TAP_MIN, DOUBLE_TAP_MAX, 0.01, 2, 1.0],
		[&"drag_slop_ratio", "拖动阈值", " %", DRAG_SLOP_MIN, DRAG_SLOP_MAX, 0.005, 1, 100.0],
		[&"pinch_deadzone_ratio", "捏合死区", " %", PINCH_DEAD_MIN, PINCH_DEAD_MAX, 0.005, 1, 100.0],
	]
