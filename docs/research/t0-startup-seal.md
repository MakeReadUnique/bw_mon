# t=0 注册范围与自动启动边界的静态依据

研究日期：2026-10-27。关联[自动注册的封口条件与统一启动顺序](https://github.com/MakeReadUnique/bw_mon/issues/41)。研究基线为 `fa20d9cb15731e68255d83fb80f950f62c24fb9c`；本文件留在独立研究分支，不合并。

本次实时讨论已确认 t=0-only 注册与成员配置，以及由 setup 自动越过初始化边界、完成准备后启动；用户不写 delay 或 start 调用。用户已选择 40µs 有效计量预算从实际共同起点 T 起算、局部复位不重启预算。**旧提案中的公共固定 1fs 起点没有获得确认。** 本文只保留相关静态依据；完整接口、状态表及边界以[关联决策票](https://github.com/MakeReadUnique/bw_mon/issues/41)最终 resolution 为准，写作时具体最终状态表仍待整体确认。

## 一手依据及适用范围

- Accellera 官方保存的 [SystemVerilog 3.1 scheduling semantics，version 6](https://www.accellera.org/images/eda/sv-ec/att-0836/01-schedSem-svLRM-v6.pdf#page=2)，2003 年 2 月工作草案，§5.3：仿真按时间顺序处理时间槽，执行并移除当前槽的全部事件后，才进入下一个非空槽。本文仅用这条时间推进原则；**该文不是 IEEE 1800-2023 正文，其旧事件区列表与 PLI 映射不用于证明当前 VCS 回调行为。**
- 已提交[时间接口文档](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-api.md#L20)规定全部生产作用域使用 `timeunit 1fs; timeprecision 1fs`，时间戳是 unsigned64 的飞秒 tick，并禁止覆盖生产时间单位或精度。[package](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L2)和 [setup](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_setup.sv#L7)确有此声明；[常量](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L69)规定每 ns 为 1,000,000 ticks。
- [点模块](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_point_mon.sv#L144)与[组模块](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_group_mon.sv#L59)在没有正时间等待的 `initial` 中登记。旧低层 API 的正时间登记确曾被支持：[点 deadline 测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_startup_deadline.sv#L7)和[组 deadline 测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_group_startup_deadline.sv#L12)均要求在 5ns 补齐最后登记后成功启动。因此 t=0 限制是兼容变更，也替代[模块职责、bind 接入与统计数据通路](https://github.com/MakeReadUnique/bw_mon/issues/7#issuecomment-6382679083)中不要求 t=0 注册加正时间里程碑的旧选择。

## 候选及工程推导

可实现候选是：唯一 setup 在初始化后首个可表示的正时间步 Δ>0 安排内部协调事件；所有注册、组声明及成员配置入口独立检查当前物理时间为 0。越过此边界后关闭集合，解析成员、验证、冻结、登记报告范围并完成内部准备，成功后公布实际共同计量起点 T 并仅发布一次 `monitor_ready`。T 表示准备完成时实际公布的起点，不是用户填写的延迟，也不预先固定为某个公共数值。当前代码仍依赖人工预期数量和配置完成标志，这些行为尚未实现。

在上述约束下，物理时间已经推进到 Δ>0，便能证明 t=0 的可执行事件已处理完；今后不会再有合法注册或配置调用。有限的 t=0 零延迟调度链可以全部参与，无需猜测 delta 轮数。等待未来事件的进程可能尚未完成，但其未来配置调用不再合法。这是从调度时间推进原则与 t=0-only 接口约束得到的推导，不能泛化为任意正时间注册也会自动被发现。

各入口必须先检查物理时间，不能仅检查协调器设置的“已关闭”标志：在 Δ 时刻即使迟到调用先于协调器运行，也必须被拒绝；调用方不得传入自己按较粗时间单位舍入后的 `$time` 代替库内检查。证明要求延时真正推进物理时间，舍入成 0 的延时不满足条件。

在当前库固定 1fs/1fs 的作用域内，`#1fs` 是一个可表示正时间步的例子；它不要求 testbench 的 `timescale` 也为 1fs。用户等待 `monitor_ready` 并使用其公布的 T，无需为库的内部边界改变自己的时间单位。本研究没有改变库时间表示或提出新的时间精度配置接口。

这条证明不依赖现有 [VCS `cbAtEndOfSimTime` adapter](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_slot_settlement.c#L175)。其[同刻多代 settlement](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_slot_settlement.svh#L18)可继续调度工作，已有数据结算证据不能被当作新启动流程已经通过验证。

## 必须保留的影响与限制

| 项目 | 静态结论或尚需决策的影响 |
| --- | --- |
| 共同计量起点 T | 沿用当前[点采样](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_point_recorder.sv#L99)及[组采样](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_group_mon.sv#L94)的严格大于关系，起点同刻沿不计量；无复位干预时，[ns 首次发布](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_stats_core.sv#L863)为 `T + S ns`，绝对发布相位随 T 确定。 |
| 旧预算原点的冲突 | 旧[数值契约](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-numeric-storage.md#L3)从原 setup 起算。若仍把上界固定为绝对 40,000ns，而 T>0，`W=S=40000ns` 的首个满窗发布在预算外；例如 T=1fs 时为 `40000ns+1fs`。这说明原点选择影响验收，用户后续已选择从 T 起算；正式替代条款由[启动决策](https://github.com/MakeReadUnique/bw_mon/issues/41)记录。 |
| 报告与内部准备 | 当前 [try_ready](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_registry.svh#L256)先置 ready，再调用报告 `on_ready()`；点与组的 reset snapshot 也在等待 ready 后进行。若承诺准备完成才公开 ready，必须拆开内部准备与公开 ready，避免相互等待；跨越初始化边界本身没有解决这项依赖。 |
| 迟到调用 | `wait(monitor_ready)` 后配置非法；非法调用也可能晚于 ready 发布。不能预知任意未来非法调用，应按封口后错误终止，并沿用[全局失败事实及报告抑制](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L250)，不生成正常完整报告。 |
| 不前进或提前结束 | t=0 无限零延迟循环使正时间边界永不到达，仿真时间 watchdog 同样无法前进；t=0 提前 `$finish` 也没有完成启动。新契约需区分外部运行停滞处置与结束时“启动未完成”的诊断，不能伪装为正常空报告。 |

## 预算从 T 起算的静态影响

当前 `monitor_start_ticks` 在 [configure_monitor](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_registry.svh#L289)赋值，此后只被[时间支持检查及诊断](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/rtl/bw_mon_pkg.sv#L494)直接使用。把一次性计量预算原点设为 T，可将支持区间表达为 `T <= time <= T+40µs`；点/组复位没有该字段的赋值，不需要改变局部复位不能刷新预算的性质。采样、控制记录、transport、统计核心、hint 定时器、结果交付及 final 共用这类检查，需一致采用新原点。合法初始化阶段应另行判定，不应因其发生在 T 之前而被当作非法计量记录。

容量上界依赖有效时长和最大采样频率。[已提交数值推导](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-numeric-storage.md#L46)使用 40µs 内至多 80,001 次采样机会及单次最大字节数；整体时间平移不会增加有效时长，因此本身不要求增大既有字节计数上界或 W≤40000ns/80000cycles 的配置范围。绝对时间戳继续保留，计算 `T+预算` 仍须防止整数溢出。

端点验收必须整体相对 T 平移。[精确预算测试](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/tests/tb_settle_exact_budget.sv#L25)的绝对终点 40µs、左端 0，应改以 `T+40µs`、T 判断，并保留每范围 40,000 次 S=1ns 发布及端点满窗要求。[deep history 场景](https://github.com/MakeReadUnique/bw_mon/blob/fa20d9cb15731e68255d83fb80f950f62c24fb9c/docs/bw-mon-history.md#L70)的首沿 0.25ns、终点 40µs及参考时间戳应一并相对 T 平移，继续验证 80,000 个实际沿、79,999 个完整周期；只延后结束时刻可能多纳入一个沿。reset、hint、episode/report final 的超预算诊断也应在 `T+40µs` 周围验证，边界内完成结算，边界后不得增加物理时间排空。历史证据保留原提交及时间基准，不冒充平移后已经验收。

验证范围仅为官方历史工作草案阅读、固定提交代码核对与上述静态推导；没有修改产品、编译、仿真、回归或原型取证。本文不是启动方案的工具验证或完整状态表的最终用户确认，也不将原代码测试的存在等同于本次重新运行通过。
