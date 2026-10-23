# bw_mon

用于 SoC 仿真验证的通用带宽监测器（bandwidth monitor）。目标是提供可复用的 SystemVerilog `module`，观察 master、memory 接口与 NoC 链路，统计带宽并辅助定位传输间隙和长时间反压。

项目处于架构规划阶段，当前包含需求、决策地图和前期调研，尚未包含监测器实现。

## 已确认需求

- **纯仿真模块**：采用 SystemVerilog `module`，不依赖 UVM，不要求可综合。
- **三类接口**：支持 valid、valid-ready、flitv/lcrdv；在传输计数之外保留诊断需要的接口信息，不额外依赖 pending 等需求提示。
- **可配置滑窗**：窗口基准可选 ns 或本地 clk 周期数，需覆盖例如 10 ns 的小窗口。
- **单点与聚合**：支持多个 master 的汇总、多个 memory 接口的汇总，以及通过 `bind` 接入的 NoC 局部观测。
- **自动阶段统计**：由 monitor 分析爬坡、稳定和下降阶段，不依赖 testbench 阶段标记；可用配置的静默时长结束一次流量过程并分别报告。
- **全程平均带宽**：e2e 指完整流量过程的累计传输字节数除以持续时间，包含其中的稳定段。
- **可观测与可检查**：统计量可在 Verdi 波形中查看，支持稳定段带宽、爬坡/下降时间、波动及 PASS/FAIL 日志；证据不足的诊断原因允许为未知。

## 架构规划

使用 wayfinder 的 GitHub Issues 决策地图逐项明确架构，当前不开展 RTL 实现。本地 `.scratch/bw-mon-architecture/` 仅保留迁移前的历史归档。

- [通用 SoC 带宽监测器架构地图](https://github.com/MakeReadUnique/bw_mon/issues/1)
- [领域术语](GLOSSARY.md)

模块接口、滑窗与异步聚合语义、自动识别算法、检查规则仍待决策；已确认需求不代表已实现功能。

## 前期调研

[EDA 验证用 bandwidth monitor 开源调研](docs/bandwidth-monitor-research.md) 汇总了已有实现、统计口径差异和可参考的设计方式。
