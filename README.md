# bw_mon

用于 SoC 仿真验证的通用带宽监测器（bandwidth monitor）。目标是提供可复用的 SystemVerilog `module`，观察 master、memory 接口与 NoC 链路，统计带宽并辅助定位传输间隙和长时间反压。

仓库包含已确认架构及正在实现的纯仿真 SystemVerilog 监测器。当前可运行路径支持类型 bind、显式注册启动、valid-only 固定逐传输计量和精确 ns 滑动窗口。其余能力按[实现规格](https://github.com/MakeReadUnique/bw_mon/issues/13)的关联 ticket 交付；规划需求不表示已通过全部验收。

运行 `make test`，使用 VCS 编译执行组件与公开入口测试。配置、公开字段、错误和独立预期见[集成说明](docs/bw-mon-api.md)。

## 已确认需求

- **纯仿真模块**：采用 SystemVerilog `module`，不依赖 UVM，不要求可综合。
- **三类接口**：支持 valid、valid-ready、flitv/lcrdv；在传输计数之外保留诊断需要的接口信息，不额外依赖 pending 等需求提示。
- **可配置滑窗**：窗口基准可选 ns 或本地 clk 周期数，需覆盖例如 10 ns 的小窗口。
- **单点与聚合**：支持多个 master 的汇总、多个 memory 接口的汇总，以及通过 `bind` 接入的 NoC 局部观测。
- **自动阶段统计**：由 monitor 分析爬坡、稳定和下降阶段，不依赖 testbench 阶段标记；可用配置的静默时长结束一次流量过程并分别报告。
- **全程平均带宽**：e2e 指完整流量过程的累计传输字节数除以持续时间，包含其中的稳定段。
- **可观测与可检查**：统计量可在 Verdi 波形中查看，支持稳定段带宽、爬坡/下降时间、波动及 PASS/FAIL 日志；证据不足的诊断原因允许为未知。

## 架构规划

使用 wayfinder 的 GitHub Issues 决策地图记录已确认架构。本地 `.scratch/bw-mon-architecture/` 仅保留迁移前的历史归档。

- [通用 SoC 带宽监测器架构地图](https://github.com/MakeReadUnique/bw_mon/issues/1)
- [领域术语](GLOSSARY.md)

最终架构已经确认；实现与验收状态由[实现规格及其 tickets](https://github.com/MakeReadUnique/bw_mon/issues/13)跟踪。跨异步时钟聚合不在首版范围内。

## 前期调研

[EDA 验证用 bandwidth monitor 开源调研](docs/bandwidth-monitor-research.md) 汇总了已有实现、统计口径差异和可参考的设计方式。
