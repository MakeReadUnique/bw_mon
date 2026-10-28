# bw_mon 中文用户手册

`bw_mon` 用于 SystemVerilog 仿真，可以观察接口传了多少字节、最近一段时间的带宽，以及一次流量过程的平均带宽。接入时，把监测器连接到接口的时钟、复位和传输控制信号即可，不需要 UVM。

第一次使用，可以先运行第 2、3 节的小例子。接到自己的 DUT 时，主要修改 **协议类型、每拍字节数、窗口大小、信号连接和观测点总数**。多接口汇总、阶段分析和性能检查可以按需增加。

目录：

- [1 接入时需要哪些模块](#1-接入时需要哪些模块)
- [2 最小可运行例子](#2-最小可运行例子)
- [3 编译和运行](#3-编译和运行)
- [4 常用参数怎么填](#4-常用参数怎么填)
- [5 三种接口怎么接线](#5-三种接口怎么接线)
- [6 用 bind 接入已有 DUT](#6-用-bind-接入已有-dut)
- [7 把多个接口汇总成一个组](#7-把多个接口汇总成一个组)
- [8 配置流量过程和阶段分析](#8-配置流量过程和阶段分析)
- [9 配置反压和信用提示](#9-配置反压和信用提示)
- [10 配置带宽达标检查](#10-配置带宽达标检查)
- [11 查看统计结果](#11-查看统计结果)
- [12 常见问题](#12-常见问题)

## 1 接入时需要哪些模块

| 模块 | 放几个 | 用途 |
| --- | --- | --- |
| `bw_point_mon` | 每个要观察的接口放一个 | 统计这个接口的传输和带宽，称为一个“观测点” |
| `bw_mon_setup` | 整个仿真放一个 | 声明观测点和聚合组的总数，统一启动监测 |
| `bw_group_mon` | 每个聚合组放一个，可选 | 汇总一组接口的原始传输，统计总带宽 |

这些模块用于仿真，不用于综合。点和组的结果直接放在各自实例内，通过层次路径或波形查看，不需要另接带宽输出端口。

## 2 最小可运行例子

假设接口是 `valid/ready` 握手：每次成功传输 64 字节，时钟周期为 1 ns。我们希望统计最近 10 ns 的带宽，每 1 ns 更新一次。

完整文件已放在 [examples/bw_mon_quickstart.sv](../examples/bw_mon_quickstart.sv)，可以直接运行：

```systemverilog
module bw_mon_quickstart;
  timeunit 1ns;
  timeprecision 1fs;
  import bw_mon_pkg::*;

  logic clk = 0;
  logic reset_n = 0;
  logic valid = 0;
  logic ready = 1;

  // 1 GHz 时钟，每个周期为 1 ns。
  always #0.5ns clk = ~clk;

  // 整个 testbench 只放一个 setup，填写实际观测点总数。
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) u_bw_setup();

  bw_point_mon #(
    .POINT_ID("master0"),
    .PROTOCOL(BW_VALID_READY),
    .FIXED_BYTES(64),
    .WINDOW_BASIS(BW_NS),
    .WINDOW_WIDTH(10),
    .UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),
    .SILENCE_THRESHOLD(10)
  ) u_bw (
    .clk(clk),
    .reset_n(reset_n),
    .valid(valid),
    .ready(ready)
  );

  initial begin
    wait (monitor_ready);
    // 在下降沿改激励，供后面的上升沿采样。
    repeat (2) @(negedge clk);
    reset_n = 1;
    valid = 1;

    // 连续传输 20 拍，每拍 64 字节，共 1280 字节。
    repeat (20) @(negedge clk);
    valid = 0;
    #1fs; // 等当前时刻的统计更新完成后读取。
    $display("QUICKSTART window_bytes=%0d bandwidth_gbps=%0.3f window_valid=%0b",
             u_bw.window_bytes, u_bw.bandwidth_gbps, u_bw.window_valid);

    // 保持时钟运行，等待末拍结束和 10 ns 静默确认。
    repeat (12) @(negedge clk);
    #1fs;
    $display("QUICKSTART total_bytes=%0d total_events=%0d e2e_gbps=%0.3f e2e_valid=%0b",
             u_bw.total_bytes, u_bw.total_events,
             u_bw.episode_result_e2e_gbps, u_bw.episode_result_e2e_valid);
    $finish;
  end
endmodule
```

例化代码分两部分：`#(...)` 里填写配置参数，实例名 `u_bw` 后面的 `(...)` 连接 DUT 信号。例如 `.FIXED_BYTES(64)` 是配置每拍字节数，`.valid(valid)` 是把外部 `valid` 信号接到监测器的 `valid` 端口。

这段代码的统计结果应为：

| 结果 | 数值 | 怎么算 |
| --- | --- | --- |
| 连续传输期间，满窗字节数 | 640 B | 10 拍 × 64 B |
| 满窗带宽 | 64 GB/s | 640 B ÷ 10 ns |
| 总传输字节数 | 1280 B | 20 拍 × 64 B |
| 全程平均带宽 | 64 GB/s | 1280 B ÷ 20 ns |

**本项目的 `bandwidth_gbps` 和配置键中的 `gbps` 都表示十进制 GB/s，B 是字节。** 数值上 `1 B/ns = 1 GB/s`。512 bit 的接口每拍传满时是 64 B，因此这里填写 `FIXED_BYTES(64)`。

如果只需要滑窗带宽，可以去掉 `EPISODE_ENABLE` 和 `SILENCE_THRESHOLD` 两行，以及最后读取 `episode_result_*` 的代码。

## 3 编译和运行

当前构建使用 VCS，已验证的工具版本为 `W-2024.09-SP1_Full64`。需要能在终端执行 `vcs`，并有可用的仿真许可。其他仿真器需要另外适配调度接口。

在仓库根目录执行下面的 Bash 命令。示例会把编译结果和日志放在 `.build/quickstart`：

```bash
mkdir -p .build/quickstart
cd .build/quickstart

# 根据 PATH 中的 vcs 找到安装目录及 SDK 头文件。
BW_VCS_ROOT="$(dirname "$(dirname "$(readlink -f "$(command -v vcs)")")")"

vcs -full64 -sverilog +vpi -debug_access+all -assert svaext \
  +incdir+../../rtl -CFLAGS "-I${BW_VCS_ROOT}/include" \
  ../../rtl/bw_mon_pkg.sv \
  ../../rtl/bw_check_report.sv \
  ../../rtl/bw_hint_duration.sv \
  ../../rtl/bw_debug_hints.sv \
  ../../rtl/bw_point_recorder.sv \
  ../../rtl/bw_stats_core.sv \
  ../../rtl/bw_point_mon.sv \
  ../../rtl/bw_group_mon.sv \
  ../../rtl/bw_mon_setup.sv \
  ../../rtl/bw_slot_settlement.c \
  ../../examples/bw_mon_quickstart.sv \
  -top bw_mon_quickstart -o simv -l compile.log

./simv -no_save -l run.log
cd ../..
```

若 `vcs` 是公司提供的包装脚本，需要把 `BW_VCS_ROOT` 改成实际 VCS 安装目录，确保其 `include` 目录里有 `svdpi.h` 和 `vpi_user.h`。

运行日志中应出现：

```text
QUICKSTART window_bytes=640 bandwidth_gbps=64.000 window_valid=1
QUICKSTART total_bytes=1280 total_events=20 e2e_gbps=64.000 e2e_valid=1
BW_SUMMARY status=STATISTICS_ONLY pass=0 fail=0 warning=0 scopes_done=1 scopes_expected=1
```

`STATISTICS_ONLY` 表示正常统计，但没有设置性能目标。第 10 节会说明如何得到 PASS 或 FAIL。

集成到自己的编译脚本时，保留以下要求：

- `bw_mon_pkg.sv` 最先编译；`bw_check_report.sv` 必须放在 `bw_mon_setup.sv` 前面。
- 加入上述 RTL 和 `bw_slot_settlement.c`。即使只监测一个点，也需要这个 C 文件及 `+vpi`、`-debug_access`、`-assert svaext`。
- 通过 `+incdir+` 指定 `rtl` 目录，通过 `-CFLAGS` 指定 VCS 的 `include` 目录。`.svh` 文件由源码包含，不单独编译。
- 保留监测器源码中的 `timeunit 1fs; timeprecision 1fs;`，不要通过工具选项覆盖它们。testbench 可以像例子一样使用 `timeunit 1ns`。

详细工具说明见[构建与调度说明](bw-mon-scheduling.md)。

## 4 常用参数怎么填

### 观测点参数

| 参数 | 默认值 | 用户怎么填 |
| --- | --- | --- |
| `POINT_ID` | 自动使用监测器实例的完整层次路径 | 可以填 `"master0"`、`"mem0"` 等名字；所有点的 ID 必须唯一且非空 |
| `PROTOCOL` | `BW_VALID_ONLY` | 根据第 5 节选择传输规则 |
| `FIXED_BYTES` | `0` | 固定计量时，每次成功传输的字节数；范围为 0 到 4294967295 |
| `DYNAMIC_BYTES` | `0` | 每拍大小不同就设为 `1`，并连接 `size_bytes`、`size_known` |
| `WINDOW_BASIS` | `BW_NS` | 按时间统计用 `BW_NS`，按本地时钟周期统计用 `BW_CYCLE` |
| `WINDOW_WIDTH` | `0`，必须修改 | 一个窗口覆盖多少 ns 或周期；必须大于 0 |
| `UPDATE_STRIDE` | 省略时取 `WINDOW_WIDTH` | 每隔多少 ns 或周期更新结果；要求 `0 < UPDATE_STRIDE <= WINDOW_WIDTH`。省略时每个窗口宽度发布一次；显式填 0 或超过 W 都会报错 |
| `EPISODE_ENABLE` | `0` | 设为 `1` 才分析完整流量过程及全程平均带宽 |
| `SILENCE_THRESHOLD` | 省略时为 10 | 开启过程分析时默认 10（ns 模式为 10 ns，cycle 模式为 10 个本地周期）；显式合法正数可覆盖且允许大于 W；显式 0／未知值报错，不回退默认；过程关闭时不校验 |
| `PHASE_ENABLE` | `0` | 设为 `1` 分析爬坡、稳定和下降；还需要第 8 节的完整参数 |

参数是例化时的配置，仿真期间不能动态修改。开关参数填已知的 `0` 或 `1`。`FIXED_BYTES` 默认的 0 是合法值：忘记填写时会统计到传输次数，但字节数为 0。

后面的参数片段都写在模块的 `#(...)` 内。参数之间用逗号分隔，整个参数列表的最后一项不加逗号。修改这些参数后需要重新编译。

### setup 参数

| 参数 | 默认值 | 用户怎么填 |
| --- | --- | --- |
| `EXPECTED_POINT_COUNT` | `0`，必须修改 | 仿真里全部观测点的数量，包括没有加入组的点；范围 1 到 16384 |
| `EXPECTED_GROUP_COUNT` | `0` | 全部 `bw_group_mon` 的数量；范围 0 到 4096 |
| `STARTUP_TIMEOUT_NS` | `100` | 等待注册和配置完成的最长时间，必须为正整数 ns |
| `MISSING_RECORD_TIMEOUT_NS` | `1` | 聚合组等待某个采样沿的成员记录送达的最长时间，必须为正整数 ns |

`MISSING_RECORD_TIMEOUT_NS` 不是允许接口空闲的时间。空闲采样沿也有记录；这里检查的是组所需的数据是否送达。

### 按时间还是按周期统计

| 需求 | 参数组合 | 停钟后的表现 |
| --- | --- | --- |
| 最近 10 ns，每 1 ns 更新 | `BW_NS`、宽度 `10`、步长 `1` | 仍按时间更新，旧传输移出窗口后带宽归零 |
| 最近 20 个周期，每 2 个周期更新 | `BW_CYCLE`、宽度 `20`、步长 `2` | 没有新采样沿就保持上一次结果 |

例如，把例子中的三个窗口参数换成：

```systemverilog
.WINDOW_BASIS(BW_CYCLE),
.WINDOW_WIDTH(20),
.UPDATE_STRIDE(2)
```

此时 `SILENCE_THRESHOLD(10)` 也变成 **10 个周期**。带宽仍然输出 GB/s，并额外提供 `bytes_per_cycle`。GB/s 使用实际经过的时间计算，变频或窗口内发生停钟都会影响它，不需要配置固定频率。

窗口宽度决定看多长时间，步长决定多久更新一次。比如宽度 10、步长 1 的相邻窗口会重叠；步长等于宽度时，相邻窗口互不重叠。步长越小，更新越频繁。

当前限制是：ns 窗口最大 40000 ns，cycle 窗口最大 80000 周期；从 setup 配置系统起，整个监测时段最长 **40000 ns，也就是 40 μs**。复位不会重新计算这个总时限，长仿真集成前要确认观察时段。

## 5 三种接口怎么接线

所有传输都在 `clk` 上升沿采样，`reset_n` 为低有效复位。

| 接口类型 | `PROTOCOL` | 需要连接的传输信号 | 什么情况算一次传输 |
| --- | --- | --- | --- |
| 只有有效信号 | `BW_VALID_ONLY` | `valid` | `valid == 1` |
| 有效与就绪握手 | `BW_VALID_READY` | `valid`、`ready` | `valid == 1` 且 `ready == 1` |
| 信用控制的 flit 接口 | `BW_CREDIT` | `flitv`、`lcrdv` | `flitv == 1`；`lcrdv` 用于信用诊断 |

不用的传输端口可以省略。尤其注意：**valid/ready 接口必须选择 `BW_VALID_READY`**，只接上 `ready` 不会自动改变默认传输规则。

以下片段用于替换或扩展自己 testbench 中的例化；每增加一个监测器，都要同步修改 setup 的点数。

### 只有 valid 的接口

假设 DUT 的传输信号叫 `tx_valid`，每拍固定 32 字节：

```systemverilog
bw_point_mon #(
  .POINT_ID("tx0"),
  .PROTOCOL(bw_mon_pkg::BW_VALID_ONLY),
  .FIXED_BYTES(32),
  .WINDOW_WIDTH(10),
  .UPDATE_STRIDE(1)
) u_tx_bw (
  .clk(clk), .reset_n(reset_n), .valid(tx_valid)
);
```

valid/ready 接法见第 2 节。接口处于反压状态时，只有真正完成握手的拍才计数。

### flitv 和 lcrdv 接口

假设每个 flit 为 32 字节：

```systemverilog
bw_point_mon #(
  .POINT_ID("noc0"),
  .PROTOCOL(bw_mon_pkg::BW_CREDIT),
  .FIXED_BYTES(32),
  .WINDOW_WIDTH(10),
  .UPDATE_STRIDE(1)
) u_noc_bw (
  .clk(clk), .reset_n(reset_n),
  .flitv(flitv), .lcrdv(lcrdv)
);
```

计量以实际发送的 `flitv` 为准。`lcrdv` 表示信用返回，一次为一份信用；不能把它当成 `ready`。即使信用诊断发现异常，已经发生的确定传输仍会计数。开启信用账本的方法见第 9 节。

### 每拍字节数不同的接口

把 `DYNAMIC_BYTES` 设为 `1`。`size_bytes` 必须是 **当前这一拍已经解码好的字节数**，`size_known=1` 表示这个数确定可用。

下面假设自己的接口用 `size_code` 表示当前拍大小，编码 `0/1/2` 分别代表 `16/32/64 B`。这个编码仅用于演示，实际工程要按 DUT 的定义解码：

```systemverilog
logic [63:0] beat_bytes;
logic beat_bytes_known;

always_comb begin
  beat_bytes = 'x;
  beat_bytes_known = 1'b1;
  case (size_code)
    2'd0: beat_bytes = 64'd16;
    2'd1: beat_bytes = 64'd32;
    2'd2: beat_bytes = 64'd64;
    default: beat_bytes_known = 1'b0;
  endcase
end

bw_point_mon #(
  .POINT_ID("master_dynamic"),
  .PROTOCOL(bw_mon_pkg::BW_VALID_READY),
  .DYNAMIC_BYTES(1),
  .WINDOW_WIDTH(10),
  .UPDATE_STRIDE(1)
) u_dynamic_bw (
  .clk(clk), .reset_n(reset_n),
  .valid(valid), .ready(ready),
  .size_bytes(beat_bytes), .size_known(beat_bytes_known)
);
```

例如一个 burst 有 4 拍，每拍 64 B，每拍应填 64，整个 burst 共计 256 B。如果每拍都填 256，就会重复计量。若要按有效字节使能计数，可以在自己的适配逻辑中先计算当前拍有效字节数，再送入 `size_bytes`。

动态字节数也限于 0 到 4294967295。已确定传输但大小未知时，传输次数仍会增加，字节结果会标为不完整。0 字节传输是合法的，也会增加传输次数。

## 6 用 bind 接入已有 DUT

`bind` 可以把监测器挂到已有模块上，无需修改 DUT 源码。假设 DUT 中有一种模块叫 `noc_link`，内部信号是 `clk`、`reset_n`、`valid`、`ready`：

```systemverilog
bind noc_link bw_point_mon #(
  .PROTOCOL(bw_mon_pkg::BW_VALID_READY),
  .FIXED_BYTES(64),
  .WINDOW_WIDTH(10),
  .UPDATE_STRIDE(1)
) u_bw (
  .clk(clk), .reset_n(reset_n), .valid(valid), .ready(ready)
);
```

把这段代码放在单独的 `.sv` 文件中，加入仿真编译列表。`noc_link` 是要绑定的 **模块类型名**，端口连接中用的是这个模块内部的信号名。

这会给每一个 `noc_link` 实例都增加一个监测器。如果 testbench 里有两个实例 `tb.link0` 和 `tb.link1`，默认 Point ID 分别为：

```text
tb.link0.u_bw
tb.link1.u_bw
```

因此，setup 的 `EXPECTED_POINT_COUNT` 应填实际生成的监测器总数，而不是 bind 语句的数量。类型 bind 时保留自动 ID，可以避免多个实例都被命名为同一个 `"master0"`。自动 ID 的完整内容可以在实例的 `scope_id` 中查看。

完成注册后，用 `wait (bw_mon_pkg::monitor_ready);` 等待启动。真正计入统计的采样沿必须晚于 ready 所在的物理时刻；像第 2 节那样在后续下降沿准备激励即可。

## 7 把多个接口汇总成一个组

例如两个 memory 接口分别命名为 `mem0`、`mem1`，想同时查看它们各自的带宽和合计带宽。需要两个点、一个组，以及一个 setup。

以下代码放进已有 testbench，假设已经有 `clk`、`reset_n`、`valid0`、`ready0`、`valid1`、`ready1` 信号。它使用一个全新的 setup；如果工程已经有 setup，应合并数量并保留一个。

```systemverilog
import bw_mon_pkg::*;

bw_mon_setup #(
  .EXPECTED_POINT_COUNT(2),
  .EXPECTED_GROUP_COUNT(1)
) u_bw_setup();

bw_point_mon #(
  .POINT_ID("mem0"),
  .PROTOCOL(BW_VALID_READY), .FIXED_BYTES(64),
  .WINDOW_BASIS(BW_NS), .WINDOW_WIDTH(10), .UPDATE_STRIDE(1)
) u_mem0_bw (
  .clk(clk), .reset_n(reset_n), .valid(valid0), .ready(ready0)
);

bw_point_mon #(
  .POINT_ID("mem1"),
  .PROTOCOL(BW_VALID_READY), .FIXED_BYTES(64),
  .WINDOW_BASIS(BW_NS), .WINDOW_WIDTH(10), .UPDATE_STRIDE(1)
) u_mem1_bw (
  .clk(clk), .reset_n(reset_n), .valid(valid1), .ready(ready1)
);

bw_group_mon #(
  .GROUP_ID("all_mem"),
  .WINDOW_BASIS(BW_NS), .WINDOW_WIDTH(10), .UPDATE_STRIDE(1)
) u_all_mem_bw (
  .clk(clk), .reset_n(reset_n)
);

initial begin
  define_group("all_mem", 2); // 这个组有两个直接成员。
  add_point_member("all_mem", "mem0");
  add_point_member("all_mem", "mem1");
  finish_configuration();    // 所有组和成员都配置好后，只调用一次。
end
```

激励仍需等待 `monitor_ready`。之后，读 `u_mem0_bw.bandwidth_gbps` 和 `u_mem1_bw.bandwidth_gbps` 得到各点带宽，读 `u_all_mem_bw.bandwidth_gbps` 得到组带宽。例如两个接口都每 1 ns 传 64 B，连续传输并满窗后，组带宽为 128 GB/s。

配置聚合组时，注意以下规则：

- 组成员用 **Point ID** 引用。如果点写了 `.POINT_ID("mem0")`，成员就填 `"mem0"`；省略 Point ID 时，要填自动生成的完整路径。
- 组和成员的 `WINDOW_BASIS`、`WINDOW_WIDTH`、`UPDATE_STRIDE` 必须一致。监测器不再要求填写时钟域名称，也不做时钟一致性检查；聚合的前提仍然是各成员实际使用同一个采样时钟，跨异步时钟汇总不支持。
- 组通过注册信息取得成员传输，不需要连接各点的带宽信号。组统计的是成员原始字节增量。
- `finish_configuration()` 要放在所有组定义和成员配置之后；有组却漏掉这一步，监测不会启动。只有点、没有组时不需要调用。
- 点和组分别控制自己的过程、阶段分析。若想得到组的全程平均带宽，也要在组实例上设置 `EPISODE_ENABLE(1)` 和正的 `SILENCE_THRESHOLD`。

也可以让一个组包含两个已经配置好的下级组：

```systemverilog
define_group("all_mem", 2);
add_group_member("all_mem", "die0_mem");
add_group_member("all_mem", "die1_mem");
```

此时三个 Group ID 都要有对应的 `bw_group_mon`，setup 的组数要包括三者；`all_mem` 的直接成员数是 2。上述语句应与下级组配置一起放在唯一一次 `finish_configuration()` 前。同一个上级组不能沿不同成员路径重复包含同一个点，也不能形成循环关系。更多分层用法见[完整接口说明](bw-mon-api.md#typed-hierarchy-and-independent-statistics)。

## 8 配置流量过程和阶段分析

### 统计一次流量过程的平均带宽

在点或组的参数列表中加入：

```systemverilog
.EPISODE_ENABLE(1),
.SILENCE_THRESHOLD(20)
```

这里的 20 跟随窗口基准：`BW_NS` 下为 20 ns，`BW_CYCLE` 下为 20 个本地周期。

监测器从第一次确定传输开始记录。最后一次传输之后，需要再看到一个真实采样沿，才能知道末拍何时结束；之后连续静默达到阈值，才确认这次过程结束。

全程平均带宽的算法是：

```text
全程平均带宽 = 这次过程的总字节数 ÷ 从首拍开始到末拍结束的实际时间
```

过程内部的短暂停顿计入持续时间，末尾为了确认结束而等待的静默不计入。静默阈值可以按业务正常间歇来选：过小会把一次业务拆成多个过程，过大会延后结果确认。

最后一拍之后直接 `$finish`，或者立刻停钟，都可能无法得到完整结果。应保持时钟运行，让末拍有结束边界，并等待足够的静默时间。读取最终结果时，先看 `episode_result_e2e_valid`，为 1 时再用 `episode_result_e2e_gbps`。

### 识别爬坡 稳定和下降

开启过程分析时，省略阶段开关就会使用已经确认的默认策略。点和具名组采用相同规则：

```systemverilog
.EPISODE_ENABLE(1) // 同时开启过程和默认阶段分析；Q 默认 10
```

若只需要全程平均带宽，可以显式保留过程并关闭阶段：

```systemverilog
.EPISODE_ENABLE(1), .PHASE_ENABLE(0)
```

两项开关都只接受已知的 0/1；过程关闭但阶段显式开启属于配置错误。省略 `EPISODE_ENABLE` 时两项均关闭。原有 N、K、最小跨度和十个 ABS/REL 算法参数已经删除，升级时移除这些参数并重新编译，不再需要人工调参。

内部策略版本为 `PAIR6_R2`：最近 6 条连续合格窗口，相邻两条配成 3 个均值，按实际物理发布时间拟合趋势；相同候选连续 2 次才确认，最小证据跨度为 `min(W,5×S)`。稳定进入／保持的拟合总变化门槛分别为平均带宽的 4%／8%，原始残差 RMS 门槛为 10%／12%；升降要求总变化至少 10%，配对拟合点残差 RMS 不超过 2.5%。全零有效活动可以确认零带宽稳定阶段，完全无活动则没有流量过程。

这些内部门槛只解释阶段识别，不代表性能达标。原始窗口不会被配对拟合替换；阶段原始残差也不同于性能波动。Q 独立决定过程结束，不会为了等阶段确认而延长。

窗口预热、字节不完整或连续结果不足时，阶段可能保持 `BW_PHASE_UNDETERMINED`，表示暂时不能判断。一次流量可以没有稳定段，也可以反复出现多个稳定段；最终代表值采用该过程最后一个已确认的稳定段。阶段边界与稍后的确认时刻分别可见，不能把确认延迟当成阶段持续时间。

## 9 配置反压和信用提示

### valid/ready 的持续反压

在 `BW_VALID_READY` 点的参数列表中加入：

```systemverilog
.BACKPRESSURE_ENABLE(1),
.BACKPRESSURE_BASIS(bw_mon_pkg::BW_NS),
.BACKPRESSURE_THRESHOLD(10)
```

这表示 `valid=1` 且 `ready=0` 持续达到 10 ns 时给出提示。若改用 `BW_CYCLE`，阈值表示持续反压覆盖的完整本地周期数。提示的基准是独立配置，不会自动继承窗口基准。

### flit 接口的信用账本和信用不足

在 `BW_CREDIT` 点的参数列表中加入，例如信用容量和初值均为 8：

```systemverilog
.CREDIT_ENABLE(1),
.CREDIT_CAPACITY(8),
.CREDIT_INITIAL(8),
.CREDIT_INITIAL_KNOWN(1),
.CREDIT_RETURN_TIMING(bw_mon_pkg::BW_RETURN_NEXT_CYCLE),
.SHORTAGE_ENABLE(1),
.SHORTAGE_BASIS(bw_mon_pkg::BW_CYCLE),
.SHORTAGE_THRESHOLD(4)
```

每次 `flitv` 发送消耗一份信用，每次 `lcrdv` 返回一份信用。初值应按 DUT 的实际复位状态填写，不能直接照搬示例的 8。初值不确定时将 `CREDIT_INITIAL_KNOWN` 设为 0，监测器会把信用状态保持为未知。

`BW_RETURN_NEXT_CYCLE` 表示本拍返回的信用从下一拍开始可用于发送；`BW_RETURN_SAME_CYCLE` 表示本拍就能使用。必须按接口真实约定选择。

本例还会在可信的信用不足状态持续 4 个完整周期时提示。信用账本失去可信度时，检查 `credit_trusted`、`credit_reason`；后续普通传输不会自动修复它，需要一次已知复位并使用已知初值恢复。

反压和信用不足可以从 `BW_HINT_HIT` 日志及 `backpressure_*`、`shortage_*` 字段查看。它们提供调试线索，不直接给出性能 FAIL；信用不足也不能单独证明发送端确实有数据等待发送。

## 10 配置带宽达标检查

性能目标放在独立文本文件中，通过仿真参数 `+BW_EXPECT=文件路径` 读取。硬件接口、窗口等模块参数仍然写在例化里。

仓库已经提供 [examples/bw_mon_quickstart.cfg](../examples/bw_mon_quickstart.cfg)：

```ini
[point master0]
e2e_bw_min_gbps = 64
e2e_bw_max_gbps = 64
```

它要求第 2 节的 `master0` 全程平均带宽恰好为 64 GB/s。在仓库根目录执行：

```bash
cd .build/quickstart
./simv -no_save +BW_EXPECT=../../examples/bw_mon_quickstart.cfg -l check.log
cd ../..
```

本例已开启过程分析并留出结束时间，应得到一条 e2e 带宽 PASS，最终汇总为：

```text
BW_SUMMARY status=PASS pass=1 fail=0 warning=0 scopes_done=1 scopes_expected=1
```

### 换成自己的目标

例如，下面的配置检查点 `master0` 和组 `all_mem`。使用前要先例化对应对象，并开启所需分析：

```ini
[point master0]
e2e_bw_min_gbps = 60
e2e_bw_rel_tol_pct = 5

[group all_mem]
steady_bw_min_gbps = 120
ramp_time_max_ns = 20
steady_cv_max_pct = 10
```

| 常用键 | 含义 | 需要的功能 |
| --- | --- | --- |
| `e2e_bw_min_gbps` / `e2e_bw_max_gbps` | 全程平均带宽的下限 / 上限 | 过程分析 |
| `steady_bw_min_gbps` / `steady_bw_max_gbps` | 最后稳定段带宽的下限 / 上限 | 过程及阶段分析 |
| `ramp_time_max_ns` / `fall_time_max_ns` | 每个已确认爬坡 / 下降阶段的最长持续时间 | 过程及阶段分析 |
| `episode_cv_max_pct` | 整个过程的窗口带宽波动比例上限 | 过程分析 |
| `steady_cv_max_pct` | 最后稳定段的窗口带宽波动比例上限 | 过程及阶段分析 |
| `e2e_bw_abs_tol_gbps` | e2e 目标允许的绝对误差，单位 GB/s | 与 e2e 上限或下限一起使用 |
| `e2e_bw_rel_tol_pct` | e2e 目标允许的相对误差，单位百分比 | 与 e2e 上限或下限一起使用 |

CV 是标准差除以平均值，再乘 100%，数值越大表示窗口带宽波动越大。至少需要两个合格样本且平均值大于 0，才能给出有效 CV。

目标下限 60、相对容差 5%，实际允许下限就是 `60 × 0.95 = 57 GB/s`。这里的 `5` 表示 5%；阶段参数 `PHASE_*_REL` 则要写 `0.05` 才表示 5%。

配置文件中，点使用 `[point 完整ID]`，组使用 `[group 完整ID]`。名字区分大小写，不支持通配符，组目标也不会自动分配到各成员。值只写数字，不要附加 `GB/s` 等单位。文件在 ready 时读取一次，运行中修改不会重新加载。

设置性能目标不会自动打开过程或阶段分析。指标无有效结果、配置错误、没有流量或提前结束时，会有 WARNING 说明原因。

`BW_CHECK` 中的 PASS、FAIL、WARNING 都不会主动终止仿真。自动化回归应检查最终 `BW_SUMMARY`，不能仅凭进程退出码判断性能达标。汇总优先级是 FAIL、WARNING、PASS、STATISTICS_ONLY；一次失败不会被后来的通过清除。完整键表见[性能预期配置说明](bw-mon-expectations.md)。

## 11 查看统计结果

先找到点或组的公共实例，例如 `tb.u_bw` 或 `tb.u_all_mem_bw`。在波形中添加这个实例下的字段即可，不需要进入内部的 `core`、队列或包数据结构。

| 想看什么 | 字段 | 怎么理解 |
| --- | --- | --- |
| 对象身份 | `scope_id`、`monitor_path` | 配置用的 ID 和真实实例路径 |
| 新窗口是否发布 | `result_seq` | 数值变化表示发布了新窗口；0 表示还没有发布 |
| 累计传输 | `total_bytes`、`total_events` | 当前统计复位周期内的已知字节小计和传输次数小计 |
| 最近窗口 | `window_bytes`、`window_events` | 当前窗口内的已知字节数和传输次数 |
| 滑窗带宽 | `bandwidth_gbps` | 单位 GB/s，结合 `window_valid` 使用 |
| 每周期字节数 | `bytes_per_cycle` | 只在 cycle 模式使用；ns 模式的这个字段保持 0 |
| 是否满窗 | `window_warmup`、`window_full` | 历史尚不足一个窗口 / 已覆盖完整窗口 |
| 观测是否完整 | `bytes_complete`、`events_complete` | 窗口内的字节数 / 是否传输能否确定 |
| 窗口可用性 | `window_valid` | 满窗、字节完整、实际覆盖时间大于 0 时为 1 |
| 窗口时间范围 | `window_start_ticks`、`window_end_ticks`、`coverage_ticks` | 单位 fs，1000000 ticks 等于 1 ns |
| 统计复位次数 | `stats_epoch` | 区分复位前后的统计结果 |
| 最终全程带宽 | `episode_result_e2e_gbps`、`episode_result_e2e_valid` | 最近一次已经结算的过程结果及其有效位 |
| 最终过程身份 | `episode_result_episode_id`、`episode_result_result_seq` | 区分多个过程；结果序号为 0 时尚未结算 |
| 当前阶段 | `phase_current` | 未判定、爬坡、稳定或下降 |
| 最后稳定段带宽 | `episode_last_steady_bandwidth_gbps`、`episode_last_steady_bandwidth_valid` | 最近结算过程选出的最终稳定段结果 |

窗口使用左闭右开区间。例如 `[10 ns, 20 ns)` 包含 10 ns 处的传输，不包含 20 ns 处的传输；20 ns 的这一拍要在后续窗口中体现。初始预热期间按实际覆盖时间计算带宽，不能仅凭它有数值就认定已经满窗。

**先看有效位，再看数值。** 无效指标的存储值可能为 0，这不代表实际测得零带宽。存在未知输入时，小计仍保留已经确定的贡献，不代表完整流量。cycle 停钟时结果保持，也不代表停钟期间产生了新的测量结果。

自己的 testbench 若在某次发布时间读取字段，应等该时刻的更新完成，例如在读数前延后 `#1fs`。驱动 `valid`、`ready`、大小等输入时，放在采样沿之前；避免与监测器在同一个上升沿用阻塞赋值争抢执行顺序。

如果工程已有 FSDB 波形输出，保持原来的输出方式，把点和组实例加入 dump 范围；调试编译可使用 `-debug_access+all -kdb`。字段读法及现有波形示例见[中文波形阅读说明](bw-mon-wave-review-zh.md)。

## 12 常见问题

| 现象 | 优先检查 |
| --- | --- |
| 一直等不到 `monitor_ready` 或报 `STARTUP_TIMEOUT` | 点数、组数是否和实际例化一致；有组时是否调用 `finish_configuration()`；每个组是否有实例和定义 |
| 报 `DUPLICATE_POINT` | 是否给多个点写了相同的 Point ID；类型 bind 时可保留自动 ID |
| 报 `WINDOW_CONFIG` | 是否漏填宽度或步长，或步长大于宽度；检查所选基准的上限 |
| 报 `GROUP_CONTEXT` | 组和成员的时钟域名称、窗口基准、宽度、步长是否一致 |
| 组等待记录超时 | 检查组和成员的实际时钟连接，以及是否有成员缺少对应采样沿的记录 |
| 有传输次数，但字节数一直为 0 | 是否忘记填 `FIXED_BYTES`；动态模式下是否提供正确的 `size_bytes` 和 `size_known` |
| `ready=0` 仍在计数 | 是否忘记设置 `PROTOCOL(BW_VALID_READY)` |
| `bytes_complete=0` 或 `events_complete=0` | 检查复位、传输控制、动态大小中是否有 X/Z；能确定不传输的拍不会因未使用的大小未知而变坏 |
| 复位后带宽暂时不可用 | 自身复位会清空本地统计，释放后要重新预热；组的统计复位不清空成员或其他组的统计 |
| 有滑窗带宽但没有完整 e2e | 是否开启过程分析；是否出现过传输；末拍后是否有真实采样沿，是否等够静默阈值 |
| 没有稳定段结果 | 是否填写全部阶段参数；是否有足够连续满窗结果，跨度和门槛是否合适 |
| 输出 `STATISTICS_ONLY` | 没有配置参与比较的性能目标；可按第 10 节传入 `+BW_EXPECT` |
| 性能 FAIL 后仿真仍运行 | 这是正常行为；自动化脚本需要检查 `BW_CHECK` 和最终 `BW_SUMMARY` |
| 报 `SIM_TIME_LIMIT` | 是否超过 setup 配置起的 40 μs 总监测时限；复位不能延长它 |
| 编译缺少 DPI/VPI 符号或头文件 | 是否加入 `bw_slot_settlement.c`、`+vpi`、调试选项和正确的 VCS SDK include 路径 |

需要查看全部参数、公开字段和边界规则时，使用[完整接口说明](bw-mon-api.md)。
