# WITProbe 依赖评估

**核验日期：** 2026-11-26。以下版本为本次实验固定点，不承诺是未来最新版本。

| 依赖 | 固定版本/提交 | 许可证依据 | 本次用途与状态 |
|---|---|---|---|
| mizchi/wit | 0.4.1 / `df59b4068926667eab2302a4daabecefad4c28ec` | 仓库 LICENSE 和 moon.mod 均为 Apache-2.0 | 已集成；JS 编译及测试通过 |
| moonbitlang/x | 0.5.4 | 下载包 moon.mod 声明 Apache-2.0 | 上游 fs 等依赖；随解析器参与构建 |
| mizchi/moon_component | 0.5.4 / `67741d56c1f87007253708165834d3f9c98867f4` | 仓库 LICENSE 为 Apache-2.0 | 仅研究，未加入 WITProbe 构建依赖 |
| wasm-tools | 1.263.0 | 官方发布包附 Apache-2.0、MIT 与 LLVM exception 许可文本 | 外部参考工具；已运行解析及 semver 探针 |

## 一、Parser API 与稳定性

`parse(String)` 返回 AST，`resolve(String)` 返回扁平模型，`resolve_path(String, world=...)` 返回 Resolve 和所选 World ID，失败以 ParseError 表示。路径加载会访问文件系统；WITProbe 应把 I/O Adapter 与纯比较逻辑隔离。

0.4.x 相比 0.3.x 扩展了类型和函数种类，0.4.1 又增加稳定性元数据及选择选项。枚举穷尽匹配与默认特性过滤都可能影响调用方，不能依赖浮动主线。[API 变更记录](https://github.com/mizchi/wit.mbt/blob/df59b4068926667eab2302a4daabecefad4c28ec/CHANGELOG.md)

**建议：** 固定提交及依赖版本；升级时同时重跑负例、JSON 语义对照与方向矩阵。Adapter 对未知类型保留信息并上报不支持，不能静默丢弃。

## 二、规范覆盖与限制

上游说明支持多种较新 WIT 语法，并区分解析支持与二进制/运行时验证。本次只确认选定样例、113 个上游 JS 测试和 13 个接入测试；不是对全部规范的符合性证明。[上游支持范围](https://github.com/mizchi/wit.mbt/blob/df59b4068926667eab2302a4daabecefad4c28ec/SPEC.md)

资源、own/borrow、async、future/stream 即使被解析器接受，也不代表 WITProbe 能判断兼容性。第一版的 UNKNOWN 策略应保留。

## 三、moon-component 协作风险

本次主线模块声明仍依赖 `mizchi/wit 0.2.4`，而 WITProbe 实验使用 0.4.1；不能假定解析模型可直接共享。当前选择只在将来通过外部工具或标准 WIT 文本协作，暂不绑定内部代码生成 API。[固定模块声明](https://github.com/mizchi/moon-component/blob/67741d56c1f87007253708165834d3f9c98867f4/moon.mod.json)

其文档已覆盖绑定生成、componentize、fetch、compose、targets；这些不作为 WITProbe 的重复建设目标。[命令范围](https://github.com/mizchi/moon-component/blob/67741d56c1f87007253708165834d3f9c98867f4/README.md)

## 四、分发注意事项

本次保留原许可文件，没有修改上游源码。未来分发 vendored 源码或二进制时，应携带对应许可证、检查 NOTICE 和所用构件的许可要求；本阶段尚未生成全量传递依赖 SBOM。

下载校验记录：`evidence/wasm-tools-download.json`。压缩包 SHA256：`0803df158b4dbea6b029d11f4206c414f432f0447af91542817061e4f0bd912e`。
