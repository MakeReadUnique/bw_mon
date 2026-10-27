# 测试证据与复现

PR 保留监测器源码、测试用例、最终结果摘要和九张真实 Verdi 截图。生成的 FSDB、原始运行数据、旧准备记录和重复源码快照已移出当前版本。它们仍可从固定的历史提交取回，不需要再次提交。

本次是文件整理：RTL、组件用例、参考模型和实际输入的 300 个文件哈希不变。已完成的测试结果见[结果摘要](../evidence/README.md)。

## 离线检查已保存的结果

```sh
make verify-evidence

# 也可以只检查一类
python3 tools/evidence.py verify compatibility --current-source
python3 tools/evidence.py verify scale --current-source
python3 tools/evidence.py verify waveforms
python3 tools/evidence.py verify common
```

需要 Python 3.6+、Git 和已记录提交。工具从 `b22e32e1beb704beb290e65f7af20bbe44065a34` 读取相应文件，在临时目录运行原校验器；完成后清理临时文件。它检查记录完整性、输入/源码哈希、预期与实际值、时间预算及图片来源，不启动仿真器。

`--current-source` 另外核对当前 300 个已测源码/输入。以后修改实现后，这个检查可能失败，不能把旧结果当成新代码的通过证明。

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

需要文档所列 Verdi 环境。九张截图仍是原已确认图片，字节内容不变；命令打开对应的原始 FSDB 与保存视图。当前实现另经 42 场端到端验证，全部 672 个公开 CSV 和最终结果与保留数据一致，这不是新的人工确认。

恢复工具遇到已有且内容不同的文件会拒绝覆盖。需要单独导出时可以使用：

```sh
python3 tools/evidence.py restore waveforms --destination /tmp/bw-wave-review
```

## 重新执行测试

以下命令需要 VCS、Verdi/FSDB 支持和项目的 native helper 构建环境，见[构建说明](bw-mon-scheduling.md)。

```sh
make test                 # 组件测试
make acceptance           # 12 点 / 4 组，42 场端到端测试
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
- [427 组件 / 42 场端到端证明](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/review/compatibility)：当前实现的对照、完整日志和 FSDB。
- [原人工审阅数据](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance)：原图片、视图、确认记录和输入/结果表。
- [旧规模准备记录](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/evidence)与[旧历史记录](https://github.com/MakeReadUnique/bw_mon/tree/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/history_evidence)：只保留原有历史含义。已停止或未启动的运行仍未通过。

清理减少的是 PR 最终文件列表，不重写已经公开的 Git 历史。当前版本不再携带波形数据或原始证明压缩包。
