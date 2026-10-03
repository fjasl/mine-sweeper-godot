extends Control
class_name SettingsPanel

## 设置抽屉。**皮肤换成 UI 模板(res://ui/)，交互契约与形态保持原样** ——
##   apply_settings / close_requested / set_restart_func / open / close 一字不改，
##   所以 main.gd 与 ui.tscn 都不用动；要回退只要 git checkout 本文件。
##
## 「以模板的风格为准」在这里的落地方式：
##   皮肤  ui/themes/base_theme.tres —— 深紫面板 + 淡青描边 + 12px 圆角 + 投影
##   字体  ui/fonts/base_font.tres（站酷快乐体），由主题带出来，不必逐个 Label 设
##   控件  ui/gameobjects/line_setting_slider（标题 + 滑条 + 数值）、segmentation_line（分段线）
##   尺寸  面板内边距 20、控件圆角 4、正文 16px —— 全部来自模板，本文件不自造样式
##
## **刻意不跟模板的一点：容器形态。** 模板 demo 是全屏 Tab 页，这里仍是原来那个
## 左半屏滑入抽屉。这次改的是"风格"，不是把游戏的交互形态换掉 —— 那属于另一个决定。
##
## 旧实现里吃过大亏的三个细节原样保留，别删：
##   1) 铺满屏幕的容器必须 mouse_filter = IGNORE，否则触控板指针推不动(事件被吃在半路)；
##   2) 隐藏前先还焦点，否则手柄 A 被隐形控件吃掉、棋盘永远收不到 action_a；
##   3) 重开前 kill 旧 Tween，否则它尾部挂的 hide 回调会把面板重新藏起来。

signal apply_settings(spec: BoardSpec, cursor_color: Color)
## 面板请求关闭(应用后 / 关闭按钮 / 手柄 B)。开关的意图归 main 的 _menu_open，
## 面板只提请求、不自己改。
signal close_requested

const UI_THEME := preload("res://ui/themes/base_theme.tres")
const ROW_SLIDER := preload("res://ui/gameobjects/line_setting_slider/line_setting_slider.tscn")
const ROW_SEGMENT := preload("res://ui/gameobjects/segmentation_line/segmentation_line.tscn")
const ROW_OPTION := preload("res://ui/gameobjects/line_setting_option_button/line_setting_option_button.tscn")
## 三个动作按钮的图标。模板只给了「齿轮 / 房子」两个字形，这三个是照模板同一套语言
## (纯白实心 + 圆头描边，200×200 视图框)在 Asset/ 里补画的，和 Asset/gear.svg 同处。
const ICON_APPLY := preload("res://Asset/icon_apply.svg")
const ICON_RESTART := preload("res://Asset/icon_restart.svg")
const ICON_CLOSE := preload("res://Asset/icon_close.svg")
## 动作按钮的皮肤。模板的 `Button/styles/*` **不在 base_theme 里**(那个主题只定义了
## HSlider / OptionButton / Panel / PopupMenu)，而是挂在模板 demo 的场景局部 Theme 上。
## 这张是从模板场景里原样抽出来的(见该文件头部注释)，所以按钮才有那层"内层 border"
## —— 那其实是 focus 样式盒的 3px 近白描边，即"当前被选中的按钮"。
const BTN_THEME := preload("res://ui/themes/button_theme.tres")
## 模板行标题用的字体(英雄榜的文字也用它，保证字形与面板其它文字一致)
const BASE_FONT := preload("res://ui/fonts/base_font.tres")

## 预设光标颜色(与界面重做前同一份色值，本轮只**重排顺序** + 补足到 24)。
## 顺序 = 色相：黄→橙→橙红→红→玫红→品红→紫→蓝紫→蓝→天蓝→青→蓝绿(第一行 12 格)，
## 第二行是余下的绿→黄绿→棕系→白→雪白→浅灰→中灰→石板灰→深灰→近黑→黑。
## **第 0 格仍是黄**，也就是原版默认的光标颜色，所以默认值没有变。
const PALETTE := [
	# 27 色 = 23 个等色相 + 4 个中性色。
	# 色相段：色相环 23 等分(步长 360/23 ≈ 15.65°)，S=0.7、V=1 恒定，只有色相在变。
	# 起点 51.43° 就是原「黄」的色相 → 第 0 格与原值逐位相同(存档默认值/图标注释都依赖它)。
	# 方向沿用原来的递减：黄→橙→红→玫红→品红→紫→蓝→青→绿→黄绿。
	# 中性段：白 1.00 → 浅灰 0.67 → 深灰 0.33 → 黑 0.00，sRGB 明度四等分。
	Color(1, 0.9, 0.3),      # 0   黄      H  51.4
	Color(1, 0.72, 0.3),     # 1   橙      H  35.8
	Color(1, 0.53, 0.3),     # 2   橙红    H  20.1
	Color(1, 0.35, 0.3),     # 3   红      H   4.5
	Color(1, 0.3, 0.43),     # 4   玫红    H 348.8
	Color(1, 0.3, 0.61),     # 5   桃红    H 333.2
	Color(1, 0.3, 0.8),      # 6   品红    H 317.5
	Color(1, 0.3, 0.98),     # 7   洋红    H 301.9
	Color(0.84, 0.3, 1),     # 8   紫      H 286.2
	Color(0.66, 0.3, 1),     # 9   蓝紫    H 270.6
	Color(0.47, 0.3, 1),     # 10  靛蓝    H 254.9
	Color(0.3, 0.31, 1),     # 11  蓝      H 239.3
	Color(0.3, 0.49, 1),     # 12  蔚蓝    H 223.6
	Color(0.3, 0.67, 1),     # 13  天蓝    H 208.0
	Color(0.3, 0.86, 1),     # 14  青蓝    H 192.3
	Color(0.3, 1, 0.96),     # 15  青      H 176.6
	Color(0.3, 1, 0.78),     # 16  碧绿    H 161.0
	Color(0.3, 1, 0.6),      # 17  翠绿    H 145.3
	Color(0.3, 1, 0.41),     # 18  绿      H 129.7
	Color(0.37, 1, 0.3),     # 19  草绿    H 114.0
	Color(0.55, 1, 0.3),     # 20  黄绿    H  98.4
	Color(0.73, 1, 0.3),     # 21  青柠    H  82.7
	Color(0.92, 1, 0.3),     # 22  柠檬黄  H  67.1
	Color(1, 1, 1),          # 23  白      中性 1.00
	Color(0.67, 0.67, 0.67), # 24  浅灰    中性 0.67
	Color(0.33, 0.33, 0.33), # 25  深灰    中性 0.33
	Color(0, 0, 0),          # 26  黑      中性 0.00
	Color(0, 0, 0, 0),       # 27  透明    斜线格，alpha=0
]

## 三档难度预设，数值照原版扫雷(初级 9x9 雷10 / 中级 16x16 雷40 / 高级 30x16 雷99)。
## 注意：本项目自带的默认值是 30x16 雷 **60**，并不是原版高级的 99 ——
## 所以开局时下拉框会正确落在「自定义」上，这不是 bug。
const PRESETS := [
	{"name": "初级", "cols": 9,  "rows": 9,  "mines": 10},
	{"name": "中级", "cols": 16, "rows": 16, "mines": 40},
	{"name": "高级", "cols": 30, "rows": 16, "mines": 99},
]

## 手柄操作下拉列表，需要 ui_up / ui_down / ui_accept / ui_cancel，
## 但本项目这四个动作里**一个手柄键位都没有**：十字键绑在 move_*、A/B 绑在
## action_a/action_b，而 ui_* 只留了键盘与摇杆轴(相机平移要用它们，见 camera_2d)。
## 而 PopupMenu 只认 ui_*，所以弹窗开着时手柄按什么都没反应。
##
## 做法：**弹窗活着的时候临时**把这四个手柄键位补进 ui_*，一关立刻摘掉。
##   - 只在弹窗存活期间存在；菜单开着时相机输入已被 main 关掉，不会顺手推走画面；
##   - 只摘自己加的那些(_pad_added)，项目原有绑定一个都不动。
## 另一个关键事实：弹窗一旦 popup，**输入路由就归它**(实测：弹窗开着时面板收不到
## 十字键，关着时收得到)，所以只能让弹窗自己认出手柄，没法由面板代它导航。
const POPUP_PAD := {
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
}

var _preset_opt: OptionButton
## 难度列表(面板内 Control)：绝对定位在难度值控件正下方，见 _make_preset_row
var _preset_list: PanelContainer
var _preset_open := false
## 列表展开时被高亮的那一项(手柄上下移动它，A 选中它)。展开时从当前档位起步。
var _preset_hl := 0
## 弹窗开着时临时补进 ui_* 的手柄键位(见 POPUP_PAD 的说明)，用来精确摘除
var _pad_added: Array[StringName] = []
## 写预设期间为 true：挡住 value_changed 回头的"反查预设"，
## 否则刚选中的档位会被自己写下去的值立刻改成「自定义」
var _syncing := false
## 抽屉里那摞面板占的**整块区域**(设置卡片 + 独立的按钮条，含中间那道缝)。
## 用来判断"鼠标点在菜单外面"(点外面就收起抽屉)：判据取整块而不是某一张卡片，
## 否则点在按钮条上(它在卡片之外)会被当成"点外面"而把抽屉关掉。
var _menu_area: Control
var _col_row: HBoxContainer
var _row_row: HBoxContainer
var _mine_row: HBoxContainer
var _apply_btn: Button
var _restart_btn: Button
var _close_btn: Button
var _palette_btns: Array[Button] = []
var _controls: Array = []
var _sel := 0
var _color: Color = PALETTE[0]
## 英雄榜：档位名 → 那一行的秒数 Label(数据由 main 通过 set_best_times 注入)
var _best_labels: Dictionary = {}

var _restart_func: Callable = Callable()
## 动画句柄：重开前必须先 kill，否则旧的 hide 回调会把面板藏起来
var _tween: Tween


func set_restart_func(callback: Callable) -> void:
	_restart_func = callback


## 安全网：弹窗存活期的接管(临时手柄键位 + 触摸转鼠标)**只该在弹窗活着时存在**。
## 万一 popup_hide 没发出来(弹窗被别的方式收掉)，下一帧就自己还原干净 ——
## 漏在全局的后果有两个，都不能接受：
##   - 临时键位漏掉 → 菜单关着时十字键会去推相机(本项目刻意避免的事)；
##   - 触摸转鼠标漏掉 → 会和虚拟光标那套自绘合成事件同时生效，一次点击变两次。
## 安全网已不需要：难度列表是面板内的 Control，展开期间由 _bind_pad_for_list()
## 补手柄键位、收起时立刻摘掉，没有"被别的方式偷偷收掉"的窗口生命周期问题。
func _ready() -> void:
	# 左半屏抽屉(与重做前一致)：宽 = 半屏，高 = 全屏，贴左
	anchor_left   = 0.0
	anchor_right  = 0.5
	anchor_top    = 0.0
	anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0
	# 本节点覆盖左半屏，自身是 Control，默认 STOP 会吃掉这半屏的事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 主题挂在根上，整棵子树继承(模板的做法是项目级 gui/theme/custom，
	# 这里刻意用节点级：不动 project.godot，旧面板以外的地方不受影响)
	theme = UI_THEME
	_build_ui()
	set_process(false)              # 安全网只在真有临时键位时跑，见 _process
	hide()


func _build_ui() -> void:
	# 留出边距，让模板面板的圆角与投影露得出来(贴边会被裁掉)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	# 抽屉里竖着叠两张面板：上面是设置卡片，下面是独立出来的按钮条。
	# 两张都用模板的面板样式盒(PanelContainer 走主题，不用手画)，
	# 中间留 12px 缝 —— 缝露出来，"它是独立的一张"才看得出来。
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	# PanelContainer 用的是模板的面板样式(深紫 + 淡青描边 + 圆角 12 + 投影，
	# 内边距 20 也来自样式盒，所以这里不再自己加 margin)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 卡片吃掉剩余高度：按钮条按自身内容高贴在抽屉底部
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(panel)
	# "菜单区域" = 这摞面板整体，点外面收起的判据取它(见 _unhandled_input)
	_menu_area = stack

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)

	vb.add_child(_make_segment("棋盘尺寸"))

	# 难度预设行(模板的下拉框控件)：选一档就把 列/行/雷 一起写下去
	vb.add_child(_make_preset_row())

	# 范围与跨字段约束一律取自 BoardSpec，界面不自带第二份副本
	# 滑条初值取自 BoardSpec 的默认值(= 原版初级)，不在本文件里另写一份。
	# **这份初值只是"还没有人来喂"时的兜底**：真正的当前规格由 main 每次拉开抽屉前
	# 经 set_spec() 注入(见该函数的说明)，所以它不再需要跟棋盘默认值永远保持一致。
	var def := BoardSpec.new()
	_col_row  = _make_slider_row("列数", " 列", BoardSpec.MIN_COLS, BoardSpec.MAX_COLS, def.cols)
	_row_row  = _make_slider_row("行数", " 行", BoardSpec.MIN_ROWS, BoardSpec.MAX_ROWS, def.rows)
	_mine_row = _make_slider_row("雷数", " 雷", 1, 999, def.mine_count)
	vb.add_child(_col_row)
	vb.add_child(_row_row)
	vb.add_child(_mine_row)
	# 列/行一变：先让雷数上限跟上(雷不能占满整盘)，再回显预设
	_slider_of(_col_row).value_changed.connect(_on_size_changed)
	_slider_of(_row_row).value_changed.connect(_on_size_changed)
	# 手改雷数也要回显预设(对不上任何一档就落到「自定义」)
	_slider_of(_mine_row).value_changed.connect(_refresh_preset_selection)
	_on_size_changed(0.0)

	vb.add_child(_make_segment("光标颜色"))
	vb.add_child(_make_palette())
	vb.add_child(_make_segment("扫雷英雄榜"))
	vb.add_child(_make_best_rows())

	# 三个动作按钮**不再塞在设置卡片里**，而是独立成下面一条面板。
	# 样式与卡片同源(同一个主题样式盒)，只把内边距收窄一点：
	# 这一条要的是"一条按钮"，不是"一张卡片"，20px 的内边距会把它撑得很胖。
	# 用 duplicate() 改既有样式盒，而不是在这里重画一遍模板的配色/描边/圆角。
	var actions := PanelContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 按钮条**收窄到刚好装下内容**：宽度 = 三个按钮宽 + 所有间隔 + 自身内边距，
	# 然后在母容器里相对上方卡片**横向居中**。
	# 上限天然就是上方卡片的宽度 —— 母容器(stack)本身被 MarginContainer 限成那么宽，
	# 收窄的子节点不可能比它更宽。
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 按钮皮肤(内层 border 的来源)挂在这一层，只作用于这条按钮条。
	# 不带字体：主题查找是**逐项**回落的，这里找不到 font 就继续往上层 base_theme 落。
	actions.theme = BTN_THEME
	stack.add_child(actions)
	var st := actions.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if st != null:
		st.content_margin_top = 10
		st.content_margin_bottom = 10
		st.content_margin_left = 14
		st.content_margin_right = 14
		actions.add_theme_stylebox_override("panel", st)

	var btns := HBoxContainer.new()
	btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btns.add_theme_constant_override("separation", 10)
	# 三个按钮按自身大小、在这条里**居中**；不横向撑满。
	# 按钮条(外层)的 x 范围仍由 MarginContainer 决定，与上方卡片逐像素对齐。
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(btns)

	_apply_btn = _make_button(ICON_APPLY, "应用：把当前设置写入棋盘")
	_apply_btn.pressed.connect(_on_apply)
	_restart_btn = _make_button(ICON_RESTART, "重开一局")
	_restart_btn.pressed.connect(_on_restart)
	_close_btn = _make_button(ICON_CLOSE, "关闭设置")
	_close_btn.pressed.connect(func(): close_requested.emit())
	btns.add_child(_apply_btn)
	btns.add_child(_restart_btn)
	btns.add_child(_close_btn)

	# 手柄可聚焦项，顺序 = 上下导航顺序
	_controls = [_preset_opt, _slider_of(_col_row), _slider_of(_row_row), _slider_of(_mine_row)]
	_controls.append_array(_palette_btns)
	_controls.append_array([_apply_btn, _restart_btn, _close_btn])
	for c in _controls:
		(c as Control).focus_mode = Control.FOCUS_ALL


# ---- 模板控件包装：把模板的设置行拿来用，不在本文件里重画样式 ----

## 分段线(模板控件)。title_show 打开后右侧会多一段线，标题居中
func _make_segment(title: String) -> HBoxContainer:
	var seg: HBoxContainer = ROW_SEGMENT.instantiate()
	seg.title = title
	seg.title_show = true
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return seg

## 标题 + 滑条 + 数值 的设置行(模板控件)。
## suffix 走模板组件的 end_text：它把数值标签拼成 "<值> 列" 这样。
## **必须在入树之前把 end_text 与 value 设好** —— 组件的 _ready 会读它们来初始化标签。
func _make_slider_row(title: String, suffix: String, mn: int, mx: int, val: int) -> HBoxContainer:
	var row: HBoxContainer = ROW_SLIDER.instantiate()
	row.get_node("LabelTitle").text = title
	var s: HSlider = row.get_node("HSlider")
	s.min_value = mn
	s.max_value = mx
	s.step = 1.0
	s.value = val
	s.focus_mode = Control.FOCUS_ALL
	row.end_text = suffix
	return row

func _slider_of(row: HBoxContainer) -> HSlider:
	return row.get_node("HSlider")


## 预设色板：**固定 12 列**的网格(单选 ButtonGroup，选中的多一圈白描边)。
## 色块的底就是颜色本身，所以样式盒是逐按钮覆盖的 —— 这是唯一没法靠主题解决的部分。
##
## 为什么不用 HFlowContainer：它是**按可用宽度**折行的，宽度不受约束时不会换成第二行，
## 而是把整个面板撑宽(加了 6 个颜色之后就是这样)。改成 GridContainer(columns=12) 之后
## 布局与面板宽度**互相独立**：永远是 12 + 12，面板宽度回到原来的 474px。
func _make_palette() -> Control:
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	grid.columns = 14
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in PALETTE.size():
		var c: Color = PALETTE[i]
		var normal := StyleBoxFlat.new()
		normal.bg_color = c
		normal.set_corner_radius_all(4)
		var selected := normal.duplicate() as StyleBoxFlat
		selected.border_width_left = 2
		selected.border_width_top = 2
		selected.border_width_right = 2
		selected.border_width_bottom = 2
		selected.border_color = Color(1, 1, 1, 0.9)

		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(34, 26)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "预设颜色 %d / %d" % [i + 1, PALETTE.size()]
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", normal)
		b.add_theme_stylebox_override("pressed", selected)
		b.add_theme_stylebox_override("focus", selected)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_color = c)
		grid.add_child(b)
		_palette_btns.append(b)
		if i == 0:
			b.button_pressed = true       # 默认选中第一格，_color 初值就是它
	return grid

## 英雄榜三行：档位名 + 最短秒数(没记录显示 "--")。
## 数值由 main 通过 set_best_times() 注入 —— 面板不认识存档，只负责显示。
func _make_best_rows() -> VBoxContainer:
	var box := VBoxContainer.new()
	for p in PRESETS:
		var nm := str(p["name"])
		var row := HBoxContainer.new()
		row.add_child(_best_label(nm, 90.0))
		var time_label := _best_label("--", 60.0)
		row.add_child(time_label)
		box.add_child(row)
		_best_labels[nm] = time_label
	return box

## 英雄榜里的文字：**用模板那一套字体**(和行标题同源，res://ui/fonts/base_font.tres)，
## 不用引擎默认字体 —— 否则"时间"那一列的字形会和面板其它文字明显不是一套。
func _best_label(text: String, min_w: float) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = BASE_FONT
	ls.font_size = 16
	l.label_settings = ls
	l.text = text
	l.custom_minimum_size = Vector2(min_w, 0)
	return l

## 注入本机记录(档位名 → 秒数，-1 表示无记录)。开机与每次破纪录后各调一次。
## 显示成**秒数**，与棋盘上 LED 的读法完全一致，避免出现两套时间语义。
func set_best_times(best: Dictionary) -> void:
	for nm in _best_labels:
		var sec := float(best.get(nm, -1.0))
		(_best_labels[nm] as Label).text = "--" if sec < 0.0 else str(int(sec))

## 注入已保存的光标颜色：既作为当前选中色，也让色板停在正确的那一格。
func set_cursor_color(c: Color) -> void:
	_color = c
	for i in _palette_btns.size():
		var on: bool = i < PALETTE.size() and PALETTE[i].is_equal_approx(c)
		_palette_btns[i].set_pressed_no_signal(on)

## 注入棋盘**当前**规格：三条滑条回到这一档，难度下拉回显对应档位(对不上任何一档
## 就落到「自定义」)。每次拉开抽屉之前由 main 喂一次。
##
## **为什么必须喂**：本面板从不主动问棋盘，滑条只活在自己这一份值上(见 _build_ui 里
## "滑条初值"那段)。不喂的后果是它会停在上一轮的值 —— 玩家拉开抽屉、一个控件都没动、
## 直接点「应用」，就把棋盘改成了那个旧规格，顺带把正在进行的局重开掉。
## 难度存档上线之后，这个坑从"碰不到"变成"每次开机都能碰到"：
## 存档里的档位和面板的兜底初值大概率不一致。
##
## 写法与 _on_preset_selected 完全一致：_syncing 挡住 value_changed 回头反查预设，
## 最后自己把下拉项定下来。语句顺序也不能换 —— 雷数上限必须在写雷数值之前先跟上，
## 否则大雷数会被旧上限夹掉。
func set_spec(spec: BoardSpec) -> void:
	if spec == null or _col_row == null:
		return                          # 还没 _build_ui()，没有控件可写
	var c := spec.clamped()
	_syncing = true
	_slider_of(_col_row).value = c.cols
	_slider_of(_row_row).value = c.rows
	_sync_mine_max()                    # 雷数上限先跟上，否则大雷数会被旧上限夹掉
	_slider_of(_mine_row).value = c.mine_count
	_syncing = false
	_refresh_preset_selection()         # 反查档位(这是回显，不发 item_selected)

## 图标按钮 —— 照模板 ButtonHome / ButtonSetting 的写法：
## 只放图标不放文字(icon_max_width 限高 + 图标居中 + 手型光标)，说明放 tooltip。
## 直接摆文字在这个皮肤里很突兀：模板的按钮都是"字形 + 底色"。
func _make_button(icon: Texture2D, tip: String) -> Button:
	var b := Button.new()
	b.icon = icon
	b.tooltip_text = tip
	b.add_theme_constant_override("icon_max_width", 22)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


# ---- 取值 / 提请求 ----

## 难度预设行。**显示仍用模板那个 OptionButton 本体**（主题里的圆角底与下拉箭头、
## 160 宽、展开、字号 14 全部原样继承，外观与原来完全一致），只是**不让它弹出自带菜单**
## —— 那个菜单是独立 Window，会吞触摸(虚拟光标冻住)、永远盖在主视口之上、点外面也关不掉。
## 展开/选择改由面板内的列表负责(_build_preset_list)。
##
## 怎么堵的：OptionButton 打开窗口的动作在 **C++ 的 pressed() 虚函数**里 ——
## 实测覆盖脚本的 _pressed()(那是给 GDScript 的 gdvirtual，并非同一个函数)与断开
## pressed 信号**都拦不住**，窗口照弹。所以改在**窗口真正显示之前**的同帧把它收起
## (about_to_popup → call_deferred hide)：既不会画出来，也不会留下抢焦点的窗口。
func _make_preset_row() -> HBoxContainer:
	var row: HBoxContainer = ROW_OPTION.instantiate()
	row.get_node("Label").text = "难度"
	_preset_opt = row.get_node("OptionButton")
	_preset_opt.clear()
	for p in PRESETS:
		_preset_opt.add_item(p["name"])
	_preset_opt.add_item("自定义")          # 索引 == PRESETS.size()，只是个状态
	_preset_opt.item_selected.connect(_on_preset_selected)
	# 自带菜单：弹出前同帧收起(理由见函数头)。它只是"关掉"这个副作用，
	# 外观、取值、键盘/手柄激活全部照旧；我接上的 _toggle_presets 是唯一的展开入口。
	var pop := _preset_opt.get_popup()
	pop.about_to_popup.connect(func() -> void: pop.hide.call_deferred())
	_preset_opt.pressed.connect(_toggle_presets)
	_build_preset_list()
	return row

## 列表本体：挂在 **SettingsPanel 根节点**下(不是容器里)，因为要绝对定位到值控件正下方，
## 而容器会强制排布子节点。挂在根上还顺便保证它画在所有行之上 —— 注意**不要**给
## z_index：那是画布内全局排序，会把 UILayer 里的虚拟光标一起压在下面。
func _build_preset_list() -> void:
	_preset_list = PanelContainer.new()
	_preset_list.visible = false
	_preset_list.mouse_filter = Control.MOUSE_FILTER_STOP   # 点在列表上不算"点外面"
	# 外框也用弹出菜单那一套面板底色(主题里 PopupMenu/styles/panel)，不自己配
	_preset_list.add_theme_stylebox_override("panel", UI_THEME.get_stylebox("panel", "PopupMenu"))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_preset_list.add_child(vb)
	for i in _preset_opt.item_count:
		vb.add_child(_make_preset_item(i))
	_sync_preset_marks()
	add_child(_preset_list)

## 单项：**照原来弹出菜单的样子做** —— 左边一个"复选框"图标 + 文字，悬停/按下用菜单的
## 高亮底色，平时透明(菜单项不是按钮)。素材与配色全部取自主题里 PopupMenu 那一组，
## 一处都不自创，所以观感和原来逐项一致。
func _make_preset_item(i: int) -> Button:
	var b := Button.new()
	b.text = _preset_opt.get_item_text(i)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true                       # 平时无底
	b.custom_minimum_size = Vector2(160, 28)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hover := UI_THEME.get_stylebox("hover", "PopupMenu")
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", UI_THEME.get_color("font_color", "PopupMenu"))
	b.add_theme_font_override("font", UI_THEME.get_font("font", "PopupMenu"))
	b.add_theme_font_size_override("font_size", UI_THEME.get_font_size("font_size", "PopupMenu"))
	b.pressed.connect(_on_preset_picked.bind(i))
	return b

## 当前档位用"选中/未选中"两个复选框图标标出 —— 和原弹出菜单的单选标记是同一对素材
func _sync_preset_marks() -> void:
	if _preset_list == null or _preset_opt == null:
		return
	var vb := _preset_list.get_child(0) as VBoxContainer
	for i in vb.get_child_count():
		var b := vb.get_child(i) as Button
		var on := (i == _preset_opt.selected)
		b.icon = UI_THEME.get_icon("radio_checked" if on else "radio_unchecked", "PopupMenu")

func _toggle_presets() -> void:
	if _preset_open:
		_collapse_presets()
	else:
		_expand_presets()

func _expand_presets() -> void:
	if _preset_list == null or _preset_opt == null:
		return
	_preset_list.reset_size()               # 先按内容算出尺寸
	_preset_list.size.x = maxf(_preset_list.size.x, _preset_opt.size.x)
	_preset_list.visible = true
	_preset_list.global_position = _preset_opt.global_position \
		+ Vector2(0.0, _preset_opt.size.y + 4.0)
	_preset_open = true
	# 手柄：列表项不在 _controls 里(面板原有的手柄导航看不见它们)，所以展开时
	# 主动把焦点放到当前档位那一项上，之后上/下与 A 由 _input 直接接管。
	_preset_hl = clampi(_preset_opt.selected, 0, maxi(0, _preset_item_count() - 1))
	_focus_preset_item()

func _collapse_presets() -> void:
	if _preset_list == null or not _preset_open:
		return
	_preset_list.visible = false
	_preset_open = false
	if _preset_opt != null:
		_preset_opt.grab_focus()            # 焦点还给难度值控件，手柄不会"丢在某处"

## 选中某档：**直接调 _on_preset_selected**，不依赖 OptionButton 的信号 ——
## 实测 select(idx) 只改了 selected，并不发 item_selected(于是数值没写下去、
## 按钮文字也不更新)。_on_preset_selected 内部自己会把 selected 定下来。
func _on_preset_picked(idx: int) -> void:
	_collapse_presets()
	_on_preset_selected(idx)

## 展开中，点在列表与值按钮之外 → 收起。
## 面板内的列表**没有** Window 那种焦点陷阱，这条必须自己加，否则它会一直挂着。
## 用 _input 而不是 _unhandled_input：后者看不到被 GUI 消费掉的点击(比如点在别的按钮上)。
func _preset_items() -> VBoxContainer:
	return _preset_list.get_child(0) as VBoxContainer

func _preset_item_count() -> int:
	var vb := _preset_items()
	return 0 if vb == null else vb.get_child_count()

func _focus_preset_item() -> void:
	var vb := _preset_items()
	if vb == null or vb.get_child_count() == 0:
		return
	_preset_hl = clampi(_preset_hl, 0, vb.get_child_count() - 1)
	(vb.get_child(_preset_hl) as Button).grab_focus()

## 手柄 A 按下**当前焦点控件**。为什么要自己按：本项目的 ui_accept 里没有任何手柄键位
## (刻意的，见 POPUP_PAD 的说明)，所以引擎不会把手柄 A 送给焦点控件。
##
## **直接调用各自的处理函数，不要用 pressed.emit()**：
##   · 难度值控件是 OptionButton —— 它内部**也**连着 pressed(那条连接会去弹它自带的
##     Window)，而且它作为 Button 子类的 toggle 语义不确定；用 emit 时这两条分支
##     都可能绕开我接的 _toggle_presets，症状就是"按 A 打不开下拉菜单"。
##   · 应用/重启/关闭直接调面板自己的处理函数，语义明确、不会触发别的连接。
##   · 色板：直接切 button_pressed(它会发 toggled，_color 靠这个回调)。
func _press_focused_control() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	if f == _preset_opt:
		_toggle_presets()
	elif f == _apply_btn:
		_on_apply()
	elif f == _restart_btn:
		_on_restart()
	elif f == _close_btn:
		close_requested.emit()
	elif f is BaseButton:
		var b := f as BaseButton
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		else:
			b.pressed.emit()
	get_viewport().set_input_as_handled()

## 当前"真正被高亮"的是哪一项 —— **以引擎的焦点为准**，不是我记的 _preset_hl。
## **焦点不在列表里时返回 -1**（这点很关键：摇杆可以把焦点移到列表之外、例如下方的
## "应用"键上，那时 A 绝不能被当成"选中列表项"，否则就是"应用没反应、反而又激活了子项"）。
##
## 为什么必须看引擎焦点：列表项的高亮有**两条**来源，而它们只在一处汇合(引擎的焦点)——
##   · 左摇杆：绑在 ui_up/ui_down 上，走引擎自带的焦点导航，把焦点挪到别的项上，
##     **完全不经过本脚本**，所以 _preset_hl 不会跟着变；
##   · 十字键：走本脚本下面的 move_up/move_down 分支，那里最后也是 grab_focus()。
func _focused_preset_index() -> int:
	var vb := _preset_items()
	if vb == null:
		return -1
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return -1
	for i in vb.get_child_count():
		if vb.get_child(i) == f:
			return i
	return -1

## 列表开着时的输入，**全部在这里接管**：
##   - 手柄 A  → 选中高亮项(以前 A 只会把列表再开关一次，因为列表项不在 _controls 里)
##   - 手柄 B  → 收起
##   - 上/下   → 在列表内移动高亮
##   - 鼠标左键点在列表与值控件之外 → 收起
func _input(event: InputEvent) -> void:
	# **手柄 A 最先处理，且不受"列表是否开着"影响。**
	#   焦点在难度列表里 → 选中那一项；焦点在别的控件上(应用/重启/关闭/色板/难度…) → 按下它。
	#
	# 为什么必须放在 _preset_open 判断之前：A 确认会把列表收起，之后用户用摇杆移到"应用"
	# 再按 A 时**列表已经关了** —— 旧代码这时整段不跑，事件落到 _unhandled_input 的
	# _activate()，而 _activate() 读的是面板自己的 _sel(只有十字键更新它，摇杆动的是引擎
	# 焦点)，_sel 还停在 open() 里 _goto(0) 放的第 0 项 = 难度 → 于是**又把下拉菜单打开**。
	# 症状正是"摇杆移到应用按 A，却又激活了下拉菜单"。
	# (第 749 行那段旧注释描述过同一类故障：鼠标左键也绑在 action_a 上，机制一样。)
	if event is InputEventJoypadButton and event.is_action_pressed(&"action_a"):
		if not visible:
			return
		var hi := _focused_preset_index()
		if hi >= 0:
			_on_preset_picked(hi)
		else:
			_press_focused_control()
		get_viewport().set_input_as_handled()   # 别再让 _activate() 按 _sel 动作第二次
		return
	if not _preset_open:
		return
	# **只接管手柄按钮** —— 别写成"有 action_a 就接管"：桌面的**左键同样映射到
	# action_a**(右键同理到 action_b)，那样会把鼠标点击在 _input 阶段就吃掉，
	# 列表项永远收不到 press，症状就是"鼠标点不中列表项"(这正是上一版引入的回归)。
	# 键鼠一律交给 GUI 正常派发；手柄才由这里接管(手柄 A 不在 ui_accept 里，
	# 引擎自带的焦点确认够不到它)。
	if event is InputEventJoypadButton:
		if event.is_action_pressed(&"action_b"):
			if _preset_open:
				_collapse_presets()
				get_viewport().set_input_as_handled()
			return
		if _preset_open and (event.is_action_pressed(&"move_up")
				or event.is_action_pressed(&"move_down")):
			var n := _preset_item_count()
			if n > 0:
				# 十字键：从**当前焦点**出发移动一格，再交回引擎焦点(与摇杆同一条最终状态)
				_preset_hl = wrapi(_focused_preset_index()
					+ (1 if event.is_action_pressed(&"move_down") else -1), 0, n)
				_focus_preset_item()
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := mb.position
	if _preset_list.get_global_rect().has_point(at) or _preset_opt.get_global_rect().has_point(at):
		return
	_collapse_presets()

## 列表展开期间**只补手柄键位**(十字键/A/B → ui_up/ui_down/ui_accept/ui_cancel)，
## 之后交给引擎自带的焦点导航；一收起立刻摘掉，项目原有绑定绝不碰。
func _bind_pad_for_list(enable: bool) -> void:
	if not enable:
		for action in _pad_added:
			var ev := _find_pad_event(action, POPUP_PAD[action])
			if ev != null:
				InputMap.action_erase_event(action, ev)
		_pad_added.clear()
		return
	for action in POPUP_PAD:
		if _find_pad_event(action, POPUP_PAD[action]) != null:
			continue                        # 项目本来就绑了 → 不碰也不记
		var e := InputEventJoypadButton.new()
		e.button_index = POPUP_PAD[action]
		InputMap.action_add_event(action, e)
		_pad_added.append(action)

## 按**按钮号**找已有绑定。不能用 InputMap.action_has_event()：
## 那个比的是 Ref 的对象身份，拿一个新建的等价事件去问永远返回 false。
func _find_pad_event(action: StringName, button: int) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return e
	return null

## 选中某一档：把 列/行/雷 一起写下去。
## 写值会触发 value_changed → 回头反查预设，那样刚选中的档位会被立刻改成「自定义」，
## 所以整段用 _syncing 挡着，最后再自己把选中项定下来。
func _on_preset_selected(idx: int) -> void:
	if _preset_opt == null or idx < 0 or idx >= PRESETS.size():
		return                              # 「自定义」不改数值
	var p: Dictionary = PRESETS[idx]
	_syncing = true
	_slider_of(_col_row).value = p["cols"]
	_slider_of(_row_row).value = p["rows"]
	_sync_mine_max()                        # 雷数上限先跟上，否则大雷数会被旧上限夹掉
	_slider_of(_mine_row).value = p["mines"]
	_preset_opt.selected = idx
	_syncing = false
	_sync_preset_marks()

## 列/行变了：先修雷数上限，再回显预设
func _on_size_changed(_v: float = 0.0) -> void:
	_sync_mine_max()
	_refresh_preset_selection()

## 按当前三个值反查预设，对不上任何一档就落到最后一项「自定义」。
## 这是"回显"不是"选择"：直接给 OptionButton.selected 赋值不会发 item_selected。
func _refresh_preset_selection(_v: float = 0.0) -> void:
	if _preset_opt == null or _syncing:
		return
	var c := int(_slider_of(_col_row).value)
	var r := int(_slider_of(_row_row).value)
	var m := int(_slider_of(_mine_row).value)
	var idx := PRESETS.size()               # 默认「自定义」
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		if p["cols"] == c and p["rows"] == r and p["mines"] == m:
			idx = i
			break
	_preset_opt.selected = idx
	_sync_preset_marks()

## 雷数上限 = 列 × 行 - 1(至少留一格给首击)。
## HSlider 在 max 变小时会自己把 value 夹回去，并触发 value_changed 刷新标签。
func _sync_mine_max(_v: float = 0.0) -> void:
	if _mine_row == null or _col_row == null or _row_row == null:
		return
	var cols := int(_slider_of(_col_row).value)
	var rows := int(_slider_of(_row_row).value)
	_slider_of(_mine_row).max_value = cols * rows - 1

func _on_apply() -> void:
	# 攒成一个规格值对象再发出去；夹取与校验的唯一出处仍是 Board.apply_spec
	var spec := BoardSpec.make(
		int(_slider_of(_col_row).value),
		int(_slider_of(_row_row).value),
		int(_slider_of(_mine_row).value))
	apply_settings.emit(spec, _color)
	close_requested.emit()

func _on_restart() -> void:
	_restart_func.call()


# ---- 开关：从左边滑入(纯表现，开关意图在 main) ----

func open() -> void:
	_kill_tween()
	show()
	position.x = -get_viewport_rect().size.x * 0.5   # 先躲到左边外
	_tween = create_tween()
	_tween.tween_property(self, "position:x", 0.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_goto(0)

func close() -> void:
	_kill_tween()
	_collapse_presets()                 # 难度列表还开着就一并收掉(连带摘掉临时键位)
	# 在隐藏前还回焦点：open() 时 _goto(0) 抓住了某个控件，
	# 而隐藏的 Control 不会自动释放焦点 —— 留着的话**空格/回车**(ui_accept 里真的
	# 绑了这两个键，而空格同时还绑着 new_game)会被那个隐形控件吃掉，棋盘收不到。
	# 注意：**手柄 A 不在 ui_accept 里** —— 本项目的 ui_accept 只剩键盘键位，
	# 所以这里挡的并不是手柄 A，旧注释那句说法与 project.godot 的绑定不符。
	_release_focus()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", -get_viewport_rect().size.x * 0.5, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)

func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

## 万一抽屉还开着下拉列表就被销毁，别把临时键位和触摸转鼠标留在全局
func _exit_tree() -> void:
	_bind_pad_for_list(false)


# ---- 手柄导航 ----

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# 鼠标事件在这里**只做一件事**：判断"点在外面"要不要收起抽屉。
	# **绝不能让它落到下面的 action_a 分支**：action_a 同时绑着手柄 A 和鼠标左键，
	# 而 open() 会把焦点放到第一个控件上 —— 于是"点哪儿都等于按 A"。
	# 第一项恰好是难度下拉时，表现就是"菜单一开，点哪里都弹出难度列表"。
	# 面板内控件的鼠标操作不归这里管：GUI 命中(_gui_input)在更早的阶段就吃掉了。
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var outside := not (_menu_area != null and _menu_area.get_global_rect().has_point(mb.position))
		if mb.button_index == MOUSE_BUTTON_RIGHT \
				or (mb.button_index == MOUSE_BUTTON_LEFT and outside):
			# 收起抽屉的那一下不能顺手再作用到棋盘(指针此时多半正压在棋盘上)，
			# 所以先把手上的事件吃掉再发关闭请求。
			# 右键 = 手柄 B = 取消，改版前就是这个手感，保留。
			get_viewport().set_input_as_handled()
			close_requested.emit()
		return

	# 以下是手柄导航(鼠标已被上面拦掉)
	if event.is_action_pressed("move_down"):
		_goto_vertical(1)
	elif event.is_action_pressed("move_up"):
		_goto_vertical(-1)
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("action_a"):
		_activate()
	elif event.is_action_pressed("action_b"):
		close_requested.emit()

func _goto(i: int) -> void:
	if _controls.is_empty():
		return
	_sel = wrapi(i, 0, _controls.size())
	(_controls[_sel] as Control).grab_focus()

## 上下导航。焦点落在调色板里时要按**视觉行**跨，不能一格一格往右挪：
## 色块由 HFlowContainer 自动折行，行宽只有布局知道，所以在运行期量出来 ——
## 换分辨率或换主题字号导致折行变化时这里跟着变，不写死列数。
func _goto_vertical(dir: int) -> void:
	if _palette_btns.is_empty():
		_goto(_sel + dir)
		return
	var first: int = _controls.find(_palette_btns[0])
	if first < 0 or _sel < first:
		_goto(_sel + dir)               # 不在调色板里 → 普通上下
		return
	var rows := _palette_rows()
	for r in rows.size():
		var row: Array = rows[r]
		var col: int = row.find(_sel - first)
		if col < 0:
			continue
		var tr := r + dir
		if tr < 0 or tr >= rows.size():
			_goto(_sel + dir)           # 已到调色板上下边界 → 落到相邻控件
			return
		var target: Array = rows[tr]
		# 走同一列；目标行更短就夹到它最后一个(两行色块数不一定相等)
		_goto(first + int(target[mini(col, target.size() - 1)]))
		return
	_goto(_sel + dir)

## 把色块按**实际布局**分行：同一 y 视为一行，行内保持添加顺序。
func _palette_rows() -> Array:
	var rows: Array = []
	var cur: Array = []
	var last_y := INF
	for i in _palette_btns.size():
		var y := _palette_btns[i].get_global_rect().position.y
		if cur.is_empty() or absf(y - last_y) < 1.0:
			cur.append(i)
		else:
			rows.append(cur)
			cur = [i]
		last_y = y
	if not cur.is_empty():
		rows.append(cur)
	return rows

func _adjust(dir: int) -> void:
	if _controls.is_empty():
		return
	var c: Control = _controls[_sel]
	if c is HSlider:
		(c as HSlider).value += dir
	elif c is OptionButton:
		# 难度：左右键直接换档(外观是 OptionButton，展开由面板内列表负责)
		var n: int = _preset_opt.item_count
		if n > 0:
			_on_preset_selected(wrapi(_preset_opt.selected + dir, 0, n))
	elif c is Button and (c as Button).toggle_mode:
		# 色块之间用左右键横移(选定靠 A)
		_goto(_sel + dir)

func _activate() -> void:
	if _controls.is_empty():
		return
	var c: Control = _controls[_sel]
	if c == _apply_btn:
		_on_apply()
	elif c == _restart_btn:
		_on_restart()
	elif c == _close_btn:
		close_requested.emit()
	elif c is OptionButton:
		# 手柄 A 展开/收起难度列表(列表是面板内的 Control，位置自己定，不涉及窗口定位)
		_toggle_presets()
	elif c is Button and (c as Button).toggle_mode:
		(c as Button).button_pressed = true
