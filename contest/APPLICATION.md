# WITProbe 项目申报说明

**项目名称：** WITProbe 0.3.0  
**方向：** MoonBit 开发者工具 / WIT 契约演进与回归检查  
**维护者 GitHub ID：** 3518936226-afk  
**仓库：** https://github.com/3518936226-afk/WITProbe  
**许可与环境：** MIT；Windows x64、PowerShell 7、可写 D 盘；MoonBit JS 目标与 Node。

## 要解决的问题

WebAssembly 组件升级时，WIT 文件能够解析，不代表新旧接口能够按预期替换。提供方升级和使用方升级的满足关系不同，资源身份、own/borrow 和依赖包版本又容易让差异难以解释。WITProbe 为维护者提供可审阅的变化说明、明确退出码和可保存的回归基线。

## 已完成的实现与价值

MoonBit 实现契约 IR、方向性比较、同步类型与资源规则、Diff 和 JSON/Markdown 报告汇总；复用固定版本的 mizchi/wit 解析器，Node 标准库负责文件、摘要、子进程和 CLI。支持常见值类型及嵌套、同步资源、own/borrow、方法和经校验的显式依赖版本映射；不能可靠判断时返回 UNKNOWN。基线保留源快照、摘要与规则版本，回归不改写基线，非零退出码可用于 CI 门禁。

wasm-tools 已有 semver-check。项目的增量是面向回归工作流的 MoonBit 实现、方向解释、规则编号、分组报告、可审阅的映射假设和基线完整性保护；不宣称首创 WIT 兼容检查或替代官方规范工具。

## 实际验证

2026-11-27，GitHub Actions 在干净 Windows checkout、新下载的锁定工具链、无构建缓存环境中通过完整验证：分析 40/40、集成 32/32、值类型与报告 60/60、资源与映射 66/66、真实项目 31/31、真实 WASI CLI 资源破坏 9/9，另有 4/4 源码变异被捕获。各套件包含预期 UNKNOWN/BREAKING，不能相加解释为兼容案例数。WASI CLI 0.2.0/0.2.1 未映射为 UNKNOWN；显式声明五个依赖版本映射后双向 COMPATIBLE。受控破坏不是上游漏洞。

**CI 证据：** https://github.com/3518936226-afk/WITProbe/actions/runs/45859517167  
**复现与演示：** 仓库 REPRODUCING.md、DEMO_GUIDE.md；准备完成后执行 `./scripts/demo.ps1`。

## 范围与贡献说明

当前检查同步契约结构；Future/Stream、部分提案及未解析身份保留 UNKNOWN。未验证 Native、Linux/macOS、业务组件运行、析构或运行时生命周期安全。实现和测试使用 AI 辅助；上游来源、初始批量上传历史及后续实质增量见 CONTRIBUTIONS_AND_AI.md。参与者需亲自演示并对技术选择负责，身份与正式报名在赛事表单中另行完成。
