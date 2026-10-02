extends Node2D


# 标上类型：否则从它们派生的局部变量用 := 推导不出类型
# (cam 现在能标 GameCamera 了 —— camera_2d.gd 已经加了 class_name；
#  反过来标成内置 Camera2D 会让 set_world_bounds()/zoom_by() 变成"方法不存在")
@onready var cam: GameCamera = $Camera2D
@onready var background: Background = $Background
@onready var board: Board = $Background/Board
@onready var timer: ScoreTimer = $Background/ScoreTimer
@onready var counter: MineCounter = $Background/MineCounter
@onready var face: StateFace = $Background/StateFace
@onready var settings_btn: Button = $UILayer/SettingsButton
@onready var settings_panel: SettingsPanel = $UILayer/SettingsPanel
@onready var game_over_panel: GameOverPanel = $UILayer/GameOverPanel
## 夜空背景(自己画的流星)。**只被喂值**：进度来自 Board，色调来自阶段机
@onready var sky: NightSky = $Backdrop/Sky

var _sm: GameStateMachine      # 对局阶段机：ready → playing → won/lost
var _store: UserStore          # 本机持久化：英雄榜 + 光标颜色
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
	# 翻开进度 → 背景(0..1)。信号是**每次成功翻开才发一次**(不是每帧轮询)，
	# 所以背景的"互动"只花在玩家真的动了棋盘的时候
	board.progress_changed.connect(func(r: float) -> void: sky.set_progress(r))
	# 阶段变化 → 黄框是否跟随：只有"进行中"才需要跟指针。
	# ready(待首击)、won/lost(结算弹窗)都会盖住/等待操作，此时黄框应当停住
	# (黄框是"下一击作用在哪"的指示器，背后乱跑会让人误判)。
	_sm.state_changed.connect(_on_game_state_changed)
	# 计时器每跳一秒 → 滴答声
	timer.ticked.connect(func(): CoreSystem.audio_manager.play_sound("res://Asset/tick.wav"))

	# 音效预热。audio_manager.play_sound(路径) 是**首次调用才同步 load()**，
	# 之后才进它自己的字典缓存(audio_manager.gd:_get_audio_resource) ——
	# 所以"第一次滴答 / 第一次胜利 / 第一次踩雷"那一下会卡在读盘上。
	# 这里开局就把三个音效灌进它的缓存：用的是 addon 自己的 preload_audio()，
	# 不在项目里另搞一份缓存，也不走 resource_manager(那条路的 LAZY 语义是坏的)。
	# 注意路径要和下面 game_state_machine.gd 里 play_sound 的三处保持一致。
	for sound in ["res://Asset/tick.wav", "res://Asset/win.wav", "res://Asset/explode.wav"]:
		CoreSystem.audio_manager.preload_audio(sound, CoreSystem.AudioManager.AudioType.SOUND_EFFECT)

	# 再来一次(_restart 内部已收起弹窗)
	game_over_panel.play_again.connect(_restart)

	# 背景音乐(项目里没有 bgm.ogg;如果加进了 Asset 就启用下面这行)
	# CoreSystem.audio_manager.play_music("res://Asset/bgm.ogg", 0.0)

	# 开局 HUD(计时器归零 + 剩余雷数 + 笑脸 normal)由 ReadyState._enter 负责

	# 输掉后点表情 → 重开
	face.restart_requested.connect(_restart)
	
	
	# 本机持久化(英雄榜 + 光标颜色)：user:// 下一个小文件，启动读一次
	_store = UserStore.new()
	add_child(_store)
	# 开机回显：光标颜色与英雄榜都照存档来(没存过就是默认值)
	board.set_cursor_color(_store.get_cursor_color())
	settings_panel.set_cursor_color(_store.get_cursor_color())
	settings_panel.set_best_times(_store.snapshot())
	settings_panel.set_restart_func(_restart)
	
	settings_btn.pressed.connect(_toggle_menu)
	settings_panel.apply_settings.connect(_apply_settings)
	# 面板请求关闭(应用后 / 关闭按钮 / 手柄 B) → main 统一改 _menu_open
	settings_panel.close_requested.connect(func(): _set_menu_open(false))

	# 初始门控显式施加一次。上面那些开关的默认值恰好等于"无覆盖"，但那是巧合 ——
	# 默认值一改就会静默走样，所以唯一入口必须在装配完成后被主动调一次。
	_apply_canvas_interaction()
	# 背景的初始值同样显式喂一次(理由同上：默认恰好正确只是巧合，不是契约)
	sky.set_progress(board.revealed_progress())
	sky.set_phase(_sm.get_current_state_name())


# 唯一的新局路径：重铺棋盘 + 把阶段机推回 ready
# (HUD 复位与收起弹窗都在 ReadyState._enter 里，这里不重复)
func _restart() -> void:
	# 先把设置抽屉收起来：否则"结算弹窗 + 设置抽屉"会同时留在屏幕上，
	# 两套控件都可交互，玩家分不清自己点的是哪一个。
	# 开新局是唯一的 UI 归一化点，所以收菜单放在这里而不是各个调用点。
	_set_menu_open(false)
	board.new_game()
	_sm.transition_to(&"ready")

## 阶段变化 → 同步画布侧的交互开关。
## 放在 main 而不是各状态的 _enter 里：状态不需要知道 Board/Camera 有这些开关，
## 部件之间的接线留在装配处，和 bind() 的用意一致。
func _on_game_state_changed(_from: BaseState, to: BaseState) -> void:
	_apply_canvas_interaction()
	# 通关 → 记成绩。表在 won 状态里已经停住，elapsed 就是本局用时。
	# 只有正好等于某一档预设的棋盘才进榜(判据在 UserStore 里)，自定义尺寸不记。
	if _sm.get_current_state_name() == &"won":
		var sp := board.spec()
		if not _store.record(sp.cols, sp.rows, sp.mine_count, timer.elapsed).is_empty():
			settings_panel.set_best_times(_store.snapshot())
	# 背景换调跟着阶段走(进行中 / 通关 / 失败)。放在这里而不是各状态的 _enter 里：
	# 和上面那条一样，部件之间的接线留在装配处，状态不需要知道背景的存在
	sky.set_phase(_sm.get_current_state_name())

## 画布侧交互的统一门控(唯一入口)。
##
## 原则：**有 UI 覆盖时，画布侧冻结；指针本身保持自由**(否则点不到 UI)。
## 覆盖来源只有两个"真的有东西盖在屏幕上"的阶段：
##   - 设置抽屉开着(_menu_open)
##   - 对局处于结算阶段(won / lost，结算弹窗在上面)
##
## **ready 阶段刻意不冻结**：它是"待首击"，屏幕上没有任何覆盖物，而且进入
## playing 的唯一途径就是棋盘收到一次点击 —— 把 ready 也冻上会形成死锁
## (冻结输入 → 点不到棋盘 → 永远进不了 playing)。
##
## 冻结的东西：棋盘输入、相机缩放/平移、黄框跟随。
## **计时不在其中**：停表/续表是一次阶段迁移(playing <-> paused，见 _sync_pause_state)，
## 归阶段机管 —— 计时器不持有"被挂起"标志，这里也不碰它。
func _apply_canvas_interaction() -> void:
	var state := _sm.get_current_state_name()
	# paused 也算"有覆盖物"：那正是抽屉开着时阶段机所处的状态
	var overlay := _menu_open or state == &"paused" or state == &"won" or state == &"lost"
	board.set_process_unhandled_input(not overlay)
	board.pause_tracking(overlay)
	cam.set_input_enabled(not overlay)

# ---- 菜单(设置面板)：一个布尔记录"是否开着"，是输入门控的唯一真相 ----

func _toggle_menu() -> void:
	_set_menu_open(not _menu_open)

func _set_menu_open(open: bool) -> void:
	if _menu_open == open:
		return
	_menu_open = open
	# 抽屉开关先翻译成一次阶段迁移(停表 / 续表)，再统一施加画布侧的后果
	_sync_pause_state()
	# 开关只负责改状态，画布侧的一切后果都由 _apply_canvas_interaction() 统一施加
	_apply_canvas_interaction()
	if open:
		settings_panel.open()
	else:
		settings_panel.close()

## 抽屉开着 = playing -> paused(表停)；收起 = paused -> playing(接着走)。
## 只在 playing 之间来回，另三种状态刻意都不迁移：
##   ready      —— 表本来就没走(待首击)
##   won / lost —— 表由各自状态停住；此时开抽屉也不该把表再走起来
## 这样"表该不该走"仍然只由当前阶段决定，main 不需要记住任何计时状态。
func _sync_pause_state() -> void:
	var state := _sm.get_current_state_name()
	if _menu_open and state == &"playing":
		_sm.transition_to(&"paused")
	elif not _menu_open and state == &"paused":
		_sm.transition_to(&"playing")


# 设置面板"应用"：颜色是表现层的事，规格变更交给 Board
func _apply_settings(spec: BoardSpec, cursor_color: Color) -> void:
	# 光标颜色：纯表现，总是生效，不需要重开；顺带存进本机偏好，下次开机回显
	board.set_cursor_color(cursor_color)
	_store.set_cursor_color(cursor_color)

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
