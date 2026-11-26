# WITProbe

**MoonBit WIT 契约演进与回归检查原型，版本 0.3.0。**

比较两个服务提供方 World，输出方向性兼容结论、Diff、规则编号和退出码。MoonBit 实现 IR、比较规则、报告及分组汇总，Node 标准库承载文件、SHA256、进程与 CLI。

## 支持范围

- 标量、别名、同步函数及 World Import/Export 约束。
- List、Tuple、Option、Result、Record、Variant、Enum、Flags 及嵌套组合。
- 已支持值类型要求相同结构，保留成员名、顺序、数量、分支有无与嵌套类型。
- 同步资源声明、own/borrow、构造器、方法和静态函数可检查；别名保留原始名义身份。
- 依赖版本支持经校验的显式一对一映射；异步、访问器提案、外部身份与未映射版本仍保守处理。
- Windows GitHub Actions 已完成干净环境验证；Native、业务组件 ABI/运行时与完整 WIT 子类型仍未验收。

真实 WASI Random 0.2.0 → 0.2.1 双向比较为 COMPATIBLE；WASI CLI 在声明五个依赖版本映射后双向为 COMPATIBLE，未声明映射时仍为 UNKNOWN。详见 [CURRENT_STATUS.md](CURRENT_STATUS.md)。

## 干净环境与 GitHub Actions

完整步骤见 [REPRODUCING.md](REPRODUCING.md)。新克隆可先运行 scripts/bootstrap-ci.ps1 自动下载并校验 MoonBit、Node 和 Python，再执行 prepare 与完整测试。Actions 使用同一入口，包含真实 WASI、全部官方对照、4 个变异、演示与门禁，并检查测试后源码不变。

## 准备环境（Windows / D 盘）

```powershell
git clone https://github.com/3518936226-afk/WITProbe.git D:\VAPP\WITProbe
Set-Location D:\VAPP\WITProbe
.\scripts\prepare.ps1 -Toolchain 'D:\VAPP\tools\moon'
```

将路径换成可写 D 盘目录及已有、符合 toolchain.lock.json 的 MoonBit 安装。完整验证需要 Git、PowerShell 7、Node 和 Python。准备脚本校验版本、克隆固定 Parser 提交、准备依赖，下载并校验官方 wasm-tools；不安装 MoonBit/MSVC，不修改系统配置。本机路径写入被忽略的 toolchain.local.json，也可使用 WITPROBE_MOON_HOME。

当前 CLI、准备与验证脚本限定 Windows/D 盘，不能直接用于 Linux CI。

## 比较

```powershell
node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world
node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world --direction consumer-upgrade --format markdown
```

两份输入都描述提供方：provider-upgrade 检查 new 满足 old；consumer-upgrade 检查 old 满足 new。消费者自身 World 的自动转换尚未实现。

| 结论 | 退出码 |
|---|---:|
| COMPATIBLE | 0 |
| BREAKING | 1 |
| ERROR（输入、配置、工具失败） | 2 |
| UNKNOWN（有效输入超出已证明规则） | 3 |

默认 `--detail summary`：精确分组计数、每组最多 3 个符号示例、最多 20 条发现及 20 条变化；明确标记截断，省略 IR 和变化定义全文。ERROR/BREAKING 优先展示；显示详略不改变结论、摘要或退出码。

`--detail full`：保存全部发现、完整变化定义、契约 IR 和规范化结构。JSON/Markdown 都支持详略切换。

```powershell
node .\witprobe.mjs compare --old OLD_WIT --new NEW_WIT --world WORLD --detail full --out D:\VAPP\reports\full.json
```

输出文件必须是尚不存在的 D 盘路径。程序库 compare() 继续返回完整报告。公开报告 Schema 2；IR/基线元数据 Schema 1；规则集 resource-sync-v3。

## 资源与版本映射

参见 [RESOURCE_MAPPING.md](RESOURCE_MAPPING.md)。Compare/Regression 使用 --dependency-map JSON_FILE；本地门禁使用 -DependencyMap。映射假设写入 JSON/Markdown，完整报告保留原始 IR 与比较投影。

## 基线、演示与验证

```powershell
.\scripts\demo.ps1
.\run-validation.ps1
```

基线保存源快照、源摘要、契约摘要、IR、Parser/选项和规则版本。回归不改写基线。旧 scalar-sync-v1/value-sync-v2 基线经人工复核后在新目录重建，不自动覆盖或迁移。

基础验证覆盖解析器、40 项分析测试、32 项产品集成、60 项类型/报告检查（含 38 组官方方向对照）、66 项资源/映射检查（含 36 组官方方向对照）及 4 项源码变异。

真实上游语料独立下载并校验固定提交、压缩包与文件摘要：

```powershell
$corpusRoot = Join-Path (Get-Location).Path 'work\wasi-corpus-v0.2.0'
python scripts/fetch-real-corpus.py $corpusRoot
.\run-validation.ps1 -RealCorpusPath (Join-Path $corpusRoot 'corpus')
```

下载目录必须是新目录。真实项目检查覆盖原始版本比较、官方工具对照、基线完整性、本地门禁、报告详略一致性，以及在独立副本中注入 List/Tuple、资源身份、own/borrow 和方法签名破坏。注入改动不是上游发布或上游漏洞。31 项真实项目检查分别记录未映射 UNKNOWN 和显式映射 COMPATIBLE；另有 9 项真实资源破坏检查（含 8 组官方对照）。

真实门禁使用 scripts/ci-gate.ps1，原样传递退出码。demo 中预期的不兼容视为演示成功，不可用作发布门禁。

## 文档与许可

- src/contract：独立 IR、Diff、类型规则、报告及汇总。
- src/analyzer：固定 Parser Adapter 和嵌套类型规范化。
- [RULES.md](RULES.md)：规则与协议；[DEMO_GUIDE.md](DEMO_GUIDE.md)：演示。
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)：第三方来源及许可。

工具链、依赖检出、构建缓存和运行日志不进入源码交付。verification/ 保留版本化脱敏记录，旧计划和旧记录仅代表当时状态。

项目自身尚未选择开源许可证；第三方代码保留原许可。初始 GitHub 仓库为私有，尚未完成公开开源发布。
