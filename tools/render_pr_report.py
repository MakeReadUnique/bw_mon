#!/usr/bin/env python3
"""Render the recorded test summary as a Chinese report for a real browser capture."""
import argparse
import html
import json
from pathlib import Path
import subprocess

from evidence import ROOT, SOURCE, check_current_source


def recorded(path):
    return json.loads(subprocess.check_output(
        ['git', '-C', str(ROOT), 'show', SOURCE + ':' + path], universal_newlines=True))


def render():
    check_current_source()
    data = json.loads((ROOT / 'evidence/results.json').read_text())
    compatibility = recorded('tests/review/compatibility/verification.json')
    scale = recorded('tests/scale/revised_evidence/final-campaign/summary.json')
    for key, value in compatibility['expected'].items():
        assert data['compatibility'][key] == value, key
    for name, result in data['scale']['suites'].items():
        for key, value in result.items():
            assert scale['suites'][name][key] == value, (name, key)
        assert result['checked_pass'] and result['elapsed_seconds'] <= result['budget_seconds']
    c, s = data['compatibility'], data['scale']
    rows = [
        ('组件边界', '三类接口、窗口、复位、阶段、性能检查', str(c['components']) + ' 项通过'),
        ('端到端', '12 个点 + 4 个组；ns / cycle 两种窗口', str(c['scenes']) + ' 场通过'),
        ('最大拓扑', '16,384 点 + 4,096 组；8 层；65,536 条成员关系', '全部范围逐项核对'),
        ('深历史', '80,000 个实际采样沿；40 μs 终点；压缩 / 不可压缩输入', '边界、裁剪与释放通过'),
    ]
    table = ''.join('<tr><td>{}</td><td>{}</td><td class="pass">{}</td></tr>'.format(
        *[html.escape(value) for value in row]) for row in rows)
    timings = ''
    for label, prefix, budget in [('日常回归', 'quick', '冷 ≤ 300 秒；缓存 ≤ 120 秒'),
                                  ('完整规模 / 历史', 'full', '每次 ≤ 1,800 秒')]:
        cold, hot = [s['suites'][prefix + '-' + mode]['elapsed_seconds'] for mode in ('cold', 'hot')]
        timings += '<tr><td>{}</td><td>{:.3f} 秒</td><td>{:.3f} 秒</td><td>{}</td><td class="pass">通过</td></tr>'.format(label, cold, hot, budget)
    return '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>bw_mon 测试内容与结果</title><style>
*{box-sizing:border-box}body{margin:0;background:#edf2f7;color:#16243b;font-family:"Noto Sans CJK SC",sans-serif}
main{width:1600px;padding:38px 48px}header{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px}
h1{font-size:36px;margin:0 0 5px;font-weight:700}p{margin:0;color:#506079;font-size:18px;line-height:1.65}
.badge{border:1px solid #80c5a0;background:#e2f5e9;border-radius:9px;color:#146d3b;padding:12px 24px;font-size:25px;font-weight:700}
.flow{display:flex;align-items:center;gap:15px;margin:22px 0}.box{flex:1;text-align:center;background:#fff;border:1px solid #c8d5e6;border-radius:10px;padding:18px 6px;font-size:22px;font-weight:600}.arrow{font-size:26px;color:#527baf}
.cards{display:flex;gap:18px;margin:20px 0}.card{flex:1;background:#fff;border:1px solid #d9e3ef;border-radius:10px;padding:14px 22px}.value{font-size:38px;font-weight:700;color:#167a44}.label{font-size:18px;color:#506079}
section{background:#fff;border:1px solid #d9e3ef;border-radius:10px;padding:18px 24px;margin-top:18px}
h2{font-size:23px;margin:0 0 10px}table{border-collapse:collapse;width:100%;font-size:18px;line-height:1.6}th{text-align:left;background:#f1f5fa;color:#536278}td,th{padding:10px 12px;border-bottom:1px solid #e5ebf2}tr:last-child td{border-bottom:0}.pass{color:#167a44;font-weight:600}
footer{margin-top:18px;font-size:16px;line-height:1.75;color:#526078}code{font-family:monospace;font-size:15px;color:#44566e}
</style><main><header><div><h1>bw_mon：测了什么，结果如何</h1><p>已完成验收的结果汇总 · 原始仿真日期：2026-10-26</p></div><div class="badge">全部通过 · 差异为 0</div></header>
<div class="flow"><div class="box">原始接口 / 时钟 / 复位</div><div class="arrow">→</div><div class="box">单点与分组监测</div><div class="arrow">→</div><div class="box">窗口 / 阶段 / 质量标志</div><div class="arrow">→</div><div class="box">独立参考逐项核对</div></div>
<div class="cards"><div class="card"><div class="value">427 / 427</div><div class="label">组件用例通过</div></div><div class="card"><div class="value">42 / 42</div><div class="label">端到端场景通过</div></div><div class="card"><div class="value">672</div><div class="label">公开结果 CSV 与保留数据一致</div></div><div class="card"><div class="value">4 / 4</div><div class="label">冷构建 / 缓存套件通过</div></div></div>
<section><h2>测试内容</h2><table><thead><tr><th>类别</th><th>重点检查</th><th>结果</th></tr></thead><tbody>''' + table + '''</tbody></table></section>
<section><h2>运行时间（包含生成、编译、仿真和独立核验）</h2><table><thead><tr><th>套件</th><th>冷构建</th><th>缓存构建</th><th>时间要求</th><th>结果</th></tr></thead><tbody>''' + timings + '''</tbody></table></section>
<footer>每次完整套件核对 <b>21,670,663</b> 条原始记录与 <b>16,236,946</b> 次窗口发布；独立差异为 0。<br>
最大拓扑和深历史分场验证；不把它们的内存峰值相加当成一次实测。性能 FAIL / WARNING 的正确报告也在测试范围内。<br>
本图由已记录结果生成，不代表本次重新运行仿真。数据：<code>evidence/results.json</code> · 记录提交：<code>b22e32e</code></footer></main></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.build/pr-report.html')
    args = parser.parse_args()
    page = render()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page)
    print(args.output)


if __name__ == '__main__':
    main()
