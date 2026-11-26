# Changelog

## 0.3.0 — 2026-11-27

- 支持同步资源声明、own/borrow、构造器、方法、静态函数与规范化别名身份。
- 增加严格的一对一依赖版本映射，保留原始 IR、映射策略摘要和比较投影。
- WASI CLI 原始版本在显式映射后双向通过；未映射和部分映射保持 UNKNOWN。
- 资源/映射增加 36 组官方对照，真实 WASI CLI 注入四类破坏并做八次双向官方对照。
- 增加资源身份擦除变异测试；旧规则基线要求明确重建。


## 0.2.0 — 2026-11-26

- 支持 List、Tuple、Option、Result、Record、Variant、Enum、Flags 及嵌套值类型的结构相等检查，保留名称、顺序与分支有无。
- 递归传播资源、异步、外部身份与深度限制的 UNKNOWN，未放宽资源和依赖身份规则。
- MoonBit Report 新增精确分组计数与符号示例；CLI 默认最多 20 条发现/变化，支持 JSON/Markdown 的 --detail full。
- 公开报告 Schema 升为 2；规则升级 value-sync-v2；旧基线保持原样并要求显式重建。
- 增加固定官方类型对照、报告完整性测试、固定提交的真实 WASI 下载器与回归检查。
- WASI Random 相邻发布版本从 UNKNOWN 改为 COMPATIBLE；WASI CLI 保留资源及依赖版本 UNKNOWN。

版本号表示本地源码版本；是否已上传、打 Tag 或发布 Release，以 GitHub 实际状态为准。
