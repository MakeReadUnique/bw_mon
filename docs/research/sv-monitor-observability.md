# 小时间窗、bind 与 Verdi 观测的技术约束

研究日期：2026-10-23。对应决策地图的 **查证小时间窗、bind 与 Verdi 观测的技术约束**；本地 ticket 路径为 `.scratch/bw-mon-architecture/issues/04-sv-observability-research.md`。

本文是架构研究，不是已批准的设计或实现。本次核对了标准条款、公开一手资料和本机 Synopsys W-2024.09-SP1 文档；没有编译 monitor、生成 FSDB 或验证 GUI，也没有检查许可证可用性。

## 结论

用户要求的纯 SystemVerilog module、ns/cycle 可选滑窗和 NoC 局部 bind 有可行的语言基础。关键约束是：**窗口宽度、统计更新时刻、协议采样时刻和分析尺度是四个不同概念**；10 ns 的窗口不要求以 10 ns 为采样周期。

| 事项 | 已查明的依据 | 对架构的影响或待选方案 |
|---|---|---|
| 时间精度 | `timeunit` 决定本地单位，`timeprecision` 决定延迟取整；`$time` 是按本地单位缩放的整数，`$realtime` 是按本地单位缩放的实数。[IEEE 1800-2023，§3.14、§20.3](https://standards.ieee.org/ieee/1800/7743/) | 时间戳在接口上传递时须带统一单位契约；不能把各 module 的原始 `$time` 数值直接混用。 |
| 同时刻调度 | Active 事件可任意排序；过程式 `#0` 不等于“全部 NBA 已完成”；Postponed 不允许再写当前时刻的变量。[IEEE 1800-2023，§4.4](https://standards.ieee.org/ieee/1800/7743/) | 不应以实例创建顺序、多个独立 `always` 的偶然执行顺序，或追加一个 `#0` 作为聚合正确性的保证。 |
| 协议采样 | clocking block 的 `input #1step` 取得时钟沿前的值，显式 `input #0` 在 Observed 采样；混用原始时钟事件和 clocking 成员仍可能产生竞态。[IEEE 1800-2023，§14.3–14.4](https://standards.ieee.org/ieee/1800/7743/) | 应明确采到的是握手边沿使用的值还是沿后状态，并保持事件控制和采样约定一致。 |
| bind | 可按目标 module 类型或具体实例插入 monitor；端口表达式按目标作用域解释。[IEEE 1800-2023，§23.11](https://standards.ieee.org/ieee/1800/7743/) | 局部 monitor 可位于 DUT 层次下；跨节点分组连线仍需独立设计。 |
| 波形数据类型 | Verdi 手册列出的 VCS 默认 FSDB 原子类型包括 `longint`、`enum`、`real`、`realtime` 等，详见下方工具资料。 | 有证据支持直接暴露标量计数、阶段与带宽数值；不必因使用 real 就放弃 module 形式。实际 dump 配置仍需验证。 |

标准官方入口提供 GET IEEE 下载路径。本次正文检索核对使用了 [IEEE 标准正文的公开镜像](https://iccircle.com/static/upload/img20240319175450.pdf)，不在仓库分发标准副本；条款编号均指 1800-2023。旧工具对新标准条款的覆盖仍须由后续实际编译确认。

## 小滑窗：建议写入决策问题的契约

以下是根据用户需求和离散事件计量推导的设计建议，尚未选定实现：

- **分开配置窗口宽度与更新步长。** 例如窗口 10 ns、每 1 ns 报告一次，与每 10 ns 报告一次是不同的观测分辨率。协议传输仍按接口时钟采样。
- **真滑窗必须删除过期事件。** 只在有新传输时执行删除，会导致停止传输后波形停留在旧值。ns 模式可选择独立报告定时器，或同时在传输到来和事件到期时唤醒；两者在更新延迟及调度成本上不同。
- **cycle 模式需要定义停钟含义。** 最近 N 个本地采样边沿构成的窗口，在本地时钟停止时不会自然增加周期数。物理静默时长与“连续多少周期未传输”不能共用一个未注明单位的量。
- **时间精度与统计精度不同。** 例如 1 ps 的计时精度并不意味着 10 ns 窗口有充分流量样本。若每次传输为 B 字节，窗口只增减一笔就造成 B/W 的带宽阶跃；这属于计量离散性，而非 timeprecision 误差。
- **统一边界后才能聚合。** 不同端口“最近 N cycles”的区间可能不同；若要物理总带宽，需共同的时间起止边界，或限制组内周期窗口使用同一采样时钟。不要直接相加覆盖区间不同的本地显示值。

精确事件队列、周期环形缓冲及时间分桶都仍是候选。研究没有决定默认精度、步长、内存上限或溢出策略。

## 采样与聚合应分别拥有时间契约

标准化事件至少需要能回答“何时观察到成功传输、多少字节、属于哪个观测点”。单点窗口和组窗口可以共用计量语义，但不得靠跨时钟共享变量的偶然更新顺序得到快照。

可讨论两种架构方向：

1. **采用右侧开区间 `[T-W, T)`。** 时刻 T 发布的快照只包含时间戳小于 T 的事件，把恰好 T 的传输留给后续快照。由此能避免快照是否包含当前时刻事件取决于线程先后的问题；仍须定义事件记录的单一写入者和原子快照流程。
2. **允许右端点事件并制定显式结算流程。** 在 T 的各采样源完成后统一提交，再发布统计结果。需要可证明的完成条件；不能用几个任意 delta cycle 冒充该条件。

这两者是工程方案，不是语言规定，后续应通过同时钟沿、异步时钟恰好重合、复位与窗口边界重合的最小实验选择。负责调度语义的标准作者也把确定性列为核心问题，可参考 [Synopsys 作者在 Accellera 提交的调度论文](https://accellera.org/images/eda/sv-bc/att-0529/01-sv31schedsemantics-dvcon03.pdf)；该论文是历史提案，当前规则以现行标准为准。

## bind 的边界

**“接口”需要区分总线接口与 SystemVerilog `interface` 类型。** 1800-2023 §23.11 的语法限制：当 bind 目标本身为 SV interface 时，被插入对象须为 interface 或 checker，不能据此承诺直接绑定一个 module。相关限制也可在 [Accellera 标准编辑者的修正记录](https://accellera.org/images/eda/sv-bc/11395.html)交叉核对。

因此，module 型局部 monitor 的候选接入方式是绑定 NoC 链路所在的 module/实例，并从目标作用域连接信号。具体采用按类型全覆盖还是按实例选择、实例名称是否冲突、参数如何映射，都需要接入契约；`bind` 本身不自动建立聚合组或发现所有监测点。VCS 本地手册的 “Binding SVA to a Design” 同样提供了 module/实例目标的绑定使用方式。

## Verdi 可观测性

以下工具事实来自本机官方手册，不把手册内容或截图上传到仓库：

- **Verdi Linking Novas Files with Simulators and Enabling FSDB Dumping Manual，W-2024.09-SP1，pp.47–49**：默认 FSDB 转储涵盖 module 等层次及上述标量类型。文件位置相对 Verdi 安装目录为 `doc/verdi_linking_dumping.pdf`。
- **同一手册，§FSDB Dumping Commands Used with Verilog**：转储受 `$fsdbDumpvars` 的层次范围、深度和选项影响；数组、结构等类型有相应选项。因此“可声明”不等于“任何现有 dump 脚本都会收集”。
- **Verdi Command Reference Manual，W-2024.09-SP1，pp.623–624**：nWave 能将数字总线按数值曲线显示，并提供离散值显示选择。文件位置相对安装目录为 `doc/verdi_command_ref.pdf`。公开产品页仅用于确认 [Verdi 的 FSDB 与波形调试定位](https://www.synopsys.com/verification/debug/verdi.html)，不作为具体数据类型支持的证明。
- **VCS User Guide，W-2024.09-SP1，Using SVAs in the HDL Design / Binding SVA to a Design**：本地可复核相对路径 `doc/UserGuide/html/vcs_user_guide/using_systemverilog_assertions/using_svas_in_hdl_design.html`。

候选观测面应包含稳定存在的 module 标量或简单向量：窗口字节数、窗口起止时间、带宽值、计量有效标志、阶段与过程编号、诊断能力及原因码。动态历史缓冲只服务内部算法，不宜成为用户理解波形的唯一入口。这是架构建议，尚未锁定端口或信号名称。

## 后续必须验证的最小实验

1. 不同 `timeunit/timeprecision` 的采样源对同一个 10 ns 窗口计量一致，含小数 ns 时钟和边界传输。
2. 无后续传输以及本地停钟时，ns 窗口能按约定更新；cycle 窗口按其定义运行。
3. 多源同一时刻完成传输、复位或到期时，改变源代码/实例顺序不改变统计结果。
4. 对两个实际 NoC 层次实例 bind 后，FSDB 中出现预期层次、标量计数、real 或定点带宽、阶段和有效状态；检查是否需要现有编译流程补充 debug/dump 选项。

这些是未来验证建议，本次均未执行。此研究已提供进入架构讨论所需的语言和工具证据，未据此批准具体实现方案。
