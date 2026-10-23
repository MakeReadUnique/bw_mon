# 模块职责、bind 接入与统计数据通路

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [模块职责、bind 接入与统计数据通路](https://github.com/MakeReadUnique/bw_mon/issues/7) 为准。

Type: grilling
Labels: wayfinder:grilling
Status: open
Assignee: none
Parent: ../map.md
Blocked by: 01, 02, 03, 04

## Question

前置决策与证据：[三类接口的传输事件、字节计量与诊断契约](01-interface-contract.md)、[ns 与本地 clk 滑窗及多观测点聚合的时间语义](02-window-aggregation.md)、[自动阶段识别与全程平均带宽的边界](03-phase-episode.md)、[查证小时间窗、bind 与 Verdi 观测的技术约束](04-sv-observability-research.md)。

在传输事件、窗口和自动阶段语义明确后，如何划分可复用的 SystemVerilog module 职责和接口，使局部 NoC bind、单点与多端口汇总、诊断及 Verdi 观测可以组合？

需要决定：原始接口观测如何分别流向字节计量和诊断；局部状态与分组数据如何连接；哪些职责合并、哪些独立；配置与层次命名、计数有效性、溢出和统计状态如何对外可见。应给出足以评审的框架，但不实现 RTL。
