extends Resource
class_name TouchConfig

## 手势阈值集中配置。
##
## 硬约定：所有"距离"阈值都以**归一化比例**表达（相对屏幕短边），由 px() 换算成像素。
## 用像素当阈值的话，换台高分屏就完全不能用了 —— 这是通用性的硬要求。
##
## 用法：TouchGestures 会在 _ready 与视口尺寸变化时调用 bind_screen()。

@export_group("轻点 / 长按")
## 位移超过这个比例就不算轻点了（相对屏幕短边）
@export var tap_slop_ratio := 0.02
## 按住超过这个时长就不算轻点（秒）
@export var tap_max_sec := 0.35
## 按住不动多久算长按（秒）
@export var long_press_sec := 0.5
## 两次轻点的最大间隔，超过就不算双击（秒）
@export var double_tap_sec := 0.3

@export_group("拖动 / 捏合")
## 位移超过这个比例才开始算拖动（相对屏幕短边）
@export var drag_slop_ratio := 0.015
## 两指距离变化小于这个比例就不算捏合（防抖，相对屏幕短边）
@export var pinch_min_ratio := 0.005
## 捏合死区：spread 相对**上次输出值**变化小于这个比例就当作噪声，不输出。
## 这是"双指平移时画面轻微缩放抖动"的主开关。
##
## 可以放心往大调，因为它同时是"最大误差"：锚点只在输出时推进，
## 所以画面缩放与手指真实比例之间最多差这么多（0.03 = 3%，肉眼不可辨）。
## 手指静止时 spread 的呼吸噪声通常就在这条线以下。
@export var pinch_deadzone_ratio := 0.03

## 当前视口尺寸（视口逻辑坐标）。由 bind_screen() 更新。
var screen_size := Vector2(1280, 720)

## 视口尺寸变化时调用（也用于首次初始化）
func bind_screen(size: Vector2) -> void:
	screen_size = size

## 归一化比例 → 像素。以屏幕**短边**为基准，保证横竖屏表现一致。
func px(ratio: float) -> float:
	return minf(screen_size.x, screen_size.y) * ratio
