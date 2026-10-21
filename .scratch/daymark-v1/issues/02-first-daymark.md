# 02: 第一条 Daymark:创建与浏览

**What to build:** 用户能创建第一条 Daymark 并在面板看到它:点 + 打开创建表单,填名称、选日期,保存;面板列表按最近将到排序,每行显示 Emoji 占位、名称、以及"还剩 N 天 / 已过去 N 天"(今天=剩 0 天)。数据落 SwiftData,重启应用仍在。DateMath 核心函数(两日期相差天数、面向未来/过去的状态判定)随票实现并带全量测试。

**Blocked by:** 01 菜单栏应用骨架

**Status:** resolved

- [x] 创建表单:名称必填、日期选择器,保存后面板列表即时出现
- [x] 列表行:Emoji 占位、名称、剩余/已过天数;排序=最近将到优先
- [x] 已过日期显示"已过去 N 天",未来日期显示"还剩 N 天",当天显示"就是今天"
- [x] SwiftData @Model 按 spec 字段建好(含本票暂未在 UI 暴露的字段:repeatCycle/remindDays 等取默认值)
- [x] DateMath:daysBetween、状态判定,固定日历+固定参考日测试(当天、跨月、跨年、闰日)
- [x] DaymarkStore:in-memory 容器 CRUD 测试通过
- [x] 重启应用数据仍在
