extends Node
class_name UserStore

## 本机的少量持久化状态：**英雄榜**(三档最短通关秒数) + **用户偏好**(光标颜色)。
##
## 后端用 CoreSystem 的 **config_manager**：它就是"键值 + 同步 ConfigFile"的形状，
## 实测能把 Color 与 Dictionary 原样往返，且不需要任何模块开关，正是这两个需求要的。
##
## 为什么英雄榜不走 CoreSystem 的 save_manager（同样实测可用）：那是"按节点组整体存 /
## 整体读"的存档机制 —— 没有键值/删键 API、存档目录只能经 ProjectSettings 改、
## 每次存盘是全量(含所有 saveable 节点)、默认 resource 策略还是主线程同步 IO。
## 为三个数字引入这套机制成本明显高于收益；config_manager 本来就能存一个 Dictionary，
## 所以记录与偏好都放它这里。
##
## **订正一条早先的错误结论**：我曾判断插件 save_system 编译不过，依据是
## `utils/async_io_manager.gd:14` 与 `save_system/save_format_strategy/resource_save_strategy.gd:3`
## 的 `const X = CoreSystem.Y`。实测在 4.7.2 下**它们完全正常**(会被解析成真脚本)；
## 报错只出现在 `--check-only` 模式，因为该模式不注册 autoload —— 是模式假象。
## 所以"不能用"的理由不成立：选 config_manager 是**按需求形状**选的，不是被迫的。

const SECTION_UI := "cursor"
const KEY_COLOR := "color"
const SECTION_BEST := "best_times"
const KEY_BEST := "list"

## 档位名 → 最短秒数。没有记录的档位不在字典里。
var _best: Dictionary = {}
## 用户选中的光标颜色。默认取面板色板第一格(与界面一致)。
var _cursor_color: Color = SettingsPanel.PALETTE[0]


func _ready() -> void:
	load_all()


func load_all() -> void:
	var cm := CoreSystem.config_manager
	cm.load_config()                    # 显式读一次，不依赖 autoload 的启动时序
	_best.clear()
	var saved: Variant = cm.get_value(SECTION_BEST, KEY_BEST, {})
	if saved is Dictionary:
		for key in (saved as Dictionary):
			_best[str(key)] = float(saved[key])
	var c: Variant = cm.get_value(SECTION_UI, KEY_COLOR, _cursor_color)
	if c is Color:
		_cursor_color = c


func _save() -> void:
	var cm := CoreSystem.config_manager
	# 注意 set_value **不会**自动落盘，必须显式 save_config()(插件源码 config_manager.gd:108/73)
	cm.set_value(SECTION_BEST, KEY_BEST, _best)
	cm.set_value(SECTION_UI, KEY_COLOR, _cursor_color)
	cm.save_config()


# ---- 英雄榜 ----

## 记一次通关。参数是**棋盘当前规格**与用时(秒，与棋盘 LED 同一套读法)。
## 返回被刷新的档位名；非预设尺寸或没破纪录返回空串。
func record(cols: int, rows: int, mines: int, seconds: float) -> String:
	var name := preset_name_for(cols, rows, mines)
	if name.is_empty():
		return ""
	var prev: float = _best.get(name, -1.0)
	if prev >= 0.0 and seconds >= prev:
		return ""                       # 没破纪录
	_best[name] = seconds
	_save()
	return name


## 这一规格属于哪一档预设；不属于任何一档返回空串。
static func preset_name_for(cols: int, rows: int, mines: int) -> String:
	for p in SettingsPanel.PRESETS:
		if int(p["cols"]) == cols and int(p["rows"]) == rows and int(p["mines"]) == mines:
			return str(p["name"])
	return ""


## 某一档的最短时间(秒)；没有记录返回 -1。
func best_for(name: String) -> float:
	return float(_best.get(name, -1.0))


## 给面板用的一张表：档位名 → 秒数(-1 表示还没记录)。
func snapshot() -> Dictionary:
	var out := {}
	for p in SettingsPanel.PRESETS:
		var n := str(p["name"])
		out[n] = best_for(n)
	return out


# ---- 用户偏好 ----

func get_cursor_color() -> Color:
	return _cursor_color


func set_cursor_color(c: Color) -> void:
	if c.is_equal_approx(_cursor_color):
		return                          # 没变就不落盘，免得每次"应用"都写一次文件
	_cursor_color = c
	_save()
