# TouchGestures —— 通用触摸手势层

把手势从"原始触摸事件"里剥离出来：**识别层只发语义信号，绝不调用游戏代码**。
游戏侧只需要 connect 信号，不需要知道 `InputEventScreenTouch` 长什么样。

## 目录结构

```
addons/touch_gestures/
├── touch_config.gd        Resource  阈值集中配置(归一化比例)          [class_name TouchConfig]
├── touch_point.gd         RefCounted 单根手指的状态
├── touch_tracker.gd       RefCounted 活跃手指集合 + centroid/spread 几何查询
├── touch_gesture.gd       RefCounted 所有识别器的基类(扩展点)          [class_name TouchGesture]
├── touch_gestures.gd      Node      组装/接事件/驱动识别器             [class_name TouchGestures]
├── mouse_to_touch.gd      Node      桌面测试通道(鼠标→假触摸)
└── gestures/
    ├── tap.gd             轻点(单指/多指)   —— 已实现，可当模板
    ├── long_press.gd      长按              —— 待实现
    ├── drag.gd            拖动(单指/双指)   —— 待实现
    └── pinch.gd           捏合(≥2 指)       —— 待实现
```

**为什么只有三个 `class_name`**：`TouchGestures` / `TouchConfig` / `TouchGesture` 是消费者
需要**写进代码**的东西（挂节点、配参数、继承扩展）。其余内部类故意不走 `class_name`，
改用 `preload` 常量引用 —— 不给使用者的项目塞一堆全局类名，同时让依赖关系显式可见。
（本项目依赖的 godot_core_system 用的也是这个套路：内部模块 `preload`，对外才 `class_name`。）

## 三条硬约定

1. **坐标系**：对外一律是**视口逻辑坐标**（`InputEventScreenTouch.position` 原生就是它）。
   screen → world 的转换**交给调用方**，因为只有调用方知道自己的相机。
2. **阈值归一化**：所有"距离"阈值都以**屏幕短边的比例**表达（如 `tap_slop_ratio = 0.02`），
   由 `TouchConfig.px()` 换算成像素。**不要**用像素当阈值，那样换台高分屏就废了。
3. **时间用 `Time.get_ticks_msec()`**，不用 `Timer` 节点 —— 轻、可控、而且能在单元测试里
   用假的 `now_ms` 确定性推进。

## 挂载方式（顺序很重要）

`_unhandled_input` 是按**场景树反序**传播的（越靠后的节点越先拿到事件）。所以：

```
Main
├── Background            ← Board 在里面，它会处理(模拟出来的)鼠标事件
├── Camera2D
├── TouchGestures         ← 放这里(Background 之后)才抢得过 Board
├── MouseToTouch          ← 桌面测试用，同样要放 Background 之后
└── UILayer
```

`TouchGestures` 默认**只消费多指事件**（`consume_multitouch`），单指事件刻意放行 ——
让引擎的"触摸转鼠标"通道（`emulate_mouse_from_touch`，默认开）继续喂给既有鼠标逻辑。
见下节。

## 和 `emulate_mouse_from_touch` 的关系

默认开着，所以**单指点击/拖动已经被翻译成鼠标事件**，既有的鼠标代码在手机上本来就能用。
本层刻意**不重复处理单指轻点**，只补引擎给不了的部分：长按、多指、捏合。

如果哪天你把引擎的模拟关掉，改由本层接管全部（包括单指点击），记得：
单指轻点的信号要自己接到游戏行为上，否则点不动了。

## 通用状态转移表（写在代码之前，先想清楚）

| 当前 | 事件 | 下一步 | 说明 |
|---|---|---|---|
| idle | 第 1 指按下 | pending | 起计时，进入"可能是轻点/长按/拖动"的暧昧状态 |
| pending | 位移 > `tap_slop` | pending_drag | 立刻**取消**轻点与长按 |
| pending | 时长 > `long_press_sec` 且没怎么动 | 已发 `long_pressed` | 之后移动不再产生拖动 |
| pending | 时长 > `tap_max_sec` | 取消轻点 | 只是不发 `tapped`，长按另有其人 |
| pending | **第 2 指按下** | multifinger | 放弃单指语义；≥2 指时交给 drag/pinch |
| pending | 全部抬起且未取消 | 发 `tapped(pos, fingers)` | `fingers` 告诉调用方是几指 |
| multifinger | 手指数变化 | 重新取 `centroid`/`spread` 基准 | 加指/减指都要重设基准，否则会跳变 |
| 任意 | 失焦 / `canceled` | clear() | 系统可能不发抬起事件，必须清干净 |

**多指抬起是分几次到达的**：务必在"全部抬起"时才判定轻点，不能在第一根抬起时就下结论。

## 桌面测试通道

`mouse_to_touch.gd` 把鼠标事件翻译成假触摸，直接喂给手势层（不走输入管线，无延迟）：

- **单指**：鼠标左键 = 手指 0
- **双指**：按住 `Shift` 时，鼠标位置当手指 1，手指 0 固定在**屏幕中心的镜像位置** ——
  于是捏合、双指拖动、旋转都能用一只鼠标模拟

**这一步建议最先做**：没有它，每加一个手势都要上真机验证，效率会崩。

## 怎么加一个新手势

1. 新建 `gestures/xxx.gd`，`extends TouchGesture`
2. `_init()` 里设 `id = &"xxx"`；声明自己的信号
3. 覆写 `reset()`（务必 `super()`）+ 需要的钩子：
   `on_touch_began / on_touch_moved / on_touch_ended / update`
4. 在 `touch_gestures.gd` 里加一个字段 + `preload` 常量 + 塞进 `_all`
5. 在本文档的转移表里补上它的规则

## 实现状态

| 部分 | 状态 |
|---|---|
| `TouchPoint` / `TouchTracker`（含 `centroid` / `spread`） | ✅ 已实现 |
| `TouchConfig`（归一化阈值） | ✅ 已实现 |
| `TouchGesture` 基类（生命周期 + `active` + `id`） | ✅ 已实现 |
| `TouchGestures` 节点（接事件 / 驱动 / 查询 / 失焦清理） | ✅ 已实现 |
| `mouse_to_touch` 桌面测试通道 | ✅ 已实现 |
| `tap`（单指/多指轻点） | ✅ 已实现（可当模板） |
| `long_press`（长按，只发一次） | ✅ 已实现 |
| `drag`（拖动，单指/双指，重心语义） | ✅ 已实现 |
| `pinch`（捏合，用 `spread`，三指也可用） | ✅ 已实现 |
| `double_tap` | ⬜ 未做（`double_tap_sec` 已在 TouchConfig 里预留；目前"双击后按住拖动"由游戏侧用原始触摸事件实现） |
| `rotate` | ⬜ 暂不做 |
| 调试可视化（画触摸点/当前状态） | ⬜ 建议早做 |

## 注意：新增 class_name 后要重载项目

本库引入了 3 个新的全局类名。如果编辑器当时是开着的，会报
`Could not find type "TouchGestures"` 之类的错 —— 那是**类缓存还没更新**，
执行 **项目 → 重新加载当前项目** 即可（不是代码问题）。
