# ns 与本地 clk 滑窗及多观测点聚合的时间语义

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [ns 与本地 clk 滑窗及多观测点聚合的时间语义](https://github.com/MakeReadUnique/bw_mon/issues/3) 为准。

Type: grilling
Labels: wayfinder:grilling
Status: open
Assignee: none
Parent: ../map.md
Blocked by: 04

## Question

前置证据：[查证小时间窗、bind 与 Verdi 观测的技术约束](04-sv-observability-research.md)。

如何提供选择 ns 或本地 clk 的窗口配置，支持例如 10 ns 的小滑窗，并对不同观测点的汇总给出一致、可解释的时间语义？

已确定：两种窗口基准都必须支持；需要多 master 与多 memory 的分别聚合。

需要决定：窗口宽度与更新步长如何配置；窗口基准与带宽输出单位如何区分；窗口左右边界、预热、无事件时的过期推进；精确滑窗与分桶近似的取舍；cycles 模式在异步时钟组中的适用条件；共同时间区间、复位/停钟/变频和同一时刻事件顺序如何处理。不能默认为不同端口的 N-cycle 统计覆盖相同物理时间。不同观察层级的重复流量也不能被当作同一总带宽相加。
