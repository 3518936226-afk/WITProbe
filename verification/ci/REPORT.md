# GitHub Actions 实际验收

日期：2026-11-27。最终运行：[Full Windows validation #2](https://github.com/3518936226-afk/WITProbe/actions/runs/45859517167)。

结果：SUCCESS。受测提交：8333b40edad47cd01dde80f0f5c591c0d535ab0b；Windows 2025 托管 runner，任务 1 分 49 秒，整体 1 分 52 秒。

从干净 checkout 开始，重新下载并校验 MoonBit、Core、Node、Python、固定 Parser、参考工具和官方 WASI 原始语料；没有恢复构建缓存。

| 检查 | 结果 |
|---|---|
| MoonBit 分析 | 40/40 |
| 集成 | 32/32 |
| 值类型与报告 | 60/60 |
| 资源与映射 | 66/66 |
| 真实项目 | 31/31 |
| 真实资源破坏 | 9/9 |
| 变异捕获 | 4/4 |
| 演示与本地门禁 | PASS |
| 测试后源码与未跟踪源文件检查 | PASS |

强制执行八个必需测试阶段，未使用 SkipMutations，未缺失真实语料阶段。PASS 包含符合预期的 UNKNOWN、BREAKING 和配置拒绝，并非所有输入兼容。

原始验证证据保存在本次运行页面的一个 artifact 中，工作流设置保留 7 天。首轮 #1 也已通过，后将基础 Action 更新为当前官方 Node 24 版本，并在 #2 重新验证；最终无弃用运行时警告。

[复现步骤](../../REPRODUCING.md)。当前仓库仍私有，复现者需要访问权限、Windows x64、可写 D 盘、Git、PowerShell 7 与网络。MoonBit 官方 latest URL 的内容以固定 SHA256 锁定；上游更新时需复核并更新锁，不会悄悄接受新文件。

本机也已安装同一套校验通过的全新工具链，并通过真实 WASI CLI 映射比较烟雾测试。本次没有验证 Native、Linux/macOS 或真实业务组件运行。历史资源验收记录保留原样。
