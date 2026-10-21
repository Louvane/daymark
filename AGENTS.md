# AGENTS.md — Daymark

macOS 菜单栏倒数日应用。Swift 6 + SwiftUI-first(MenuBarExtra),SwiftData 本地存储,macOS 15+,中英双语,MIT 开源。功能对齐原版 Moment(studio.fireball.moment),刻意不做云同步与付费墙。

- 开发前先读 `CONTEXT.md`(领域词汇表)与 `docs/adr/`(架构决策);用词遵循词汇表,与 ADR 冲突时显式指出。
- 构建:`xcodebuild` 或直接在 Xcode 打开 `Daymark.xcodeproj`;测试:`xcodebuild test`(域层纯函数测试在 DaymarkTests,经 TEST_HOST 运行),或 Xcode Test 导航器。
- 本仓库为中文优先沟通;代码注释用中文;UI 文案走 String Catalog 中英双语。

## Agent skills

### Issue tracker

本地 markdown:`.scratch/<feature>/issues/<NN>-<slug>.md`。见 `docs/agents/issue-tracker.md`。

### Triage labels

默认五角色(needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix)。见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文:根 `CONTEXT.md` + `docs/adr/`。见 `docs/agents/domain.md`。
