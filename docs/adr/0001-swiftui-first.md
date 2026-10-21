# SwiftUI-first,不复刻原版 AppKit 结构

原版 Moment 是 AppKit nib + SwiftUI 混合的 2020 年代架构。Daymark 全新实现,选择 SwiftUI-first(MenuBarExtra、SwiftUI 生命周期),只在 SwiftUI 够不到的系统能力处局部用 AppKit。目标:同等功能下约省一半 UI 代码,且不受原版 nib 结构约束。视觉按 macOS 15 设计语言自由重设计,功能与信息架构对齐原版即可。
