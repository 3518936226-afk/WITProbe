# WITProbe 项目任务计划书

**项目名称：** WITProbe  
**英文定位：** WebAssembly Interface Contract Compatibility & Regression Testing  
**项目类别：** 工具库 / 开发者工具  
**开发语言：** MoonBit  
**参赛策略：** MoonBit 生态贡献优先、技术创新优先  
**计划版本：** V1.0

---

## 一、项目背景介绍

### 1.1 技术背景

WebAssembly Component Model 是 WebAssembly 生态的重要发展方向。

它希望通过标准化的组件接口，让不同语言、不同运行环境开发的组件能够互相组合和调用。

WIT（WebAssembly Interface Types）是其中的重要接口描述语言。

WIT 可以描述：

- Package
- Interface
- World
- Function
- Record
- Variant
- Resource
- Import
- Export

MoonBit 官方已经提供 WebAssembly Component Model 开发教程，介绍如何通过 WIT、wit-bindgen 和 wasm-tools 构建 WebAssembly 组件。

### 1.2 当前生态基础

MoonBit 生态已经有一些相关基础设施：

**mizchi/wit**

提供 MoonBit 原生 WIT Parser 和 Resolver，可以将 WIT 源码解析为 AST，并解析为便于后续处理的结构。

**mizchi/moon-component**

提供：
- WIT 到 MoonBit 的绑定生成。
- WebAssembly Component 构建。
- WIT 依赖获取。
- 组件组合。
- Component Target 与 WIT 定义的验证。

因此，WITProbe 不应该重复开发 WIT Parser、绑定生成器或 Componentize 工具。

### 1.3 真实问题

假设一个开发团队维护了一个 WebAssembly 组件。

第一版接口：

```wit
package demo:calculator@1.0.0;

interface calculator {
    add: func(a: u32, b: u32) -> u32;
}

world calculator {
    export calculator;
}
```

后来开发者修改了接口：

```wit
package demo:calculator@2.0.0;

interface calculator {
    add: func(a: string, b: string) -> string;
}

world calculator {
    export calculator;
}
```

新版本可能破坏旧调用方的兼容性。

开发者需要知道：

1. 哪些接口发生了变化？
2. 哪些变化会破坏兼容性？
3. 变化影响的是组件提供方还是使用方？
4. 是否存在无法自动判断的复杂类型变化？
5. 如何将这些检查加入 CI？

目前项目准备专门解决 WIT 接口版本变化的分析与回归验证问题。

## 二、项目定位

WITProbe 是一个基于 MoonBit 的 WIT 接口契约比较和兼容性验证工具。

它不负责重新生成组件，而是帮助开发者判断：

**新版本 WIT 契约是否会破坏现有组件之间的调用关系。**

## 三、目标用户

1. MoonBit WebAssembly 开发者。
2. WIT 接口维护者。
3. WebAssembly 组件开发者。
4. 跨语言组件集成团队。
5. WASI 生态开发者。

## 四、核心功能设计

### P0：第一阶段必须完成

**1. WIT 解析与解析结果复用**

优先集成现有 `mizchi/wit`，不重复实现完整解析器。

**2. Contract IR**

建立统一的 WIT 接口数据结构：

- Package
- World
- Interface
- Function
- Type
- Import
- Export

**3. Contract Diff**

比较两个版本的 WIT 文件，识别：

- 函数新增与删除。
- 参数变化。
- 返回类型变化。
- 接口新增与删除。
- World Import/Export 变化。
- 类型定义变化。

**4. Compatibility Analyzer**

建立方向明确的兼容性判断：

- Provider Upgrade：新提供方是否能够继续满足旧消费者。
- Consumer Upgrade：新消费者是否能够使用旧提供方。

结果分为：

- COMPATIBLE
- BREAKING
- UNKNOWN

对于暂时无法可靠判断的复杂类型，必须输出 UNKNOWN，不得直接判断兼容。

**5. Regression Test**

保存旧版本 WIT 和兼容性判断结果。

修改新版本后自动重新比较。

### P1：增强功能

- WebAssembly Component 实际接口检查。
- 与 wasm-tools 集成。
- 与 moon-component 工具链协作。
- GitHub Actions。
- JSON、Markdown、HTML 报告。

## 五、技术架构

整体分为七层：

1. CLI：命令行入口。
2. WIT Adapter：复用现有解析器。
3. Contract IR：统一接口模型。
4. Canonicalizer：规范化接口数据。
5. Diff Engine：接口差异计算。
6. Compatibility Engine：方向性兼容性分析。
7. Report & Regression：报告和回归测试。

### MoonBit 模块设计

| 模块 | 职责 |
|---|---|
| wit_adapter | 调用 WIT Parser / Resolver |
| contract_ir | 统一接口数据结构 |
| canonicalizer | 规范化接口定义 |
| diff | 识别新旧接口变化 |
| compatibility | 兼容性规则判断 |
| component_adapter | 组件元数据检查 |
| regression | 历史契约回归 |
| report | JSON / Markdown 报告 |
| cli | 命令行入口 |

## 六、关键技术设计

### 6.1 Contract IR

将 WIT AST 转换为统一数据模型。

示意：

```text
Contract
├── package
├── worlds[]
│   ├── name
│   ├── imports[]
│   └── exports[]
├── interfaces[]
│   ├── name
│   └── functions[]
└── types[]
```

### 6.2 差异分析

对比两个版本的契约，生成变更记录：

```text
Change
├── change_type
├── symbol
├── old_definition
├── new_definition
├── direction
└── severity
```

### 6.3 兼容性判断

第一版先实现经过测试矩阵验证的基础规则。

例如：

- 删除已有函数。
- 修改函数参数类型。
- 修改返回值类型。
- 修改必要的 Import。
- 删除已有 Export。

不同变更必须结合提供方和使用方方向判断。

不能简单地将所有新增、删除和类型变化统一认定为破坏性变更。

对于 Resource、borrow/own、async、future/stream 等复杂场景，第一版可以先返回 UNKNOWN。

## 七、开发任务计划

### 阶段一：生态调研和技术验证（D1-D2）

任务：

1. 阅读 WIT 规范和 MoonBit Component Model 教程。
2. 检查 mizchi/wit 的许可证、版本和 API。
3. 检查 moon-component 已有功能。
4. 验证 WIT 解析和 Resolve。
5. 准备两个版本的测试 WIT 文件。

交付：

- TECHNICAL_FEASIBILITY.md
- 依赖评估报告。
- WIT Parser 实验。
- 竞品与功能边界分析。

验收：

至少成功解析并解析依赖一个简单 WIT World。

### 阶段二：Contract IR（D3-D4）

任务：

1. 建立统一数据模型。
2. 实现 WIT 到 IR 的转换。
3. 实现规范化。
4. 编写类型和接口测试。

交付：

- Contract IR。
- Canonicalizer。
- 单元测试。

### 阶段三：Diff 和 Compatibility（D5-D7）

任务：

1. 实现接口差异计算。
2. 实现函数变化识别。
3. 实现 Import/Export 变化识别。
4. 建立方向性兼容性规则。
5. 对复杂情况输出 UNKNOWN。

交付：

- Diff Engine。
- Compatibility Engine。
- 规则测试矩阵。

### 阶段四：CLI 和回归体系（D8-D10）

任务：

1. 实现命令行工具。
2. 输出 JSON 和 Markdown 报告。
3. 保存历史契约。
4. 加入自动回归测试。
5. 加入 GitHub Actions。
6. 建立性能基准。

交付：

- 可运行 CLI。
- Regression Corpus。
- CI 工作流。
- Benchmark 报告。

## 八、工程验证体系

**Harness**

准备不同版本的 WIT 测试样本，固定解析环境和工具链。

**Regression**

将已知兼容和不兼容案例保存为测试集。

**Benchmark**

测试不同规模 WIT 契约的解析与差异计算耗时。

**Automation**

自动执行构建、测试和兼容性检查。

**AI Validation**

使用 AI 辅助审查兼容性规则覆盖缺口，最终判断由确定性规则和测试矩阵完成。

## 九、阶段验收标准

1. 能解析并解析依赖指定范围的 WIT 文件。
2. 能生成稳定的 Contract IR。
3. 能比较两个版本的 WIT。
4. 能识别至少五种基础接口变化。
5. 能区分提供方和使用方的兼容性方向。
6. 对无法判断的复杂情况输出 UNKNOWN。
7. 能保存历史契约并执行回归测试。
8. CLI 能输出机器可读和人工可读报告。
9. 能通过 CI 自动检查。

## 十、风险与边界

1. WIT 兼容性涉及方向性和类型子类型规则，不能只用简单文本差异判断。
2. 不能重复实现现有 WIT Parser。
3. 不能重复实现 moon-component 已有的组件生成和基本 Target 检查。
4. Resource 和复杂异步接口先作为后续支持目标。
5. wasm-tools 的具体版本和命令必须在实际环境中验证。
6. 第三方依赖必须检查许可证及 API 稳定性。

## 十一、最终演示场景

1. 准备 V1 版本 WIT。
2. 构建对应的 WebAssembly 组件。
3. 修改 V2 的函数参数类型。
4. 运行 WITProbe。
5. 自动识别接口变化。
6. 判断该变化对旧消费者的影响。
7. 生成兼容性报告。
8. 在 CI 中阻止不符合策略的变更。

## 十二、预期生态贡献

为 MoonBit WebAssembly Component Model 生态增加一套接口契约演进、方向性兼容性分析和回归测试工具。

帮助组件开发者在发布新版本之前，发现接口变更带来的兼容性风险。

**核心成果：MoonBit 原生 WIT 契约兼容性与回归验证工具。**