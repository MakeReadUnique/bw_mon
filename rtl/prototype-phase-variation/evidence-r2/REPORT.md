# 默认阶段策略与波动检查：一次固定输入原型记录

本记录是实测结果，不是用户决议。候选失败、质量缺口与定向人工归属均保留。

| 候选 | 阶段场景通过 | 期限失败 | 错误确认 | 多余切换 |
| --- | --- | --- | --- | --- |
| 候选 A：四点直线拟合 | 10/13 | 4/27 | 0 | 0 |
| 候选 B：六点相邻配对拟合 | 13/13 | 0/27 | 0 | 0 |

VCS 窗口独立对照：1582 条，0 处不一致。定向 checker 数值输入：32/32 与预期一致。

修复核验：7/7；旧输入原始样本保留：12/12。

| 输入 | 候选 | 阶段 | checker 预期 | checker 实际 |
| --- | --- | --- | --- | --- |
| 清晰连续变化 / 恒定、阶跃、下降、爬坡及重复平台 | ols4 | PASS | PASS | FAIL |
| 清晰连续变化 / 恒定、阶跃、下降、爬坡及重复平台 | pair6 | PASS | PASS | PASS |
| 清晰连续变化 / 恰好十二个完整窗口的平台 | ols4 | PASS | PASS / WARNING | PASS |
| 清晰连续变化 / 恰好十二个完整窗口的平台 | pair6 | PASS | PASS / WARNING | WARNING |
| 波动平台 / 交替 ±2% 长平台 | ols4 | PASS | PASS | PASS |
| 波动平台 / 交替 ±2% 长平台 | pair6 | PASS | PASS | PASS |
| 波动平台 / 交替 ±8% 长平台 | ols4 | FAIL | FAIL | WARNING |
| 波动平台 / 交替 ±8% 长平台 | pair6 | PASS | FAIL | FAIL |
| 波动平台 / 早期波动失败后出现新平台 | ols4 | FAIL | FAIL | PASS |
| 波动平台 / 早期波动失败后出现新平台 | pair6 | PASS | FAIL | FAIL |
| 活动与短过程 / 短暂停顿后恢复同一过程 | ols4 | PASS | FAIL | FAIL |
| 活动与短过程 / 短暂停顿后恢复同一过程 | pair6 | PASS | FAIL | FAIL |
| 活动与短过程 / 证据不足的三周期短突发 | ols4 | PASS | WARNING | WARNING |
| 活动与短过程 / 证据不足的三周期短突发 | pair6 | PASS | WARNING | WARNING |
| 活动与短过程 / 零字节传输维持零带宽平台 | ols4 | PASS | WARNING | WARNING |
| 活动与短过程 / 零字节传输维持零带宽平台 | pair6 | PASS | WARNING | WARNING |
| 活动与短过程 / 完全没有传输 | ols4 | PASS | WARNING | WARNING |
| 活动与短过程 / 完全没有传输 | pair6 | PASS | WARNING | WARNING |
| 活动与短过程 / 密集发布的持续升降 | ols4 | FAIL | PASS | FAIL |
| 活动与短过程 / 密集发布的持续升降 | pair6 | PASS | PASS | PASS |
| 证据中断与恢复 / 观测缺口与复位后重新积累 | ols4 | PASS | WARNING | WARNING |
| 证据中断与恢复 / 观测缺口与复位后重新积累 | pair6 | PASS | WARNING | WARNING |
| 证据中断与恢复 / 偏离后回到原平台的保留证据 | ols4 | PASS | PASS | PASS |
| 证据中断与恢复 / 偏离后回到原平台的保留证据 | pair6 | PASS | PASS | PASS |
| 证据中断与恢复 / 持续异常跨短平台后回到原平台 | ols4 | PASS | FAIL | FAIL |
| 证据中断与恢复 / 持续异常跨短平台后回到原平台 | pair6 | PASS | FAIL | FAIL |

## 证据边界

- 正式 bw_stats_core / bw_check_report 尚未实现新默认；本证据不能视为产品回归通过。
- 点/四成员组是固定 1 ns 采样、精确整数计量的原型；未验证实际注册、cfg 创建组、DPI、Verdi、规模、变频或资源上限。
- 平台交接与阶跃包络证明是候选算法；通过固定输入不表示任意复杂过渡均已验证。
- 候选 B 相邻配对只评估固定交替输入；没有证明任意随机 ±8% 序列。
- 全零特判和纯相对系数需要改变内部校验；现有 trend_abs > steady_exit_abs 约束不允许直接套入。
- 最终窗口按 [阶段起点,阶段终点) 的发布时间归属；结束边界上的窗口不计入离开平台。
- 候选通过情况基于预先固定窗口参考；保留第一轮12场景全部原始样本，错误预期被明确修正；本轮不在失败后调参重跑。

专项墙钟：14.691 秒（上限 900 秒）；详见 budget.json。
