# WITProbe 本地演示与复现

当前示例全部位于 D 盘，不需要安装新依赖或修改系统配置。需使用锁文件对应的现有 MoonBit、Node、Git 与参考工具；Native 不属于本次演示范围。

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
| 新增未被函数使用的公开 Record | UNKNOWN，带公开类型路径 | 3 |
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

该脚本执行上游/接入检查、分析测试、产品集成、官方有限对照及 3 种源码变异。每次保存独立目录，索引见 `evidence/latest-product-run.json`。变异的独立源码副本及预期失败日志全部保留，没有删除原工程文件。

远程 CI 尚未配置或运行。本地门禁检查使用真实子进程退出码，记录于演示汇总；它不代表已在 GitHub Actions 运行成功。
