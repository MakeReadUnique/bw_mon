# 工单 #58 正式产品专项联合结果表

来源: 154d45f2ba32242cd728c9996157cee296491fa2
预算: 900 秒；实测总耗时: 152.629 秒（等待计入，冷构建）

## 固定输入确认目标（条款 3）

| 族 | 用例 | 类型 | 目标 | 首个完整反映窗口(ns) | 确认时刻(ns) | 有效更新次数 | 首窗→确认延迟(ns) | 输入变化→确认延迟(ns) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| continuous | 1 | point | c1 | 10.000001 | 70.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 1 | point | c2 | 170.000001 | 230.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 1 | point | fall | 330.000001 | 370.000001 | 5 | 40.000000 | 49.999999 |
| continuous | 1 | point | c3 | 490.000001 | 540.000001 | 6 | 50.000000 | 59.999999 |
| continuous | 1 | point | ramp | 650.000001 | 680.000001 | 4 | 30.000000 | 39.999999 |
| continuous | 1 | point | c4 | 810.000001 | 850.000001 | 5 | 40.000000 | 49.999999 |
| continuous | 1 | group | c1 | 10.000001 | 70.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 1 | group | c2 | 170.000001 | 230.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 1 | group | fall | 330.000001 | 370.000001 | 5 | 40.000000 | 49.999999 |
| continuous | 1 | group | c3 | 490.000001 | 540.000001 | 6 | 50.000000 | 59.999999 |
| continuous | 1 | group | ramp | 650.000001 | 680.000001 | 4 | 30.000000 | 39.999999 |
| continuous | 1 | group | c4 | 810.000001 | 850.000001 | 5 | 40.000000 | 49.999999 |
| continuous | 2 | point | short1 | 983.000001 | 1043.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 2 | point | short2 | 1103.000001 | 1163.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 2 | group | short1 | 983.000001 | 1043.000001 | 7 | 60.000000 | 69.999999 |
| continuous | 2 | group | short2 | 1103.000001 | 1163.000001 | 7 | 60.000000 | 69.999999 |
| platforms | 3 | point | micro | 10.000002 | 70.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 3 | group | micro | 10.000002 | 70.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 4 | point | alt8 | 263.000002 | 323.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 4 | group | alt8 | 263.000002 | 323.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 5 | point | firstfail | 516.000002 | 576.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 5 | point | lastpass | 756.000002 | 816.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 5 | group | firstfail | 516.000002 | 576.000002 | 7 | 60.000000 | 70.000000 |
| platforms | 5 | group | lastpass | 756.000002 | 816.000002 | 7 | 60.000000 | 70.000000 |
| activity | 6 | point | beforepause | 10.000002 | 16.000002 | 7 | 6.000000 | 16.000000 |
| activity | 6 | point | afterpause | 93.000002 | 99.000002 | 7 | 6.000000 | 16.000000 |
| activity | 6 | group | beforepause | 10.000002 | 16.000002 | 7 | 6.000000 | 16.000000 |
| activity | 6 | group | afterpause | 93.000002 | 99.000002 | 7 | 6.000000 | 16.000000 |
| activity | 8 | point | zero | 205.000002 | 211.000002 | 7 | 6.000000 | 16.000000 |
| activity | 8 | group | zero | 205.000002 | 211.000002 | 7 | 6.000000 | 16.000000 |
| activity | 10 | point | dense1 | 369.000002 | 375.000002 | 7 | 6.000000 | 16.000000 |
| activity | 10 | point | denseup | 419.000002 | 419.000002 | 1 | 0.000000 | 10.000000 |
| activity | 10 | point | dense2 | 446.000002 | 446.000002 | 1 | 0.000000 | 10.000000 |
| activity | 10 | point | densedown | 506.000002 | 511.000002 | 6 | 5.000000 | 15.000000 |
| activity | 10 | point | dense3 | 533.000002 | 535.000002 | 3 | 2.000000 | 12.000000 |
| activity | 10 | group | dense1 | 369.000002 | 375.000002 | 7 | 6.000000 | 16.000000 |
| activity | 10 | group | denseup | 419.000002 | 419.000002 | 1 | 0.000000 | 10.000000 |
| activity | 10 | group | dense2 | 446.000002 | 446.000002 | 1 | 0.000000 | 10.000000 |
| activity | 10 | group | densedown | 506.000002 | 511.000002 | 6 | 5.000000 | 15.000000 |
| activity | 10 | group | dense3 | 533.000002 | 535.000002 | 3 | 2.000000 | 12.000000 |
| recovery | 11 | point | beforegap | 10.000001 | 16.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 11 | point | recover | 91.000001 | 97.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 11 | point | afterreset | 182.000002 | 188.000002 | 7 | 6.000000 | 16.000000 |
| recovery | 11 | group | beforegap | 10.000001 | 16.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 11 | group | recover | 91.000001 | 97.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 11 | group | afterreset | 182.000002 | 188.000002 | 7 | 6.000000 | 16.000000 |
| recovery | 12 | point | base | 285.000001 | 291.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 12 | point | return | 411.000001 | 417.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 12 | group | base | 285.000001 | 291.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 12 | group | return | 411.000001 | 417.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 13 | point | sustainedbase | 524.000001 | 530.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 13 | point | sustainedreturn | 676.000001 | 682.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 13 | group | sustainedbase | 524.000001 | 530.000001 | 7 | 6.000000 | 15.999999 |
| recovery | 13 | group | sustainedreturn | 676.000001 | 682.000001 | 7 | 6.000000 | 15.999999 |

全部目标满足最迟第八次有效更新确认；错误确认/额外切换为 0。

## 默认 5% 检查联合结果（条款 4，固定输入部分）

| 族 | 用例 | 类型 | 平台 | 预期 | 实际 | B(产品) | B(精确有理数) | 样本数 | 最长超限段(条/跨度ns) | 参考序号 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| continuous | 1 | group | 1 | PASS | PASS | 100 | 100 | 11 | 0/0.000000 | 7,8,9,10,11,12 |
| continuous | 1 | group | 2 | PASS | PASS | 200 | 200 | 14 | 1/0.000000 | 23,24,25,26,27,28 |
| continuous | 1 | group | 4 | PASS | PASS | 100 | 100 | 14 | 1/0.000000 | 54,55,56,57,58,59 |
| continuous | 1 | group | 6 | PASS | PASS | 200 | 200 | 13 | 0/0.000000 | 85,86,87,88,89,90 |
| continuous | 1 | point | 1 | PASS | PASS | 100 | 100 | 11 | 0/0.000000 | 7,8,9,10,11,12 |
| continuous | 1 | point | 2 | PASS | PASS | 200 | 200 | 14 | 1/0.000000 | 23,24,25,26,27,28 |
| continuous | 1 | point | 4 | PASS | PASS | 100 | 100 | 14 | 1/0.000000 | 54,55,56,57,58,59 |
| continuous | 1 | point | 6 | PASS | PASS | 200 | 200 | 13 | 0/0.000000 | 85,86,87,88,89,90 |
| continuous | 2 | group | 7 | PASS | PASS | 100 | 100 | 7 | 0/0.000000 | 104,105,106,107,108,109 |
| continuous | 2 | group | 8 | PASS | PASS | 200 | 200 | 7 | 0/0.000000 | 116,117,118,119,120,121 |
| continuous | 2 | point | 7 | PASS | PASS | 100 | 100 | 7 | 0/0.000000 | 104,105,106,107,108,109 |
| continuous | 2 | point | 8 | PASS | PASS | 200 | 200 | 7 | 0/0.000000 | 116,117,118,119,120,121 |
| platforms | 3 | group | 1 | PASS | PASS | 400 | 400 | 18 | 0/0.000000 | 7,8,9,10,11,12 |
| platforms | 3 | point | 1 | PASS | PASS | 400 | 400 | 18 | 0/0.000000 | 7,8,9,10,11,12 |
| platforms | 4 | group | 2 | FAIL | FAIL | 400 | 400 | 18 | 18/0.000170 | 32,33,34,35,36,37 |
| platforms | 4 | point | 2 | FAIL | FAIL | 400 | 400 | 18 | 18/0.000170 | 32,33,34,35,36,37 |
| platforms | 5 | group | 3 | FAIL | FAIL | 400 | 400 | 19 | 19/0.000180 | 57,58,59,60,61,62 |
| platforms | 5 | group | 4 | PASS | PASS | 800 | 800 | 12 | 0/0.000000 | 81,82,83,84,85,86 |
| platforms | 5 | point | 3 | FAIL | FAIL | 400 | 400 | 19 | 19/0.000180 | 57,58,59,60,61,62 |
| platforms | 5 | point | 4 | PASS | PASS | 800 | 800 | 12 | 0/0.000000 | 81,82,83,84,85,86 |
| activity | 6 | group | 1 | FAIL | FAIL | 100 | 100 | 83 | 12/0.000011 | 25,26,27,28,29,30 |
| activity | 6 | group | 2 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| activity | 6 | group | 3 | PASS | PASS | 100 | 100 | 65 | 0/0.000000 | 108,109,110,111,112,113 |
| activity | 6 | point | 1 | FAIL | FAIL | 100 | 100 | 83 | 12/0.000011 | 25,26,27,28,29,30 |
| activity | 6 | point | 2 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| activity | 6 | point | 3 | PASS | PASS | 100 | 100 | 65 | 0/0.000000 | 108,109,110,111,112,113 |
| activity | 7 | group | 0 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| activity | 7 | point | 0 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| activity | 8 | group | 5 | WARNING | WARNING | 0 | 0 | 0 | 0/0.000000 | 216,217,218,219,220,221 |
| activity | 8 | point | 5 | WARNING | WARNING | 0 | 0 | 0 | 0/0.000000 | 216,217,218,219,220,221 |
| activity | 10 | group | 6 | PASS | PASS | 100 | 100 | 51 | 7/0.000006 | 376,377,378,379,380,381 |
| activity | 10 | group | 8 | PASS | PASS | 200 | 200 | 69 | 6/0.000005 | 447,448,449,450,451,452 |
| activity | 10 | group | 10 | PASS | PASS | 100 | 100 | 49 | 0/0.000000 | 536,537,538,539,540,541 |
| activity | 10 | point | 6 | PASS | PASS | 100 | 100 | 51 | 7/0.000006 | 376,377,378,379,380,381 |
| activity | 10 | point | 8 | PASS | PASS | 200 | 200 | 69 | 6/0.000005 | 447,448,449,450,451,452 |
| activity | 10 | point | 10 | PASS | PASS | 100 | 100 | 49 | 0/0.000000 | 536,537,538,539,540,541 |
| recovery | 11 | group | 1 | WARNING | WARNING | 400 | 400 | 71 | 0/0.000000 | 25,26,27,28,29,30 |
| recovery | 11 | group | 2 | WARNING | WARNING | 400 | 400 | 75 | 0/0.000000 | 106,107,108,109,110,111 |
| recovery | 11 | group | 3 | PASS | PASS | 400 | 400 | 75 | 0/0.000000 | 196,197,198,199,200,201 |
| recovery | 11 | point | 1 | WARNING | WARNING | 400 | 400 | 71 | 0/0.000000 | 25,26,27,28,29,30 |
| recovery | 11 | point | 2 | WARNING | WARNING | 400 | 400 | 75 | 0/0.000000 | 106,107,108,109,110,111 |
| recovery | 11 | point | 3 | PASS | PASS | 400 | 400 | 75 | 0/0.000000 | 196,197,198,199,200,201 |
| recovery | 12 | group | 5 | PASS | PASS | 400 | 400 | 126 | 9/8.000000 | 297,298,299,300,301,302 |
| recovery | 12 | group | 6 | PASS | PASS | 400 | 400 | 86 | 0/0.000000 | 423,424,425,426,427,428 |
| recovery | 12 | point | 5 | PASS | PASS | 400 | 400 | 126 | 9/8.000000 | 297,298,299,300,301,302 |
| recovery | 12 | point | 6 | PASS | PASS | 400 | 400 | 86 | 0/0.000000 | 423,424,425,426,427,428 |
| recovery | 13 | group | 8 | FAIL | FAIL | 400 | 400 | 140 | 46/45.000000 | 534,535,536,537,538,539 |
| recovery | 13 | group | 10 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | group | 11 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | group | 12 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | group | 14 | PASS | PASS | 400 | 400 | 86 | 0/0.000000 | 686,687,688,689,690,691 |
| recovery | 13 | point | 8 | FAIL | FAIL | 400 | 400 | 140 | 46/45.000000 | 534,535,536,537,538,539 |
| recovery | 13 | point | 10 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | point | 11 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | point | 12 | WARNING | WARNING | UNAVAILABLE | - | 0 | 0/0.000000 |  |
| recovery | 13 | point | 14 | PASS | PASS | 400 | 400 | 86 | 0/0.000000 | 686,687,688,689,690,691 |

## 启停控制表（条款 2）

| EPISODE_ENABLE | PHASE_ENABLE | 结果 | 承载用例 |
| --- | --- | --- | --- |
| 0 | 省略 | 战役内验证 | phase_defaults |
| 1 | 省略 | 战役内验证 | phase_defaults |
| 1 | 0 | 战役内验证 | phase_defaults |
| 1 | 1 | 战役内验证 | phase_defaults |
| 0 | 1 | 配置错误（拒绝） | phase_config_episode |

## 5% 逐项独立预期核对（条款 4）

| 方面 | 承载用例 | 状态 |
| --- | --- | --- |
| equality | checker_numeric_low_equal, checker_numeric_high_equal, checker_numeric_expanded_high_equal | PASS |
| sustained_span | checker_numeric_dense_short, checker_numeric_dense_fail | PASS |
| reference_backcheck | checker_numeric_reference_backcheck | PASS |
| ownership_crop | checker_ownership_crop, checker_ownership_crop_reset, checker_ownership_crop_truncated | PASS |
| short_platform_old_evidence | checker_ownership_five_reference | PASS |
| early_fail | checker_ownership_early_fail | PASS |
| zero_nearzero | checker_numeric_zero, checker_numeric_nearzero, checker_numeric_nearzero_pass | PASS |
| no_process | checker_empty | PASS |
| rule_coexistence | checker_default_explicit, checker_numeric_explicit_time | PASS |
| dedup | checker_replay, checker_numeric_platform_replay, checker_default_reset | PASS |

差异: 无（全部独立预期核对通过）

## 适用边界（不声称）

- 本专项仅覆盖四份固定输入的既定分配与映射用例；未展开参数笛卡尔积、未新增随机扫测，未加入规模、最大窗口或变频。
- 5% 等号、零/近零、密集跨度等精确数学边界由获批数值缝用例承载，为数学补充证据，不冒充公开链路联合识别证明。
- 原型期记录与人工指定平台归属用例不作为本表联合证据；43 场验收链、规模/深历史战役与真实 Verdi 人工验收属后续工单。
