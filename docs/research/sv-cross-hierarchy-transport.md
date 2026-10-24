# SystemVerilog 跨层次观测数据通信

研究日期：2026-10-24。服务于[模块职责、bind 接入与统计数据通路](https://github.com/MakeReadUnique/bw_mon/issues/7)。本文核对语言与本机官方文档，不批准架构；没有编写、编译或仿真具体通信代码，没有验证 VCS/Verdi 行为。

## 语言事实

下列条款均指 [IEEE 1800-2023](https://standards.ieee.org/ieee/1800/7743/)；正文通过[公开标准镜像](https://iccircle.com/static/upload/img20240319175450.pdf)核对，不在仓库分发标准副本。

| 机制 | 已确认的语言契约 |
|---|---|
| package 共享数据与函数 | 多个 module 可用 import 或 `pkg::` 共享变量、类型及子程序；package 须先编译，其内部不能通过层次路径引用外部 DUT。无需 class 或 UVM。见 §26.2–26.3。 |
| function/task | 普通 function 不得等待或直接调用 task；mailbox `put/get/peek` 是 task，`try_put/try_get/try_peek` 是 function。package 不提供独立运行的普通 `initial/always`。见 §13.4、§15.4、§26.2。 |
| typed mailbox | 参数类型提供编译期类型检查；FIFO 保留到达顺序，不确定生产者的到达次序。`get` 移除一条，`peek` 保留队首；`num` 只是瞬时数量。见 §15.4.2–15.4.9。 |
| event | `@event` 可错过先发生的触发；`triggered` 仅保留当前时间步状态，不是通知计数器；`->>` 调度至 NBA。见 §15.5.1–15.5.3。 |
| class 单例 | class 句柄默认为 null，`new` 才创建对象；static 属性由同类型对象共享。共享句柄和创建策略仍需显式定义。见 §8.9–8.12。 |
| 初始化与调度 | package 声明初始化先于 `initial/always`；独立 Active 过程顺序不确定，`#0` 进入 Inactive。见 §26.2、§4.4。 |

## 本机工具文档

一手来源为 Synopsys VCS W-2024.09-SP1 的 `doc/UserGuide/html/vcs_user_guide/using_systemverilog/systemverilog_constructs.html`：

- **SystemVerilog Bounded Queues**：满 queue 的 `push_back()` 不加入新项，`push_front()` 可挤掉尾项；它不具有 bounded mailbox 的阻塞契约。
- **Support for Inclusion of Dynamic Types in Sensitivity List**：默认忽略隐式敏感表中的动态类型并给出 IDTS 警告；`-ntb_opts sensitive_dyn` 的支持有限，unpacked struct 元素仍有限制。
- **wait() Statement with a Static Class Member Variable**：列明对等待 class static 变量条件的支持。

本机 `vcs_ntb_lang_rfm/concurrency_control/mailboxes.html` 属于 OpenVera 文档，不作为 SV typed mailbox 的证据。本次没有复制商业手册正文，也没有将文档支持宣称为实测通过。

## 对本项目的技术推论，待架构讨论

以下是根据上述事实作出的工程推论：

- **package 函数加按 source 分开的存储**有语言基础，可让 bound module 主动提交数据，统计仍由 module 执行。package 不能自行沿外部层次发现观测点；成员标识、注册、锁定和查询规则需要额外契约。
- **共享 mailbox/queue**可传递记录，但空队列不能证明所有 source 已完成本沿提交。多个消费者竞争 `get()` 会分走记录；`peek()` 虽可唤醒多个等待者，也没有逐订阅者游标或确认，因此不自动构成可靠广播。
- **package 中持有通信 class 单例**是另一种封装；它不必依赖 UVM，但不会自行获得屏障或重置语义。全局存储及共享句柄不会随某个 monitor 的局部复位自动清理，需要显式隔离不同组、source 与观测世代。
- **确定性原子提交是独立问题**：可以讨论 expected 成员清单、每源本沿完成标记、周期序号、零活动记录及单消费者快照。不能以注册到达顺序、队列暂空、一次 event 或随意增加 delta cycle 代替完成条件。
- **槽位和通知不是同一职责**：只保留最新值的槽位可能覆盖尚未消费的数据；event 不保存记录。多聚合组复用同一 source 时，还须讨论保留、复制或独立消费位置。动态数组变化也不能默认依赖 `always_comb` 自动通知消费者。

这些推论用于比较方案，没有选择最终通信机制、注册时序、数据结构或调度实现。实际工具兼容性与资源容量仍待后续验证和决策。
