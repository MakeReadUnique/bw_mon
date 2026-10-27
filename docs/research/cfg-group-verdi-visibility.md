# cfg 新增聚合组的 Verdi 波形可见性验证

研究日期：2026-10-27。适用工具资料：Synopsys VCS / Verdi W-2024.09-SP1。

关联问题：[cfg 新增聚合组的 Verdi 波形可见性验证](https://github.com/MakeReadUnique/bw_mon/issues/46)，支持[文件新增聚合组的时钟、复位与波形契约](https://github.com/MakeReadUnique/bw_mon/issues/37)的后续讨论。

## 所核实的要求

已经接入 p0/p1，编译一次后，只在第二次启动使用的 cfg 中加入 g1 并让 g2 引用它。本票核实能否在离线 Verdi/nWave 中找到 g1 的连续 `real` 带宽和普通状态信号；用整数、质量位、结果序号及枚举验证相关类型的承载。完整阶段、过程和复位状态属于后续产品观测契约，本探针不生成或验收这些语义。只多出文本报告或一个登记项不满足此要求。

本研究核实观测能力，不把探针当作完整聚合统计实现，不决定时钟、复位、配置来源和资源规模。

### 当前产品基线

研究基线是产品提交 `fa20d9cb15731e68255d83fb80f950f62c24fb9c`。[`bw_group_mon`](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_group_mon.sv#L23)具有 `clk/reset_n`、公开标量和逐沿收集逻辑，并在模块内例化统计核心；[组登记对象](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_registry_types.svh#L32)保存身份、成员及拓扑信息。仅在登记表中加入 Group ID 不会自动得到这些模块行为。因此，下文的运行期对象加静态槽位是独立工具探针，不表示现有产品已具备文件新增组的统计与波形能力。

## 官方资料明确支持的能力

| 事实 | 一手资料及定位 | 可以得出的结论 |
| --- | --- | --- |
| VCS 三步流程在 elaboration 时建立实例层级并生成 `simv`，随后由该可执行文件运行仿真。 | [S7]，Three-step Flow → Elaboration。 | 启动 cfg 中的逻辑身份与编译时建立的模块层级是两种对象；本探针的 cfg 不创建新的 module 实例。 |
| 普通 FSDB dumping 支持 module、generate、package、interface 等层级中的标量，以及 `int`、`longint`、`enum`、`real`、`realtime` 等类型。 | [S1]，第 48–49 页，默认 hierarchy construct / non-MDA atom data type 表。 | 若每个运行期聚合组把公开观测值更新到预先存在的标量信号，所需基本类型有正式 dumping 支持。 |
| VCS 使用 `-debug_access` 启用 FSDB；`$fsdbDumpfile` / `$fsdbDumpvars` 或 UCLI 可以开始录波。 | [S2]，Dumping FSDB File for Various Flows。 | 调试可见性必须在编译和录波流程中启用；cfg 创建逻辑对象不会自动替用户补录未记录的数据。 |
| Verdi 交互调试能把 class 对象及其数据成员加入 nWave；class 对象本身的值是对象指针，展开后可看成员。 | [S3]，第 81–82 页，Dumping Dynamic Objects。 | 不能笼统说“class 在 Verdi 看不到”。 |
| 同一交互调试手册列出动态数组、关联数组、queue 的 dumping 限制；该交互流程的 `inter.fsdb` 不支持 FSDB utilities。 | [S3]，第 171 页，Known Problems and Limitations。 | 不能仅凭交互 Object Browser 能显示值，就保证普通离线 FSDB、任意动态容器及导出工具均可用。此限制只按手册所述交互流程引用。 |
| UVM component post-process waveform 有单独流程，要求 VCS、调试选项及 `+UVM_VERDI_TRACE=COMPWAVE`；它支持的类和成员类型也有限制。 | [S4]，第 114–118 页，Viewing OVM/UVM Component Waveforms in nWave。 | 不能把 UVM component 的成功案例直接套用到本项目任意普通 class；本地图也未选择引入 UVM。 |
| VCS 的 `-debug_access+cbkd` 提供 class 内动态变量的 dumping/callback 能力；`+class`、`+all` 含相关调试能力。 | [S5]，debug option 表。 | 动态对象路线存在工具支持基础，但所需完整 batch dumping、按 Group ID 定位和全部数据类型仍应单独实测，不能宣称已经不可行或已经通过。 |

## 可测试的承载方式及边界

推导出的候选方式是：内部在编译时预留观测槽位，启动读取 cfg 后自动把 Group ID 绑定到槽位，再把该组的公开结果写入其中。例：`group_view[1].group_id = "g1"` 与 `group_view[1].bw_GBps`。cfg 用户不填写槽号，不为每个新 Group ID 例化 module。

这里需要区分 Group ID 和 SV module 路径。Group ID 是运行期身份；已有的观测槽位是静态层级。新增 Group ID 不意味着同一个 `simv` 会凭 cfg 新建一个名为 `g1` 的 SV module 层级。用动态对象也同样不等于创建 module 实例。VCS 在 elaboration 阶段建立实例层级 [S7]；本候选方案避免依赖运行期新增静态层级。

此方案是否可接受还有两个明确边界：

- 槽位是有限资源。正式设计需确定容量、自动分配和溢出错误；本次小探针不能代替原有规模目标的证据。
- Group ID 到槽位的对应关系必须随本次仿真保存。不同 cfg 的槽号可能不同，不能只保存裸槽号并假定永远代表同一组。可以输出映射、给波形显示名称加 Group ID，或自动生成本次运行的信号视图；具体体验尚待用户决定。

上面的候选及边界是根据类型支持和静态观测方式得出的工程推导，不是官方手册提供的 bw_mon 实现保证。实际可见性以本研究的可复现探针为准。

## 实测结论

**可以保留波形观测。** 在本机 VCS / Verdi W-2024.09-SP1 上，独立探针从 cfg 创建新 Group ID 后，真实 nWave 成功拉出了该组的 `real` 带宽曲线、字符串身份、64 位计数、质量位和枚举状态。该结果证明一种可行的观测承载方式，尚未给产品增加文件建组功能。

### 同一编译产物，两份启动文件

探针[源码](cfg-group-verdi-probe/probe.sv)只预留四个匿名标量观测槽；统计对象在读取 cfg 时通过 `new` 创建，源码中没有写死 `g1/g2`，用户文件不含槽号。探针采用每 2 ns 一个输入区间、最多四个区间的简单窗口，目的是产生可以独立核对的真实变化值，不复用或声称验收产品统计核心。

| 运行 | cfg 内容 | 自动映射 |
| --- | --- | --- |
| [第一次](cfg-group-verdi-probe/first.cfg) | `g2 p0 p1` | `g2 → wave_slots[0]` |
| [第二次](cfg-group-verdi-probe/second.cfg) | `g2 g1 p1`；`g1 p0 -` | `g2 → wave_slots[0]`，新增 `g1 → wave_slots[1]` |

`-` 仅为探针表示没有第二成员的占位符，不是正式分组文件语法。第二次运行增加此前不存在的 g1，由 g2 引用；g2 的全部窗口结果与第一次相同。

最终冻结源码只编译一次，然后连续运行上述两份 cfg。两次前后的 `simv` SHA-256 均为 `ce2acd7edffe6b511637ac18831a8576c3657dc4d09ede4aa8369392da5f9aef`；共享对象的哈希也逐次核对不变，详见[构建及运行清单](cfg-group-verdi-probe/evidence/manifest.json)。开发探针时对录波范围做过调整；该清单记录的是调整完成后整套重新生成的证据，两次 cfg 运行之间没有编译或修改 SV。

### 实际录波与查看结果

- 以 `vcs -full64 -sverilog -debug_access+all -kdb` 构建，使用 `$fsdbDumpvars(0, tb_cfg_group_probe, "+all")` 录波。本机实测不加 `+all` 时普通标量带宽等已录下，但 string Group ID 没有录入；加 `+all` 后 `fsdbreport` 和 nWave 均可读取身份。
- [独立核验脚本](cfg-group-verdi-probe/verify.py)以另一份明确列出的 p0/p1 输入表和前缀和计算窗口，核对 FSDB 转出的 VCD/CSV。[核验结果](cfg-group-verdi-probe/evidence/verification.json)为 **72/72 发布通过**，包括第一遍 g2 和第二遍 g1/g2。验证覆盖真实 `real` 声明、字符串身份、整数、质量位、枚举标签、闲置槽位未激活，以及两次 g2 结果相同。
- [第一次真实 Verdi 截图](cfg-group-verdi-probe/evidence/first/view.png)和[第二次真实 Verdi 截图](cfg-group-verdi-probe/evidence/second/view.png)均由 nWave 的 `wvCapture` 直接输出，没有图像后处理。nWave 实际执行 `wvAddSignal`，随后保存可重开的 `.sav`。曲线使用 analog 阶梯保持；连线不表示产生了额外统计样本。
- 新 g1 的路径为 `/tb_cfg_group_probe/wave_slots[1]/bandwidth_gbps`，同一层级 `group_id="g1"`。18.001 ns 的 nWave 光标值为 g1 **16 GB/s**、g2 **22 GB/s**；32.001 ns 两者为 0；40.001 ns 为 g1 **8 GB/s**、g2 **12 GB/s**。[原始光标读数](cfg-group-verdi-probe/evidence/second/nwave-values.tsv)与[截图取证清单](cfg-group-verdi-probe/evidence/second/capture.json)可核对。
- 原始 [第一次 FSDB](cfg-group-verdi-probe/evidence/first/waves.fsdb) 与 [第二次 FSDB](cfg-group-verdi-probe/evidence/second/waves.fsdb)随研究分支保存。查看过程没有修改这两个文件。

本轮收口时重新核对了保留的 `simv` 及两份共享对象，均与清单指纹一致；从两份原始 FSDB 再次导出的 CSV/VCD 与冻结证据逐字节相同，独立核验仍为 72/72。随后在隔离临时目录重新启动 nWave，加信号、读取上述三处光标值并直接截图，两次均通过，代理也查看了新截图。原始 FSDB 和已发布截图保持不变；该复核没有把尚待用户讨论的观测契约标为已接受。

### 证据边界

| 已验证 | 未验证或未决定 |
| --- | --- |
| 同一编译产物、仅改启动 cfg 增加逻辑组及一层成员引用 | 完整产品解析器、原始记录调度、多父消费、真实统计与报告接入 |
| 新组数据能进入真实 FSDB，并在离线 nWave 拉出普通信号和 analog 曲线 | 完整流量阶段、过程分析、复位隔离、性能预期检查；探针 `probe_state` 只是 WARMUP/FULL 类型演示 |
| Group ID 由工具自动关联匿名静态观测路径；本次运行中映射固定 | 跨 cfg 改动保持同一槽号、最终 UI/自动命名约定 |
| 四个内部预编译槽位范围内新增组可见 | 4096 组规模、内存及仿真开销、正式容量与溢出契约 |

研究不要求用户为每组例化 module 或手工占槽，但内部静态槽仍有上限。如果用户必须要求文件里的新名称直接成为新 module 层级，则这个槽位方案不满足那种路径要求；本次尚未将此观测契约作为用户已接受的选择。动态 class 直接录波方案未在此探针中验收。

### 复现

在研究分支仓库根执行（需要相同或兼容的 VCS/Verdi 工具及许可）：

```bash
python3 docs/research/cfg-group-verdi-probe/run.py
python3 docs/research/cfg-group-verdi-probe/verify.py
python3 docs/research/cfg-group-verdi-probe/capture.py --xvfb-bin /path/to/working/Xvfb
```

`run.py` 会重新建立它独占的 `.build/cfg-group-verdi-probe`，然后只编译一次、顺序运行两个 cfg；不修改产品 RTL。`capture.py` 默认建立独立 `:94` 显示；可传 `--display` 选择另一个未占用编号。

仅查看已有第二次波形，无需编译：

```bash
cd docs/research/cfg-group-verdi-probe/evidence/second
verdi -nWave -ssf waves.fsdb -play open.tcl
```

## 来源

以下只记录来源和结论，不复制发行包手册或大段内容。

- **[S1]** Synopsys，*Verdi Linking Novas Files with Simulators and Enabling FSDB Dumping Manual*，W-2024.09-SP1，第 48–49 页。本机原件：`/home/eda/app/synopsys/verdi/W-2024.09-SP1/doc/verdi_linking_dumping.pdf`。
- **[S2]** Synopsys，*VCS User Guide*，W-2024.09-SP1，Debugging With Verdi → Dumping FSDB File for Various Flows。本机 HTML：`/home/eda/app/synopsys/vcs/W-2024.09-SP1/doc/UserGuide/html/vcs_user_guide/debugging_with_verdi/dumping_fsdb_file_for_various_flows.html`。
- **[S3]** Synopsys，*Verdi SVTB Interactive Simulation Debug User Guide*，W-2024.09-SP1，第 81–82、171 页。本机原件：`/home/eda/app/synopsys/verdi/W-2024.09-SP1/doc/verdi_svtb_interactive_debug.pdf`。
- **[S4]** Synopsys，*Verdi UVM Debug User Guide*，W-2024.09-SP1，第 113–118 页。本机原件：`/home/eda/app/synopsys/verdi/W-2024.09-SP1/doc/verdi_uvm_debug_ug.pdf`。
- **[S5]** Synopsys，*VCS User Guide*，W-2024.09-SP1，Compiling/Elaborating Design → Optimizing Simulation Performance for Desired Debug Visibility With the -debug_access Option。本机 HTML：`/home/eda/app/synopsys/vcs/W-2024.09-SP1/doc/UserGuide/html/vcs_user_guide/compiling_elaborating_design/optimizing_simulation_performance_for_desired_debug_visibility_with_debug_access_option.html`。
- **[S6]** Synopsys 官方公开说明：[Verdi Waveform Utilities](https://www.synopsys.com/blogs/chip-design/verdi-waveform-utilities.html)。它确认 FSDB 可用批处理工具抽取信号、报告值变化及转换 VCD，但未给出本研究动态 group 的实现契约；因此只作为批处理验证手段的背景。
- **[S7]** Synopsys，*VCS User Guide*，W-2024.09-SP1，VCS Flow → Three-step Flow → Elaboration。本机 HTML：`/home/eda/app/synopsys/vcs/W-2024.09-SP1/doc/UserGuide/html/vcs_user_guide/vcs_flow/three_step_flow.html`。

2026-10-27 再次核对了 [S1]–[S5]、[S7] 原件及 [S6] 公开网页。[S1]、[S3]、[S4] 的封面版本均为 W-2024.09-SP1（December 2024）；上述页码为手册正文页码，与本机 PDF 页序一致。对动态容器及 `inter.fsdb` 的限制只归属于 [S3] 的交互调试流程，不据此否定其他离线动态对象录波流程。

已浏览公开官方资料；决定类型与 dumping 范围的依据以上述安装版本手册为主。IEEE 1800-2023 的[官方条目](https://ieeexplore.ieee.org/document/10458102)可检索，但正文网页被访问校验拦住，本报告没有把未读取的标准正文当作证据。
