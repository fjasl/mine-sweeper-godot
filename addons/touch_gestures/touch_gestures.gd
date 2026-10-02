extends Node
class_name TouchGestures

## 触摸手势层。挂在场景里接收 ScreenTouch / ScreenDrag，驱动各识别器。
##
## **挂载位置很重要**：_unhandled_input 按场景树**反序**传播（越靠后的节点越先拿到），
## 所以本节点要排在"想优先于谁"的那个节点**之后**。例如要抢在 Background/Board 之前，
## 就放在 Background 之后的兄弟位置（和 Camera2D 同级即可）。

const TouchTracker := preload("res://addons/touch_gestures/touch_tracker.gd")
const TouchPoint := preload("res://addons/touch_gestures/touch_point.gd")
const TapGesture := preload("res://addons/touch_gestures/gestures/tap.gd")
const LongPressGesture := preload("res://addons/touch_gestures/gestures/long_press.gd")
const DragGesture := preload("res://addons/touch_gestures/gestures/drag.gd")
const PinchGesture := preload("res://addons/touch_gestures/gestures/pinch.gd")

## 阈值配置；留空会自动 new 一份默认值（想调参就建个 .tres 拖进来）
@export var config: TouchConfig

## 是否消费多指事件（set_input_as_handled）。
## 单指事件刻意**不消费** —— 让它们继续走完事件管线（谁是消费者由上层决定）。
##
## 本项目（mine-sweeper）已把引擎的触摸转鼠标关掉
## （project.godot 的 [input_devices] pointing/emulate_mouse_from_touch=false），
## 单指语义由 res://touch_bindings.gd 自行合成鼠标事件接管；
## 本插件不依赖那条通道，单指依然照常推进各识别器。
@export var consume_multitouch := true

var tracker: TouchTracker
var tap: TapGesture
var long_press: LongPressGesture
var drag: DragGesture
var pinch: PinchGesture

var _all: Array[TouchGesture] = []

## 触摸手势层是否启用。**默认自动判定：只在移动平台启用**。
## 桌面端(含带触摸屏的 Windows)不跑识别器、不跟踪手指、不消费事件，
## 免得和系统鼠标抢输入。
## 想强开(含桌面)就在 Inspector 里显式设一次；自动判定只在**没人设过**时生效。
## 桌面调试用本插件自带的 mouse_to_touch.gd(鼠标→假触摸，**直接调 feed_event**，
## 不受本开关影响)——但那个脚本会先看本开关，所以强开时它也一并生效。
const AUTO := 2
@export var enabled := AUTO

func _init() -> void:
	# 识别器在**构造期**就建好：这样别的节点（例如游戏的映射层）在自己的
	# _ready 里就能连信号，不受"谁是先 ready 的兄弟"影响。
	# 但 setup() 要留到 _ready —— 那时代码里 / Inspector 里的 config 才最终生效
	# （导出属性是在 _init 之后才赋值的）。
	if config == null:
		config = TouchConfig.new()
	tracker = TouchTracker.new()
	tap = TapGesture.new()
	long_press = LongPressGesture.new()
	drag = DragGesture.new()
	pinch = PinchGesture.new()
	# 用 assign 填 typed 数组，避免"Array 赋给 Array[TouchGesture]"的类型问题
	_all.assign([tap, long_press, drag, pinch])

func _ready() -> void:
	# 没人在 Inspector 里设过 → 按平台自动判定(这里是运行期，"mobile" 特征才准确)
	if enabled == AUTO:
		enabled = OS.has_feature("mobile") or OS.has_feature("android")
	if not enabled:
		set_process(false)
		set_process_unhandled_input(false)
		return
	config.bind_screen(_screen_size())
	for g in _all:
		g.setup(tracker, config)

	get_viewport().size_changed.connect(_on_viewport_resized)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if not feed_event(event):
		return
	# 只在多指时消费：单指放行给排在后面的节点(本项目是 TouchBindings)
	if consume_multitouch and tracker.count() >= 2:
		get_viewport().set_input_as_handled()

## 直接喂一个触摸事件，返回是否被本层接管。
##
## _unhandled_input 只是它的一个入口 —— 桌面测试通道与单元测试都可以**直接调它**，
## 绕过场景树输入管线：没有帧延迟、行为可确定、不需要造场景。
func feed_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# 先留一份引用：tracker 移除这根手指后，point 对象里的数据仍然完整
		var before: TouchPoint = tracker.get_point(t.index)
		tracker.feed(event)
		if t.pressed:
			_notify_began(tracker.get_point(t.index))
		else:
			_notify_ended(before)
		return true
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		tracker.feed(event)
		_notify_moved(tracker.get_point(d.index))
		return true
	return false

func _process(delta: float) -> void:
	if not enabled:
		return
	for g in _all:
		g.update(delta)

func _notification(what: int) -> void:
	# 失焦/切后台时系统可能不发抬起事件 → 必须清干净，否则手指会"永远按着"
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear()

## 清空所有手指与识别器状态
func clear() -> void:
	tracker.clear()
	for g in _all:
		g.reset()

func touch_count() -> int:
	return tracker.count()

## 某个手势是否正在进行（调用方做互斥用，例如"捏合中不响应点击"）
func is_active(id: StringName) -> bool:
	for g in _all:
		if g.id == id and g.active:
			return true
	return false

func _notify_began(p: TouchPoint) -> void:
	if p == null:
		return
	for g in _all:
		g.on_touch_began(p)

func _notify_moved(p: TouchPoint) -> void:
	if p == null:
		return
	for g in _all:
		g.on_touch_moved(p)

func _notify_ended(p: TouchPoint) -> void:
	if p == null:
		return
	for g in _all:
		g.on_touch_ended(p)

func _on_viewport_resized() -> void:
	config.bind_screen(_screen_size())

## 视口可见尺寸（视口逻辑坐标）。
## 注意：本节点 extends Node，**没有** CanvasItem.get_viewport_rect()，
## 所以必须走 get_viewport().get_visible_rect()。
func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size
