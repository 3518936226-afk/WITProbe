# 参赛交付与人工事项清单

更新：2026-11-27。此清单针对 MoonBit 开发者工具方向准备，不是报名成功或审核通过凭证。

## 已准备的工程材料

- [x] GitHub 仓库改为公开；可匿名 HTTPS 克隆。
- [x] 自有代码和文档采用 [MIT](../LICENSE)，保留 [第三方声明](../THIRD_PARTY_NOTICES.md) 和原许可文本。
- [x] [项目说明](APPLICATION.md) 与一页 [PDF](WITProbe-Application.pdf)。
- [x] [复现步骤](../REPRODUCING.md)、[演示说明](../DEMO_GUIDE.md)、[当前能力与限制](../CURRENT_STATUS.md)。
- [x] [完整远程 CI](https://github.com/3518936226-afk/WITProbe/actions/runs/45859517167) 和仓库内脱敏验证记录。
- [x] [贡献、上游与 AI 辅助披露](CONTRIBUTIONS_AND_AI.md)，说明早期批量上传、此前私有开发和本期增量核对方式。

## 正式提交前需要本人完成或确认

- [ ] 确认具体比赛、赛季、适用章程、截止时间、允许的平台、主要语言要求及是否要求 Mooncakes 发布。不同赛事不能混用规则。
- [ ] 若要求全程公开的连续开发记录，确认本项目此前私有开发、后续公开的实际历史是否被接受；不能靠补写文档消除历史差异。
- [ ] 按官方报名表填写本人实名、联系方式、队伍及资格信息；核对需要的授权或签字。公开材料不代填或编造这些信息。
- [ ] 提交仓库链接与申报 PDF，保存官方报名/修改回执。仓库上传不等于提交表单。
- [ ] 按本期要求加入官方赛事群并设置 GitHub ID 昵称。
- [ ] 本人按 DEMO_GUIDE.md 完成演练，并能解释 CONTRIBUTIONS_AND_AI.md 中五个问题。
- [ ] 若本期明确要求视频、PPT、签章或其它附件，再按实际模板准备；目前没有这些项目“均为必交”的证据。

官方入口：[MoonBit 官网](https://www.moonbitlang.cn/)、[黑客松页面](https://moonbitlang.github.io/Hackathon2026/)。截至核对时，官网宣传十一月活动，而可检索详情仍显示十月赛季。因此本材料不填写未经确认的本期截止日期，也不把四至七月开源大赛或软件合成挑战赛的规定当作当前黑客松规则。

## 可直接粘贴的项目简介

WITProbe 是用 MoonBit 实现核心分析的 WIT 契约演进与回归检查工具。它比较两份提供方 World，给出方向性兼容结果、规则编号和 JSON/Markdown 汇总，支持常见同步值类型、资源名义身份、own/borrow 与显式依赖版本映射；无法可靠判断时返回 UNKNOWN。项目提供只读基线、CI 门禁及真实 WASI 验证，完整 Windows GitHub Actions 已通过。定位为可解释的静态契约检查原型，不宣称验证业务运行时或覆盖所有 WIT 提案。

## 表单附件索引

| 字段 | 材料 |
|---|---|
| 项目名称 | WITProbe |
| 方向 | MoonBit 开发者工具 / WIT 契约演进与回归检查 |
| 仓库 | https://github.com/3518936226-afk/WITProbe |
| 维护账号 | 3518936226-afk（实名和队伍另行核对） |
| 项目申报书 | WITProbe-Application.pdf |
| 源码许可 | MIT；第三方保留原许可 |
| 测试证据 | verification/ci/REPORT.md、CURRENT_STATUS.md、远程 Actions 运行链接 |
| 演示方法 | DEMO_GUIDE.md；首次环境准备见 REPRODUCING.md |
