# 三类接口的传输事件、字节计量与诊断契约

> **已迁移归档**：本文件保留迁移前的历史快照，不再作为活动 tracker。
> 后续问题、认领、依赖和结论请以 [三类接口的传输事件、字节计量与诊断契约](https://github.com/MakeReadUnique/bw_mon/issues/2) 为准。

Type: grilling
Labels: wayfinder:grilling
Status: open
Assignee: none
Parent: ../map.md
Blocked by: none

## Question

如何为 valid、valid-ready、flitv/lcrdv 三类接口定义统一的传输与诊断观测契约，使窗口计数可复用，同时保留断流和长时间反压的分析能力？

已确定：不区分有效载荷与链路开销两套口径；不增加 pending 等外部需求提示，原因不可确定时允许报告未知。不能仅把所有接口压成一个 valid 后丢弃原始信息。

需要决定：每次传输的字节量从固定宽度还是可配置计量取得；保留哪些原始状态和诊断能力标志；valid-only 的可观测范围；credit 接口所需的初始状态、发送/归还含义和同拍处理契约。讨论中应区分“观测到没有传输”“观测到握手反压”“可证明 credit 不足”和“确定有待发送数据却无法发送”。
