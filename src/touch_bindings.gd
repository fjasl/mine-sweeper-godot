extends Node
class_name TouchBindings

## 触摸 → 鼠标的映射层（**触控板模式**）。故意放在插件之外：
## addons/touch_gestures 是通用的"触摸 → 语义信号"，本文件是游戏专用的
## "语义信号 → 一个鼠标能做的所有事"。
##
## 模型（把手机屏幕当触控板）：
##   单指拖动          = 相对移动指针（带增益与加速）
##   单指轻点          = 左键点击
##   双击后按住拖动    = **左键按住拖动**（触控板经典 idiom，用来拖滑块/色轮）
##   单指长按          = 右键点击
##   双指拖动          = 平移视角（等价"按住鼠标中键拖动"）
##   双指捏合          = 缩放
##   双指轻点/长按     = **不产生任何点击**（双指是"平移/捏合"的操作手型，
##                       顺带点一下不该等价于左键或右键）
##
## 两个前提：
##  1) project.godot 的 [input_devices] 里必须保持
##       pointing/emulate_mouse_from_touch=false
##     **不要打开它**。它做的是"手指按下 = 在手指位置产生一个鼠标事件"，
##     与这里"指针位置才是唯一真相、点击永远发生在指针处"是两套坐标模型，
##     同时开着会互相打架(同一次触摸被解释成两次点击、位置还不同)。
##  2) **指针位置由本节点自己持有**，不去读 Viewport.get_mouse_position()：
##     合成的鼠标事件不会改变引擎记录的鼠标位置，读它只会读到 0。
##     所有合成事件都显式带上本节点算出来的 position。
##
## 平台：**只在移动平台启用**。桌面端(含带触摸屏的 Windows)整个触摸层不运行 ——
## 桌面开发要验证手势，不要打开"总是"，而是挂
## addons/touch_gestures/mouse_to_touch.gd(鼠标→假触摸)，它不经过引擎那条模拟通道。
## 判定见 is_touch_enabled()，PointerCursor 也用它，两处不会走偏。

@export var gestures: TouchGestures
@export var cam: GameCamera
## 移动端的可见指针（桌面留空也行，系统光标已经在显示）
@export var pointer: PointerCursor

@export_group("指针手感")
## 手指移动 1 像素 → 指针移动多少像素
@export var pointer_gain := 1.6
## 加速强度：0 = 不加速；1 = 达到参考速度时增益翻倍。手感主要靠这两个数
@export var pointer_accel := 0.8
## 加速的参考速度（像素/秒）
@export var accel_ref_speed := 1600.0

@export_group("行为")
## true = 轻点直接落在手指处（更省事）；
## false = 严格触控板：点击永远发生在指针处。默认严格
@export var tap_at_touch_point := false
## 双击间隔（秒），也决定"双击后按住拖动"的窗口
@export var double_tap_sec := 0.3

@export_group("调试")
@export var debug_log := true

@export_group("平台")
## 只在移动平台(手机/平板)启用触摸层。
## **桌面端刻意不接受触摸输入**：桌面触摸屏的输入会被完全忽略，走系统鼠标。
## 开发时想用鼠标验证手势，不要打开这里的"总是"，
## 而是挂 addons/touch_gestures/mouse_to_touch.gd(鼠标→假触摸)，那条通道与
## emulate_mouse_from_touch 无关，不需要动 project.godot。
@export_enum("仅移动平台", "总是") var input_mode: int = MODE_POCKET_ONLY

enum { MODE_POCKET_ONLY, MODE_ALWAYS }

## 触摸层是否应当启用。**本方法是"该不该有触摸输入"的唯一判定**：
## PointerCursor 也调用它，于是"指针是否接管"与"手势层是否运行"不可能走偏。
static func is_touch_enabled() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android")

## 指针位置（视口逻辑坐标）—— 本节点是它的唯一真值
var pointer_pos := Vector2.ZERO

var _enabled := false                 ## 本次运行的平台判定结果
var _ready_ok := false
var _pending_move := Vector2.ZERO     ## 本帧累计的手指位移(在 _process 里统一应用)
var _last_tap_ms := -999999
var _raw_owned := false               ## 本次触摸的按键已由"双击按住"那一支负责
var _held := false                    ## 左键当前是否按住
var _touch_index := -1                ## 当前负责指针的那根手指(-1 = 没有)
var _panning := false                 ## pan_drag 是否已合成按下
var _last_pinch := 1.0

func _ready() -> void:
	# 平台门控放在最前面：桌面端本节点不接线、不合成事件、不碰指针、不碰相机，
	# 等于"触摸层不存在"。
	_enabled = (input_mode == MODE_ALWAYS) or is_touch_enabled()
	if not _enabled:
		set_process(false)
		set_process_unhandled_input(false)
		_log("桌面平台：触摸层已禁用(系统鼠标接管)")
		return

	if gestures == null:
		gestures = get_parent().get_node_or_null("TouchGestures") as TouchGestures
	if cam == null:
		cam = get_parent().get_node_or_null("Camera2D") as GameCamera
	if pointer == null:
		pointer = get_parent().find_child("PointerCursor", true, false) as PointerCursor
	if gestures == null:
		push_warning("TouchBindings: 没找到 TouchGestures，映射不会生效")
		return
	_ready_ok = true

	# 指针从屏幕中心起步
	pointer_pos = get_viewport().get_visible_rect().size * 0.5
	_update_pointer()

	gestures.tap.tapped.connect(_on_tap)
	gestures.long_press.long_pressed.connect(_on_long_press)
	gestures.drag.drag_changed.connect(_on_drag_changed)
	gestures.drag.drag_ended.connect(_on_drag_ended)
	gestures.pinch.pinch_began.connect(_on_pinch_began)
	gestures.pinch.pinch_changed.connect(_on_pinch_changed)
	gestures.pinch.pinch_ended.connect(_on_pinch_ended)

func _process(delta: float) -> void:
	if not _enabled:
		return
	# 指针移动放在每帧统一应用：这样才有可靠的 dt 可以算速度(加速曲线用)，
	# 而且每帧只合成一个 MouseMotion，事件管线压力小得多。
	if _pending_move != Vector2.ZERO:
		var move := _pending_move
		_pending_move = Vector2.ZERO
		var speed := move.length() / maxf(delta, 0.0001)
		var gain := pointer_gain * (1.0 + pointer_accel * clampf(speed / accel_ref_speed, 0.0, 1.0))
		_move_pointer(move * gain)
	else:
		# 没有位移也要同步一次可见指针。
		# 本节点是 pointer_pos 的唯一真值，但显示端(_pos)是被"推"的：
		# 若只在手指移动时推，初始化顺序(本节点 _ready 早于 PointerCursor _ready)
		# 或任何一次漏推都会让"显示位置"和"逻辑位置"长期不一致。
		# 每帧对齐一次，两个位置就不可能分家。
		_update_pointer()

# ---- 原始触摸：只为"双击后按住拖动"这个 idiom ----
# 它必须靠按下/抬起事件来认：第二次按下如果紧接着拖动，就不会产生 tap 信号。

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not _ready_ok:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_finger_down(t.index)
		elif t.index == _touch_index:
			_on_finger_up()

func _on_finger_down(index: int) -> void:
	if _touch_index != -1:
		return                                  # 已有手指负责指针，后续手指交给手势层
	_touch_index = index
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms <= int(double_tap_sec * 1000.0):
		# 双击窗口内再次按下 → 立刻按住左键，之后拖动即"按住拖动"
		_raw_owned = true
		_held = true
		_send_button(pointer_pos, MOUSE_BUTTON_LEFT, true)
		_update_pointer()
		_log("hold left (double-tap idiom)")
	else:
		_raw_owned = false

func _on_finger_up() -> void:
	if _held:
		_held = false
		_send_button(pointer_pos, MOUSE_BUTTON_LEFT, false)
		_update_pointer()
		_log("release left")
	_touch_index = -1
	# _raw_owned 刻意不在这里清：同一帧稍后 tap 信号还会来，
	# 它要靠这个标志知道"这次点击已经由按住那一支负责过了"，避免重复点击。
	# 它会在下一次"窗口外的按下"里被清掉。

# ---- 单指拖动：移动指针；双指拖动：平移视角 ----

func _on_drag_changed(delta: Vector2, _total: Vector2, fingers: int) -> void:
	if fingers >= 2:
		_pan_camera(delta)
		return
	_pending_move += delta                      # 单指：交给 _process 统一应用(带加速)

func _on_drag_ended(_total: Vector2, fingers: int) -> void:
	if fingers >= 2:
		_end_pan()

func _move_pointer(delta: Vector2) -> void:
	var rect := get_viewport().get_visible_rect()
	pointer_pos = (pointer_pos + delta).clamp(rect.position, rect.end)
	_update_pointer()
	# 每次都通知引擎指针在哪：光标(黄框)要跟着走；按住时还要带按键掩码，
	# 这样 UI 的滑块/色轮才拖得动。
	_send_motion(pointer_pos, Vector2.ZERO, MOUSE_BUTTON_MASK_LEFT if _held else 0)

func _update_pointer() -> void:
	if pointer:
		pointer.set_pointer(pointer_pos, &"drag" if _held else &"normal")

# ---- 点击：轻点=左键，长按=右键（都发生在指针处） ----

func _on_tap(pos: Vector2, fingers: int) -> void:
	# 多指轻点 = 插旗（等价右键）。
	# 插件刻意把"手指数"带出来交给调用方决定(tap.gd 注释)：双指是"平移/捏合"的
	# 操作手型，顺手点一下正好用来插旗，省得去够右上角。
	#
	# **不要动指针**：触控板模型下双指手势期间指针是不动的，插旗就插在指针当前
	# 所在格。曾经这里把 pointer_pos 挪到落点，结果是指针每次双指点击都突变。
	if fingers >= 2:
		_fire_action(&"action_b", true)
		_fire_action(&"action_b", false)
		_last_tap_ms = Time.get_ticks_msec()
		_log("flag at pointer %s (multi-finger tap, fingers=%d)" % [pointer_pos, fingers])
		return
	if _raw_owned:
		# 这次触摸的按下/抬起已经由"双击按住"那一支发过了，别再点一次
		_last_tap_ms = Time.get_ticks_msec()
		return
	var at := pointer_pos
	# 单指轻点且允许"直接落点"时，先把指针挪到手指处再点
	if tap_at_touch_point:
		pointer_pos = pos
		_update_pointer()
		at = pos
	_click(at, MOUSE_BUTTON_LEFT)
	_last_tap_ms = Time.get_ticks_msec()

func _on_long_press(pos: Vector2, fingers: int) -> void:
	if _held:
		return                                  # 左键按住期间不理会长按
	# 多指长按同多指轻点：插旗（同样不动指针）
	if fingers >= 2:
		_fire_action(&"action_b", true)
		_fire_action(&"action_b", false)
		_log("flag at pointer %s (multi-finger long press, fingers=%d)" % [pointer_pos, fingers])
		return
	var at := pos if tap_at_touch_point else pointer_pos
	_click(at, MOUSE_BUTTON_RIGHT)

## 合成一次完整点击(先定位、再按下、再抬起)
func _click(at: Vector2, button: MouseButton) -> void:
	_send_motion(at)
	_send_button(at, button, true)
	_send_button(at, button, false)
	_log("click %s at %s" % ["R" if button == MOUSE_BUTTON_RIGHT else "L", at])

## 指针当前位置(**屏幕/视口逻辑坐标**)。触控板模式下它是唯一真值，
## 棋盘/相机的世界坐标都要从这里换算。
func pointer_screen_pos() -> Vector2:
	return pointer_pos

## 由外部按屏幕位移推动指针(方向键 / 手柄 dpad 用)。
## 指针是唯一真相，所以"十字键移动"也走同一条路：推动指针，黄框自然跟上，
## 不需要第二个光标状态。桌面端本节点未接管指针时它是空操作。
func nudge_pointer(delta: Vector2) -> void:
	if not _enabled:
		return
	var rect := get_viewport().get_visible_rect()
	pointer_pos = (pointer_pos + delta).clamp(rect.position, rect.end)
	_update_pointer()
	_send_motion(pointer_pos, delta, MOUSE_BUTTON_MASK_LEFT if _held else 0)

## 本节点是否真的在管指针(桌面端门控关掉时为 false，
## 调用方应回退到引擎的真鼠标位置)
func is_tracking_pointer() -> bool:
	return _enabled and _ready_ok

## 屏幕(视口)坐标 → 世界坐标(显式、单一出处)。
## 合成事件按**屏幕坐标**发送，谁需要世界坐标谁调这个函数 —— 这样就不必去猜
## 引擎对合成事件到底做了哪一层视图变换。
func to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

# ---- 双指拖动 = 平移（等价按住鼠标中键拖动） ----

func _pan_camera(delta: Vector2) -> void:
	if cam == null:
		return
	if not _panning:
		_panning = true
		_fire_action(&"pan_drag", true)          # 相机靠这个动作锁存"正在拖"
	_send_motion(gestures.tracker.centroid(), delta)

func _end_pan() -> void:
	if _panning:
		_panning = false
		_fire_action(&"pan_drag", false)
		_log("pan end")

# ---- 双指捏合 = 缩放 ----

func _on_pinch_began(_center: Vector2) -> void:
	_last_pinch = 1.0

func _on_pinch_changed(factor: float, center: Vector2) -> void:
	if cam == null or is_zero_approx(factor):
		return
	# 识别器给的 factor 是"相对本次捏合基准"的比例；直接反复应用会**指数放大**，
	# 所以取"本次相对上次"的增量再喂给相机。
	var step := factor / _last_pinch
	# 消费端也过一道死区：识别器那边已经滤掉大部分噪声，这里再挡掉残留的
	# 亚像素级增量。阈值直接取自 TouchConfig，避免两处各写一个魔数。
	# (没挂 config 的场景用 0.01 兜底)
	var dead := 0.01
	if gestures != null and gestures.config != null:
		dead = gestures.config.pinch_deadzone_ratio * 0.5
	if absf(step - 1.0) < dead:
		return
	_last_pinch = factor
	cam.zoom_by(step, center)
	_log("pinch factor=%.3f step=%.4f" % [factor, step])

func _on_pinch_ended(total_factor: float) -> void:
	_last_pinch = 1.0
	_log("pinch end total=%.3f" % total_factor)

# ---- 合成事件的小工具 ----

func _send_motion(pos: Vector2, relative := Vector2.ZERO, mask := 0) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = relative
	e.button_mask = mask
	Input.parse_input_event(e)

func _send_button(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if (pressed and button == MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(e)

## 用 InputEventAction 而不是 Input.action_press()：后者只改 Input 的状态、
## **不经过视口事件管线**，而 board / 面板都是在 _unhandled_input 里读事件的 —— 收不到。
func _fire_action(action: StringName, pressed := true) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)

func _log(msg: String) -> void:
	if debug_log:
		print("[touch] ", msg)
