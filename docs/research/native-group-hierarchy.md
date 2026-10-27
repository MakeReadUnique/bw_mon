# Group ID 命名的原生 FSDB 层级与源码关联验证

研究日期：2026-10-27，VCS/Verdi W-2024.09-SP1。关联[研究票](https://github.com/MakeReadUnique/bw_mon/issues/47)与[文件新增聚合组的时钟、复位与波形契约](https://github.com/MakeReadUnique/bw_mon/issues/37)。

## 对用户要求的结论

用户先明确需要“在原生层级树中按组名查找，再手动拉信号”，随后明确“还需要与真实 SV 实例、源码层级一致”。因此：

- 显示别名不能满足此要求。
- 工具可以给派生 FSDB 的真实 scope 改名，但不会同步创建或修改真实 SV 实例、KDB 或源码层级，也不满足完整要求。
- 静态 SV module 实例及其名称由编译／展开确定；重跑同一个已编译 simv 不会从 cfg 创建新的同名 SV 实例。若要求这种实例，需在编译前生成或编写 SV 并重新编译。

用户最终明确选择：**“放弃新增组，以及 通过cfg 修改配置成员”**。本路线被撤回，不以本实验成功录波替代用户的可读性及源码关联要求，也不交付新的分组后处理功能。

## 已取证的工具事实

复用前次[可见性探针](cfg-group-verdi-visibility.md)第二次运行的冻结 FSDB，没有编译或重跑仿真。

1. 原文件直接进入 `fsdbedit` 会报 `doesn't support packed mode dumping FSDB`。经 `fsdbextract -seq` 提取已使用的两个观测槽，再逐项 `fsdbedit -rename_scope` 后，工具成功生成独立 `groups.fsdb`。单条命令只允许一个 `-rename_scope`，实验使用两个连续处理步骤。
2. 原始 FSDB 的 SHA-256 不变。派生文件包含真实 `/tb_cfg_group_probe/g1`、`/tb_cfg_group_probe/g2` scope；`fsdbreport` 可直接按这些路径读取。
3. 对两个组共16个公开字段，转换后的 CSV 与原始 CSV 除路径外逐值、逐时间戳相同，包括 string Group ID、real 带宽、整数、质量位及枚举标签。
4. 真实 nWave 查询 `wvGetScope` 返回 `g1 g2`，`wvGetSignalsByScope` 返回 g1 的八个公开字段；通过新路径 `wvAddSignal` 成功加入波形。保存视图没有 `addRenameSig`。
5. [真实 Get Signals 截图](cfg-group-verdi-probe/native-hierarchy/evidence/native-tree.png)显示原生树下 g1/g2。图像由隔离 Xvfb 上的 X11 窗口直接捕获，没有图片后处理。它证明树的显示与字段可访问，不代表用户已经实际拖拽或认可工作流。

[处理与数值核对清单](cfg-group-verdi-probe/native-hierarchy/evidence/manifest.json) · [原生树查询](cfg-group-verdi-probe/native-hierarchy/evidence/native-tree.txt) · [派生 FSDB](cfg-group-verdi-probe/native-hierarchy/evidence/groups.fsdb) · [GUI 取证清单](cfg-group-verdi-probe/native-hierarchy/evidence/capture.json)

## 边界

这不是一条满足用户最终要求的方案。额外 FSDB 的 scope 名字与真实设计/KDB 不同，不能宣称按新名字跳转真实同名实例；原匿名槽位不是用户想要的具名组实例。

实验提取时设置 `FSDB_ENV_MAX_GLITCH_NUM=0`、`-seq`。原厂手册说明默认提取可能省略同时间 glitch，启用这些选项也不应推导为任意 FSDB、复杂类型和工具流程全部无损；本次只核对所列16个公开字段及此输入的时间戳/数值，没有通用无损、规模性能、实时调试或源码交叉定位的验收。

复现处理：`python3 docs/research/cfg-group-verdi-probe/native-hierarchy/run.py`。本机 GUI 证据脚本为同目录 `capture_native.py`，使用本机已有的独立 Xvfb 路径与 `:95` 显示；它不修改源 FSDB。资产留在独立研究分支，不合并。

## 一手依据

- Synopsys *Verdi Tcl Reference*，W-2024.09-SP1，pp505–508：`wvRenameSignal` 与波形视图保存／恢复；pp487–488、679–680：`wvGetSignalOpen`、`wvGetScope`、`wvGetSignalsByScope`。本机原件 `/home/eda/app/synopsys/verdi/W-2024.09-SP1/doc/verdi_tcl.pdf`。
- Synopsys *Verdi Command Reference*，W-2024.09-SP1，pp1823–1828：`fsdbedit -rename_scope` 与 packed mode 限制；pp1833、1836：`fsdbextract`、glitch及序号选项。本机原件 `/home/eda/app/synopsys/verdi/W-2024.09-SP1/doc/verdi_command_ref.pdf`。本次命令日志与派生文件补充实际行为证据。
- 本探针只有编译时 `wave_slots` 实例的[SV源码](cfg-group-verdi-probe/probe.sv)与[编译日志](cfg-group-verdi-probe/evidence/compile.log)，以及本次处理没有编译或修改源码的命令记录，用于区分该设计的静态层级与派生 FSDB 的 scope 名字。没有引用未读取的 IEEE 标准正文。
