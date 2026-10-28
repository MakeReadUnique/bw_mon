# 固定阶段策略迁移与证据边界

来源：Spec 48 D3/D11/D16、T1–T4；原组件来源 `9618e0e`，采纳策略来源 `3fb3fdb93249db0ca0211d9d6e0110d72d51521b`。这里保留的是输入、独立公式和已确认行为；旧 PASS 不作为新产品证明。

`python3 tests/run.py phase_defaults phase_pair6 phase_fixed_continuous phase_fixed_platforms phase_fixed_activity phase_fixed_recovery` 通过真正的点、具名四成员组、成员调用和 setup 运行。四个 `.txt` 文件保留 R2 十三个场景的原始逐沿输入；`fixed.json` 固定其独立审核过的阶段时间线和 27 个目标。点和组分别核对这些目标，合计 54 项。`check.py` 从原始输入计算半开窗口字节、完整性、计划发布集合、阶段原始字节/事件及窗口分布，并核对最终边界与两种物理延迟。公开 enum 名称在仿真时映射，不依赖其数值编码。组的四个真实成员包含零字节活动。

专项只证明阶段和既有统计语义，不声称新的 5% checker 已实现或已联合验收。其严格冷构建耗时、工具/来源和输出归档由运行记录提供；规模迁移见 [公开入口与规模参考迁移](../acceptance/spec48-migration.md)，后续完整 M/H 及完成协议仍由对应票据验收。

| 原组件 / 原意图 | 固定策略下的替代 / 保留证据 |
| --- | --- |
| phase_config_n/span/k/negative/exit/overlap/nan/storage/infinite、group_analysis_config_unknown_n/infinity | 删除专家参数使这些值不再是合法产品输入；phase_removed_parameters 对点/组/核心要求原生未知参数错误。其他通用数值/资源边界继续保留。VCS 使用 `-error=AOUP`，避免其默认警告后忽略未知覆盖。 |
| phase_config_missing | 不填写算法参数现在必须成功；phase_defaults 覆盖点/组/核心默认跟随、明确启停和普通可解释状态。 |
| phase_config_valid/episode/unknown、group_analysis_config_*、numeric_policy_phase_* | 保留已知 0/1、过程依赖和非法有效开关；组 fixture 恢复 WIP 误删的真实成员声明。 |
| phase_fit_error | 原输入用公开系数 1e308 制造溢出；参数已删除，不能再构造该输入。通过未知参数原生拒绝替代，合法实际时间/零值/不同量级输入由 phase_actual_time、phase_zero 和四固定输入覆盖。 |
| phase_delayed + metrics_delayed | 合并到 phase_delayed：原 640B@95ns 保留，零字节活动 135→155ns，延续同一过程；六窗口边界150、确认160、实际尾156，阶段原始0B/6ns与一条6.4窗口分开。原95/135短证据场景在公开入口 e3_delayed 保留。 |
| phase_zero + metrics_zero | 合并到 phase_zero：零字节活动与无活动分开；短过程最终裁剪不产生假阶段；一条阶段样本只支持 min/max，零均值过程支持 sigma0、CV不可用。 |
| phase_actual_time + metrics_actual_clock | 合并到 phase_actual_time：真实周期沿含2ns/1ns/0.5ns间隔；六条时间直线配对拟合、停钟旧快照不增加证据；原始696B/4ns与150/166两窗口均值158、sigma8分开。 |
| phase_hysteresis | 纯相对门槛替换旧绝对门槛：4%进入等号与8%保持等号明确验证；±8%长期平台另由 phase_pair6 和固定输入覆盖。 |
| phase_candidate_change | 构造不继承候选计数的短平台/上升/突变/恢复；相邻配对的独立数值证据确定首次候选，只有最后连续链能确认。 |
| phase_episode_residue + metrics_exclusions | 原始零字节旧过程、未知旧活动与新过程输入保留；证据要求3→6，半开边界、未知样本与正常排除分别核对，平均带宽独立有效。 |
| phase_repeated | 将已确认 continuous 输入连续复用两次且连接处不插入静默；一个过程内精确两次爬坡、两次下降、八个平台和全部原始字节。四固定输入另外核对全部最终时间线。 |
| metrics_repeated + report_metrics_repeated | 合并到 report_metrics_repeated，保留原24拍输入和末拍额外80B；旧短升降在新策略下未确认，最终阶段20→25ns，原始20/36与窗口20分开。显式BW/CV仍独立产生应有FAIL/WARNING，不放宽阈值。 |
| phase_reset | 先给予足够默认确认证据，再复位；旧不可变结果/epoch保留，当前状态清空，恢复必须重新积累六条证据和两候选。 |
| metrics_interrupted | 新默认下先确认并完成爬坡[6,12)，原始540B/6ns与六个窗口分布独立；随后稳定阶段的复位/截断不能擦去前段，也不能变成可靠末平台。 |
| metrics_stopped_history | 无后续采样沿仍能证明已过去的[6,10)区间；不捏造过程尾，原始240B/4ns与四窗口60/70/80/90分布分开。 |
| metrics_controls + metrics_quality | 合并到真实具名组 metrics_controls；无沿未知成员区间影响原始质量，已选窗口仍完整。另用 LATE_GAP 保留末平台原始字节不完整但窗口sigma有效的反例；已知成员复位只记录覆盖。 |
| metrics_first_boundary | 原未知起点/已知起点/未知末端三种原始活动保留；新阶段[7,11.25)的40B/4.25ns与五条10窗口；e2e与末平台选择独立。 |
| report_group_metrics NS/cycle/full/repeat | 原拓扑、同名point/group、复位/未知/二次过程和独立计数保留；仅删除算法覆盖、迁到共同T；检查真实组普通信号与不可变记录。 |
| settle_phase_* | 同刻module NBA/program Re-NBA复位移到第七个满窗（原第三）；仍必须抑制该时刻阶段确认/瞬态片段。 |
| storage_failure_phase_pending/final_phase | 故障注入方式和资源要求不变；触发移到已有固定策略确认后，不能靠短输入不走到目标资源通过。 |
| variation_pending_retention | 原六次8B、Q30000原始输入不变；删除K60000后仍保留30000条待裁剪后缀并释放，最终只选原三条16GB/s窗口。规模wrapper独立核对真实高水位。 |
| history_trace、storage其它分类、report_records | 去除多余算法参数；原计量/质量/数值/不可变报告输入和独立预期继续使用。T偏移由启动迁移核对。 |
| cfg_explicit_max_* | 修复原省略sentinel将显式全1错误当默认的反例；自然S=W/Q10默认与显式非法值严格分开，未使用Q继续不校验。 |

合并后的组件保留原 case 名称作为覆盖索引，指向共享 fixture；退役的参数专用 case 明确映射到上述原生拒绝或新的默认成功行为。不会为了保留旧测试数量而重复旧算法断言。
