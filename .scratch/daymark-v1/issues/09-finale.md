# 09: 收尾:URL scheme / README / LICENSE

**What to build:** v1 发布面收口:daymark:// 链接唤起应用并预填创建表单(便于外部集成);README 讲清项目是什么、为什么(受 Moment 启发的免费开源本地版)、怎么构建;MIT LICENSE 落盘;打好 1.0.0 tag 与 GitHub Release 的打包说明(含本地 adhoc 签名构建命令)。

**Blocked by:** 08 偏好设置(传递依赖:02~07 全部完成)

**Status:** ready-for-agent

- [ ] daymark://create?name=…&date=…&repeat=… 解析:预填创建表单并打开面板;参数非法时安全降级为空表单
- [ ] URL 解析为纯函数(可测),测试覆盖正常/缺参/乱码/恶意长度
- [ ] README:简介、截图位、功能清单、构建步骤(xcodebuild)、Roadmap(v1.5/v2 引用 CONTEXT.md 交付阶段)、致谢 Moment
- [ ] LICENSE:MIT(版权人 Louvane)
- [ ] 版本号 1.0.0、tag 规范、Release 附件构建说明写入 README
- [ ] 全部验收清单(.scratch/daymark-v1/issues/01~09)逐项复查勾选
