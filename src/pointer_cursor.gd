extends Node2D
class_name PointerCursor

## 局内鼠标指针（桌面与移动端**统一显示同一个**），使用 Asset/cursors 里的素材。
##
## 素材来源：Asset/Lightech Editor Cursor（Windows .cur 光标包，已改名成英文）。
## .cur **不是** Godot 能 import 的格式，所以挑出来的几张已转成 PNG 放在 Asset/cursors/。
## _ready 里用 load() 兜底而不是 preload()，避免 Godot 还没导入完这批新 PNG 时报"无法预载资源"。
##
## 关于"看起来有锯齿"：
##   项目全局是 default_texture_filter=0（最近邻，为了像素画不糊），
##   但窗口尺寸不是 1280x720 的整数倍时，32x32 的指针会被最近邻放大成硬锯齿。
##   这里**按节点覆盖**成线性过滤（smooth 开关），指针平滑、其余部分仍是像素风。
##
## 它和棋盘那个黄框的关系（不是两个光标）：
##   本节点 = 指针（对应鼠标箭头）
##   CursorOverlay = "指针所在的那一格"（目标指示）
## 桌面上本来就是这两个一起显示，现在只是把系统箭头换成了自绘的。
##
## 挂载：放进一个 CanvasLayer（例如 UILayer），放在它**最后一个**子节点，
##       这样它画在所有 UI 之上；在 CanvasLayer 里也不会被相机缩放带着跑。

@export var tex_normal: Texture2D      ## 普通箭头（pointer.png）
@export var tex_drag: Texture2D        ## 按住拖动中（move.png）
@export var tex_flag: Texture2D        ## 插旗模式（cross.png，暂未被调用，留给以后）

## 每帧的**热点**（对齐点）。数值是从 .cur 文件头里直接读出来的真实值，不是估的：
##   pointer.cur  32x32 hotspot=(6,6)
##   move.cur     32x32 hotspot=(15,16)
##   cross.cur    32x32 hotspot=(15,16)
## 三帧热点不同，所以要逐帧查表 —— 统一成一个值的话，切换形态时指针会跳几个像素。
const HOTSPOT := {
	&"normal": Vector2(6, 6),
	&"drag": Vector2(15, 16),
	&"flag": Vector2(15, 16),
}

## 平台：**只在移动平台显示并由 TouchBindings 驱动**。
## 桌面端本节点完全不接管：系统光标照常显示，本节点不画、不藏光标、不轮询鼠标。
## 判定复用 TouchBindings.is_touch_enabled()，与手势层同一个真相，不会走偏。
@export_group("外观")
## 指针显示缩放。**不要**用节点的 scale 来缩小：那会把位置一起缩放、热点就跑偏了。
## 这个字段只缩放贴图与热点偏移，尖端始终对齐 _pos。
@export var pointer_scale := 1.0
## 指针单独使用平滑过滤（覆盖项目的最近邻设置）。关掉就是硬边像素感
@export var smooth := true

## 跟随真鼠标(触摸平台恒为 false：那里没有系统鼠标，位置由手势层喂)
var follow_system_mouse := true
## 是否隐藏系统光标(只在触摸平台做，桌面必须保留系统光标)
var hide_system_cursor := true

var _frame: StringName = &"normal"
var _pos := Vector2.ZERO

func _ready() -> void:
	# 桌面端：什么都不做，把光标留给系统。
	# (以前靠 hide_system_cursor / show_on_desktop 两个开关约束，配错就会出现
	#  "系统箭头和局内箭头同时显示"或"一个光标都没有"，现在由平台硬判定)
	if not TouchBindings.is_touch_enabled():
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return

	follow_system_mouse = false     # 触摸平台没有系统鼠标，位置只能由手势层驱动

	# Godot 还没导入这批 PNG 时 preload 会直接报错，所以这里兜底加载
	if tex_normal == null:
		tex_normal = load("res://Asset/cursors/pointer.png")
	if tex_drag == null:
		tex_drag = load("res://Asset/cursors/move.png")
	if tex_flag == null:
		tex_flag = load("res://Asset/cursors/cross.png")

	# 只覆盖这一个节点的过滤方式，项目全局仍然是最近邻
	texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR if smooth
			else CanvasItem.TEXTURE_FILTER_NEAREST)

	visible = true
	# 层级不在这里管：本节点是 ui.tscn 模板里 UILayer 的**最后一个子节点**，
	# 同画布内"后添加者后画"，所以它画在按钮与面板之上。脚本不参与置顶。
	# 只有贴图确实加载成功才藏系统光标：否则"系统光标藏了、局内指针也没画出来"，
	# 一个光标都没有，反而更容易被误判成输入坏了。
	if hide_system_cursor and texture_of(&"normal") != null:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if follow_system_mouse:
		_pos = get_viewport().get_mouse_position()
	set_process(follow_system_mouse)
	queue_redraw()

func _process(_delta: float) -> void:
	# 只在 follow_system_mouse 为真时运行 —— 触摸平台恒为 false，所以这段不会跑。
	# 保留它是为了桌面开发时能"临时"让局内指针顶替系统光标。
	var p := get_viewport().get_mouse_position()
	if p != _pos:
		_pos = p
		queue_redraw()

## 由 TouchBindings 调用（只在触摸平台）。follow_system_mouse 为真时**只换形态、不动位置**。
## frame: "normal"（普通箭头）/ "drag"（按住拖动中）
## 每帧都会被调用，位置与形态都没变时直接返回，不做无谓重画。
func set_pointer(screen_pos: Vector2, frame: StringName = &"normal") -> void:
	var f := frame if HOTSPOT.has(frame) else &"normal"
	var moved := (not follow_system_mouse) and screen_pos != _pos
	if not moved and f == _frame:
		return
	_frame = f
	if moved:
		_pos = screen_pos
	queue_redraw()

func texture_of(frame: StringName) -> Texture2D:
	match frame:
		&"drag":
			return tex_drag
		&"flag":
			return tex_flag
		_:
			return tex_normal

func _draw() -> void:
	var tex := texture_of(_frame)
	if tex == null:
		return
	# 贴图按 hotspot 对齐到指针位置，并且两者一起缩放，所以尖端始终落在 _pos
	var hotspot: Vector2 = HOTSPOT[_frame]
	draw_texture_rect(tex, Rect2(_pos - hotspot * pointer_scale, tex.get_size() * pointer_scale), false)
