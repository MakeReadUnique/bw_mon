# T6 波形查看旧指南（历史说明）

当前人工评审见[新的九张模拟曲线图](https://github.com/MakeReadUnique/bw_mon/issues/33)。用户 MakeReadUnique 已于 2026-10-26 [确认全部满足需求](https://github.com/MakeReadUnique/bw_mon/issues/33#issuecomment-6411618527)，范围是该 Issue 中列出的九个视图及区间。本页保留旧图的查看说明；原始清单和生成记录中的 PENDING 是当时的状态。

本文对应已经生成并冻结的 [T6 原始清单](../artifacts/acceptance/HUMAN-REVIEW.md)。新的人工确认不表示逐一查看了这里的全部 42 个场景或旧 33 张图，也不替代规模验收。原始仿真检出提交为 `cd07c77fcb706022069a9496bcf72d4354c1d2f8`，其 18 个生产文件与修复提交 `56127495f597d215003000356ac3b5387cc809a1` 逐字节相同。独立组件证明来自 `467b722cde3ea00e8eb8ed0e97dcc72d4dc67aa9`，共 427 项用例 / 168 个顶层；不同检出身份通过生产文件哈希关联。原 42 份输入与配置、33 张真实 Verdi 图和 42 份独立数值参考保持不变。原始数据资产指纹为：

```text
863af4f477409bf3e36af90f8fd7b2ffc7d008e2281f83fef759607482eeadee
```

固定数据提交为 [`59fc046a154945b6a6ae60220e663f7d5ee12bb6`](https://github.com/MakeReadUnique/bw_mon/tree/59fc046a154945b6a6ae60220e663f7d5ee12bb6/artifacts/acceptance)。本说明及人工状态记录的后续编辑不改变这份数据身份；实际查看时请同时核对上面的资产指纹。

[证据总索引](../artifacts/acceptance/INDEX.md)列出原始 FSDB、保存的公开信号视图、真实 Verdi 截图和独立预期/实际值表；[人工/代理记录](../artifacts/acceptance/review.json)分别记录两类查看。本文只索引这些现有对象，不扩大待签认范围。上一轮来源与代理记录保存在[历史记录](../artifacts/acceptance/review-history/README.md)；旧指纹不覆盖本轮。

本轮停钟和变频的 `clock` 图末尾还显示了 die0、die1、mixed 的 `bytes_per_cycle` 三行，便于同时核对组的周期口径；NS 图这些行均为 0，cycle 图按实际周期计量。原对象、光标时刻和数值目标未变。

## 先跟着一个例子读图

1. 打开 [NS 稳态截图](../artifacts/acceptance/steady_ns/overview.png)，同时打开它的[预期/实际值表](../artifacts/acceptance/steady_ns/expected-actual.md)。截图可下载后放大到原始分辨率查看。
2. 左侧是公开信号的完整层次路径，中间一列是黄色竖直光标处的值，右侧是随时间变化的波形；顶部横轴单位为 **ns**。同名信号要连同路径看，区分点 `ports[0]/dut/mon` 与组 `die0`、`die1`、`all_dmc`、`mixed`。本例中的点标识是 `p0`。
3. 保存的光标为 **102.000001 ns**，对应 102 ns 发布完成后的窗口。读 `window_start_ticks=92000000`、`window_end_ticks=102000000`，换算得到 **[92,102) ns**；`coverage_ticks=10000000` 表示覆盖 10 ns。光标时刻与窗口右端点是两个不同字段。
4. 读 `window_full=1`、`window_warmup=0`、`bytes_complete=1`、`events_complete=1`。这些条件各有含义：满窗表示历史覆盖足够，字节/事件完整表示观测是否确定，不能用满窗代替完整性。
5. 点 `p0` 的 `window_bytes=1280`、`window_events=20`，所以 `1280 B / 10 ns = 128 GB/s`。`bandwidth_gbps=1.2800000000e+02` 正是 128。再读 `all_dmc` 的 10240 B，得到 1024 GB/s；用整数与区间可以核对实数显示。
6. 对照表中的 Expected、Actual、Difference 三列；本例差值为 0。随后查看 [cycle 稳态截图](../artifacts/acceptance/steady_cycle/clock.png)，区间是 **[92.5,102.5) ns**，覆盖 20 个实际周期，点仍是 128 GB/s，同时为 **64 B/cycle**。

本套场景的物理时间精度为 **1 fs**：`1 tick = 1 fs = 0.000001 ns`，`1 ns = 1000000 ticks`。带宽使用十进制 GB/s，因此数值上 `B/ns = GB/s`；B/cycle 则用字节数除以实际覆盖的周期数。**B/cycle 只在 cycle 窗口对象中读取；NS 模式的 `bytes_per_cycle` 保持 0，不表示吞吐为零。** 不要把窗口采用 cycle 基准理解为带宽改用周期作物理时间分母。

`[a,b)` 是左闭右开的半开区间：包含时刻 a 的传输，排除时刻 b 的传输。例如 E2 的 [1,11) ns 不计入 11 ns 发生的那一笔。数字结果是离散发布并保持的值，波形连线不代表中间又产生了新样本；需要同时看 `result_seq` 和窗口边界。在交互式 Verdi 中核对某次发布时，可把光标移到该时刻之后 1 fs，避免把同一时刻更新前的显示当成已发布结果。

## 常用视图里看哪些行

各目录的 `.sav` 已保存固定的公开路径。只需要按下表选择视图；图中个别长路径或总线值被截短时，可在 Verdi 中展开或读旁边的完整数值表。

| 视图名 | 查看目的与关键行 |
| --- | --- |
| `overview` | 时钟、原始 valid/字节数、标识、`stats_epoch`、`result_seq`、窗口起止/字节/事件/完整性，以及点和各组的 `bandwidth_gbps`。适合先确认总体流量。 |
| `quality` | 原始 reset/有效性/大小与采样值，点和组的 epoch、预热、`bytes_complete`、`events_complete`、`member_reset_coverage`。适合分清复位、未知和已知小计。 |
| `episode` | 活动过程 `episode_*` 与已结算的不可变结果 `episode_result_*`，首/末/尾/确认时刻、字节/事件、有效位和 e2e；以及最终选中的稳定段。新过程开始后，旧结果的身份和数值仍独立保留。 |
| `phase` | `phase_candidate`、候选计数/时刻、`phase_current`、`phase_start_ticks`、`phase_confirmation_ticks`、证据数/跨度，以及最终阶段结果与波动统计。候选边界与确认时刻要分别读。 |
| `clock` | 实际时钟、发布序号、物理覆盖时间、周期覆盖数、字节、GB/s 和 B/cycle。适合停钟、变频及两种基准的比较。 |
| `hints` / `protocols` | 前者查看独立反压提示的开始、命中、结束、持续时间和计数；后者查看 valid/ready 与 flitv/lcrdv、信用可信度及实际计数。提示不等于性能判定或待发送需求证明。 |

先看有效位，再读数值：`*_valid=0` 时的实数存储值 0 不能作为测量值。`episode_result_result_seq=0`、`phase_result_result_seq=0` 表示尚未发布对应最终记录，不能把这些初始字段当成已经结算的零值。`phase_fit_rms` 是趋势拟合残差；波动标准差来自窗口样本分布，两者不能互相替代。阶段原始字节/持续时间得到的带宽，也要与窗口样本均值区分。

## 完整查看清单：三类主要场景、两种窗口基准

下列各行都是冻结清单中的实际对象。主场景使用 NS 窗口 W=10 ns、S=1 ns，或 cycle 窗口 W=20、S=2 个本地周期；初始首沿为 0.5 ns。两套发布轴初始相差 0.5 ns，**各自按表中的实际窗口核对**。E3 等补充向量有独立配置，见后表。

稳态满窗的共同数值如下；`p10`、`p11` 是自由点，也各自保持 128 GB/s，不应因未归入这些组而停止统计。

| 对象 | 每 10 ns 字节数 | GB/s | 每 20 周期的 B/cycle |
| --- | ---: | ---: | ---: |
| 单点（如 p0） | 1280 | 128 | 64 |
| die0、die1，各自 | 5120 | 512 | 256 |
| all_dmc | 10240 | 1024 | 512 |
| mixed | 7680 | 768 | 384 |

| 场景和精确范围 | 应核对的现象 | NS 对象 | cycle 对象 |
| --- | --- | --- | --- |
| 稳态满窗：NS [92,102)，cycle [92.5,102.5) ns | 满窗且字节/事件完整；点/两 die/全部/mixed 分别为 128/512/1024/768 GB/s。cycle 同时为 64/256/512/384 B/cycle。 | [图](../artifacts/acceptance/steady_ns/overview.png) · [FSDB](../artifacts/acceptance/steady_ns/waves.fsdb) · [overview 视图](../artifacts/acceptance/steady_ns/overview.sav) · [表](../artifacts/acceptance/steady_ns/expected-actual.md) | [图](../artifacts/acceptance/steady_cycle/clock.png) · [FSDB](../artifacts/acceptance/steady_cycle/waves.fsdb) · [clock 视图](../artifacts/acceptance/steady_cycle/clock.sav) · [表](../artifacts/acceptance/steady_cycle/expected-actual.md) |
| 开始和停止：查看 18～72 ns，实际流量 [20,60) ns | 原始 valid 在 20/60 ns 开始/停止。NS 点在 20/21/30/60/61/70 ns 发布值依次为 0/12.8/128/128/115.2/0 GB/s；停止后历史逐步过期。cycle 按自己的周期边界发布。 | [图](../artifacts/acceptance/start_stop_ns/overview.png) · [FSDB](../artifacts/acceptance/start_stop_ns/waves.fsdb) · [overview 视图](../artifacts/acceptance/start_stop_ns/overview.sav) · [表](../artifacts/acceptance/start_stop_ns/expected-actual.md) | [图](../artifacts/acceptance/start_stop_cycle/overview.png) · [FSDB](../artifacts/acceptance/start_stop_cycle/waves.fsdb) · [overview 视图](../artifacts/acceptance/start_stop_cycle/overview.sav) · [表](../artifacts/acceptance/start_stop_cycle/expected-actual.md) |
| 变化与重复阶段：20～153 ns | 原始字节先爬升，经历平台、下降、短间隙和重复平台。候选边界先于连续证据确认；最终稳定段与整个过程分别判断。NS p0 最后稳定段 [136,140) 为 128 GB/s，137 ns 确认；整个过程 CV=43.5681793525% 超过 10%，应 FAIL，稳定段仍 PASS。较早完成的爬坡/下降结果保留。 | [阶段图](../artifacts/acceptance/varying_ns/phase.png) · [最终结果图](../artifacts/acceptance/varying_ns/episode.png) · [FSDB](../artifacts/acceptance/varying_ns/waves.fsdb) · [phase 视图](../artifacts/acceptance/varying_ns/phase.sav) · [episode 视图](../artifacts/acceptance/varying_ns/episode.sav) · [表](../artifacts/acceptance/varying_ns/expected-actual.md) | [阶段图](../artifacts/acceptance/varying_cycle/phase.png) · [FSDB](../artifacts/acceptance/varying_cycle/waves.fsdb) · [phase 视图](../artifacts/acceptance/varying_cycle/phase.sav) · [episode 视图](../artifacts/acceptance/varying_cycle/episode.sav) · [表](../artifacts/acceptance/varying_cycle/expected-actual.md) |

## 独立复位与未知场景

这些扰动分别运行，不能把其中一个文件的现象当成另一个场景的证据。复位或 reset X 区间为 **103.9～104.1 ns**，跨过 104 ns 的实际采样沿；大小/valid 未知也在 104 ns 的记录上观察。先看 104 ns 附近原始采样，再看 105～115 ns 的窗口传播与恢复。

| 独立场景 | 应核对的现象与范围 | NS 对象 | cycle 对象 |
| --- | --- | --- | --- |
| 点自身复位 | p0 epoch 增加并重新预热；组的原历史/过程继续。104 ns 少 p0 一笔；已知成员复位覆盖为 1，本身不会把已知字节/事件判为不完整。NS [95,105) 的 all_dmc 为 10176 B/159 事件；之后恢复。 | [图](../artifacts/acceptance/point_reset_ns/quality.png) · [FSDB](../artifacts/acceptance/point_reset_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/point_reset_ns/quality.sav) · [表](../artifacts/acceptance/point_reset_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/point_reset_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/point_reset_cycle/quality.sav) · [表](../artifacts/acceptance/point_reset_cycle/expected-actual.md) |
| 仅下级组 die0 统计复位 | 只有 die0 epoch/窗口/过程重启；p0、all_dmc、mixed 仍在原 epoch/过程，原始成员数据继续供两个上级使用；无实际点复位覆盖。NS die0 从 104.1 ns 重新计窗，而 all_dmc 的 [95,105) 仍为 10240 B/160 事件。 | [图](../artifacts/acceptance/child_reset_ns/quality.png) · [FSDB](../artifacts/acceptance/child_reset_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/child_reset_ns/quality.sav) · [表](../artifacts/acceptance/child_reset_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/child_reset_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/child_reset_cycle/quality.sav) · [表](../artifacts/acceptance/child_reset_cycle/expected-actual.md) |
| 仅上级组 all_dmc 统计复位 | 只有 all_dmc epoch/预热改变；共享下级、点与 mixed 继续。无实际点复位覆盖。NS all_dmc 从 104.1 ns 重新计窗，die0/mixed 原窗口保持。 | [图](../artifacts/acceptance/upper_reset_ns/quality.png) · [FSDB](../artifacts/acceptance/upper_reset_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/upper_reset_ns/quality.sav) · [表](../artifacts/acceptance/upper_reset_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/upper_reset_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/upper_reset_cycle/quality.sav) · [表](../artifacts/acceptance/upper_reset_cycle/expected-actual.md) |
| 仅传输大小未知 | 104 ns 事件确定，字节未知；NS [95,105) all_dmc 已知小计 10176 B、事件仍 160，full=1、BC=0、EC=1。到 [105,115) 窗口恢复完整；133 ns 看最终结果，旧全程 e2e 仍不可用，后来的完整最终稳定段可独立通过。 | [完整性图](../artifacts/acceptance/size_unknown_ns/quality.png) · [最终结果图](../artifacts/acceptance/size_unknown_ns/episode.png) · [FSDB](../artifacts/acceptance/size_unknown_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/size_unknown_ns/quality.sav) · [episode 视图](../artifacts/acceptance/size_unknown_ns/episode.sav) · [表](../artifacts/acceptance/size_unknown_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/size_unknown_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/size_unknown_cycle/quality.sav) · [episode 视图](../artifacts/acceptance/size_unknown_cycle/episode.sav) · [表](../artifacts/acceptance/size_unknown_cycle/expected-actual.md) |
| 仅 valid 未知 | 104 ns 是否发生事件不可确定；NS [95,105) all_dmc 已知小计 10176 B/159 事件，同时 BC=0、EC=0。其他已知成员继续计数；未知不能当成已知空闲或补一个零事件。 | [图](../artifacts/acceptance/valid_unknown_ns/quality.png) · [FSDB](../artifacts/acceptance/valid_unknown_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/valid_unknown_ns/quality.sav) · [表](../artifacts/acceptance/valid_unknown_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/valid_unknown_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/valid_unknown_cycle/quality.sav) · [表](../artifacts/acceptance/valid_unknown_cycle/expected-actual.md) |
| 仅 reset 未知 | 103.9～104.1 ns 为 X，epoch 保持 0；未知区间已影响 NS [94,104) 完整性，随后未知记录继续影响窗口；无已知复位覆盖。到 [105,115) 恢复窗口质量，不会修复旧过程的缺口。 | [图](../artifacts/acceptance/reset_unknown_ns/quality.png) · [FSDB](../artifacts/acceptance/reset_unknown_ns/waves.fsdb) · [quality 视图](../artifacts/acceptance/reset_unknown_ns/quality.sav) · [表](../artifacts/acceptance/reset_unknown_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/reset_unknown_cycle/waves.fsdb) · [quality 视图](../artifacts/acceptance/reset_unknown_cycle/quality.sav) · [表](../artifacts/acceptance/reset_unknown_cycle/expected-actual.md) |

BC 指 `bytes_complete`，EC 指 `events_complete`。E1 还可以核对 **104 ns 那一条原始记录的增量**，注意它不是 10 ns 窗口总量：

| E1 场景 | die0 字节/事件 | all_dmc 字节/事件 | mixed 字节/事件 | 该条记录的质量 |
| --- | ---: | ---: | ---: | --- |
| 无扰动；或仅 die0/上级统计复位 | 256 / 4 | 512 / 8 | 384 / 6 | 已知且完整；统计复位不删上游原始输入 |
| p0 已知复位 | 192 / 3 | 448 / 7 | 320 / 5 | 已知且完整；有实际成员复位覆盖 |
| p0 大小未知 | 192 / 4 | 448 / 8 | 320 / 6 | 字节为已知小计，BC=0、EC=1 |

## 停钟、变频、协议、提示与过程有效性

有图的条目直接链接原图；没有另拍截图的另一基准，链接已有 FSDB 和保存的视图进行交互式查看，不代表缺少仿真数据。

| 独立场景和精确范围 | 应核对的现象 | NS 对象 | cycle 对象 |
| --- | --- | --- | --- |
| 停钟：末沿 79.5 ns，下一沿 100.5 ns，恢复发布 101 ns | NS 历史随物理时间过期；cycle 发布序号/窗口在停钟时保持旧值。恢复时点窗口 [70.5,101) 跨 30.5 ns、20 周期、1280 B，得到 41.967213… GB/s，同时仍为 64 B/cycle。不存在虚构时钟沿或尾边界。 | [图](../artifacts/acceptance/clock_stop_ns/clock.png) · [FSDB](../artifacts/acceptance/clock_stop_ns/waves.fsdb) · [clock 视图](../artifacts/acceptance/clock_stop_ns/clock.sav) · [表](../artifacts/acceptance/clock_stop_ns/expected-actual.md) | [图](../artifacts/acceptance/clock_stop_cycle/clock.png) · [FSDB](../artifacts/acceptance/clock_stop_cycle/waves.fsdb) · [clock 视图](../artifacts/acceptance/clock_stop_cycle/clock.sav) · [表](../artifacts/acceptance/clock_stop_cycle/expected-actual.md) |
| 变频：末快沿 79.5 ns，首慢沿 80.5 ns；看 90～104 ns | 时钟周期从 0.5 ns 变为 1 ns。完全慢速窗口下点为 64 GB/s、all_dmc 为 512 GB/s；cycle 视图还分别为 64、512 B/cycle，NS 的该字段保持 0。跨频率窗口按真实时间作分母。 | [图](../artifacts/acceptance/frequency_ns/clock.png) · [FSDB](../artifacts/acceptance/frequency_ns/waves.fsdb) · [clock 视图](../artifacts/acceptance/frequency_ns/clock.sav) · [表](../artifacts/acceptance/frequency_ns/expected-actual.md) | [图](../artifacts/acceptance/frequency_cycle/clock.png) · [FSDB](../artifacts/acceptance/frequency_cycle/waves.fsdb) · [clock 视图](../artifacts/acceptance/frequency_cycle/clock.sav) · [表](../artifacts/acceptance/frequency_cycle/expected-actual.md) |
| 独立 ns 反压提示：停钟期间 85～95 ns | p1 live valid=1/ready=0，85 ns 开始、87 ns 达到阈值、95 ns 结束，时长 10 ns；cycle 统计快照仍保持。提示命中/区间计数与性能 PASS/FAIL/WARNING 各自独立，也不证明发送端有未满足需求。 | [FSDB](../artifacts/acceptance/hints_ns/waves.fsdb) · [hints 视图](../artifacts/acceptance/hints_ns/hints.sav) · [表](../artifacts/acceptance/hints_ns/expected-actual.md) | [图](../artifacts/acceptance/hints_cycle/hints.png) · [FSDB](../artifacts/acceptance/hints_cycle/waves.fsdb) · [hints 视图](../artifacts/acceptance/hints_cycle/hints.sav) · [表](../artifacts/acceptance/hints_cycle/expected-actual.md) |
| 三协议辨别：59～66 ns | p1 为 valid/ready：ready=0 时 valid=X 仍能确定无传输，事件完整。p2 为 credit：valid=0、flitv=1、lcrdv=0 仍发生传输；61 ns 信用余额 13 且可信。valid-only 点按自身规则计量，固定/动态字节保持正确。 | [图](../artifacts/acceptance/protocols_ns/protocols.png) · [FSDB](../artifacts/acceptance/protocols_ns/waves.fsdb) · [protocols 视图](../artifacts/acceptance/protocols_ns/protocols.sav) · [表](../artifacts/acceptance/protocols_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/protocols_cycle/waves.fsdb) · [protocols 视图](../artifacts/acceptance/protocols_cycle/protocols.sav) · [表](../artifacts/acceptance/protocols_cycle/expected-actual.md) |
| 零字节过程：20～53 ns | [20,40) 内 40 个零字节事件形成真实过程，52 ns 确认；e2e=0 有效，标准差=0 有效；均值为零使 CV 不可用，原因 ZERO_MEAN。 | [图](../artifacts/acceptance/zero_ns/episode.png) · [FSDB](../artifacts/acceptance/zero_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/zero_ns/episode.sav) · [表](../artifacts/acceptance/zero_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/zero_cycle/waves.fsdb) · [episode 视图](../artifacts/acceptance/zero_cycle/episode.sav) · [表](../artifacts/acceptance/zero_cycle/expected-actual.md) |
| 从无过程：20～53 ns | 一直没有传输事件，没有可结算过程；e2e 配置得到 NO_EPISODE 的 WARNING，不能用存储值 0 代替一次“0 带宽通过”。与上一行并排看事件计数、身份和有效位。 | [图](../artifacts/acceptance/no_episode_ns/episode.png) · [FSDB](../artifacts/acceptance/no_episode_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/no_episode_ns/episode.sav) · [表](../artifacts/acceptance/no_episode_ns/expected-actual.md) | [FSDB](../artifacts/acceptance/no_episode_cycle/waves.fsdb) · [episode 视图](../artifacts/acceptance/no_episode_cycle/episode.sav) · [表](../artifacts/acceptance/no_episode_cycle/expected-actual.md) |
| 观测截断：109.5～110.000001 ns | 109.5 ns 是末次采样沿，仿真在 110.000001 ns 结束，未观察到下一沿；尾边界/e2e 不可用，最终状态 TRUNCATED（数值 4）。以前的平台不能替代有效的最终稳定段代表，存储值 0 不能通过性能判定。 | [FSDB](../artifacts/acceptance/truncated_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/truncated_ns/episode.sav) · [表](../artifacts/acceptance/truncated_ns/expected-actual.md) | [图](../artifacts/acceptance/truncated_cycle/episode.png) · [FSDB](../artifacts/acceptance/truncated_cycle/waves.fsdb) · [episode 视图](../artifacts/acceptance/truncated_cycle/episode.sav) · [表](../artifacts/acceptance/truncated_cycle/expected-actual.md) |

## E2～E5：边界、延迟确认、性能容差和精确 ID

这些是各自合法的独立采样场景，不能把 E3 的两种时间线拼成同一个过程。E1 对应上面的稳态、复位与大小未知增量表。

| 对象和精确范围 | 应核对的数值与含义 | 冻结对象链接 |
| --- | --- | --- |
| E2：物理时刻 11/12/13/21/23 ns（原向量相对时刻 10/11/12/20/22） | NS 窗口字节依次 320/384/384/256/256 B，即 32/38.4/38.4/25.6/25.6 GB/s。11 ns 发布的 [1,11) 不计入 11 ns 新到的 128 B。cycle 按自身发布区间核对，勿套用相同横轴标签。 | NS：[图](../artifacts/acceptance/e2_ns/overview.png) · [FSDB](../artifacts/acceptance/e2_ns/waves.fsdb) · [overview 视图](../artifacts/acceptance/e2_ns/overview.sav) · [表](../artifacts/acceptance/e2_ns/expected-actual.md)；cycle：[FSDB](../artifacts/acceptance/e2_cycle/waves.fsdb) · [overview 视图](../artifacts/acceptance/e2_cycle/overview.sav) · [表](../artifacts/acceptance/e2_cycle/expected-actual.md) |
| 单笔边界补充：20 ns 的 64 B，查看 20/21/30/31 ns | NS [10,20) 为 0，[11,21) 与 [20,30) 各 64 B，[21,31) 归零；因此能同时核对右端排除、左端包含和过期。单笔过程尾为 20.5 ns，e2e=64/0.5=128 GB/s；这与窗口中的 6.4 GB/s 含义不同。 | NS：[图](../artifacts/acceptance/isolated_ns/overview.png) · [FSDB](../artifacts/acceptance/isolated_ns/waves.fsdb) · [overview 视图](../artifacts/acceptance/isolated_ns/overview.sav) · [表](../artifacts/acceptance/isolated_ns/expected-actual.md)；cycle：[FSDB](../artifacts/acceptance/isolated_cycle/waves.fsdb) · [overview 视图](../artifacts/acceptance/isolated_cycle/overview.sav) · [表](../artifacts/acceptance/isolated_cycle/expected-actual.md) |
| E3 过程边界：80～132.000001 ns，Q=30 ns | 旧过程 first=80、last=100、tail=102，区间 [80,102) 共 256 B/3 事件/22 ns，e2e=11.6363636364 GB/s，在 132 ns 确认。132 ns 新传输先与旧结果分离：活动过程已是新过程、当前 128 B，旧不可变结果仍为 256 B。p0、die0、all_dmc、mixed 的表和运行时标记共同核对先结算旧过程再接收新过程；新过程 [132,134) 在 164 ns 确认。 | [图](../artifacts/acceptance/e3_boundary_ns/episode.png) · [FSDB](../artifacts/acceptance/e3_boundary_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/e3_boundary_ns/episode.sav) · [表](../artifacts/acceptance/e3_boundary_ns/expected-actual.md) |
| E3 延迟阶段确认：候选 120、确认 150、最终端点 136 ns；W=100/S=10 ns | 95 ns 传 640 B，135 ns 发生零字节事件；过程 [95,136) 在 196 ns 完成。阶段候选从 120 ns 起，150 ns 才确认；最终阶段裁剪为 [120,136)，持续 16 ns，区间原始带宽 0，而两次合格窗口的均值为 6.4 GB/s。150 ns 图里最终结果序号仍为 0 是未结算；196.000001 ns 最终图再读有效结果。 | [候选/确认图](../artifacts/acceptance/e3_delayed_ns/phase.png) · [最终结果图](../artifacts/acceptance/e3_delayed_ns/episode.png) · [FSDB](../artifacts/acceptance/e3_delayed_ns/waves.fsdb) · [phase 视图](../artifacts/acceptance/e3_delayed_ns/phase.sav) · [episode 视图](../artifacts/acceptance/e3_delayed_ns/episode.sav) · [表](../artifacts/acceptance/e3_delayed_ns/expected-actual.md) |
| E4 等于允许下限：完整过程 [1,101) ns，113 ns 确认 | 原目标下限 160 GB/s、相对容差 5%，有效下限 152。实际 15200 B/100 ns=152 GB/s，应 PASS。 | [图](../artifacts/acceptance/e4_boundary_ns/episode.png) · [FSDB](../artifacts/acceptance/e4_boundary_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/e4_boundary_ns/episode.sav) · [表](../artifacts/acceptance/e4_boundary_ns/expected-actual.md) |
| E4 略低于允许下限：同一独立时间范围 | 实际 15199 B/100 ns=151.99 GB/s，低于 152，应 FAIL，仿真继续。读完整科学计数或整数，不能将显示四舍五入成 152 后判通过。 | [图](../artifacts/acceptance/e4_below_ns/episode.png) · [FSDB](../artifacts/acceptance/e4_below_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/e4_below_ns/episode.sav) · [表](../artifacts/acceptance/e4_below_ns/expected-actual.md) |
| E4 明显低于允许下限：同一独立时间范围 | 实际 12800 B/100 ns=128 GB/s，应 FAIL，仿真继续；不要把某个滑窗值当成全程平均值。 | [图](../artifacts/acceptance/e4_low_ns/episode.png) · [FSDB](../artifacts/acceptance/e4_low_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/e4_low_ns/episode.sav) · [表](../artifacts/acceptance/e4_low_ns/expected-actual.md) |
| E5 精确 ID 与各自目标：20～153 ns | 注册点 `tb.top.master0.bw` 只检查 `e2e_bw/steady_bw/ramp_time/steady_cv`；组 `memory_all` 只检查 `steady_bw/episode_cv`。不向其他点/组继承，也不按成员数缩放目标。最后稳定段 [136,140) 点/组为 128/1024 GB/s；组全程 CV=38.3623243353%，超过 10% 应 FAIL。 | [图](../artifacts/acceptance/e5_ns/episode.png) · [FSDB](../artifacts/acceptance/e5_ns/waves.fsdb) · [episode 视图](../artifacts/acceptance/e5_ns/episode.sav) · [表](../artifacts/acceptance/e5_ns/expected-actual.md) · [原配置](../artifacts/acceptance/e5_ns/expect.cfg) |

## 怎样理解预期的 FAIL 和 WARNING

每个数值表末尾都列出真实 `BW_CHECK` 和最终 `BW_SUMMARY`，可以连同该目录的 `expect.cfg` 一起看：

| 输出 | 本套证据中的含义与例子 |
| --- | --- |
| `PASS` | 指定指标有有效证据，并满足该对象显式配置的目标。例如 E4 实际 152 等于允许下限。 |
| `FAIL` | 指标有效但未达到目标。例如 E4 的 151.99/128，或重复阶段中全程 CV 超过 10%。这些是故意设置的性能失败，监测器应继续仿真并只结算一次；它们不会让正确的验收测试变成仿真故障。稳态 p0 的目标也故意设成 160、容差 5%，实际 128 的 FAIL 是预期。 |
| `WARNING` | 配置要求检查，但证据不足以比较。例如 `BYTES_INCOMPLETE`、`RESET_INTERRUPTED`、`NO_EPISODE`、`OBSERVATION_TRUNCATED`，或零均值下 CV 的 `ZERO_MEAN`。应核对原因和有效位，不能据此填一个 0 再作 PASS/FAIL。 |

一个场景可以同时有 PASS、FAIL、WARNING，汇总按 FAIL 优先，其次 WARNING，再是 PASS。预期计数就在各表中。这里所说的证据 WARNING 是性能检查结果；`BW_CFG WARNING`（配置解析问题）或核心 `$fatal` 不属于这些预期现象。表中后续窗口和原始运行日志里的 `TB_PASS` 共同说明仿真在性能 FAIL/WARNING 后仍继续。需要追查时，各目录 `trace.tar.gz` 保存原始运行日志与 CSV；仅查看现有证据不需要重跑。

## 可选：在 Verdi 中打开原始 FSDB

截图足以开始查看。若要移动光标、展开路径或看另一基准没有另拍的画面，需要本机具备可用的 Verdi/nWave、许可和图形显示环境。**这些命令只打开已有 FSDB，不重新运行仿真。** 在仓库根目录执行，例如：

```bash
./artifacts/acceptance/steady_ns/open.sh overview
```

每条命令打开一个窗口；结束该次查看后再选择下一对象。例如：

```bash
./artifacts/acceptance/steady_cycle/open.sh clock
./artifacts/acceptance/point_reset_cycle/open.sh quality
./artifacts/acceptance/varying_ns/open.sh phase
./artifacts/acceptance/e3_delayed_ns/open.sh episode
```

脚本会切到自己的目录，加载同目录 `waves.fsdb` 和相应 `.sav`，所以从其他工作目录调用也可。视图名用上面索引中已经存在的 `overview/quality/episode/phase/clock/hints/protocols`；并非每个目录都有全部视图。若直接用命令行打开，等价示例为：

```bash
cd artifacts/acceptance/steady_ns
BW_VIEW=overview verdi -nWave -ssf waves.fsdb -play open-view.tcl
```

先保留保存好的布局、时间范围和光标，核对表中那一个窗口；之后再缩放到待查看区间、拖动黄色光标。中间值列读取当前光标处的值。需要核对“发布先后”时，放大相邻发布点，结合结果序号和不可变记录身份查看；同一时间内的细粒度先后还应参照 E3 表所指原始日志标记，单张静态截图不能显示全部调度次序。

## 实际查看后怎样记录

请按自己真正看过的对象记录，可分批反馈，也可以明确标出尚未查看的行。无需提供真实姓名，稳定的评审别名即可。建议复制下面模板，填写实际日期、范围与结论；发现差异时给出具体文件、信号、光标时刻、预期/实见值，保留差异，不因自动化通过而略去。

```text
评审人/别名：
实际查看日期（含时区）：
实际查看的资产提交/交接链接：59fc046a154945b6a6ae60220e663f7d5ee12bb6（请确认本次确实打开此数据版本）
冻结运行源码：cd07c77fcb706022069a9496bcf72d4354c1d2f8
资产指纹：863af4f477409bf3e36af90f8fd7b2ffc7d008e2281f83fef759607482eeadee

已看对象与区间（逐项写 NS/cycle、文件/视图、时间范围）：
1.
2.

核对方法：截图 / 原始 FSDB+Verdi / 预期实际值表（按实际使用方式保留）
结论：所列范围一致 / 发现以下差异 / 尚无法判断
差异：对象、时间、信号或指标、预期值、实见值、附件（如有）
未查看或待补查的清单项：
```

仅写“告诉我怎么看”或只确认已收到文件，不会被登记为通过；只有真实查看后的明确结论才能更新人工记录。部分查看只覆盖写明的对象和区间，完整 T6 仍需覆盖这份冻结清单。此次查看不签认未来资产、其他配置或源版本、规模测试、工具探测截图、HTML 示意图；代理图片检查也始终单列，不替代人工结论。
