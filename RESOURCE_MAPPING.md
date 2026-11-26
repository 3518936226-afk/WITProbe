# 资源与依赖版本映射（0.3.0）

规则集为 `resource-sync-v3`。这是同步 WIT 契约结构检查，不执行资源析构、借用或业务组件；不证明运行时生命周期和跨组件资源实例身份。

支持资源声明、`own<T>`、`borrow<T>`、同步构造器/方法/静态函数，以及嵌套句柄。资源按包、接口（含 World 内联标签）和原始类型名建立名义身份；别名与重导出追溯原始定义，不使用 Parser 数组编号。结构相同的不同资源不会自动合并。

## 显式映射

默认不忽略依赖版本。使用如下 JSON 声明同一 namespace/package 的旧、新版本：

```json
{"schema_version":1,"packages":[
  {"old_package":"wasi:io@0.2.0","new_package":"wasi:io@0.2.1"}
]}
```

两端必须实际存在于各自输入，必须一对一且版本不同。拒绝跨包、重复端点、根包映射、缺失版本及会合并新输入中共存版本的映射；拒绝未知字段、重复 JSON 键和超限配置。根包版本仍由原有规则独立处理。

映射只把比较投影中的 new 包身份对齐到 old 身份，之后仍逐项检查资源、所有权、方法、值类型、公开类型和能力约束。它不是“相信版本兼容”的跳过开关。部分映射会保留其余 UNKNOWN；多版本复杂图暂采用保守拒绝策略。

原始 old_contract/new_contract 和它们的语义摘要保持原始身份；完整报告另存 comparison_new_contract。dependency_mappings、mapping_sha256 和 Markdown 假设清单记录本轮使用的策略。Change 表示映射后的结构差异，版本假设由独立清单表达。

## WASI CLI

仓库提供 `fixtures/wasi-cli-0.2.0-to-0.2.1.mapping.json`，逐条列出 clocks、filesystem、io、random、sockets 的版本对。以下命令中的路径替换为已下载的原始语料：

```powershell
node .\witprobe.mjs compare --old OLD_CLI_WIT --new NEW_CLI_WIT --world command --dependency-map .\fixtures\wasi-cli-0.2.0-to-0.2.1.mapping.json
node .\witprobe.mjs regression run --baseline NEW_V3_BASELINE --new NEW_CLI_WIT --dependency-map .\fixtures\wasi-cli-0.2.0-to-0.2.1.mapping.json
.\scripts\ci-gate.ps1 -Baseline NEW_V3_BASELINE -New NEW_CLI_WIT -DependencyMap .\fixtures\wasi-cli-0.2.0-to-0.2.1.mapping.json
```

映射始终按输入 old/new 的时间顺序填写；consumer-upgrade 只反转满足关系，不反转映射文件。

Async、Future、Stream、访问器提案、外部身份或无法稳定定位的资源仍 UNKNOWN。旧 value-sync-v2/scalar-sync-v1 基线需人工复核后在新目录重建；回归拒绝静默迁移。报告 Schema 2、IR/基线 Schema 1 保持不变。
