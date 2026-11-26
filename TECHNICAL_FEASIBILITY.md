# WITProbe 第一阶段技术可行性报告

**核验日期：** 2026-11-26（北京时间）  
**阶段：** 生态调研和解析接入实验  
**结论：** 可以进入 Contract IR 原型阶段；Windows Native 发布尚未验证通过，项目差异化需要收窄。

## 一、已完成的验收

已复用 `mizchi/wit`，没有重新编写 WIT Parser。实验成功加载 `fixtures/dependency/`，从 `deps/common/` 解析 `demo:common@1.0.0`，解析 `number = u32` 别名，并选中 `calculator-world`。结果包含 2 个包、2 个接口、1 个 World；导出计算接口时，其类型依赖形成 1 个隐式导入。

实验输出保存在 `evidence/resolved-fixtures.json`。该文件是上游 Resolve 的 JSON，**不是已经完成的 WITProbe Contract IR**。

| 验证项 | 本机结果 | 证据 |
|---|---|---|
| MoonBit JS 类型检查 | 通过 | `evidence/check-js.txt` |
| 上游解析器测试 | 113/113 通过 | `evidence/upstream-tests-js.txt` |
| WITProbe 接入测试 | 13/13 通过 | `evidence/integration-tests-js.txt` |
| 官方解析器正负样例 | 3 个有效样例通过，1 个无效样例按预期拒绝 | `evidence/official-validation.json` |
| 官方解析器语义对照 | 3/3 一致，范围为当前样例中的包、World、函数、标量与别名 | `evidence/fixture-semantic-comparison.json` |
| 官方 semver 方向探针 | 6/6 符合预期结果，包含预期不兼容案例 | `evidence/semver-oracle-results.json` |
| 本项目格式检查 | 通过 | `evidence/format-check.txt` |
| Windows Native 测试 | 构建失败，未执行测试 | `evidence/integration-tests-native.txt` |

原始失败日志也保留：`integration-tests-js-first.txt` 记录了修正样例之前的失败，不能用当前通过结果覆盖这一事实。

## 二、原计划需要修正的地方

### 2.1 示例中的名称冲突

原计划同时使用 `interface calculator` 和 `world calculator`。本次两个解析器均拒绝该输入：MoonBit 解析器报 `duplicate name`，官方工具报 `duplicate item named calculator`。

可运行样例把 World 改为 `calculator-world`，函数签名保持原意。原输入保留在 `fixtures/invalid-duplicate/`，作为负例；修正后的 V1、V2 位于各自目录。

### 2.2 已有官方兼容性检查工具

`wasm-tools 1.263.0` 已有 `component semver-check`。因此，“能够比较 WIT 是否兼容”不是独占创新点。建议以 MoonBit 原生库、解释性 Diff、显式方向策略、UNKNOWN、回归语料和 CI 策略作为可验证贡献。[官方 CLI 源码](https://github.com/bytecodealliance/wasm-tools/blob/v1.263.0/src/bin/wasm-tools/component.rs)

### 2.3 官方工具的方向必须实际验证

在固定版本的源码和本机探针中，`semver-check --prev P --new N` 检查旧组件形状能否满足新 World 期望。实测 N 增加导出时失败、删除导出时通过；增加导入时通过、删除导入时失败。它不能直接被当成“新提供方替换旧提供方”的同名判定器。[固定版本的判定实现](https://github.com/bytecodealliance/wasm-tools/blob/v1.263.0/crates/wit-component/src/semver_check.rs)

这不等于删除提供方 Export 是安全操作。后续必须先定义参与者、提供/需要的接口和替换关系，再映射工具参数。

## 三、依赖接入结论

实际源仓库是 `mizchi/wit.mbt`，模块名是 `mizchi/wit`。本次固定 0.4.1 / `df59b4068926667eab2302a4daabecefad4c28ec`，使用 `moon.work` 接入本地源码。其直接依赖 `moonbitlang/x` 固定为 0.5.4。两者声明 Apache-2.0；完整评估见 `DEPENDENCY_ASSESSMENT.md`。[固定版本模块声明](https://github.com/mizchi/wit.mbt/blob/df59b4068926667eab2302a4daabecefad4c28ec/moon.mod)

已验证的 API 是 `parse`、`resolve` 和 `resolve_path(path, world=...)`。上游还有 `resolve_multi` 和特性选项，本次未穷尽其行为。默认不启用不稳定特性；后续必须把解析选项写入报告及回归基线。

## 四、IR 设计依据

本次对照发现两个解析器的原始 JSON 并不相同：官方解析器为导入别名创建了额外类型节点，MoonBit 解析器在本样例中复用类型 ID。展开标量别名后，当前样例语义一致。

因此，IR 不应把上游数组索引或 `interface-0` 当成稳定符号身份。应使用包名、版本、接口身份、World 边和有序函数参数建立稳定键；记录/元组/变体成员的语义顺序不得为了排序而丢失。资源需要保留 nominal identity，不能仿照标量别名直接抹平。

本次 Python 对照脚本只处理样例中的标量别名。它会拒绝不支持的类型，不能作为完整 Canonicalizer 使用。

## 五、环境与边界

- MoonBit：moon `0.1.20261119`，moonc `v0.10.22+124d61d05`。
- 官方参考工具：wasm-tools `1.263.0 (7a2fa422c 2026-10-30)`，下载压缩包 SHA256 已与 GitHub release asset digest 核对。
- 现有 D 盘工具链被复用；源码、下载、缓存、临时文件、构建和证据均放在 D 盘。
- Windows Native 构建选用了 `C:\mingw64\bin\gcc.exe`，运行时明确报 Windows 当前仅支持 MSVC。本机 vswhere 查询未找到相应 C++ 工具组件；未安装或更改系统工具链。
- 没有构建或运行实际业务组件，没有进行 ABI/运行时互操作验证；官方 semver 工具内部合成组件不等同于业务组件验收。
- 没有完成 Contract IR、Diff、Compatibility Engine、回归基线管理、正式 CLI、CI 或性能基准。
- 没有提交、推送 GitHub 或部署网站。

磁盘核对时，项目目录逻辑大小约 67.2 MiB；共享 D 盘工具链新增的注册表与 JS/Native 标准库 bundle 当前合计约 187.7 MiB，合计约 254.9 MiB。详见 `evidence/storage-inventory.json`。这是文件长度之和，非精确物理分配量；不包含原有工具链主体。未主动写入、覆盖或删除 C 盘文件，可控 C 盘新增写入为 0 字节；应用和操作系统内部写入未作全盘监测。失败产物与下载包保留，没有擅自清理。

## 六、下一阶段入口

先实现稳定 IR 与独立的上游 Adapter，再建立方向测试矩阵。第一轮覆盖同步函数、基础标量、函数增删和 World 边；类型身份、包版本和复杂类型未能可靠证明时返回 UNKNOWN。解析错误应作为输入失败处理，不能冒充一个成功分析的 UNKNOWN。

基础结构比较只能说明契约层面的关系，不能证明实现行为、业务语义或资源生命周期兼容。MoonBit 官方教程可作为后续实际组件构建的独立验收依据。[MoonBit Component Model 教程](https://github.com/moonbitlang/moonbit-docs/blob/main/next/toolchain/wasm/component-model-tutorial.md)
