# WITProbe 竞品与功能边界

**结论：** 项目仍可做，但应把生态贡献表述为 MoonBit 可复用的解释性契约分析与回归层，不能宣称已有生态完全没有 WIT 兼容性工具。

| 工具 | 已有职责 | WITProbe 的关系 |
|---|---|---|
| mizchi/wit | WIT 解析、名称及依赖解析、模型与 JSON | 直接复用，保留为独立 Adapter |
| mizchi/moon-component | 绑定、构建封装、拉取依赖、组合、Target 检查 | 协作对象，不重复实现生成与封装 |
| wasm-tools component wit / targets | 读取接口、验证组件是否满足 World | 解析和组件验证的外部对照 |
| wasm-tools component semver-check | 已有 World 演进关系验证 | 直接相关基线；必须区分方向语义 |
| WITProbe 后续原型 | MoonBit 库、稳定 IR、逐项 Diff、双向策略、UNKNOWN、回归及报告 | 本阶段仅完成接入实验，尚未实现这些引擎 |

上述上游职责依据：[解析器](https://github.com/mizchi/wit.mbt/blob/df59b4068926667eab2302a4daabecefad4c28ec/README.md)、[moon-component](https://github.com/mizchi/moon-component/blob/67741d56c1f87007253708165834d3f9c98867f4/README.md)、[wasm-tools](https://github.com/bytecodealliance/wasm-tools/blob/v1.263.0/src/bin/wasm-tools/component.rs)。

## 一、方向契约的建议定义

以下为下一阶段待实现和验证的策略，不是本阶段已经做出的兼容性判定：

- Provider Upgrade：固定旧使用方和旧环境，检查新组件能否替换旧组件；新组件不能增加环境无法提供的必需导入，也不能失去旧调用方需要的导出。
- Consumer Upgrade：固定旧提供方，把新契约作为新使用方所期待的接口；检查旧组件形状能否满足新期望。比较整份 World 时，还必须明确导入侧环境所提供的能力。

在相同身份映射和基础同步签名前提下，提供方的新增导出通常不破坏旧需求；新增必需导入通常不满足旧环境。使用方要求新导出时，旧提供方可能无法满足。导入接口内部的函数增删也必须按照“需要/提供”关系判断，不可直接套用导出规则。

**官方对照的实际方向：** `semver-check --prev old --new new` 用旧形状满足新期望；本次同包 World 探针结果为：

| new 相对 prev 的变化 | 官方 exit | 含义 |
|---|---:|---|
| 增加导出 | 1 | 旧形状缺少新要求 |
| 删除导出 | 0 | 新期望减少 |
| 增加导入 | 0 | 新期望允许更强的环境 |
| 删除导入 | 1 | 旧形状仍需要被删除的环境能力 |
| u32 参数/结果改成 string | 1，正反均失败 | 不同基础签名无法满足 |

这是该固定工具版本和样例的结果，不是所有 WIT 变化的规范定理。[实现及方向说明](https://github.com/bytecodealliance/wasm-tools/blob/v1.263.0/crates/wit-component/src/semver_check.rs)

## 二、版本身份与结构分析应分别说明

原计划把包从 1.0.0 改为 2.0.0。即使函数结构不变，带版本的接口名仍可能影响链接身份。后续应明确选择“结构演进分析”或“严格身份/链接检查”，报告选择及身份映射。官方 semver 实现会移除包版本再比较，不能用它证明任意运行时都能直接链接两个版本。

## 三、下一阶段应有的失败边界

解析失败属于输入错误；UNKNOWN 表示已读入契约但缺少可靠判定规则。Resource 身份、句柄所有权、复杂异步、未支持类型或无法匹配的身份，都不能默认为 COMPATIBLE。

建议先提供有限范围且说明理由的确定性规则，再用回归语料扩展；不把 AI 推断作为最终兼容性结果。CI 应允许明确选择 UNKNOWN 是否阻止发布，默认策略应在正式 CLI 阶段确定。
