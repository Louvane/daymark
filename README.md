# Daymark(日标)

macOS 菜单栏倒数日应用:把重要的日子(生日、活动、截止日)放在菜单栏触手可及的地方——倒数还剩几天,纪念已过去多久。

> 受 [Moment](https://apps.apple.com/app/moment/id1433358248) 启发,非官方复刻。免费、开源、纯本地。

<!-- 截图占位:发布前补一张面板截图(菜单栏 + 面板) -->
<!-- ![Daymark 面板](docs/images/panel.png) -->

## 功能(v1)

- **倒数 / 纪念日**:未来日期显示「还剩 N 天」,当天「就是今天」,过去显示「已过去 N 天」
- **重复周期**:不重复 / 每周 / 每月 / 每年;生日设一次每年重复,永远显示距下一个(2/29 生日在平年按 3/1 计算)
- **日期区间**:单日 ↔ 区间(旅行/展会),显示「进行中 · 第 X 天/共 Y 天」
- **具体时刻**:日期可附带时刻,提醒落在正确时刻
- **提醒**:提前 1/2/3/7/14/30 天本地通知;无时刻的日标落全局默认提醒时刻(默认 09:00);点通知定位到对应日标
- **外观**:内置分类 Emoji 选择器 + 预设色板;列表「最近优先 / 手动」排序,手动模式可拖拽
- **偏好设置**:默认提醒时刻、开机自启动(SMAppService)、关于页
- **中英双语**跟随系统语言;纯菜单栏形态(无 Dock 图标);数据只存本地 SwiftData,无云同步、无付费墙、无遥测

## 构建

要求:Xcode 16+(Swift 6,macOS 15+ SDK)。

```bash
git clone https://github.com/louvane/daymark.git
cd daymark
xcodegen generate        # 由 project.yml 生成 Daymark.xcodeproj(仓库已含生成物,可跳过)
xcodebuild build -project Daymark.xcodeproj -scheme Daymark -configuration Debug
```

直接开发:用 Xcode 打开 `Daymark.xcodeproj`,⌘R 运行。

### 测试

```bash
xcodebuild test -project Daymark.xcodeproj -scheme Daymark -destination 'platform=macOS'
```

领域层(日期运算、提醒规划、URL 解析、仓储)以固定日历纯函数测试钉死;UI 层保持薄层,以 SwiftUI Preview 人工验证。

### 发布打包(本地 adhoc 签名)

```bash
xcodebuild -project Daymark.xcodeproj -scheme Daymark -configuration Release \
  -derivedDataPath build
cd build/Build/Products/Release
codesign --force --deep --sign - Daymark.app          # adhoc 签名
ditto -ck --keepParent Daymark.app Daymark-1.0.0.zip  # 打包发布附件
```

Release tag 规范:`vMAJOR.MINOR.PATCH`(如 `v1.0.0`),附件命名 `Daymark-<version>.zip`。

## Roadmap

交付阶段见 [CONTEXT.md](CONTEXT.md#交付阶段):

- **v1.5**:年/季/月进度、钉选日标为独立菜单栏项、通知中心「今日」小组件、引导页、Sparkle 自动更新
- **v2**:年龄/Life 追踪

## 设计文档

- 领域词汇表:[CONTEXT.md](CONTEXT.md)
- 架构决策:[docs/adr/](docs/adr/)(SwiftUI-first、SwiftData、纯本地免费、macOS 15 下限)

## 致谢

- [Moment](https://apps.apple.com/app/moment/id1433358248):功能与信息架构的参照对象。Daymark 受其启发重新实现,与其无隶属关系。

## 许可证

[MIT](LICENSE) © Louvane
