# 当前规则与报告协议

**IR / Report Schema：** 1  
**规则集：** scalar-sync-v1  
**分析范围：** structural；同步函数、基础标量与标量别名可判定。

| 类别 | rule_id | 含义与处理 |
|---|---|---|
| BREAKING | MISSING_WORLD_ITEM | 缺少期望的 World 能力 |
| BREAKING | MISSING_FUNCTION | 缺少接口中所需函数 |
| BREAKING | MISSING_PUBLIC_TYPE | 公开类型缺失，不要求先被函数引用 |
| BREAKING | TYPE_CHANGED | 已支持基础类型不一致 |
| BREAKING | PARAMETER_COUNT_CHANGED | 参数数量不一致 |
| BREAKING | RESULT_PRESENCE_CHANGED | 结果有/无不一致 |
| BREAKING | WORLD_ITEM_KIND_CHANGED | 已匹配 World 项种类不同 |
| UNKNOWN | PARAMETER_NAME_CHANGED | 单独参数改名的语义尚未证明 |
| UNKNOWN | UNSUPPORTED_RESOURCE | 资源/句柄需要名义身份、所有权和生命周期规则 |
| UNKNOWN | UNSUPPORTED_RESOURCE_OR_ACCESSOR | 资源方法/访问器不在基础规则内 |
| UNKNOWN | UNSUPPORTED_ASYNC | 异步函数、future、stream、error-context 尚未判定 |
| UNKNOWN | UNSUPPORTED_COMPOSITE | Record、Variant、Enum、Flags、List、Tuple、Option、Result 等保留形状，尚未证明兼容 |
| UNKNOWN | UNMAPPED_DEPENDENCY_VERSION | 同一依赖身份的版本不一致，需要明确映射 |
| UNKNOWN | UNSUPPORTED_EXTERNAL_ID | 外部身份元数据保留，但没有对应判定规则 |
| UNKNOWN | TYPE_DEPTH_LIMIT | 类型遍历达到保护深度；不能解释为无变化 |
| ERROR | INVALID_DIRECTION / ROOT_IDENTITY_MISMATCH | 方向或根包身份无有效配置 |

错误输入由 OLD_INPUT_ERROR / NEW_INPUT_ERROR 表达，退出码 2。Host 还会报告参数、I/O、工具、基线损坏和版本漂移等错误；这些不是 UNKNOWN。

每条 Finding 包含 status、rule_id、symbol、reason、action。Change 与 Finding 分别记录：新增导出可以有 Change，但没有破坏项；复杂类型即使未修改，仍可能有 UNKNOWN Finding。

报告保存 old_contract/new_contract、结构投影、根包版本映射、解析选项、Parser 版本与两份 semantic_hash。Markdown 直接由同一个 MoonBit Report 生成。根包版本映射不代表实际运行时可直接链接。

`src/contract` 的公共比较 API 不依赖上游 Parser 类型；`src/analyzer` 负责将固定解析模型转换为这些数据结构。尚未宣告公共 API 稳定，也未发布到包注册表。

任何改变判定行为的修改都必须升级 rule_set_version 并重跑语料；本原型不自动推断规则的语义版本。semantic_hash 相等不能覆盖 UNKNOWN 或代替规则验证。
