# 通用 SoC 带宽监测器架构地图

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [通用 SoC 带宽监测器架构地图](https://github.com/MakeReadUnique/bw_mon/issues/1) 为准。

Label: wayfinder:map

## Destination

明确一个用于 SoC 仿真验证的通用 SystemVerilog 带宽监测器的架构：形成足以指导后续实现的模块职责、接口契约、滑窗与聚合语义、自动阶段统计及检查规则。
本地图完成的标志是关键架构选择均已明确；本轮不实现监测器。

## Notes

- 采用本地 Markdown tracker，遵循 `/home/eda/.agents/skills/setup-matt-pocock-skills/issue-tracker-local.md`。子 ticket 位于 `issues/`；依赖使用 `Blocked by`，frontier 为 open、未认领且依赖均已 resolved 的子 ticket。
- 每次会话使用 wayfinder、grilling、domain-modeling；技术研究使用 research。用户参与的选择必须经真实交流，不以研究建议代替用户决定。
- 已确定的产品范围：纯仿真的 SystemVerilog module，无 UVM；多 master、多 memory 汇总；NoC 可 bind 的局部观测；Verdi 波形；滑窗；自动阶段分析与 PASS/FAIL 日志。
- 用户在首轮纠正和补充的具体约束记录于相应 ticket 的问题上下文；术语见 [bw_mon 领域术语](../../GLOSSARY.md)。
- 研究使用独立 `research/` 分支与 worktree，推送研究文档，不开 PR、不合并。研究结论可关闭 research ticket，但不能自动关闭依赖它的架构选择。
- 建图阶段不解决 HITL ticket；后续每次至多解决一个非 research ticket。

## Decisions so far

<!-- 只索引已解决 ticket；答案保存在各自 ticket。 -->

- [查证小时间窗、bind 与 Verdi 观测的技术约束](issues/04-sv-observability-research.md)：已查明时间与调度、bind 目标及 FSDB 类型约束；实际编译与波形仍待验证。
- [查证自动流量阶段识别与短滑窗统计的适用方法](issues/05-auto-phase-research.md)：已有候选统计方法与适用性证据；窗口平滑、相关性和边界估计需要明确处理，算法仍待选择。

## Not yet specified

- 等自动阶段方法和统计量确定后，再梳理多平台段、重复突发、时钟停止与复位交错等组合场景对状态和检查有效性的影响。
- 等窗口与 bind 接入方案确定后，再具体化大量观测点下的资源预算、配置组织方式及可接受的统计误差。
- 等模块契约确定后，再整理架构验收示例与实现交接材料。

## Out of scope

- 本轮不写 RTL、完整 testbench 或测试基础设施，不开展监测器实现。
- 可综合监控 IP、UVM 封装、软件寄存器配置接口。
- 逐笔端到端事务匹配、丢包验证和事务延迟分析；本项目的 e2e 指流量过程的全程平均带宽。
- 同时维护有效载荷与链路开销两套带宽口径；用户要求统一接口计量口径，具体字节计量由接口契约决定。
- 增加 pending 等外部需求提示信号；用户要求仅使用三类接口本身的信号，接受部分原因不可判定。
