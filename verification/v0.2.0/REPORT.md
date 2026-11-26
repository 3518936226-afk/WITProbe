# 0.2.0 真实项目复测

日期：2026-11-26。规则：value-sync-v2；报告 Schema 2，IR/基线 Schema 1。

常见值类型和嵌套组合已通过确定性规则、官方对照和实际 CLI 验证。测试来源与固定提交见 source-manifest.json；原始外部语料未修改。完整本地运行记录保留在项目 evidence/，本目录仅为路径脱敏后的精选记录。

| 输入/实验 | 旧版表现 | 当前实测 |
|---|---|---|
| WASI Random 0.2.0/0.2.1 双向版本比较 | UNKNOWN | COMPATIBLE / 0 |
| Random 两个版本各自比较自身 | UNKNOWN | COMPATIBLE / 0 |
| 真实 Random 副本的 List 元素类型变化 | 旧版不支持此类判定 | 双向 BREAKING / 1，官方对照一致 |
| 真实 Random 副本的 Tuple 成员类型变化 | 旧版不支持此类判定 | 双向 BREAKING / 1，官方对照一致 |
| WASI CLI 双向版本比较 | UNKNOWN | 仍为 UNKNOWN / 3，保留资源和依赖版本限制 |
| CLI Provider 默认 JSON | 1,510,227 字节 | 19,944 字节；完整 JSON 1,305,784 字节 |

27 项真实项目检查的 PASS 表示结果符合逐项预期，不能说两个项目都已兼容。官方工具接受 WASI CLI 的版本比较，WITProbe 的资源和身份规则尚未达到同等覆盖。

基线回归保持原始文件不变；真实本地门禁 Random 返回 0、CLI 返回 3。旧规则真实基线明确报 BASELINE_RULE_VERSION_CHANGED / 2。List/Tuple 改动是受控测试注入，不是上游发布或发现的上游缺陷。

基础验证：分析 33/33，产品集成 32/32，类型/报告 60/60（含 38 组额外官方对照），变异 3/3 被捕获；解析器接入 13/13、上游 113/113 单独记录。

默认汇总最多展示 20 条发现/变化，计数依据完整数组，ERROR/BREAKING 优先；--detail full 保留完整路径与定义。JSON/Markdown 来源一致。

未执行远程 GitHub Actions、Native 和真实业务组件运行。已有工具链复用，不代表全新机器安装验证。未修改公开性或许可证。
