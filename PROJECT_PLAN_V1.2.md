# WITProbe 优化落实与后续计划 V1.2

> 历史计划：本文描述常见类型扩展之前的阶段。当前 0.2.0 的支持范围、已上传状态与真实复测以 README.md、CURRENT_STATUS.md 和 verification/v0.2.0 为准。

**日期：** 2026-11-26  
**当前成果：** 已有 MoonBit 分析库、可运行 JS/Node CLI、结构化报告和源契约基线的小闭环。  
**当前范围：** 基础标量、标量别名、同步函数，以及 World 的 Import/Export 约束。复杂类型保留并给 UNKNOWN。

本版承接 `PROJECT_PLAN_V1.1.md` 的总体定位，同时以本次真实实现更新优先级。V1.1 中的“尚待开发”属于当时状态，当前以本文件和 `CURRENT_STATUS.md` 为准。

## 一、七项优化如何落实

| 优化点 | 本次实现 | 验收证据 |
|---|---|---|
| 先完成小闭环 | 两份 WIT → 稳定 IR → Diff → 方向性判断 → JSON/Markdown → 退出码 | `witprobe.mjs compare`，完整示例见 `DEMO_GUIDE.md` |
| 补严公开契约范围 | 遍历所选 World 的接口全部公开类型，不仅追踪函数签名 | 未被函数使用的公开 Record 仍为 UNKNOWN；删除公开标量类型判 BREAKING |
| 解释 Consumer Upgrade | 输入统一为服务提供方契约；报告显示 actual_side/expected_side | 相同新增导出：Provider 通过、Consumer 失败 |
| UNKNOWN 可处理 | 固定 rule_id、符号路径、原因与对应 action | 资源、复杂类型、异步、参数改名、依赖版本分别说明 |
| 分离基线变化来源 | 源摘要、规范化契约摘要、规则版本分别记录 | 注释变化仅改变 source_hash；规则漂移要求显式迁移 |
| 加强正确性验收 | 双向规则、错误分类、官方有限对照、真实 CLI、源码变异测试 | 25 项 MoonBit 分析测试、32 项产品集成测试、3 个变异被捕获 |
| 演示体现实际价值 | 同一新增函数展示方向差异，接着展示签名破坏与 UNKNOWN，再执行本地门禁 | `scripts/demo.ps1` 保存每份 JSON、Markdown 和汇总 |

## 二、已确定的语义

统一关系是：`check(actual, expected)` 检查实际提供方能否满足期望契约。

| 模式 | actual | expected | 解释 |
|---|---|---|---|
| provider-upgrade | new | old | 新提供方继续满足旧要求与旧环境 |
| consumer-upgrade | old | new | 旧提供方满足调用方升级后的服务要求 |

消费者自身的 World 到“服务期望”的自动转换尚未实现。不能把任意消费者 World 直接当作上述 new 输入。

导出侧检查 actual 提供 expected 所需能力；导入侧检查 expected 环境提供 actual 所需能力。根包允许在相同 namespace/name 下做结构版本映射，原始版本仍保留在报告中；依赖版本不会被全局抹去。

结果优先级为 ERROR → BREAKING → UNKNOWN → COMPATIBLE；明确破坏与未知项同时存在时，结论为 BREAKING，未知项仍保留。ERROR 属于输入、配置或运行失败，不冒充兼容性未知。

## 三、交付结构

| 位置 | 职责 |
|---|---|
| `src/contract/` | 独立 MoonBit IR、Diff、纯比较函数、统一报告；不导入上游 WIT 模型 |
| `src/analyzer/` | 上游 Parser/Resolve Adapter、稳定身份转换、公开类型遍历 |
| `src/cli/` | 编译后的 MoonBit 分析进程入口 |
| `witprobe.mjs` | Node 标准库实现参数、进程、文件、摘要及基线 I/O；不实现兼容性规则 |
| `scripts/ci-gate.ps1` | 原样传递回归的退出码，供本地或已配置的 CI 环境使用 |
| `run-validation.ps1` | 解析、分析、CLI 集成、官方对照和变异测试统一入口 |

当前交付是 MoonBit 实现、编译到 JS、由 Node 承载的 CLI。Windows Native 可执行文件仍未通过，不能把本成果称作已验证的 Native 发布。

## 四、基线协议

创建基线会拒绝已有路径，并要求输出位于输入树之外。基线保存：

- 完整选定 WIT 源文件及本地 deps 快照、相对路径与文件摘要。
- 所选 World、IR Schema、Parser 版本/提交与解析选项。
- source_hash：文件字节和相对路径的摘要。
- semantic_hash：当前规范化 IR 的摘要，排除根包版本显示字段。
- rule_set_version：规则版本；另保存 IR 文件摘要。

回归只读基线；源快照、IR、Parser、选项或规则版本不符时，明确报错，禁止自动重写预期。尚未提供自动迁移/更新基线命令。

semantic_hash 只代表当前 IR 投影，不能替代兼容性判断；尤其不能据 UNKNOWN 类型的摘要相同就推断兼容。

## 五、验收与演示

本次已完成的产品验收：

1. 基础 Import/Export 增删在两个方向下得到相应结论。
2. 参数数量、基础类型、结果存在性变化能够报告破坏项。
3. 参数名称单独变化保守返回 UNKNOWN。
4. 公开但未被函数使用的类型参与分析；所选 World 不可达的顶层接口不影响结论。
5. 集合声明重排规范化，参数和 Record 成员顺序保留。
6. JSON 与 Markdown 使用同一个 Report 生成。
7. CLI 的 0/1/2/3 退出码均通过真实进程验证。
8. 基线回归不改写任何基线文件，并能检测源、IR、规则及 Parser 漂移。
9. 与固定官方工具进行 8 组方向对照；预期不兼容必须带相应错误语义，普通工具失败不算成功对照。
10. 在独立副本中反转方向、忽略类型变化和吞掉 UNKNOWN，测试均失败，原工程不受修改。

演示优先顺序：新增导出双向差异 → 参数与结果类型破坏 → 公开复杂类型 UNKNOWN → 只改注释的基线区分 → 本地 CI 门禁拦截。版本变化单独展示。

## 六、后续优先级

### P0.1：先评审当前规则与 API

- 审查接口身份、显式标签、隐式类型依赖与复杂跨包别名的边界。
- 在规则版本升级时增加相应样例；现有基线的重新计算需明确迁移记录。
- 增加跨包类型重导出和更复杂别名图的独立参考对照。
- 发布前明确公共模块命名、JSON Schema 和兼容承诺。

### P0.2：完成真实工程接入

- 选择获授权的仓库和可用 CI 环境，实际运行门禁并保留日志。
- 用真实项目建立历史基线；继续记录无法判定的类型，避免一开始扩大支持承诺。
- 增加规模基准并检查线性搜索带来的开销。本次没有新跑性能基准。

### P1：按需求扩展

Record/Variant/Flags 等规则、消费者 World 自动转换、实际业务组件 ABI/行为验证、HTML 报告，以及 Native 打包。当前的 UNKNOWN 不因演示需要而放宽。

**状态边界：** 本地闭环和门禁已验证；远程 CI、业务组件互操作、Native 发布与完整 WIT 子类型兼容性尚未验收。没有推送仓库、发布软件或部署网站。
