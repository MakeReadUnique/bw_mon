/* THROWAWAY behavioral model. No production RTL is imported or changed. */
const PV = (() => {
  const candidates = [
    {id: 'ols4', name: '候选 A：四点直线拟合', n: 4, k: 2, pair: false},
    {id: 'pair6', name: '候选 B：六点相邻配对拟合', n: 6, k: 2, pair: true}
  ];
  const thresholds = {steadyEnter: .04, steadyExit: .08,
    rmsEnter: .10, rmsExit: .12, trend: .10, trendRms: .025};
  const mean = a => a.reduce((s, v) => s + v, 0) / a.length;
  const clone = v => JSON.parse(JSON.stringify(v));
  function config(id, f) {
    const c = candidates.find(c => c.id === id);
    return {...c, ...thresholds, minSpan: Math.min(f.w, (c.n - 1) * f.s),
      referenceCount: c.n, w: f.w, s: f.s, q: f.q, basis: f.basis,
      absoluteThresholds: 0, scale: '当前合格证据的平均带宽；全零单独识别稳定'};
  }
  function fit(a) {
    const mx = mean(a.map(v => v.t)), my = mean(a.map(v => v.y));
    const xx = a.reduce((s, v) => s + (v.t - mx) ** 2, 0);
    const slope = xx ? a.reduce((s, v) => s + (v.t - mx) * (v.y - my), 0) / xx : 0;
    return {mean: my, slope,
      rms: Math.sqrt(mean(a.map(v => (v.y - my - slope * (v.t - mx)) ** 2)))};
  }
  function classify(a, c, current) {
    const f = fit(a);
    let points = a;
    if (c.pair) points = [0, 2, 4].map(i => ({
      t: (a[i].t + a[i + 1].t) / 2, y: (a[i].y + a[i + 1].y) / 2}));
    const p = fit(points), spanT = a[a.length - 1].t - a[0].t;
    const delta = p.slope * spanT;
    const rawRms = Math.sqrt(mean(a.map(v =>
      (v.y - p.mean - p.slope * (v.t - mean(points.map(p => p.t)))) ** 2)));
    const m = f.mean;
    let proposed = 'UNDETERMINED';
    if (a.every(v => v.y === 0)) proposed = 'STEADY';
    else if (m > 0) {
      const se = current === 'STEADY' ? c.steadyExit : c.steadyEnter;
      const re = current === 'STEADY' ? c.rmsExit : c.rmsEnter;
      if (Math.abs(delta) <= se * m && rawRms <= re * m) proposed = 'STEADY';
      else if (Math.abs(delta) >= c.trend * m && p.rms <= c.trendRms * m)
        proposed = delta > 0 ? 'RAMP' : 'FALL';
    }
    return {proposed, mean: m, delta, rawRms, trendRms: p.rms,
      steadyEnterAbsolute: c.steadyEnter * m, steadyExitAbsolute: c.steadyExit * m,
      trendAbsolute: c.trend * m};
  }
  function phase(records, c, end) {
    let current = 'UNDETERMINED', evidence = [], pending = null, active = null;
    const phases = [], trace = [], seen = new Set();
    const close = u => { if (active) { active.end = Math.min(u, end); active = null; } };
    for (const r of records) {
      if (seen.has(r.seq)) continue;
      seen.add(r.seq);
      let reason = '', f = null;
      if (!r.eligible) {
        close(r.u); current = 'UNDETERMINED'; evidence = []; pending = null;
        reason = r.reason || '不合格阶段证据';
      } else {
        evidence.push(r); evidence = evidence.slice(-c.n);
        const span = evidence[evidence.length - 1].u - evidence[0].u;
        if (evidence.length < c.n) reason = '连续证据数量不足';
        else if (span < c.minSpan) reason = '连续证据跨度不足';
        else {
          f = classify(evidence, c, current);
          if (f.proposed === current) pending = null;
          else {
            if (!pending || pending.label !== f.proposed)
              pending = {label: f.proposed, start: r.u, startTime: r.t, count: 1,
                support: evidence.map(v=>v.seq)};
            else { pending.count++; pending.support.push(r.seq); }
            if (pending.count >= c.k) {
              close(pending.start);
              current = pending.label;
              if (current !== 'UNDETERMINED') {
                active = {id: phases.length + 1, label: current, start: pending.start,
                  startTime: pending.startTime, confirm: r.u, confirmTime: r.t,
                  end, fit: f, confirmationSeqs:pending.support.slice()};
                phases.push(active);
              }
              pending = null;
            }
          }
          if (pending) reason = '候选确认尚未完成';
          else if (current === 'UNDETERMINED') reason = '已有证据未支持任何阶段';
        }
      }
      trace.push({seq: r.seq, u: r.u, t: r.t, current, phaseId:active?active.id:null, reason,
        count: evidence.length, need: c.n, span: evidence.length ? r.u - evidence[0].u : 0,
        minSpan: c.minSpan, pending: pending ? {...pending,support:pending.support.slice()} : null, fit: f});
    }
    close(end);
    return {phases: phases.filter(p => p.start < end), trace};
  }
  function control(episode, phaseEnabled) {
    const enabled = phaseEnabled === undefined ? episode : phaseEnabled;
    return !episode && enabled ? 'CONFIG_ERROR' : enabled ? 'ANALYZE' : 'STATISTICS_ONLY';
  }
  // Phase-layer attribution only: no checker reference B, percentage, or verdict input.
  // A handoff and a reference have different qualification requirements.
  function ownership(records, phases, c) {
    const rr=[], seen=new Set();
    for(const r of records)if(!seen.has(r.seq)){seen.add(r.seq);rr.push(r);}
    const steady=phases.filter(p=>p.label==='STEADY');
    const platforms=steady.map(p=>{
      let chain=[], qualified=null;
      for(const r of rr.filter(r=>r.u>=p.start&&r.u<p.end)){
        if(!r.eligible){chain=[];continue;}
        chain.push(r);
        if(chain.length>=2&&r.u-chain[0].u>=c.w){qualified=chain.slice();break;}
      }
      const support=p.confirmationSeqs?
        rr.filter(r=>p.confirmationSeqs.includes(r.seq)):
        rr.filter(r=>r.u>=p.start&&r.u<p.end&&r.eligible).slice(0,c.n+c.k-1);
      const supportValid=support.length>=c.n+c.k-1&&support.every(r=>r.eligible)&&
        support[support.length-1].u-support[0].u>=c.minSpan&&
        support.every((r,i)=>!i||rr.indexOf(r)===rr.indexOf(support[i-1])+1);
      return {id:p.id,start:p.start,end:p.end,canHandoff:!!qualified,
        qualification:qualified?{first:qualified[0].u,last:qualified.at(-1).u,
          count:qualified.length,span:qualified.at(-1).u-qualified[0].u,
          confirmation:Math.max(p.confirm,qualified.at(-1).u),seqs:qualified.map(r=>r.seq)}:null,
        supportSeqs:support.map(r=>r.seq),supportValid,
        envelope:supportValid?{low:Math.min(...support.map(r=>r.y)),high:Math.max(...support.map(r=>r.y))}:null,
        reason:qualified?'已确认平台含至少 W 的连续有效发布跨度':'最终平台跨度不足 W；保留旧平台待结算证据'};
    });
    const steps=[], attempts=[];
    for(let i=1;i<steady.length;i++){
      const old=steady[i-1], next=steady[i], a=platforms[i-1], b=platforms[i];
      const attempt={oldPhase:old.id,newPhase:next.id,accepted:false};attempts.push(attempt);
      if(!a.canHandoff||!b.canHandoff||!a.supportValid||!b.supportValid){
        attempt.reason='平台或确认样本不足，不证明正常阶跃';continue;
      }
      if(phases.some(p=>p.label!=='STEADY'&&p.start<next.start&&p.end>old.start)){
        attempt.reason='已有升降阶段，使用其独立区间';continue;
      }
      const direction=b.envelope.low>a.envelope.high?1:b.envelope.high<a.envelope.low?-1:0;
      if(!direction){attempt.reason='两平台确认样本带宽包络重叠，不能证明阶跃';continue;}
      const inBand=(r,band)=>r.y>=band.low&&r.y<=band.high;
      let j=rr.findIndex(r=>r.u===next.start);
      if(j<0||!rr[j].eligible||!inBand(rr[j],b.envelope)){
        attempt.reason='新平台边界没有合格的对应窗口';continue;
      }
      // Find the complete contiguous suffix at the new independently confirmed level.
      // Recognition delay in this suffix is not the duration of the physical bridge.
      while(j>0&&rr[j-1].u>old.start&&rr[j-1].eligible&&inBand(rr[j-1],b.envelope))j--;
      const newLevelStart=j;
      let k=j-1;
      while(k>=0&&rr[k].u>=old.start&&rr[k].eligible&&!inBand(rr[k],a.envelope)&&
        direction*(rr[k+1].y-rr[k].y)>=0&&rr[newLevelStart].u-rr[k].u<=c.w+c.s)k--;
      if(k<0||rr[k].u<old.start||!rr[k].eligible||!inBand(rr[k],a.envelope)||
        rr[newLevelStart].u-rr[k].u>c.w+c.s){
        attempt.reason='没有连续、单调且跨度不超过 W+S 的旧平台连接；保留待结算前缀';continue;
      }
      const bridge=rr.slice(k,newLevelStart+1);
      if(bridge.some((r,idx)=>!r.eligible||(idx&&direction*(r.y-bridge[idx-1].y)<0))){
        attempt.reason='连接区间不连续或存在反向变化';continue;
      }
      const start=rr[k+1].u;
      if(start>=next.start){attempt.reason='没有需要豁免的确认前区间';continue;}
      const proof={oldPhase:old.id,newPhase:next.id,start,end:next.start,
        reason:'独立阶段证据确认的平台阶跃',confirmation:b.qualification.confirmation,
        oldEnvelope:a.envelope,newEnvelope:b.envelope,
        oldSupport:a.supportSeqs,newSupport:b.supportSeqs,
        bridge:{start:rr[k].u,end:rr[newLevelStart].u,span:rr[newLevelStart].u-rr[k].u,
          maximum:c.w+c.s,seqs:bridge.map(r=>r.seq)},
        recognitionSuffix:{start:rr[newLevelStart].u,end:next.start},
        retainedPrefix:{start:old.start,end:start}};
      steps.push(proof);attempt.accepted=true;attempt.reason=proof.reason;
    }
    return {platforms,steps,attempts};
  }
  function check(records, phases, c, meta = {}) {
    if (meta.enabled === false) return {status:rank(['STATISTICS_ONLY',...(meta.otherStatuses||[])]),
      platforms: [], exclusions: [], finalRecords: []};
    const unique = [], seen = new Set();
    for (const r of records) if (!seen.has(r.seq)) { unique.push(r); seen.add(r.seq); }
    const steady = phases.filter(p => p.label === 'STEADY');
    const attribution=ownership(unique,phases,c);
    const exclusions = phases.filter(p => p.label === 'RAMP' || p.label === 'FALL')
      .map(p => ({start: p.start, end: p.end, reason: '独立确认的 ' + p.label,
        confirmation: p.confirm})).concat(attribution.steps);
    const platforms = steady.map((p, pi) => {
      const next = steady.slice(pi+1).find(q=>attribution.platforms.find(v=>v.id===q.id).canHandoff);
      const stop = next ? next.start : (meta.end === undefined ? Infinity : meta.end);
      const owned = unique.filter(r => r.u >= p.start && r.u < stop);
      const excluded = r => exclusions.some(x => r.u >= x.start && r.u < x.end);
      let ref = [], reference = null;
      for (const r of owned) {
        if (!r.eligible || r.left < p.start || r.u >= p.end) { ref = []; continue; }
        ref.push(r);
        ref = ref.slice(-c.referenceCount);
        if (ref.length >= c.referenceCount && r.u - ref[0].u >= c.minSpan) {
          reference = ref.slice(); break;
        }
      }
      const key = [meta.type || 'point', meta.id || 'demo', meta.reset || 0,
        meta.episode || 1, p.id].join(':');
      const out = {key, phase: clone(p), checking: {start: p.start, end: stop,
          handoffPhase:next?next.id:null,retainedShortPlatforms:steady.slice(pi+1)
            .filter(q=>q.start<stop).map(q=>q.id)},
        referenceSamples: reference || [], B: null, threshold: null, thresholdPct: 5,
        dMax: null, pMax: null, runs: [], evidence: [], status: 'WARNING', reasons: [],
        quality: [], longestSpan: 0, adequateCoverage: false};
      if (!reference) { out.reasons.push('无连续且整个窗口位于平台内的足够参考样本'); return out; }
      const B = mean(reference.map(r => r.y)); out.B = B; out.threshold = .05 * B;
      if (B === 0) { out.reasons.push('零参考：百分比不适用'); return out; }
      if (!(B > 0) || !Number.isFinite(B)) { out.reasons.push('参考数值无效'); return out; }
      let run = [], coverage = [];
      const flush = () => {
        if (run.length) {
          const span = run[run.length - 1].u - run[0].u;
          out.runs.push({start: run[0].u, end: run[run.length - 1].u,
            count: run.length, span, sustained: run.length >= 2 && span >= c.w,
            seqs: run.map(r => r.seq)});
          out.longestSpan = Math.max(out.longestSpan, span);
          run = [];
        }
      };
      for (const r of owned) {
        if (excluded(r)) { flush(); coverage = []; out.evidence.push({seq:r.seq,u:r.u,excluded:true}); continue; }
        if (!r.eligible) {
          flush(); coverage = []; out.quality.push({u:r.u,reason:r.reason || '证据不完整'});
          out.evidence.push({seq:r.seq,u:r.u,invalid:true}); continue;
        }
        coverage.push(r);
        if (coverage.length >= 2 && r.u - coverage[0].u >= c.w) out.adequateCoverage = true;
        const d = Math.abs(r.y - B), over = d > .05 * B;
        out.dMax = Math.max(out.dMax === null ? 0 : out.dMax, d);
        out.pMax = Math.max(out.pMax === null ? 0 : out.pMax, 100 * d / B);
        out.evidence.push({seq:r.seq,u:r.u,y:r.y,d,p:100*d/B,over,
          reference: reference.some(v => v.seq === r.seq)});
        if (over) run.push(r); else flush();
      }
      flush();
      if (meta.incomplete && !next) out.quality.push({reason:meta.incomplete});
      if (out.runs.some(r => r.sustained)) {
        out.status = 'FAIL'; out.reasons.push('存在独立有效的持续超限证据');
      } else if (out.quality.length || !out.adequateCoverage) {
        out.reasons.push(out.quality.length ? '检查区间存在质量缺口或截断' : '有效检查覆盖不足 W');
      } else { out.status = 'PASS'; out.reasons.push('覆盖足够且没有持续超限'); }
      return out;
    });
    const usable=platforms.some(p=>p.B>0&&Number.isFinite(p.B));
    const warning=meta.noEpisode?'范围内未产生过程':'过程没有可用平台或有效参考';
    const finalRecords=usable?platforms:[{key:[meta.type||'point',meta.id||'demo',meta.reset||0,
      meta.noEpisode?'scope':meta.episode||1,'warning'].join(':'),status:'WARNING',reasons:[warning]}];
    return {status: rank(finalRecords.map(p => p.status).concat(meta.otherStatuses || [])),
      platforms, exclusions, attribution, finalRecords, warning:usable?null:warning};
  }
  function rank(statuses) {
    if (!statuses.length) return 'WARNING';
    return ['FAIL','WARNING','PASS','STATISTICS_ONLY'].find(s => statuses.includes(s));
  }
  function assess(records, result, goals) {
    const expectations = goals.map(g => {
      const eligible = records.filter(r => r.expectedKey === g.key && r.eligible);
      if (eligible.length < 8) return {...g, count: eligible.length,
        result: g.required ? 'FAIL' : 'INSUFFICIENT'};
      const first = eligible[0], deadline = eligible[7];
      const matched = result.phases.find(p => p.label === g.label && p.confirm <= deadline.u &&
        p.end > first.u && (!g.newPhase || p.start >= g.inputU));
      return {...g, count:eligible.length, first:first.u, deadline:deadline.u,
        firstTime:first.t, deadlineTime:deadline.t,
        phaseId:matched?matched.id:null,
        boundary:matched ? matched.start : null, confirmation:matched ? matched.confirm : null,
        updateLatency:matched ? Math.max(1, eligible.filter(r => r.u <= matched.confirm).length) : null,
        physicalLatency:matched ? Math.max(0, matched.confirmTime - first.t) : null,
        inputToConfirmation:matched ? matched.confirmTime - g.inputTime : null,
        result:matched ? 'PASS' : 'FAIL'};
    });
    const wrong = result.phases.filter(p => {
      const r = records.find(r => r.u === p.start);
      return r && r.allowed && !r.allowed.includes(p.label);
    });
    const extra = [];
    for (const g of goals.filter(g => g.required)) {
      const rr = records.filter(r => r.expectedKey === g.key);
      if (!rr.length) continue;
      const matched=expectations.find(e=>e.key===g.key);
      if(!matched||matched.phaseId===null||matched.phaseId===undefined)continue;
      const states = result.trace.filter(p => p.u >= Math.max(rr[0].u,matched.confirmation) && p.u <= rr[rr.length-1].u);
      const switches = states.slice(1).filter((p,i) => p.current !== states[i].current||p.phaseId!==states[i].phaseId);
      if (switches.length) extra.push({key:g.key,changes:switches,extra:switches.length});
    }
    return {expectations, wrong, extra,
      passed: expectations.every(g => g.result !== 'FAIL') && !wrong.length && !extra.length};
  }
  function settle(results) {
    const unique = new Map();
    for (const p of results) if (!unique.has(p.key)) unique.set(p.key,p);
    const entries=[...unique.values()];
    return {status:rank(entries.map(p=>p.status)),count:entries.length,
      counts:Object.fromEntries(['FAIL','WARNING','PASS','STATISTICS_ONLY'].map(s=>[s,entries.filter(p=>p.status===s).length]))};
  }
  return {candidates, config, phase, ownership, check, control, rank, assess, mean, settle};
})();
if (typeof module !== 'undefined') module.exports = PV;
