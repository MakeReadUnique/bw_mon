# 测试证据与复现

PR 保留监测器源码、测试用例、最终结果摘要和真实 Verdi 截图。生成的 FSDB、原始运行数据及源码快照从记录的固定提交取回，不覆盖本地运行结果。

历史 `b22e32e` 的427组件／42场证明保留原来源；接入简化、默认阶段及完成协议采用新版独立证明。两者的适用范围及实际结果见[结果摘要](../evidence/README.md)，不能互相替代。

## 离线检查已保存的结果

```sh
make verify-evidence

# 新版完整串行矩阵、当前源码适用性及已确认的波形资产
python3 tools/evidence.py verify spec48 --current-source

# 下列入口只重放历史证明，不把历史通过绑定到当前源码
python3 tools/evidence.py verify compatibility
python3 tools/evidence.py verify scale
python3 tools/evidence.py verify waveforms
python3 tools/evidence.py verify common
```

需要 Python 3.6+、Git 和已记录提交。历史证明从 `b22e32e1beb704beb290e65f7af20bbe44065a34` 读取；新版证明使用交付摘要记录的独立归档提交。工具在临时目录重放校验器，检查原始输入再生成、源码／工具／构建回执、预期／实际／差异、串行时序、预算及资产哈希，不启动仿真器。

`verify spec48 --current-source` 与 `make verify-evidence` 核对新版实测源码清单，并拒绝遗漏的新RTL文件；历史证明仍按其原源码核验。显式历史入口的 `--current-source` 只用于对照旧300文件清单，升级后失败是预期行为。任何来源检查失败均不能用旧结果替当前代码背书。

若浅克隆缺少记录提交，先明确取回一次：

```sh
git fetch origin b22e32e1beb704beb290e65f7af20bbe44065a34
```

## 在 Verdi 中打开关键波形

```sh
# 只恢复到本地忽略目录，不加入 PR
make evidence-waveforms

./artifacts/review-analog/open.sh start_stop_ns
./artifacts/review-analog/open.sh varying_steady_ns
./artifacts/review-analog/open.sh size_unknown_ns
./artifacts/review-analog/open.sh clock_stop_cycle
```

上述命令打开历史九图；它们的42场／672个CSV及人工确认只属于原资产。新版四图的具体区间、用户反馈、哈希与打开命令见[聚焦验收说明](../evidence/verdi61/README.md)，来源改变后须另行核对适用性。

恢复工具遇到已有且内容不同的文件会拒绝覆盖。需要单独导出时可以使用：

```sh
python3 tools/evidence.py restore waveforms --destination /tmp/bw-wave-review
```

## 重新执行测试

以下命令需要 VCS、Verdi/FSDB 支持和项目的 native helper 构建环境，见[构建说明](bw-mon-scheduling.md)。

```sh
make test                 # 组件测试
make acceptance           # 12 点 / 4 组，43 场端到端测试
make scale-quick          # 日常规模 / 边界回归
make scale-quick BW_CACHE_MODE=hot # 使用匹配的已有构建
make scale-full           # 完整修订矩阵，先恢复依赖的 COMMON 记录
make test-evidence-tools  # 恢复工具、记录审计与发布保护测试
```

需要自选缓存模式或输出目录时：

```sh
python3 tools/evidence.py restore common
python3 tests/scale/revised_suite.py full --cache-mode cold --output-root .build/revised
python3 tests/scale/revised_suite.py full --cache-mode hot --output-root .build/revised
```

恢复和新生成的数据目录均已加入 `.gitignore`。原始场景定义、参考模型及测试断言继续作为源码保留。

## 历史记录

- [最终规模/历史证明](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/revised_evidence/final-campaign)：四套件、32 次运行、原始输入和完整审计记录。
- [427 组件 / 42 场端到端证明](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/review/compatibility)：历史产品的对照、完整日志和 FSDB。
- [原人工审阅数据](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance)：原图片、视图、确认记录和输入/结果表。
- [旧规模准备记录](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/evidence)与[旧历史记录](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/history_evidence)：只保留原有历史含义。已停止或未启动的运行仍未通过。

清理减少的是 PR 最终文件列表，不重写已经公开的 Git 历史。当前版本不再携带波形数据或原始证明压缩包。
