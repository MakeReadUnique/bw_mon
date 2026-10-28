#!/usr/bin/env python3
"""Render existing R2 evidence for direct display in the issue; never runs a model."""
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
from matplotlib import pyplot as plt
from matplotlib import font_manager
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

ROOT = Path(__file__).resolve().parent
DATA = json.loads((ROOT / 'evidence-r2/results.json').read_text())
CASES = {c['id']: c for f in DATA['families'] for c in f['cases']}
FONT = '/usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc'
font_manager.fontManager.addfont(FONT)
plt.rcParams.update({'font.family': font_manager.FontProperties(fname=FONT).get_name(),
                     'font.size': 12, 'axes.unicode_minus': False,
                     'axes.spines.top': False, 'axes.spines.right': False,
                     'savefig.facecolor': 'white'})

fig, axes = plt.subplots(4, 1, figsize=(11.2, 13.2), layout='constrained')
fig.suptitle('候选 B · R2 记录结果\n窗口来自 VCS 原型探针；阶段归属与检查结果来自行为模型', fontsize=18)
panels = [
    (1, (120, 260), (70, 230), '正常 100→200 阶跃：修复后 PASS', 'ns'),
    (4, (50, 240), (345, 475), '交替 ±8% 平台：阶段保持 STEADY，波动检查 FAIL', 'cycle'),
    (6, (70, 110), (45, 120), '三周期暂停：短平台不再切断证据，修复后 FAIL', 'cycle'),
    (13, (90, 185), (-45, 525), '持续异常跨三个短平台：早期 FAIL 保留，最后平台 PASS', 'ns'),
]

for ax, (case_id, limits, ylimits, title, basis) in zip(axes, panels):
    case = CASES[case_id]
    run = case['candidates']['pair6']['runs'][0]
    check = run['checker']
    rows = [r for r in case['windows'] if limits[0] <= r['u'] <= limits[1] and r['eligible']]
    ax.set_title(title, loc='left', fontsize=14, pad=10)
    ax.set_xlim(*limits)
    ax.set_ylim(*ylimits)
    ax.set_ylabel('带宽（GB/s）')
    ax.set_xlabel('逻辑窗口端点 u（{}）'.format(basis))
    ax.grid(axis='y', alpha=.16)
    for p in check['platforms']:
        left, right = max(limits[0], p['phase']['start']), min(limits[1], p['phase']['end'])
        if right > left:
            ax.axvspan(left, right, color='#73a897', alpha=.08, zorder=0)
            if p['B'] is None:
                ax.axvspan(left, right, facecolor='#f5e0b3', edgecolor='#c99845',
                           hatch='///', alpha=.48, zorder=1)
        if p['B'] is not None:
            left, right = max(limits[0], p['checking']['start']), min(limits[1], p['checking']['end'])
            if right > left:
                ax.fill_between([left, right], [.95*p['B']]*2, [1.05*p['B']]*2,
                                color='#9ac7b1', alpha=.22, zorder=1)
                ax.plot([left, right], [p['B']]*2, color='#397e64', linestyle='--', linewidth=1.4)
        failure_seqs = {seq for r in p['runs'] if r['sustained'] for seq in r['seqs']}
        failing = [r for r in rows if r['seq'] in failure_seqs]
        ax.scatter([r['u'] for r in failing], [r['y'] for r in failing], color='#b94343', s=24, zorder=5)
    for e in check['exclusions']:
        left, right = max(limits[0], e['start']), min(limits[1], e['end'])
        if right > left:
            ax.axvspan(left, right, facecolor='#f6d67c', alpha=.35, zorder=2)
    ax.plot([r['u'] for r in rows], [r['y'] for r in rows], color='#24648a',
            linewidth=1.8, marker='o', markersize=2.5, zorder=3)
    if case_id == 1:
        ax.text(194, 146, '独立证据豁免\n[170,220)', ha='center', fontsize=12)
        ax.axvline(220, color='#44576a', linestyle=':', linewidth=1)
        ax.annotate('新平台边界 220\n确认时刻 230', xy=(230, 200), xytext=(241, 136),
                    ha='center', arrowprops={'arrowstyle': '->', 'color': '#44576a'}, fontsize=11)
    elif case_id == 4:
        ref = check['platforms'][0]['referenceSamples']
        ax.scatter([r['u'] for r in ref], [r['y'] for r in ref], s=85,
                   facecolors='none', edgecolors='#ba8126', linewidths=1.5, zorder=6)
        ax.text(145, 470, '参考值 368/432 交替，冻结 B=400\n18 条持续超限，跨度 170 cycle',
                va='top', ha='center', fontsize=11,
                bbox={'facecolor': 'white', 'alpha': .85, 'edgecolor': 'none'})
    elif case_id == 6:
        ax.text(89.5, 117, '无参考短平台\n[88,91)', ha='center', va='top', fontsize=10)
        ax.annotate('', xy=(81, 61), xytext=(92, 61),
                    arrowprops={'arrowstyle': '|-|', 'color': '#b94343'})
        ax.text(86.5, 57, '12 条 / 跨度 11 ≥ W=10', ha='center', va='top', color='#9b3333', fontsize=10)
    else:
        ax.text(135, 285, '46 条未豁免样本：u=111…156\n跨度 45 ns，跨三个短平台仍保留 FAIL',
                ha='center', fontsize=11, color='#9b3333')

legend = [Line2D([0], [0], color='#24648a', lw=2, label='记录的窗口带宽'),
          Line2D([0], [0], color='#397e64', linestyle='--', label='冻结参考 B'),
          Patch(facecolor='#9ac7b1', alpha=.35, label='B 的 ±5%'),
          Patch(facecolor='#f6d67c', alpha=.6, label='正常过渡豁免'),
          Line2D([0], [0], color='#b94343', marker='o', linestyle='', label='构成持续超限的样本')]
axes[0].legend(handles=legend, loc='lower left', bbox_to_anchor=(0, 1.18),
               ncol=3, fontsize=10, frameon=False)
out = ROOT / 'comment-images' / 'r2-results.png'
out.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(out, dpi=160)
print(out)
