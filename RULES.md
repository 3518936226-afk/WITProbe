# 当前规则与报告协议

版本 0.2.0；规则集 **value-sync-v2**；公开报告 Schema **2**；IR/基线元数据 Schema **1**。

## 值类型

支持标量、别名及 List、Tuple、Option、Result、Record、Variant、Enum、Flags 的递归组合。规范化结构不含 Parser 数组编号，保留名称、顺序、数量、分支有无及嵌套类型。别名展开后比较结构。

已匹配位置要求已支持类型的结构完全相等。成员增删、改名、重排与嵌套类型变化判 TYPE_CHANGED / BREAKING。固定官方工具的 38 组方向对照覆盖这些变化；不尝试宽松数据转换。

容器任意子类型若含资源、异步、外部身份或达到深度保护，整体仍带对应 UNKNOWN 原因。相同形状和相同摘要不能消除未知。FixedLengthList、Map 等额外构造尚未纳入已证明规则。

## 判定与身份

provider-upgrade：actual=new，expected=old；consumer-upgrade：actual=old，expected=new。输入都描述提供方；不自动解释消费者 World。

导出侧要求 actual 提供 expected 所需能力；导入侧由 expected 环境满足 actual 的需求。

结果优先级为 ERROR → BREAKING → UNKNOWN → COMPATIBLE，退出码为 2/1/3/0。明确破坏与未知同时存在时保留两者并返回 BREAKING。

根包 namespace/name 相同才显式映射根版本，同时保留原版本。依赖版本不会自动擦除，同名不同版本为 UNMAPPED_DEPENDENCY_VERSION / UNKNOWN。参考工具接受版本变化不代表 WITProbe 已证明资源与依赖身份的兼容。

| 分类 | rule_id | 含义 |
|---|---|---|
| BREAKING | MISSING_WORLD_ITEM / MISSING_FUNCTION / MISSING_PUBLIC_TYPE | 所需能力或公开类型缺失；未被函数使用的公开类型也参与分析 |
| BREAKING | TYPE_CHANGED | 已支持值类型结构不同 |
| BREAKING | PARAMETER_COUNT_CHANGED / RESULT_PRESENCE_CHANGED / WORLD_ITEM_KIND_CHANGED | 参数数量、结果存在性或 World 项种类不同 |
| UNKNOWN | PARAMETER_NAME_CHANGED | 单独参数改名未纳入已证明规则 |
| UNKNOWN | UNSUPPORTED_RESOURCE / UNSUPPORTED_RESOURCE_OR_ACCESSOR | 资源、句柄、方法、访问器未验收 |
| UNKNOWN | UNSUPPORTED_ASYNC | Async、Future、Stream、ErrorContext 未验收 |
| UNKNOWN | UNSUPPORTED_COMPOSITE | 其他未支持的容器构造 |
| UNKNOWN | UNMAPPED_DEPENDENCY_VERSION / UNSUPPORTED_EXTERNAL_ID | 缺少身份映射证明 |
| UNKNOWN | TYPE_DEPTH_LIMIT | 遍历保护限制，不代表无变化 |
| ERROR | INVALID_DIRECTION / ROOT_IDENTITY_MISMATCH / OLD_INPUT_ERROR / NEW_INPUT_ERROR | 配置、身份或解析失败 |

Host 的参数、I/O、工具和基线损坏/漂移错误同样不属于 UNKNOWN。

## 汇总与完整报告

每条 Finding 保留 status、rule_id、symbol、reason、action。MoonBit Report 的 summary 统计全部发现，含 finding_count、breaking_count、unknown_count、error_count、change_count；各组包含 count、最多 3 个 sample_symbols 和 action。

公开 CLI 默认 detail=summary：最多 20 条 Finding 和 20 条 Change，Change 仅保留 kind/symbol，不嵌入完整 IR。findings_truncated/changes_truncated 明确标记省略。ERROR/BREAKING 优先排序，完整计数、结论、摘要和退出码不变。

--detail full 保留完整数组、变化定义、old_contract/new_contract 及规范化契约。JSON/Markdown 来源一致，均支持详略。程序库 compare() 返回完整结构。默认 CLI 由完整改为汇总是协议变化，因此报告 Schema 升至 2。

## 基线迁移

旧 scalar-sync-v1 基线保持原样，回归报 BASELINE_RULE_VERSION_CHANGED / 2。经人工复核源快照与新规则后，在新路径创建 value-sync-v2 基线；不得静默改写预期。

semantic_hash 仅表示当前 IR 投影，不能替代兼容判断。解析器测试、业务组件运行、Native 和远程 CI 各自独立记录。
