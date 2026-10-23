# CHI Size 字段与单次传输字节计量

研究日期：2026-10-23。研究票：[查证 CHI Size 字段与单次传输字节计量的关系](https://github.com/MakeReadUnique/bw_mon/issues/9)。服务于 [三类接口的传输事件、字节计量与诊断契约](https://github.com/MakeReadUnique/bw_mon/issues/2)，不替代用户的计量选择。

版本锁定：[Arm AMBA CHI Architecture Specification，ARM IHI 0050 Issue H，2025-09-17](https://developer.arm.com/documentation/ihi0050/h/)。以下页码为 PDF 印刷页码。

## 官方事实

- Size describes transaction-associated data. Codes 0–6 mean 1–64 bytes in powers of two; 7 is reserved. It appears in REQ; DAT has no Size field. [B13.9.1, B13.9.4, B13.10.21，pp471、475–476、488](https://documentation-service.arm.com/static/69df590612ab715369d31af4#page=488)。
- A data message can span packets. Data_Width limits each packet's capacity; supported widths are 128/256/512 bits. Multi-request data messages have an effective 64-byte Size. [B2.9.1, B2.9.4，pp162、164](https://documentation-service.arm.com/static/69df590612ab715369d31af4#page=164)。
- BE marks valid write/snoop bytes, but is inapplicable for CompData/DataSepResp. Address and memory attributes also affect accessed bytes. [B2.9.2–B2.9.3，pp162–164](https://documentation-service.arm.com/static/69df590612ab715369d31af4#page=163)。
- Without Resource Planes, each transmitted flit spends one L-credit; each asserted LCRDV cycle grants one. Received credits cannot fund same-cycle sends. [B14.2.1.1，pp518–519](https://documentation-service.arm.com/static/69df590612ab715369d31af4#page=518)。
- At reset exit, credits reside at the receiver. LCrdReturn flits use Opcode=0 and TxnID=0; other fields are unconstrained. [B14.5.1、B13.11，pp524、515](https://documentation-service.arm.com/static/69df590612ab715369d31af4#page=524)。

## 对本项目的推论和接入建议

以下为研究建议，尚未成为架构决策：

- 保留用户要求的固定字节量和动态 size 两种模式；动态输入先明确计量层级及编码，避免将编码值直接当字节数。
- 若一个 64 B 数据消息通过两次 32 B 传输发送，逐事件各计 32 B，总计 64 B；逐事件各计事务长度 64 B 则会得到 128 B。这是同一流量计量层级混用造成的多计示例。
- REQ 事件按请求 Size 加权，表达请求量；DAT 事件表达数据传送时序。两种观察不能自然视为同一个完成吞吐口径，也不能直接相加。是否需要前者，由用户明确。
- 逐传输动态入口宜提供“本次传输的计量字节数”，或由接入层将字段解码成该量；通用计数部分无需假定信号叫 size 就有某种固定语义。
- 若选取 BE 计数，应先限定适用操作；不能把全部读响应的 BE 当有效掩码。对 LCrdReturn 等无数据操作，也需明确计量规则。
- 对从复位开始完整观察的普通 CHI，信用账本可从发送端可用信用 0 开始。中途接入若无可信快照，应将信用不足诊断标为未知；信用不确定不影响已观测传输事件本身。

## 限制与复核

本研究没有检查用户实际 DUT 的 CHI 版本、通道、Opcode 组合、字段提取、Size 信号是否已被预先转换，亦未验证 RTL 或波形。Resource Planes、多请求和数据省略功能只提示适用范围，不给出完整支持方案。是否接收原始协议编码、如何处理不适用字段，以及统计请求量还是每次实际传送量，仍由当前决策票与用户讨论。

旧静态 PDF 地址已迁移。本次从 [官方文档 API](https://documentation-service.arm.com/documentation/ihi0050/h) 的 resources 链接取得当前 PDF，并下载、文本核对及查看相关表格页面；没有依赖第三方转述或镜像。研究不合并到主分支。
