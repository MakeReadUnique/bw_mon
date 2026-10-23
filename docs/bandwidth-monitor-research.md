# EDA 验证用 bandwidth monitor 开源调研

调研日期：2026-10-21。范围：可实例化的 Verilog/SystemVerilog `module`，用于仿真验证中的传输量、带宽或吞吐率统计，也考察可综合实现。以下结论基于官方仓库、源码和已有测试的静态核查；本次没有运行这些项目的仿真或综合。

## 结论

**已有非常接近需求的开源实现。若目标是 testbench 中实例化的 AXI4 带宽统计 module，优先参考 FlooNoC 的 `axi_bw_monitor.sv`。** 它直接观察握手并在仿真结束时输出读写带宽。若接口是 AXI-Stream，可参考 `axis_stat_counter.v`；若以后需要上 FPGA 或进一步分析 AXI 阻塞原因，可参考 ZipCPU `axiperf`。多接口统一统计则适合参考 Corundum/TAXI 的增量收集结构。各实现的统计口径与窗口不同，不能把它们的结果直接互换。

| 候选 | 形式与接口 | 已有功能 | 对当前需求的主要差距 | 相关文件许可 |
|---|---|---|---|---|
| [FlooNoC `axi_bw_monitor`](https://github.com/pulp-platform/FlooNoC/blob/c48b6456079b634ccce94231f619bf5990d18331/hw/test/axi_bw_monitor.sv) | SystemVerilog 仿真 module；AXI req/rsp 结构体输入 | 读写 Bits/cycle、利用率、延迟 | 单次总区间；按完整数据位宽计量；没有周期报告/CSV | SHL-0.51 |
| [verilog-axis `axis_stat_counter`](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/rtl/axis_stat_counter.v) | Verilog RTL module；旁路观察 AXI-Stream | 字节、tick、frame 计数；trigger 快照输出 | 需换算带宽；tick 和 TKEEP 算法有特定口径；仓库已弃用 | MIT |
| [ZipCPU `axiperf`](https://github.com/ZipCPU/wb2axip/blob/2e8d3bc2d26ddc33d1881022a2a2b9d3f0c16b9b/rtl/axiperf.v) | 可综合 Verilog module；AXI4 观察口 + AXI-Lite 配置口 | 读写传输量、周期、停顿及吞吐分析相关计数器 | 接入较重；软件配置窗口并读取计数器 | Apache-2.0 |
| [Corundum `stats_collect`](https://github.com/corundum/corundum/blob/1ca0151b97af85aa5dd306d74b6bcec65904d2ce/fpga/common/rtl/stats_collect.v) / [TAXI `taxi_stats_collect`](https://github.com/fpganinja/taxi/blob/cc70b270b910d369ab1ad7b3855e76399fd461f1/src/stats/rtl/taxi_stats_collect.sv) | Verilog / SystemVerilog RTL module；多路增量输入 | 多路累计、周期或外部触发发送统计增量 | 需自行把握手转换成 byte 增量，并增加准确时间窗口 | 前者 MIT；后者 CERN-OHL-S-2.0 |

## 1. FlooNoC：最接近仿真验证需求

文件是约 150 行的独立 `module axi_bw_monitor`，参数包括 `req_t`、`rsp_t`、`AxiIdWidth`、`Name`；端口为 `clk_i`、`en_i`、`end_of_sim_i`、AXI 请求/响应以及两个在途数量输出。使用队列、`real`、`initial` 和 `$display`，适合仿真 testbench。带宽计数依据 `WVALID && WREADY`、`RVALID && RREADY`，因此背压下未接受的数据不会被重复计算。[源码与文件许可](https://github.com/pulp-platform/FlooNoC/blob/c48b6456079b634ccce94231f619bf5990d18331/hw/test/axi_bw_monitor.sv)

其输出口径是：

```text
读带宽 = 接受的 R beats × RDATA 位宽 / 统计周期数，单位 Bits/cycle
写带宽 = 接受的 W beats × WDATA 位宽 / 统计周期数，单位 Bits/cycle
利用率 = 接受的对应数据 beats / 统计周期数 × 100%
```

复用前要补齐的内容：

- `en_i` 是一次启动事件：代码等待其上升沿后运行至 `end_of_sim_i`；拉低 `en_i` 不会暂停。没有 reset 端口，也没有连续固定窗口或滑动窗口。
- 统计的是完整数据通道位宽，写带宽没有使用 `WSTRB`；若要求“实际有效字节/s”，应修改 byte 计数口径。读窄传输也不能直接按完整 `RDATA` 位宽当作有效字节。
- 当前打印整个区间的平均值；MB/s、GB/s、周期性 CSV、阈值检查需要添加。空窗口、开始/结束边界也应在接入时定义。

仓库已有 mesh testbench 中的实际实例化用例，可参考其 req/rsp 连接方式。[集成示例](https://github.com/pulp-platform/FlooNoC/blob/c48b6456079b634ccce94231f619bf5990d18331/hw/tb/tb_floo_axi_mesh.sv#L146-L159)

这些限制来自上述源码；将它作为轻量仿真 monitor 的起点，是本次调研的工程建议。

若同时复用延迟和在途统计，需要额外核查：读延迟量到首个 R beat，AR 队列也在首拍弹出；因此 `ar_in_flight_o` 不是所有尚未完成的读 burst 数。识别首拍使用一个全局 `prev_r_last`，对不同 ID 的读响应交织可能不适用。这是静态源码观察，尚未仿真验证。

## 2. verilog-axis：AXI-Stream 统计 module

`axis_stat_counter` 不读取 payload，只输入 `monitor_axis_tkeep/tvalid/tready/tlast`、`clk/rst`、`tag/trigger`。在成功握手时累计数据量，`trigger` 在空闲状态下锁存并清零本区间计数；快照由一个 8-bit AXI-Stream 输出，统计本身继续进行。不是自动按秒报告带宽的模块。[RTL 源码](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/rtl/axis_stat_counter.v)

这里有两个容易误用的实现细节：

- `KEEP_ENABLE=1` 时，`tick_count` 每周期增加 `KEEP_WIDTH`，并非增加 1。常见 64-bit / 8-byte 通道下，100 个周期对应 800 ticks；官方测试也明确检查这个关系。因此通常 `cycles = ticks / KEEP_WIDTH`，再计算 `bytes / cycles`。[对应测试](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/tb/test_axis_stat_counter.py)
- byte 算法匹配低位连续为 1 的 TKEEP，如 `00001111`；不是通用 popcount，稀疏 mask 可能计为 0。需要支持任意 byte mask 时应改为 `$countones(tkeep)` 或等效实现。[计数逻辑](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/rtl/axis_stat_counter.v#L228-L246)

另外，发送快照期间不能把新 `trigger` 当作必然被接受的请求；集成时应利用 `busy` 管理触发间隔。原仓库为 MIT，但 README 明确声明已弃用，后续维护转入 TAXI；不能据此假定 TAXI 有同名替代模块或相同许可。[项目状态](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/README.md)

## 3. ZipCPU：更完整的 AXI 性能监控 IP

`axiperf` 的 `M_AXI_*` 端口为被动观察输入，`S_AXI_*` 为 AXI-Lite 配置和读出接口，并依赖 `skidbuffer.v`。启动与停止请求等待总线空闲后生效。它按周期分类记录传输、等待和停顿，支持进一步区分 master 与 slave 对吞吐的影响。[作者源码说明](https://github.com/ZipCPU/wb2axip/blob/2e8d3bc2d26ddc33d1881022a2a2b9d3f0c16b9b/rtl/axiperf.v)

统计口径也要区分：写有效字节使用成功 W 握手的 `WSTRB` 位数；读字节计数来自接受的 AR 请求长度与尺寸，并非逐个 R 握手完成的字节数，另有实际 R beat 计数。源码头部旧使用说明与当前控制寄存器地址不一致，接入应以当前地址译码和[作者说明](https://zipcpu.com/blog/2021/08/14/axiperf.html)为准。

适合“AXI 为什么跑不满”以及需要可综合 monitor 的场景。若仅在仿真里打印每 N 周期 GB/s，其寄存器接口和诊断计数器会增加集成工作；输出仍是原始计数，带宽公式及报告需要在 testbench 或软件侧实现。

宽数据总线接入前需检查参数：当前 [WSTRB 累加表达式](https://github.com/ZipCPU/wb2axip/blob/2e8d3bc2d26ddc33d1881022a2a2b9d3f0c16b9b/rtl/axiperf.v#L858) 包含复制次数 `LGCNT-C_AXI_DATA_WIDTH/8-1`；默认 `LGCNT=32` 时，256-bit 及以上会得到负值。这是静态发现，需修改并通过目标工具验证后再使用。

## 4. Corundum / TAXI：通用多路统计后端

Corundum 的 `stats_collect` 接收 `COUNT` 路 `stat_inc/stat_valid`，以 `UPDATE_PERIOD` 或外部 `update` 请求输出各统计 ID 的增量。可令一条输入代表 read bytes，另一条代表 write bytes，也可扩展为 beat、stall 等。它不理解 AXI 握手，也没有内建 GB/s 计算；统计输出是 AXI-Stream 风格的 `{ID, increment}`。[collector 源码](https://github.com/corundum/corundum/blob/1ca0151b97af85aa5dd306d74b6bcec65904d2ce/fpga/common/rtl/stats_collect.v)

配套 `stats_counter` 累加这些增量并提供 AXI-Lite 读口。官方有 collector 的 cocotb 测试，检查多路增量的最终累计结果。[counter 源码](https://github.com/corundum/corundum/blob/1ca0151b97af85aa5dd306d74b6bcec65904d2ce/fpga/common/rtl/stats_counter.v)、[collector 测试](https://github.com/corundum/corundum/blob/1ca0151b97af85aa5dd306d74b6bcec65904d2ce/fpga/common/tb/stats_collect/test_stats_collect.py)

TAXI 中的 `taxi_stats_collect` 使用 SystemVerilog 数组及 `taxi_axis_if`，还提供 `gate`；其文件明确标识 CERN-OHL-S-2.0，和 Corundum 相关文件的 MIT 不同。核查当前源码树时，没有发现可直接宣称为 `axis_stat_counter` 一对一替代品的同名模块。[TAXI collector](https://github.com/fpganinja/taxi/blob/cc70b270b910d369ab1ad7b3855e76399fd461f1/src/stats/rtl/taxi_stats_collect.sv)、[TAXI 源码目录](https://github.com/fpganinja/taxi/tree/cc70b270b910d369ab1ad7b3855e76399fd461f1/src)

需要注意：周期更新只是请求输出，通道轮询及输出背压会影响实际输出时刻；不能直接把每一条收到的增量都除以 `UPDATE_PERIOD` 并认为是严格同边界的窗口带宽。若要求精确固定窗口，应单独做同步快照及窗口周期计数。这是根据 collector 状态机得到的工程判断。

## 对拟开发模块的建议

如果目标只是仿真验证，建议以 FlooNoC 为参考，保持 monitor 被动观察接口，并把以下需求显式化：

1. **成功传输事件**：通常为 `valid && ready`；背压周期不能计为已传输数据。
2. **统计口径**：区分完整总线传输量与实际有效 payload；AXI 写可使用 `popcount(WSTRB)`，AXI-Stream 可使用 `popcount(TKEEP)`。AXI 读若支持窄传输，应追踪请求尺寸/地址及响应 ID，或者明确只统计通道占用量。
3. **时间窗口**：支持可配置 N-cycle 窗口和从 start 到 stop 的累计统计；报告 bytes、cycles、bytes/cycle、MB/s、利用率时明确单位与时钟频率。变频时用实际时间差，而非固定频率换算。
4. **接入形式**：通用统计核心输入 `transfer`、`bytes_this_transfer`、`start/stop/clear`；AXI、AXI-Stream 或自定义接口适配层负责提供事件与字节数。这样可以保持 module 形式，同时避免将通用统计逻辑绑定到单一协议。

上述是建议的最小设计范围，并不是声称这些开源项目已经全部实现。对纯仿真用途，可直接输出 CSV；只有需要综合时，再考虑 Corundum/TAXI 的统计流或 ZipCPU 的寄存器读出结构。
