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

## 预设光标颜色(与界面重做前是同一份，保证"只换皮肤、不改表现")
const PALETTE := [
	Color(1, 0.9, 0.3),     # 黄
	Color(1, 0.75, 0.2),    # 橙
	Color(1, 0.5, 0.2),     # 橙红
	Color(1, 0.3, 0.3),     # 红
	Color(1, 0.35, 0.6),    # 玫红
	Color(1, 0.4, 1),       # 品红
	Color(0.8, 0.4, 1),     # 紫
	Color(0.55, 0.4, 1),    # 蓝紫
	Color(0.35, 0.5, 1),    # 蓝
	Color(0.3, 0.75, 1),    # 天蓝
	Color(0.3, 1, 1),       # 青
	Color(0.2, 0.9, 0.6),   # 蓝绿
	Color(0.3, 1, 0.4),     # 绿
	Color(0.65, 1, 0.3),    # 黄绿
	Color(1, 1, 1),         # 白
	Color(0.8, 0.8, 0.8),   # 浅灰
	Color(0.5, 0.5, 0.5),   # 中灰
	Color(0.25, 0.25, 0.25),# 深灰
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

var _restart_func: Callable = Callable()
## 动画句柄：重开前必须先 kill，否则旧的 hide 回调会把面板藏起来
var _tween: Tween


func set_restart_func(callback: Callable) -> void:
	_restart_func = callback


## 安全网：临时补的那组手柄键位**只该在弹窗活着时存在**。
## 万一 popup_hide 没发出来(弹窗被别的方式收掉)，下一帧就自己摘干净 ——
## 漏在全局的后果是"菜单关着时十字键去推相机"，那恰恰是本项目刻意避免的
## (十字键绑在 move_* 上、没进 ui_*，就是为了这个)。
func _process(_delta: float) -> void:
	if not _pad_added.is_empty() and not _preset_opt.get_popup().visible:
		_bind_pad_for_popup(false)


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
	# 滑条初值取自 BoardSpec 的默认值(= 原版初级)，不在本文件里另写一份 ——
	# 面板并不接收棋盘当前规格(apply_settings 只是发出去给 main 的信号)，
	# 所以这份初值必须和棋盘默认一致，否则一按"应用"就会把棋盘改掉。
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


## 预设色板：一排小色块按钮，单选(ButtonGroup)，选中的那个多一圈白描边。
## 色块的底就是颜色本身，所以样式盒是逐按钮覆盖的 —— 这是唯一没法靠主题解决的部分。
func _make_palette() -> Control:
	var group := ButtonGroup.new()
	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
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
		flow.add_child(b)
		_palette_btns.append(b)
		if i == 0:
			b.button_pressed = true       # 默认选中第一格，_color 初值就是它
	return flow

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

## 难度预设行(模板的下拉框控件 line_setting_option_button)。模板场景里预置的是
## 「语言」一项；这里把标题改成「难度」，按原版三档重建列表，末尾补一个「自定义」。
func _make_preset_row() -> HBoxContainer:
	var row: HBoxContainer = ROW_OPTION.instantiate()
	row.get_node("Label").text = "难度"
	_preset_opt = row.get_node("OptionButton")
	_preset_opt.clear()
	for p in PRESETS:
		_preset_opt.add_item(p["name"])
	_preset_opt.add_item("自定义")          # 索引 == PRESETS.size()，只是个状态
	_preset_opt.item_selected.connect(_on_preset_selected)
	# 弹窗开/关 → 临时补上/摘下那组手柄键位(鼠标点开的也照样补，手柄可以接着操作)
	var pop := _preset_opt.get_popup()
	pop.about_to_popup.connect(func() -> void: _bind_pad_for_popup(true))
	pop.popup_hide.connect(func() -> void: _bind_pad_for_popup(false))
	return row

## 把 POPUP_PAD 里的手柄键位补进 ui_*(enable=true) 或摘掉(enable=false)。
## 摘的时候只摘 _pad_added 里记着的那几个，项目原有绑定绝不碰。
func _bind_pad_for_popup(enable: bool) -> void:
	if not enable:
		for action in _pad_added:
			var ev := _find_pad_event(action, POPUP_PAD[action])
			if ev != null:
				InputMap.action_erase_event(action, ev)
		_pad_added.clear()
		set_process(false)              # 没有键位要守了，安全网也跟着停
		return
	for action in POPUP_PAD:
		if _find_pad_event(action, POPUP_PAD[action]) != null:
			continue                        # 项目本来就绑了 → 不碰也不记
		var e := InputEventJoypadButton.new()
		e.button_index = POPUP_PAD[action]
		InputMap.action_add_event(action, e)
		_pad_added.append(action)
	# 只有真的补进了键位，才需要每帧盯着"弹窗有没有被别的方式收掉"
	set_process(not _pad_added.is_empty())

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
	# 下拉列表还开着就一并收掉，并把临时补的手柄键位摘干净
	# (不能只靠 popup_hide 信号：hide() 不一定会发它)
	if _preset_opt != null and _preset_opt.get_popup().visible:
		_preset_opt.get_popup().hide()
	_bind_pad_for_popup(false)
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

## 万一抽屉还开着下拉列表就被销毁，别把临时补的手柄键位留在全局 InputMap 里
func _exit_tree() -> void:
	_bind_pad_for_popup(false)


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
		# 难度下拉：左右键直接换档
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
		# 手柄 A 展开难度列表。**必须自己定位**：裸 popup() 会把窗口丢到左上角(0,0)，
		# 鼠标点击那条路是 OptionButton 内部定位的。
		# 展开之后手柄怎么操作列表，见 POPUP_PAD 的说明(临时补 ui_* 键位)。
		var ob := c as OptionButton
		var pop := ob.get_popup()
		pop.position = Vector2i(ob.global_position) + Vector2i(0, int(ob.size.y))
		pop.popup()
	elif c is Button and (c as Button).toggle_mode:
		(c as Button).button_pressed = true
