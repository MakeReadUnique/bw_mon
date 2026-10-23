# 阶段统计、波动指标及 PASS/FAIL 检查规则

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [阶段统计、波动指标及 PASS/FAIL 检查规则](https://github.com/MakeReadUnique/bw_mon/issues/8) 为准。

Type: grilling
Labels: wayfinder:grilling
Status: open
Assignee: none
Parent: ../map.md
Blocked by: 03, 06

## Question

前置决策：[自动阶段识别与全程平均带宽的边界](03-phase-episode.md)、[模块职责、bind 接入与统计数据通路](06-module-bind-design.md)。

稳定段带宽、爬坡时间、下降时间、总体波动和 e2e 应输出哪些明确统计量，如何按观测点、聚合组与流量过程配置规则并生成可解释的 PASS/FAIL 日志？

需要决定：统计量的区间、单位和有效性；可配置目标与容差；阶段未出现、样本不足、零流量、观察截断和异常状态如何影响结果；规则何时结算、如何汇总与定位失败。应区分充分观察得到的零带宽与尚无有效观察数据，不把阶段识别条件直接当作性能验收条件。
