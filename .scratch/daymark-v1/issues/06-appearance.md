# 06: 外观自定义:Emoji/颜色/手动排序

**What to build:** 用户给每条 Daymark 选 Emoji 和颜色,列表一眼可辨;并可手动拖动排序(sortWeight),列表提供"最近优先/手动"两种排序切换。Emoji 选择器按分类展示(复用原版思路:内置分类 Emoji 数据,双击即选)。

**Blocked by:** 03 面板导航:详情/编辑/删除/空态

**Status:** resolved

- [x] 创建/编辑表单:Emoji 选择器(分类浏览 + 常用区),选中即预览
- [x] 创建/编辑表单:预设色板选颜色,列表行与详情页呈现颜色标识
- [x] 列表行显示所选 Emoji(替换 02 票占位)
- [x] 手动排序:列表模式切换(最近优先 ↔ 手动),手动模式下拖动生效并持久化
- [x] Emoji 数据源内置(分类 JSON 进 bundle),不依赖系统 Emoji 面板
- [x] 颜色与 Emoji 存 SwiftData,重启后保留
