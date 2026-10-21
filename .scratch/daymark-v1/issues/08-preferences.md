# 08: 偏好设置

**What to build:** 应用获得 Settings 场景(⌘, 或菜单项打开):①全局默认提醒时刻(时间选择器,默认 09:00),改动后全部无时刻 Daymark 的已排提醒按新时刻重排;②开机自启动开关,即时注册/注销 login item(SMAppService);③(顺手)关于页:版本号、开源地址、"受 Moment 启发"致谢。

**Blocked by:** 05 提醒通知

**Status:** resolved

- [x] Settings 场景可从面板入口(齿轮图标)打开,macOS 15 原生样式
- [x] 默认提醒时刻持久化(UserDefaults),修改后通知重排生效(假调度器测试验证重排被触发且用新时刻)
- [x] 开机启动开关:状态与 SMAppService 实际注册状态同步(打开应用时校正)
- [x] 关于页:版本(build)、GitHub 链接、MIT、"受 Moment 启发,非官方复刻"
- [x] 全部文案双语
- [x] 既有测试不回归
