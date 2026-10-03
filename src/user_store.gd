extends Node
class_name UserStore

## 本机的少量持久化状态：**英雄榜**(三档最短通关秒数) + **用户偏好**(光标颜色)
## + **棋盘规格**(上次用的难度，开机照它铺盘) + **触屏手感**(指针/轻点/拖动阈值)。
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
const SECTION_BOARD := "board"
const KEY_COLS := "cols"
const KEY_ROWS := "rows"
const KEY_MINES := "mines"
## 手感参数按字段名逐个存(见 TouchFeel.KEYS)，config.cfg 里是可读可手改的
const SECTION_TOUCH := "touch"

## 档位名 → 最短秒数。没有记录的档位不在字典里。
var _best: Dictionary = {}
## 用户选中的光标颜色。默认取面板色板第一格(与界面一致)。
var _cursor_color: Color = SettingsPanel.PALETTE[0]
## 上次用的棋盘规格。初值就用 BoardSpec 自己的默认值(= 原版初级)，本文件不再抄一份 9/9/10。
##
## 定位澄清：它存的是**存档**，不是棋盘的第二个真相 —— 对局中的真相永远只在 MineField
## 那三个 int 上(见 BoardSpec 的类注释)。本字段只在"开机读一次 / 改难度写一次"过手，
## 并且对外一律给新建的值对象(get_board_spec)，别让调用方拿到这里这份去改。
var _board: BoardSpec = BoardSpec.new()
## 触屏手感。初值 = TouchFeel 的基线(= 那几个参数的唯一出处)，本文件不再抄一份数字。
## 与 _board 同样只作"存档"用：生效中的值在 TouchBindings / TouchGestures.config 上。
var _touch: TouchFeel = TouchFeel.defaults()


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
	# 棋盘规格：三个 int 各自兜底，读完再统一过一遍 clamped() ——
	# 存档被手改坏、或跨版本换了约束(见 BoardSpec 的 MIN/MAX)时，
	# 只会被夹回合法范围，绝不会让开局拿到一个非法尺寸
	var b := BoardSpec.make(
		int(cm.get_value(SECTION_BOARD, KEY_COLS, _board.cols)),
		int(cm.get_value(SECTION_BOARD, KEY_ROWS, _board.rows)),
		int(cm.get_value(SECTION_BOARD, KEY_MINES, _board.mine_count)))
	_board = b.clamped()
	# 触屏手感：按 TouchFeel.KEYS 逐项读，缺项用基线兜底，读完同样过一遍 clamped()。
	# 用 get/set 按字段名取值，所以以后加参数只要往 KEYS 里加一项，这里不用动
	var base := TouchFeel.defaults()
	for k in TouchFeel.KEYS:
		_touch.set(k, cm.get_value(SECTION_TOUCH, String(k), base.get(k)))
	_touch = _touch.clamped()


func _save() -> void:
	var cm := CoreSystem.config_manager
	# 注意 set_value **不会**自动落盘，必须显式 save_config()(插件源码 config_manager.gd:108/73)
	cm.set_value(SECTION_BEST, KEY_BEST, _best)
	cm.set_value(SECTION_UI, KEY_COLOR, _cursor_color)
	cm.set_value(SECTION_BOARD, KEY_COLS, _board.cols)
	cm.set_value(SECTION_BOARD, KEY_ROWS, _board.rows)
	cm.set_value(SECTION_BOARD, KEY_MINES, _board.mine_count)
	for k in TouchFeel.KEYS:
		cm.set_value(SECTION_TOUCH, String(k), _touch.get(k))
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


# ---- 棋盘规格(上次用的难度) ----

## 上次用的规格。返回**新建的值对象**，与 Board.spec() 同一套约定：
## 真相永远在 MineField 上，这里给的只是一份快照，别存起来当状态
func get_board_spec() -> BoardSpec:
	return BoardSpec.make(_board.cols, _board.rows, _board.mine_count)


## 记一次难度。校验/夹取只走 BoardSpec.clamped()(规格约束的唯一出处)，
## 本方法只负责"过一手存档"，不判断合法性
func set_board_spec(s: BoardSpec) -> void:
	if s == null:
		return
	var c := s.clamped()
	if c.equals(_board):
		return                          # 没变就不落盘，和 set_cursor_color 同一套节制
	_board = c
	_save()


# ---- 触屏手感 ----

## 上次调好的手感。返回**新建的值对象**，调用方改不到存档里那一份
func get_touch_feel() -> TouchFeel:
	return _touch.clamped()


## 记一次手感。夹取与范围约束只走 TouchFeel.clamped()(唯一出处)，
## 本方法只负责"过一手存档"。**拖动滑条的过程中不要每帧调这里** ——
## 面板是拖动时实时生效、松手/收起抽屉时才落盘，见 SettingsPanel 的说明
func set_touch_feel(f: TouchFeel) -> void:
	if f == null:
		return
	var c := f.clamped()
	if c.equals(_touch):
		return                          # 没变就不落盘
	_touch = c
	_save()
