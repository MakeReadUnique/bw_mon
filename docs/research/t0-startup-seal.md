# t=0 注册范围与 1fs 自动封口候选的静态依据

研究日期：2026-10-27。关联[自动注册的封口条件与统一启动顺序](https://github.com/MakeReadUnique/bw_mon/issues/41)。研究基线为 `fa20d9cb15731e68255d83fb80f950f62c24fb9c`；本文件留在独立研究分支，不合并。

本次实时讨论已确认：合法点注册、具名 SV 组注册及成员配置仅在 t=0 完成；零点零组报错；组实例本身作为组声明，用户使用 `add_point_member()` / `add_group_member()`，移除 `define_group()`、人工成员数及 `finish_configuration()`。这些是讨论输入，最终契约以关联决策票的 resolution 为准。**在 1fs 关闭并启动仍是待确认候选，不是已作出的决议。**

## 一手依据及适用范围

- Accellera 官方保存的 [SystemVerilog 3.1 scheduling semantics，version 6](https://www.accellera.org/images/eda/sv-ec/att-0836/01-schedSem-svLRM-v6.pdf#page=2)，2003 年 2 月工作草案，§5.3：仿真按时间顺序处理时间槽，执行并移除当前槽的全部事件后，才进入下一个非空槽。本文仅用这条时间推进原则；**该文不是 IEEE 1800-2023 正文，其旧事件区列表与 PLI 映射不用于证明当前 VCS 回调行为。**
- 已提交[时间接口文档](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-api.md#L20)规定全部生产作用域使用 `timeunit 1fs; timeprecision 1fs`，时间戳是 unsigned64 的飞秒 tick，并禁止覆盖生产时间单位或精度。[package](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L2)和 [setup](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_setup.sv#L7)确有此声明；[常量](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L69)规定每 ns 为 1,000,000 ticks。
- [点模块](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_point_mon.sv#L144)与[组模块](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_group_mon.sv#L59)在没有正时间等待的 `initial` 中登记。旧低层 API 的正时间登记确曾被支持：[点 deadline 测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_startup_deadline.sv#L7)和[组 deadline 测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_group_startup_deadline.sv#L12)均要求在 5ns 补齐最后登记后成功启动。因此 t=0 限制是兼容变更，也替代[模块职责、bind 接入与统计数据通路](https://github.com/MakeReadUnique/bw_mon/issues/7#issuecomment-6382679083)中不要求 t=0 注册加正时间里程碑的旧选择。

## 候选及工程推导

候选要求唯一 setup 自 t=0 安排 `#1fs` 的内部协调事件；所有公开注册、组声明及成员配置入口在固定 1fs 的库作用域中独立检查当前 `$time == 0`。tick 1 关闭集合，解析成员、验证、冻结、登记报告范围并完成内部准备，成功后仅发布一次 `monitor_ready`。这里描述的是待实现行为，当前代码仍依赖人工预期数量和配置完成标志。

在上述约束下，时间已经到达 tick 1，便能证明 tick 0 的可执行事件已处理完；今后不会再有合法注册或配置调用。有限的 t=0 零延迟调度链可以全部参与，无需猜测 delta 轮数。等待未来事件的进程可能尚未完成，但其未来配置调用不再合法。这是从调度时间推进原则与 t=0-only 接口约束得到的推导，不能泛化为任意正时间注册也会自动被发现。

各入口必须先检查物理时间，不能仅检查协调器设置的“已关闭”标志：tick 1 中即使迟到调用先于协调器运行，也必须被拒绝；调用方不得传入自己按较粗时间单位舍入后的 `$time` 代替库内检查。`#1fs` 位于既有 1fs 精度作用域，因而是正时间里程碑，不是 `#0`。

这条证明不依赖现有 [VCS `cbAtEndOfSimTime` adapter](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_slot_settlement.c#L175)。其[同刻多代 settlement](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_slot_settlement.svh#L18)可继续调度工作，已有数据结算证据不能被当作新启动流程已经通过验证。

## 必须保留的影响与限制

| 项目 | 静态结论或尚需决策的影响 |
| --- | --- |
| 共同计量起点取 1fs | 沿用当前[点采样](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_point_recorder.sv#L99)及[组采样](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_group_mon.sv#L94)的严格大于关系，起点同刻沿不计量；无复位干预时，[ns 首次发布](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_stats_core.sv#L863)变为 `1fs + S ns`，绝对发布相位改变。 |
| 40µs 总预算 | [数值契约](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-numeric-storage.md#L3)从原 setup 起算，不能未经决策顺延。若保留从 tick 0 到 40,000ns 的预算，`W=S=40000ns` 的首次满窗发布时间为 `40000ns+1fs`，落在预算外；`S=1ns` 的预算内发布次数也少一次。现有[精确预算测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_settle_exact_budget.sv#L25)要求在 40µs 获得完整端点窗口及每范围 40,000 次发布，因此不能声称这项验收不受影响。如何处理须由决策明确，本文不延长预算、不更改起点。 |
| 报告与内部准备 | 当前 [try_ready](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_registry.svh#L256)先置 ready，再调用报告 `on_ready()`；点与组的 reset snapshot 也在等待 ready 后进行。若承诺准备完成才公开 ready，必须拆开内部准备与公开 ready，避免相互等待；1fs 封口本身没有解决这项依赖。 |
| 迟到调用 | `wait(monitor_ready)` 后配置非法；tick 1 的非法调用也可能晚于 ready 发布。不能预知任意未来非法调用，应按封口后错误终止，并沿用[全局失败事实及报告抑制](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L250)，不生成正常完整报告。 |
| 不前进或提前结束 | t=0 无限零延迟循环使 tick 1 永不到达，仿真时间 watchdog 同样无法前进；t=0 提前 `$finish` 也没有完成启动。新契约需区分外部运行停滞处置与结束时“启动未完成”的诊断，不能伪装为正常空报告。 |

验证范围仅为官方历史工作草案阅读、固定提交代码核对与上述静态推导；没有修改产品、编译、仿真、回归或原型取证。本文不是 1fs 方案的工具验证或最终用户确认，也不将原代码测试的存在等同于本次重新运行通过。
