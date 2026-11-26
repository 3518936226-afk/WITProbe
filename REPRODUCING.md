# 从干净仓库复现完整验证

环境：Windows x64、可写 D 盘路径、Git、PowerShell 7、网络。仓库已公开，HTTPS 克隆不需要账号或仓库授权；Linux/macOS 不在本次验收范围。

## 首次准备

```powershell
git clone https://github.com/3518936226-afk/WITProbe.git D:\VAPP\WITProbe
Set-Location D:\VAPP\WITProbe
.\scripts\bootstrap-ci.ps1
.\scripts\prepare.ps1 -Toolchain $env:WITPROBE_MOON_HOME
$corpusRoot = Join-Path (Get-Location).Path 'work\reproduction-corpus'
python -B scripts/fetch-real-corpus.py $corpusRoot
pwsh -NoProfile -File .\run-validation.ps1 -RealCorpusPath (Join-Path $corpusRoot 'corpus')
pwsh -NoProfile -File .\scripts\demo.ps1
pwsh -NoProfile -File .\scripts\verify-ci.ps1
```

将 D:\VAPP 换成自己的可写 D 盘路径，在同一个 PowerShell 会话执行；失败时先检查日志，不将后续步骤冒充成功。

bootstrap-ci.ps1 在 work/ci 内下载、校验并解压 MoonBit、Node、Python，不安装到个人配置目录，不修改系统配置。toolchain.lock.json 固定版本，ci-tools.lock.json 固定压缩包 SHA256。当前 MoonBit 为 2026-11-26 的 1.0.0-rc1 工具链，Node 24.20.0，Python 3.14.4。

MoonBit 官方下载 URL 使用 latest，但本脚本逐字节校验锁定 SHA256；上游文件改变会明确失败，维护者必须复核后更新锁文件，不会自动接受新二进制。旧 2026-11-19 工具链历史下载地址在本次检查时无法访问，故不依赖本机旧安装。

首次准备使用新工具和语料目录；旧证据不自动删除。已准备好的环境可直接重跑 run-validation.ps1，每轮保留独立日志。

## GitHub Actions

[Full Windows validation](https://github.com/3518936226-afk/WITProbe/actions/workflows/full-validation.yml) 使用 Windows 2025 托管 runner、干净 checkout，不恢复构建缓存。main 代码变更、Pull Request、手动 workflow_dispatch 可以触发；仅文档更新不会重复执行。

强制执行 parser、analysis、integration、value-types、resources、real-projects、real-resources、mutations 八阶段；还执行演示、真实本地门禁和测试后 Git 源码一致性检查。任意缺失、跳过或失败都会阻止成功。

基础 Action 固定官方 commit，使用 Node 24；只申请 contents:read，checkout 不保留凭据。成功和失败均上传证据，artifact 保留 7 天，可在运行页面下载。

测试全通过包含符合预期的 UNKNOWN、配置拒绝和 BREAKING，不代表所有输入兼容。Native、实际业务组件运行未覆盖。网络与上游文件可用性是首次复现前提。

实际运行链接和提交见 CURRENT_STATUS.md 与 verification/ci/。
