# 01: 菜单栏应用骨架

**What to build:** 从零建立可运行的 Daymark.app:构建产物是纯菜单栏应用(LSUIElement),点图标弹出一个空面板(占位文案),再点外部关闭。双语 String Catalog 基建随票就位,后续票直接往里加 key。空壳 XCTest target 能被 xcodebuild test 跑绿,为后续票铺好验证通道。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `xcodebuild build` 产出 Daymark.app,零警告门槛警告项
- [ ] Info.plist:LSUIElement=true、bundle id、daymark:// scheme 占位
- [ ] 菜单栏图标常驻,点击弹出 MenuBarExtra window 样式面板,面板含占位文案与一个禁用的 + 按钮
- [ ] Localizable.xcstrings 建立,开发语言 zh-Hans,占位文案双语(en 翻译就位)
- [ ] 测试 target 存在且含一个恒真冒烟测试,`xcodebuild test` 全绿
- [ ] 提交信息引用本票编号
