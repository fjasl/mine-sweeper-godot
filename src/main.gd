extends Node2D


# 标上类型：否则从它们派生的局部变量用 := 推导不出类型
# (cam 现在能标 GameCamera 了 —— camera_2d.gd 已经加了 class_name；
#  反过来标成内置 Camera2D 会让 set_world_bounds()/zoom_by() 变成"方法不存在")
@onready var cam: GameCamera = $Camera2D
@onready var background: Background = $Background
@onready var board: Board = $Background/Board
@onready var timer: ScoreTimer = $Background/ScoreTimer
@onready var counter: MineCounter = $Background/MineCounter
@onready var face: Smiley = $Background/StateFace
@onready var settings_btn: TextureButton = $UILayer/SettingsButton
@onready var settings_panel: SettingsPanel = $UILayer/SettingsPanel
@onready var game_over_panel: GameOverPanel = $UILayer/GameOverPanel

var _sm: GameStateMachine      # 对局阶段机：ready → playing → won/lost
var _menu_open := false        # 菜单是否开着：唯一真相，供输入门控使用

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 摆放与相机：几何全部由 _relayout() 统一负责
	_relayout()

	# 对局阶段机：ready → playing → won/lost。
	# 迁移由规则层信号驱动(在 bind 里映射)，副作用写在各自状态的 _enter 里
	_sm = GameStateMachine.new()
	# 调试开关：需要看每次进入/退出状态的 Output 时自行打开
	# _sm.is_debug = true
	# 注入状态要用到的部件(刻意不用 BaseState.agent：那得给 main 加 class_name
	# 并在状态里引用它，会和 main 引用 GameStateMachine 构成循环依赖)
	_sm.board = board
	_sm.timer = timer
	_sm.counter = counter
	_sm.face = face
	_sm.result_panel = game_over_panel
	_sm.bind(board)
	# 三个驱动标志全给 false：阶段机是纯事件驱动的，不需要每帧 update；
	# 尤其 run_input 走的是 _input 阶段，会抢在 GUI 之前吃掉事件，绝不能开
	CoreSystem.state_machine_manager.register_state_machine(
		&"game", _sm, self, &"ready", {}, false, false, false)

	# 与阶段无关的接线
	board.flags_changed.connect(func(r): counter.set_number(r))
	# 计时器每跳一秒 → 滴答声
	timer.ticked.connect(func(): CoreSystem.audio_manager.play_sound("res://Asset/tick.wav"))

	# 再来一次(_restart 内部已收起弹窗)
	game_over_panel.play_again.connect(_restart)

	# 背景音乐(项目里没有 bgm.ogg;如果加进了 Asset 就启用下面这行)
	# CoreSystem.audio_manager.play_music("res://Asset/bgm.ogg", 0.0)

	# 开局 HUD(计时器归零 + 剩余雷数 + 笑脸 normal)由 ReadyState._enter 负责

	# 输掉后点表情 → 重开
	face.restart_requested.connect(_restart)
	
	
	settings_panel.set_restart_func(_restart)
	
	settings_btn.pressed.connect(_toggle_menu)
	settings_panel.apply_settings.connect(_apply_settings)
	# 面板请求关闭(应用后 / 关闭按钮 / 手柄 B) → main 统一改 _menu_open
	settings_panel.close_requested.connect(func(): _set_menu_open(false))


# 唯一的新局路径：重铺棋盘 + 把阶段机推回 ready
# (HUD 复位与收起弹窗都在 ReadyState._enter 里，这里不重复)
func _restart() -> void:
	board.new_game()
	_sm.transition_to(&"ready")

# ---- 菜单(设置面板)：一个布尔记录"是否开着"，是输入门控的唯一真相 ----

func _toggle_menu() -> void:
	_set_menu_open(not _menu_open)

func _set_menu_open(open: bool) -> void:
	if _menu_open == open:
		return
	_menu_open = open
	# 菜单占着屏幕时棋盘不接受输入(手柄导航归面板)。
	# 这里是"意图"驱动：滑出动画那 0.2s 内棋盘已恢复响应，影响可忽略
	board.set_process_unhandled_input(not open)
	# 相机同样让路：否则菜单开着还能滚轮缩放/摇杆平移，面板背后的画面在动
	cam.set_input_enabled(not open)
	if open:
		settings_panel.open()
	else:
		settings_panel.close()


# 设置面板"应用"：颜色是表现层的事，规格变更交给 Board
func _apply_settings(spec: BoardSpec, cursor_color: Color) -> void:
	# 光标颜色：纯表现，总是生效，不需要重开
	board.set_cursor_color(cursor_color)

	# 规格校验/写入都在 Board 里(规则的唯一出处)；规格没变就直接结束
	if not board.apply_spec(spec):
		return

	_restart()      # 新局 + HUD 复位 + 收起弹窗(修掉改尺寸后笑脸/弹窗不复位)
	_relayout()     # 尺寸变了，表现层几何与相机要重算

# 尺寸变化后的表现层重排(几何与相机的唯一出处)
func _relayout() -> void:
	var s := board.spec()                        # BoardSpec
	background.boardColumns = s.cols             # 从唯一真值同步，不再由外部传参
	background.boardRows = s.rows
	board.position = background.board_grid_origin()
	timer.position  = background.place_display(timer,   "right", 8)
	counter.position = background.place_display(counter, "left", 8)
	face.position = background.place_display(face, "center", 0)
	background.center_in_viewport()   # 背景先居中，相机位置依赖它
	background.queue_redraw()
	# 相机中心的活动范围＝原版那一屏世界区域(棋盘中心 ± 半个视口)，
	# 范围沿用原版，夹取方式换成"中心夹取"，所以 zoom == 1 时不再被钉死
	var view: Vector2 = get_viewport_rect().size
	var board_center: Vector2 = background.position + background.board_size() / 2.0
	cam.set_world_bounds(Rect2(board_center - view / 2.0, view))
	cam.position = board_center       # 相机复位到新棋盘中心
	cam.zoom = Vector2(1, 1)          # 相机复位到新棋盘视野

# new_game 输入 → 重开(_restart 内部已收起弹窗)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_game"):
		_restart()
	elif event.is_action_pressed("setting_pane"):
		_toggle_menu()
