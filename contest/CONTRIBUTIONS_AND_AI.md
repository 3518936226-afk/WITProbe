# 实现来源、开发记录与 AI 辅助说明

记录日期：2026-11-27。此文披露可核对的工程事实，不代替作者身份、队伍、知识产权签字或主办方资格审核。

## 自有实现与上游边界

| 范围 | 所在位置 | 说明 |
|---|---|---|
| WIT 解析、名称和依赖解析 | mizchi/wit 0.4.1，固定提交 | 复用上游，不计为本项目原创解析器；保留 Apache-2.0 许可 |
| 规范化与契约模型 | src/analyzer、src/contract | MoonBit Adapter、IR、名义身份与映射投影 |
| 比较及报告 | src/contract | MoonBit 方向关系、同步值类型/资源规则、Diff、规则编号与报告汇总 |
| 文件与宿主能力 | witprobe.mjs、scripts | Node CLI、摘要、只读基线、子进程；PowerShell 环境准备、门禁与验证 |
| 参考工具与真实输入 | wasm-tools、WebAssembly WASI 仓库 | 外部对照与测试语料；不是本项目实现，也不是本项目发现的上游漏洞 |

核心契约分析由 MoonBit 承担。仓库也包含较多 JavaScript 测试与宿主代码、PowerShell 验证脚本，GitHub 的语言比例不等同于核心引擎比例，也不保证满足任何特定赛规中的比例要求。未通过修改 Linguist 设置隐藏这些代码。是否满足“主要实现语言”要求，应由实际参赛规则和审核判断。

第三方版本、来源与许可证见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。[生态边界研究](../ECOSYSTEM_BOUNDARIES.md)是早期历史记录，已完成能力以 [CURRENT_STATUS.md](../CURRENT_STATUS.md) 为准。

## 可追溯的实际增量

早期工程先在本地开发，随后通过 GitHub 页面按文件目录分批上传。初始上传提交不能还原为连续的原始开发过程，也不能全部宣称是独立、有效的功能迭代。未补造旧提交、Issues 或 PR。仓库在 2026-11-27 才改为公开，不能声称此前全程公开开发。

| 阶段 | 已交付内容 | 可核对位置 |
|---|---|---|
| 接入与可行性 | 固定解析器、名称/依赖解析、官方方向探针 | TECHNICAL_FEASIBILITY.md、DEPENDENCY_ASSESSMENT.md |
| 值类型与汇总 | 常见同步值类型、嵌套结构、报告详略与分组 | CHANGELOG.md、src、scripts/test-value-types.mjs、verification |
| 资源与映射 | 名义资源身份、own/borrow、方法、显式映射、真实 WASI CLI | RESOURCE_MAPPING.md、verification/v0.3.0 |
| 独立复现 | 锁定工具下载、八阶段完整验证、源码一致性检查 | .github/workflows/full-validation.yml、verification/ci |
| 公开交付 | MIT、申报说明、演示与贡献披露 | LICENSE、contest、DEMO_GUIDE.md；本次真实提交记录 |

具体提交时间和文件差异以 [真实 Git 历史](https://github.com/3518936226-afk/WITProbe/commits/main/) 为准。如以已有项目参赛，只申报目标赛季内真实新增的部分；不得把已有代码或上游实现重复计入。是否接受前期私有开发记录，需按主办方实际口径确认。

## AI 辅助范围与责任

项目在需求梳理、规则实现、测试与变异用例、真实语料验证、故障排查、CI 配置及文档整理中使用了 Codex / AI 辅助。兼容结论由代码中的确定性规则计算，不调用模型生成判断。自动化执行结果已有日志和远程 CI 证据，但不等于参与者已亲自理解或完成演示。

参与者提交前应亲自完成下面的讲解与演示，并按赛事表单要求如实披露 AI 使用。没有完成的项目不能签为“已完成”。

1. 用同一新增导出说明 provider-upgrade 与 consumer-upgrade 为何得出不同结论。
2. 解释为何结构相同的不同资源不自动视为同一种资源，以及 own/borrow 的检查范围。
3. 展示未映射 UNKNOWN，再展示显式映射；说明映射假设保留在报告中。
4. 展示真实门禁拒绝 BREAKING，说明演示脚本整体返回 0 的含义。
5. 指出上游解析器、自有 MoonBit 引擎及 Node 宿主的边界，说明未验证的运行时能力。

GitHub ID 3518936226-afk 是仓库维护账号，不代表已核验参赛者实名、队伍人数、原创权属或报名资格。个人隐私信息应在官方表单中填写，不写入公开仓库。
