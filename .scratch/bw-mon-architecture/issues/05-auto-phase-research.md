# 查证自动流量阶段识别与短滑窗统计的适用方法

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [查证自动流量阶段识别与短滑窗统计的适用方法](https://github.com/MakeReadUnique/bw_mon/issues/6) 为准。

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: MakeReadUnique
Parent: ../map.md
Blocked by: none
Research branch: research/auto-phase-statistics
Research asset: docs/research/auto-phase-statistics.md

## Question

哪些有一手资料依据的在线统计方法适合在纯 SystemVerilog 仿真 monitor 中识别流量的爬坡、稳定、下降与静默结束？哪些误判和不可辨识条件必须暴露给使用者？

比较少量可实现的候选方法，关注短窗口的量化噪声、滑窗重叠相关性、低均值波动量的退化、无预先已知目标带宽的稳定判定、斜率/变点、最少样本与迟滞，以及检测延迟与回溯估计边界。阶段必须自动识别；允许可配置静默确认，并按过程报告；不得假装能够从无传输必然推断发送需求或故障原因。

产出方法的证据与取舍，不替用户选择算法或默认数值，不实现 monitor 或原型。

## Comments

已认领并委派研究；结果存放于独立 research 分支，不合并、不创建 PR。研究完成后在本 ticket 记录答案与文档链接。

## Answer

研究完成，依据包括 NIST 官方统计资料、ADWIN 作者论文和 Sandia 统计矩资料。完整证据与推导见 [自动流量阶段识别与短滑窗统计研究](https://github.com/MakeReadUnique/bw_mon/blob/e1d88b853022eb228f03e9c6a735e1e3d689839c/docs/research/auto-phase-statistics.md)。

- 线性拟合、EWMA、CUSUM 和 ADWIN 可提供趋势/变点的不同证据，但不能代替项目定义“稳定段”；本文没有选定算法或默认阈值。
- 小窗口存在计数量化；矩形滑窗本身会把瞬时速率跃迁平滑成表观爬坡。显示尺度与分析尺度应进入明确的设计比较。
- 重叠窗口存在相关性，不能把连续窗口数直接解释成独立样本数；均值近零时 CV 也需要有效条件或替代量。
- 确认时刻与估计边界、原始字节累计与滑窗速率、阶段识别与性能验收应区分。静默等待、单事件持续时间和截断过程仍由后续决策确定。
- 仅从同一外部信号轨迹不能恢复唯一内部原因，自动分析需要保留未知或证据不足状态。

资产已提交并推送到 `research/auto-phase-statistics`，commit `e1d88b853022eb228f03e9c6a735e1e3d689839c`；没有 PR 或合并。未执行监测器实现、原型或仿真，结论为文献研究与显式推导。
