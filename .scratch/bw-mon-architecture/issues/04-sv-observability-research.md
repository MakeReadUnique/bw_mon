# 查证小时间窗、bind 与 Verdi 观测的技术约束

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [查证小时间窗、bind 与 Verdi 观测的技术约束](https://github.com/MakeReadUnique/bw_mon/issues/5) 为准。

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: MakeReadUnique
Parent: ../map.md
Blocked by: none
Research branch: research/sv-monitor-observability
Research asset: docs/research/sv-monitor-observability.md

## Question

在纯仿真 SystemVerilog module 中实现 ns/cycle 可切换滑窗、NoC bind 观测和 Verdi 可见统计信号，需要哪些可确认的语言与工具契约？

查证 timeunit/timeprecision、时间换算、无传输时窗口过期、同一仿真时刻采样/聚合次序、bind 作用域和层次可观测性，以及整数/定点/real 等统计量的转储可见性。区分语言保证、工具文档与尚未实测的假设。

本机可发现 VCS 与 Verdi W-2024.09-SP1；安装路径不代表许可证或可执行仿真已验证。研究优先一手资料，不复制商业手册大段内容，不把未经实验验证的 GUI 行为宣称为已验证。

## Comments

已认领并委派研究；结果存放于独立 research 分支，不合并、不创建 PR。研究完成后在本 ticket 记录答案与文档链接。

## Answer

研究完成，依据包括 IEEE 1800-2023 与本机 Synopsys W-2024.09-SP1 官方文档。完整证据与候选方案见 [小时间窗、bind 与 Verdi 观测的技术约束](https://github.com/MakeReadUnique/bw_mon/blob/e063471d09a568224a9ab883e31e5700ee748862/docs/research/sv-monitor-observability.md)。

- 10 ns 窗口具有语言表达基础；时间单位、精度、窗口宽度、更新步长和协议采样时刻必须分别约定，跨 module 时间戳须使用统一单位。
- ns 滑窗需要在无新传输时推进过期，cycle 模式则须明确停钟语义；异步端口的 N-cycle 窗口不能默认直接相加。
- 采样与聚合需要确定的调度契约，不能依靠多个过程的偶然执行顺序或简单 `#0`。
- module monitor 可以绑定 NoC 所属 module/实例；SV interface 作为 bind 目标时有不同的标准限制，接入设计必须区分。
- 本机 Verdi FSDB 手册列出 longint、enum、real、realtime 等可转储类型；实际可见性还取决于编译与 dump 范围和选项。

资产已提交并推送到 `research/sv-monitor-observability`，commit `e063471d09a568224a9ab883e31e5700ee748862`；没有 PR 或合并。未运行仿真、生成 FSDB、验证 GUI 或检查许可证。语言与文档证据已经具备，实际工具验证留待后续工作。
