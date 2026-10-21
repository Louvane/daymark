# Spec: Daymark v1 — 菜单栏倒数日应用

Status: ready-for-agent

## Problem Statement

macOS 用户想把重要的日子(生日、纪念日、活动、截止日)放在触手可及的地方,随时看到"还剩几天 / 已过去几天"。原版 Moment 满足这个需求,但:(1) 核心功能锁在 Pro 付费墙后;(2) 强推 iCloud 同步;(3) 闭源不可审计。用户想要一个免费、开源、纯本地的等价物,自己拥有全部数据。

## Solution

用 SwiftUI(MenuBarExtra)+ SwiftData 全新实现的菜单栏应用 **Daymark**:点击菜单栏图标弹出面板,浏览、创建、编辑"Daymark(日标)"——一条带名称、日期、Emoji、颜色的日子记录;系统按重复周期自动滚动到下一次发生,提前 N 天发本地提醒。无付费墙、无云同步、无遥测。v1 覆盖核心闭环,v1.5/v2 分期补齐原版其余功能。

## User Stories

**创建与浏览**
1. As a 用户, I want 点击菜单栏图标弹出面板, so that 不打开独立窗口就能看到全部 Daymark
2. As a 用户, I want 面板按"最近将到"排序展示 Daymark 列表, so that 最紧迫的日子一眼可见
3. As a 用户, I want 每行显示 Emoji、名称与剩余/已过天数, so that 不用点开就知道状况
4. As a 用户, I want 创建一条 Daymark(名称+日期), so that 记住一个重要日子
5. As a 用户, I want 给 Daymark 选一个日期区间(开始+结束), so that 追踪一段活动(如旅行、展会)
6. As a 用户, I want 在创建/编辑时为日期指定具体时间, so that 提醒落在正确时刻
7. As a 用户, I want 编辑已有 Daymark 的任何字段, so that 改错了不用删掉重建
8. As a 用户, I want 删除 Daymark(带确认), so that 清理不再关心的日子
9. As a 用户, I want 空列表时有友好引导(点击 + 创建第一条), so that 第一次打开不茫然

**重复与滚动**
10. As a 用户, I want 设重复周期(不重复/每周/每月/每年), so that 生日这类循环日子自动滚动
11. As a 用户, I want 已过的周期事件自动显示"距下次还有 N 天", so that 不用手动改日期
12. As a 用户, I want 已过的非重复事件显示"已过去 N 天", so that 纪念过去的时刻(如"在家工作满 N 天")

**提醒**
13. As a 用户, I want 设提醒(提前 1/2/3/7/14/30 天), so that 不会错过重要日子
14. As a 用户, I want 设全局默认提醒时刻(如 09:00), so that 无具体时间的日标在统一时间提醒
15. As a 用户, I want 提前收到 macOS 本地通知, so that 即使没打开面板也知道
16. As a 用户, I want 点通知打开面板并定位到对应 Daymark, so that 直接处理

**外观自定义**
17. As a 用户, I want 给 Daymark 选 Emoji(内置分类 Emoji 选择器), so that 列表里快速识别
18. As a 用户, I want 给 Daymark 选颜色, so that 视觉分组
19. As a 用户, I want 在面板内调整 Daymark 排序(最近优先/手动), so that 按自己习惯看

**应用行为**
20. As a 用户, I want 开机自启动(可开关), so that 重启后菜单栏还在
21. As a 用户, I want 应用是纯菜单栏形态(无 Dock 图标、无主窗口), so that 不占任务栏
22. As a 用户, I want 中英双语界面跟随系统语言, so that 中英文环境都舒服
23. As a 用户, I want 通过 moment:// 同类 scheme(daymark://)从链接唤起创建, so that 便于集成(可选,v1 不阻塞)
24. As a 用户, I want 界面视觉遵循 macOS 15 设计语言(半透明面板、原生控件), so that 和系统浑然一体

**数据**
25. As a 用户, I want 数据只存本地 SwiftData, so that 隐私可控、离线可用
26. As a 用户, I want 应用重启/升级后数据完好, so that 多年积累不丢失

## Implementation Decisions

- 模块:App 入口(MenuBarExtra + Settings 场景)、Panel(列表+详情+编辑表单)、Domain(DateMath 纯函数)、Store(SwiftData 仓储)、Notifications(UNUserNotificationCenter 封装)。分层单向:UI → Store → Domain。
- DateMath 为纯 Swift 包内可测函数集:输入(锚定日、重复周期、可选区间、参考日)输出(下次发生日、剩余天数、已过天数、进度)。所有日历运算(周/月/年滚动)走 Gregorian + 用户当前时区;跨时区/夏令时边界行为由测试钉死。
- 数据模型(SwiftData @Model,字段对齐原版 Moment 实体,去掉 sync 字段):id(UUID)、name、emoji、colorIndex、startDate、endDate?、hasTime(Bool,日期是否含时刻)、repeatCycle(none/weekly/monthly/yearly)、remindDays(Int,提前天数)、sortWeight、createdAt、updatedAt。
- 提醒调度:ReminderScheduling 协议包装 UNUserNotificationCenter;应用启动与数据变更时全量重排 pending 请求(先清后加,id 用 Daymark id+发生日派生,幂等);重复事件只为"下一次发生"排提醒。
- 默认提醒时刻作为 Setting 存 UserDefaults(09:00),无时刻的 Daymark 落在当天该时刻。
- 开机启动用 SMAppService.register(loginItem)(macOS 13+ API,取代旧 SMLoginItemSetEnabled)。
- LSUIElement=true 纯菜单栏;面板用 MenuBarExtra 的 window 样式;详情/编辑在面板内导航(push),不另开窗口。
- 中英双语用 String Catalog(.xcstrings),开发语言 zh-Hans 优先,en 为第一翻译。
- URL scheme daymark:// 挂 Info.plist,解析逻辑进 v1(创建表单预填),UI 宣传后置。
- 构建产物:Daymark.app(Xcode 项目,单 target;后续 v1.5 加 Widget extension 再多 target)。

## Testing Decisions

- 只测外部行为,不测实现细节;好测试 = 换实现不改测试仍绿。
- 两个接缝(已在 to-spec 对话确认):
  - **DateMath 纯函数层**:XCTest 全覆盖——下次发生日滚动(含 2/29、月末、跨年)、剩余/已过天数(含今天当天=0、时区边界)、日期区间进度、提醒触发日推导。用固定日历+固定参考日构造用例,不依赖运行机器时区。
  - **DaymarkStore + ReminderScheduling**:SwiftData in-memory 容器 + 假调度器(记录 add/remove 调用),验证 CRUD、重排幂等、删除时撤销已排提醒。
- UI 层不写自动化测试,保持薄层;用 SwiftUI Preview 人工验证。无先行测试可参考(greenfield)。
- 回归门槛:xcodebuild test 全绿才允许提交。

## Out of Scope

- iCloud / 任何云同步(ADR-0003)
- 付费墙、授权、试用期(ADR-0003)
- 年/季/月进度条展示(v1.5)
- 钉选 Daymark 为独立菜单栏项(v1.5)
- 通知中心"今日"小组件 WidgetKit(v1.5)
- 欢迎引导页(v1.5)
- Sparkle 自动更新(v1.5)
- 年龄/Life 追踪(v2)
- 数据导出/导入(另行提案)
- iOS / iPadOS 版本

## Further Notes

- 原版行为证据来自 REA 对 Moment_1_5_1.dmg 的静态分析(Info.plist、zh-Hans 141 条本地化字符串、Core Data Moment.momd 实体字段、资源 nib 清单),存档于分析会话;字段名与功能清单与原版一一对应,便于行为对齐。
- 原版数据实体含 synced/inMenubar/inToday 字段——分别对应本 spec 的 Out of Scope(同步、钉选、小组件),v1.5/v2 届时再加回。
- 名称 Daymark 与原版 Moment 无商标冲突风险,但 README 应注明"受 Moment 启发,非官方复刻"。
