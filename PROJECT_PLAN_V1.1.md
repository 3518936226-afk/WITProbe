# WITProbe 项目任务计划书

> 历史计划版本；当前实现进度及后续优先级见 `PROJECT_PLAN_V1.2.md` 和 `CURRENT_STATUS.md`。下文保留 V1.1 制定时的状态。

**计划版本：** V1.1（基于第一阶段实测修订）  
**修订日期：** 2026-11-26  
**项目类别：** MoonBit 工具库 / 开发者工具  
**英文定位：** Explainable WIT Contract Evolution & Regression Testing

## 一、项目定位

WITProbe 为 MoonBit 开发者提供可复用的 WIT 契约差异分析、方向性兼容检查和回归验证能力。

开发者提交接口修改后，工具应说明：哪个 World、哪条 Import/Export、哪个函数发生变化；按所选方向，哪一项旧约束无法满足；结论基于哪条规则；哪些部分仍无法判断。

核心成果是 **MoonBit 原生分析库、可解释报告和可重复执行的回归语料**。CLI 是这些能力的入口，AI 只辅助发现测试缺口。

### 1.1 与现有生态的关系

| 已有能力 | 采用方式 | 本项目新增的交付 |
|---|---|---|
| mizchi/wit 的解析与 Resolve | 固定版本直接复用 | 隔离上游 API 的 Adapter、稳定 IR |
| wasm-tools 的 World 兼容检查 | 作为有限范围的外部参考 | 明确方向、逐项变更理由、UNKNOWN 与策略报告 |
| moon-component 的生成与组件封装 | 后续通过标准 WIT 或 CLI 协作 | 契约演进和历史基线管理 |

官方工具已有 `component semver-check`；项目不以“首个 WIT 兼容性检查工具”作为参赛主张。[固定参考实现](https://github.com/bytecodealliance/wasm-tools/blob/v1.263.0/crates/wit-component/src/semver_check.rs)

## 二、当前起点

阶段一已完成：13 个接入测试、113 个上游测试、3 个解析语义对照、4 个官方正负例，以及 6 个官方方向探针。跨包依赖解析已经跑通。详情和失败证据见 `TECHNICAL_FEASIBILITY.md`。

Windows Native 尚未通过：现有 MinGW 不满足此次 MoonBit 运行时要求。当前先用 MoonBit JS 目标验证分析库和 CLI；Native 作为独立验收项，不能用 JS 成绩替代。暂不安排大型工具链安装。

**尚待开发：** 稳定 IR、Canonicalizer、Diff、兼容性引擎、基线管理和正式 CLI。本计划中的命令、字段和规则均是开发目标，不能据此宣称已经支持。

## 三、先固定兼容性问题的含义

### 3.1 统一判定入口

定义 `check(actual, expected)`：实际组件形状是否满足给定 World 期望。

在可判定的基础范围内，需要同时满足：

1. actual 提供 expected 要求的全部导出。
2. actual 所需的导入，可由 expected 所描述的环境能力满足。
3. 匹配项的接口、函数和类型满足已实现的确定性规则。

这检查的是契约约束，不证明实现行为、业务语义或任意运行时的链接结果。

### 3.2 两种方向只改变参与者映射

| 模式 | actual | expected | 用户关心的问题 |
|---|---|---|---|
| provider-upgrade | new | old | 新组件能否替换旧组件，继续满足旧使用方和旧环境？ |
| consumer-upgrade | old | new | 旧组件能否满足升级后的调用期望？ |

P0 的两份输入统一表示“服务提供方的 World 契约”。consumer-upgrade 的 new 是调用方对服务的新期望，不能直接把任意消费者自身的 World 当作它。消费者自身 Import 到服务期望的转换另列增强功能。

同身份映射的基础范围内，首批规则矩阵如下：

| new 相对 old 的变化 | Provider Upgrade | Consumer Upgrade |
|---|---|---|
| 新增导出函数/接口 | COMPATIBLE | BREAKING |
| 删除导出函数/接口 | BREAKING | COMPATIBLE |
| 新增必需导入函数/接口 | BREAKING | COMPATIBLE |
| 删除必需导入函数/接口 | COMPATIBLE | BREAKING |
| 已匹配同步函数改变参数数量 | BREAKING | BREAKING |
| 已匹配参数的已支持基础类型改变 | BREAKING | BREAKING |
| 已匹配结果的已支持基础类型改变，包括有/无结果 | BREAKING | BREAKING |
| 仅文档、空白或声明顺序变化 | COMPATIBLE | COMPATIBLE |
| 所选 World 不可达的定义变化 | 仅记录 Diff，不影响结论 | 同左 |
| 可达 Resource、句柄、异步或未支持复杂类型 | UNKNOWN，除非另有明确破坏项 | 同左 |
| 仅参数名称改变 | UNKNOWN，待独立验证规则 | 同左 |
| 无法确定依赖版本或符号身份对应关系 | UNKNOWN | UNKNOWN |

导入接口中的函数增删按“需要的能力”比较，导出接口中的函数增删按“提供的能力”比较；不能统一套用增删规则。

固定参考工具实际按旧形状满足新期望验证。适用样例的参考调用映射为：provider-upgrade 用 `--prev new --new old`，consumer-upgrade 用 `--prev old --new new`。只对工具支持、身份策略一致的样例对照；错误退出还须区分工具失败和预期的不兼容。[参考实现与本地探针](ECOSYSTEM_BOUNDARIES.md)

### 3.3 结论和错误分开

| 情况 | 结果 | 计划退出码 |
|---|---|---:|
| 分析范围内均有兼容证明 | COMPATIBLE | 0 |
| 至少一项确定违反约束 | BREAKING | 1 |
| 输入无效、World 选择错误、配置错误或工具执行失败 | ERROR，附错误类别 | 2 |
| 输入有效，但规则覆盖不足 | UNKNOWN | 3 |

聚合优先级：输入/运行错误先终止；有效分析中 BREAKING 优先于 UNKNOWN，UNKNOWN 优先于 COMPATIBLE。报告仍保留所有未知项，不能因存在破坏项而丢弃它们。P0 中 UNKNOWN 阻止 CI 通过。

## 四、P0 范围与非目标

### 4.1 必须完成

- 读取本地 WIT 文件或目录，解析本地 `deps/`；明确选择 old/new World。
- 建立带版本的、可序列化的稳定 IR，并保留上游来源及解析选项。
- 识别函数、参数、结果、接口、World Import/Export 和类型定义的变化。
- 为同步函数、标量及标量别名建立首批规则；对未支持的可达类型返回 UNKNOWN。
- 输出 JSON 与 Markdown；每条判断带稳定符号路径、规则 ID、方向和理由。
- 保存源契约快照及基线元信息；在不同进程中重复执行并校验一致性。
- 提供本地 CLI 和 GitHub Actions 配置，在可用环境实际执行完整检查。

“识别类型定义发生变化”与“证明该类型变化兼容”分别验收。Record、Variant、Flags 等先保留并报告，不承诺 P0 实现全部子类型规则。

### 4.2 延后到 P1

实际业务组件构建/ABI 验证、消费者自身 World 转换、完整复杂类型规则、HTML 报告、联网依赖拉取、moon-component 内部 API 集成，以及跨平台 Native 打包。

P0 不重写 Parser、绑定生成、componentize 或组件组合工具。

## 五、IR 与规范化设计

### 5.1 先保留身份，再进行比较

建议采用 `Contract / World / Interface / Function / Type / Edge` 六类对象，IR Schema 从 1 起独立版本化。

- Package 保存 namespace、name 和 version。
- World 和 Interface 使用限定名；边另外保存方向、显式标签与目标身份。
- Function 保存有序参数、参数名、结果和同步/异步种类。
- Type 保存定义、来源、owner 和可达关系。未知节点也有明确表示。
- 上游数组索引只作 Adapter 内部引用，不能进入公共稳定 ID。

规范化仅排序语义无序的集合。参数、字段、变体和元组等有序成员不得排序。标量别名可展开；Resource 的 nominal identity 不得抹平。

### 5.2 版本策略必须出现在报告中

P0 做结构演进分析：同 namespace/name 的根包可按显式记录的 old→new 版本映射比较。其余依赖版本保持原始身份，不能全局删除版本。

若依赖身份无法对应，保留 Diff 并给 UNKNOWN；根包 namespace/name 不同且没有映射属于配置错误。报告明确记录 `analysis_scope=structural` 和身份映射，不声称已经证明真实组件可直接链接。严格链接身份策略列为 P1。

## 六、模块安排

初期保留五个清晰模块，减少空壳工程：

| 模块 | 对外职责 |
|---|---|
| wit_adapter | 文件读取、上游解析、错误转换；上游类型不泄漏到公共分析 API |
| contract | IR、Schema、稳定身份、规范化和可达关系 |
| analysis | 纯函数 Diff、规则判断、方向映射和结论聚合 |
| report | JSON/Markdown，序列化与反序列化 |
| cli | 参数、文件输出、基线命令和退出码；不包含兼容性规则 |

回归执行器先服务于 CLI，只有形成独立可复用 API 时再拆包。组件 Adapter 到 P1 再建立。

## 七、CLI 与回归交付目标

以下是目标命令示意，**当前尚不可执行**：

```text
witprobe compare --old <path> --new <path> --world <name>
                 --direction provider-upgrade --format json --out <report>

witprobe baseline create --wit <path> --world <name> --out <new-baseline-dir>
witprobe regression run --baseline <dir> --new <path> --direction provider-upgrade
```

old/new World 名称不同时提供独立选择参数。不得默认选择第一个 World。

基线包含源 WIT/deps 快照、源文件摘要、IR Schema、工具链及依赖版本、解析特性选项、所选 World、分析策略和预期结果。只保存上游 JSON 不足以重现历史检查。

`baseline create` 默认拒绝覆盖。回归运行只读基线；修改预期结果必须使用显式更新操作，并展示差异。每次执行保存独立报告和汇总，失败证据保留。

## 八、后续里程碑

以下按阶段一已完成估算后续约 8 个工作日，不作为已承诺工期；遇到规则或环境问题按验收项调整。

| 里程碑 | 参考工作量 | 必须拿出的证据 |
|---|---:|---|
| M1：IR 与 Adapter | 2 日 | 不同声明顺序得到相同 IR；参数顺序变化仍可见；依赖身份不丢失 |
| M2：Diff 与方向规则 | 3 日 | 基础矩阵双向通过；加入反例后测试必须失败；UNKNOWN 可达性与优先级明确 |
| M3：CLI、报告与基线 | 2 日 | 从全新输出目录执行；0/1/2/3 四类退出结果；基线不会被检查操作改写 |
| M4：CI、基准与演示 | 1 日 | 实际 CI 日志或明确未运行状态；可复现计时；完整演示和限制说明 |

M2 必须先固定规则 ID 与矩阵，再扩展规则数量。未通过 M1/M2，不用额外界面掩盖分析能力缺口。

## 九、工程验证与参赛证据

| 验证维度 | 具体证据 |
|---|---|
| Harness | 固定输入、World、特性选项、工具版本；上游模型差异须经过语义规范化 |
| Regression | 至少 12 类基础情景双向覆盖，另有未知类型、身份异常和无效输入；数量不替代规则正确性 |
| Oracle | 匹配范围内对照官方工具；不支持或工具异常不计为兼容 |
| Mutation | 故意反转方向、忽略类型或吞掉 UNKNOWN，现有测试必须捕获 |
| Benchmark | 100/1,000/10,000 个同步函数样例；固定工具链；分开记录冷启动及热运行、解析及分析耗时，保留原始计时 |
| Automation | 本地脚本和 CI 使用同一入口；每次运行独立保存 summary 与日志 |
| AI Validation | AI 提议的规则缺口必须转成可复现样例；最终结果来自确定性代码 |

报告内容不把解析测试、业务运行测试或不同方向的检查合并成一个“全通过”数字。Native、业务组件和真实 CI 各自独立标注状态。

## 十、最终演示

采用相同包版本先隔离接口结构变化，避免演示一开始混入链接版本问题：

1. 准备可运行的 `calculator` 接口与 `calculator-world`，保存基线。
2. 仅新增一个导出函数，显示两种方向得到不同结论及原因。
3. 把 `add(u32, u32) -> u32` 改为字符串签名，显示具体破坏路径。
4. 加入暂未支持的可达复杂类型，显示 UNKNOWN 和退出码 3。
5. 执行历史基线回归并展示 CI 阻止发布的实际结果。

最后再单独演示包版本映射。实际业务组件互操作在 P1 单独验收，不能把合成组件检查包装成业务运行成功。

## 十一、最终验收清单

- [ ] 分析核心为 MoonBit，可被其他 MoonBit 项目直接调用。
- [ ] 稳定 IR 不依赖上游数组编号；依赖身份及参数顺序保真。
- [ ] 至少覆盖原计划要求的五类基础变化，并解释每条规则。
- [ ] Provider/Consumer 映射与官方有限对照一致。
- [ ] ERROR、BREAKING、UNKNOWN、COMPATIBLE 可区分，退出码有实际验证。
- [ ] 基线源文件和元信息足以重现；回归不会改写基线。
- [ ] JSON 有 Schema 版本，Markdown 与 JSON 的结论一致。
- [ ] 本地完整检查通过；CI 的实际运行状态明确。
- [ ] 原始基准数据、失败样例、许可证和复现说明完整。

**预期成果：** 一套范围清晰、理由可追踪、能够嵌入 MoonBit 开发流程的 WIT 契约演进与回归工具。
