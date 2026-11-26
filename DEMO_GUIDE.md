# WITProbe 0.3.0 本地演示与复现

环境为 Windows x64、PowerShell 7、Git、可写 D 盘及网络。首次克隆必须先按 [REPRODUCING.md](REPRODUCING.md) 准备锁定工具与依赖；完成准备后再执行下面的演示。Native 不属于本次演示范围。

## 一键演示

```powershell
Set-Location 'D:\VAPP\WITProbe'
.\scripts\demo.ps1
```

脚本创建独立的演示目录，保存基线、每个 JSON/Markdown 报告和汇总。位置记在 `evidence/latest-demo.json`。期望的不兼容和 UNKNOWN 是演示内容，demo 只有在所有预期结果匹配时才整体返回 0。

| 场景 | 预期结果 | 真实 CLI 退出码 |
|---|---|---:|
| 新增 subtract，Provider Upgrade | COMPATIBLE | 0 |
| 同一新增，Consumer Upgrade | BREAKING | 1 |
| add 的参数和结果改成 string | BREAKING | 1 |
| 新增含 Future 字段、未被函数使用的公开 Record | UNKNOWN，带公开类型路径 | 3 |
| 只修改注释后执行基线回归 | COMPATIBLE；源摘要变化，契约摘要不变 | 0 |

## 手工比较

```powershell
node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world --direction provider-upgrade

node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world --direction consumer-upgrade --format markdown
```

两份输入均表示服务提供方契约。报告中的 actual_side/expected_side 明确说明比较关系。多个 World 必须明确选择；名称不同使用 `--old-world` 和 `--new-world`。

输出默认写到标准输出。`--out` 可以保存新报告，只允许 D 盘新路径，拒绝覆盖已有文件。

## 基线与门禁

```powershell
# 将示例路径换成尚不存在的目录；再次创建不会覆盖。
node .\witprobe.mjs baseline create --wit .\fixtures\vertical\base --world calculator-world --out 'D:\VAPP\WITProbe\work\my-baseline'

node .\witprobe.mjs regression run --baseline 'D:\VAPP\WITProbe\work\my-baseline' --new .\fixtures\vertical\comment-only

.\scripts\ci-gate.ps1 -Baseline 'D:\VAPP\WITProbe\work\my-baseline' -New '.\fixtures\vertical\breaking'
$LASTEXITCODE
```

最后的真实门禁应返回 1，CI 应据此失败。UNKNOWN 返回 3，也应阻止通过。不要把一键演示脚本的“预期失败算演示成功”逻辑用于真实发布门禁。

`BASELINE_CREATED / 0` 仅表示快照创建成功；若输入存在复杂类型，返回中仍会标明 `baseline_analysis_status=UNKNOWN`，不能解释为契约兼容。

## 完整验证

```powershell
.\run-validation.ps1
```

该脚本执行解析器、分析、产品集成、类型/报告、资源/映射、4 种源码变异；提供 RealCorpusPath 时还执行真实项目与真实资源检查，完整八阶段命令见 REPRODUCING.md。每次保存独立目录，索引见 `evidence/latest-product-run.json`。变异的独立源码副本及预期失败日志全部保留，没有删除原工程文件。

默认 JSON/Markdown 为精简汇总；使用 `--detail full` 保存完整明细和 IR。基础值类型 Record 不再因为类型种类而返回 UNKNOWN，演示中的 Record 明确含有尚未支持的 Future 字段。

旧 scalar-sync-v1 基线不可静默复用；人工复核后，在新目录创建 resource-sync-v3 基线。真实语料的获取与完整测试命令见 README。

远程 [完整 Windows CI 已实际通过](https://github.com/3518936226-afk/WITProbe/actions/runs/45859517167)，采用干净 checkout、新下载的锁定工具、无恢复缓存。本地 demo 只证明当前这轮本地演示，因此其 summary 中 remote_ci=NOT_RUN 仍是正确记录；远程结果另见 verification/ci/，不能把两者混为一轮运行。

## 五分钟评审演示顺序

| 时间 | 操作 | 讲解重点 |
|---|---|---|
| 0:00-0:40 | 展示 README、LICENSE 和 src/contract | WIT 解析成功不等于契约可替换；说明上游解析器与自有核心 |
| 0:40-2:00 | 运行一键演示，打开 provider-added 与 consumer-added 报告 | 同一变化的升级方向不同；展示规则编号、差异与退出码 |
| 2:00-2:50 | 打开 public-unused-record、signature-breaking、ci-gate 报告 | UNKNOWN 不能冒充兼容；真实门禁应拒绝非零退出码 |
| 2:50-4:10 | 执行下述 WASI CLI 原始版本比较 | 未映射 UNKNOWN；声明五包映射后 COMPATIBLE；展示报告假设 |
| 4:10-5:00 | 展示 CURRENT_STATUS、verification/v0.3.0/real-resource-breaks.json 与远程 CI | 原始上游与受控破坏分开；明确运行时能力未验证 |

### WASI CLI 手工比较

以下命令接续 REPRODUCING.md 中同一会话，$corpusRoot 指向已下载目录；输出到标准输出，不覆盖文件。依次读取实际退出码：

```powershell
$oldCli = Join-Path $corpusRoot 'corpus/wasi-cli-v0.2.0/wit'
$newCli = Join-Path $corpusRoot 'corpus/wasi-cli-v0.2.1/wit'
node .\witprobe.mjs compare --old $oldCli --new $newCli --world command
$LASTEXITCODE # 3，UNKNOWN
node .\witprobe.mjs compare --old $oldCli --new $newCli --world command --dependency-map .\fixtures\wasi-cli-0.2.0-to-0.2.1.mapping.json --format markdown
$LASTEXITCODE # 0，COMPATIBLE，含映射假设
```

映射不是跳过结构检查，也不证明任意组件运行时能够直接链接这两个版本。资源破坏测试在独立副本中执行，结果不是上游漏洞公告。现场不必重新下载工具和执行全部测试；完整复现是另一条可核对的验收路径。

### 提交者演练

本人需能独立解释上述方向、UNKNOWN、映射和门禁，AI 自动运行不代替本人演练。讲解提纲和贡献披露见 [contest/CONTRIBUTIONS_AND_AI.md](contest/CONTRIBUTIONS_AND_AI.md)，报名待办见 [contest/SUBMISSION_CHECKLIST.md](contest/SUBMISSION_CHECKLIST.md)。
