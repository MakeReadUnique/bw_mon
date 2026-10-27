#!/usr/bin/env node
// Single cold-build command; one 900 s deadline including preparation and cleanup.
const start=process.hrtime.bigint();
const fs=require('node:fs'), path=require('node:path'), cp=require('node:child_process');
const os=require('node:os'), crypto=require('node:crypto');
const root=__dirname, out=path.resolve(process.argv[2]||path.join(root,'evidence'));
const elapsed=()=>Number(process.hrtime.bigint()-start)/1e9;
if(fs.existsSync(out))throw Error('Output exists. This command will not restart the recorded budget.');
fs.mkdirSync(out,{recursive:true});
const budget={started:new Date().toISOString(),limitSeconds:900,stages:[],environment:{
  node:process.version,os:os.type(),release:os.release(),arch:os.arch(),
  cpu:os.cpus()[0].model,baseline:'fa20d9cb15731e68255d83fb80f950f62c24fb9c'},
  command:'node rtl/prototype-phase-variation/run.js',sourceHashes:{}};
const write=(name,v)=>fs.writeFileSync(path.join(out,name),typeof v==='string'?v:JSON.stringify(v,null,2)+'\n');
function step(name,fn){const at=elapsed();if(at>=900)throw Error('Budget exhausted before '+name);
  write('progress.json',{...budget,currentStep:name,elapsed:at});
  const value=fn();budget.stages.push({name,seconds:elapsed()-at});return value;}
function exec(name,cmd,args,cwd){
  const remaining=Math.floor((900-elapsed())*1000);
  if(remaining<=0)throw Error('900 s budget exhausted before '+name);
  const r=cp.spawnSync(cmd,args,{cwd,encoding:'utf8',timeout:remaining,killSignal:'SIGKILL',maxBuffer:8*1024*1024});
  write(name+'.log',(r.stdout||'')+(r.stderr||''));
  if(r.error||r.status!==0)throw Error(name+': '+(r.error||'exit '+r.status));
  return r.stdout;
}
let data=null, build=path.join(out,'cold-build');
try {
  const P=require('./model.js'), F=require('./fixtures.js');
  const families=step('固定输入生成与工具准备',()=>{
    for(const name of ['model.js','fixtures.js','window_probe.sv','run.js','demo.template.html'])
      budget.sourceHashes[name]=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,name))).digest('hex');
    const families=F.fixtures();
    fs.mkdirSync(build);
    for(const f of families){
      write('input-'+f.id+'.json',f);
      write('input-'+f.id+'.txt',f.cases.flatMap(c=>c.rows.map(r=>
        [c.id,r.u,...r.members,r.events,r.known,r.reset].join(' '))).join('\n')+'\n');
    }
    write('frozen-plan.json',{candidates:P.candidates.map(c=>({candidate:c.id,
      configs:families.map(f=>({family:f.id,...P.config(c.id,f)}))})),
      cases:families.map(f=>({family:f.id,cases:f.cases.map(c=>({name:c.name,goals:c.goals,
        expectedChecker:c.expectedChecker,expectedCheckerNote:c.expectedCheckerNote}))})),
      numericContracts:F.contracts(),sourceHashes:budget.sourceHashes,
      scope:'四份固定输入，两个预先声明候选；没有参数扫描、随机种子或第二次专项。'});
    return families;
  });
  step('一次 VCS 冷编译',()=>exec('compile','vcs',['-full64','-sverilog','-timescale=1ns/1ps',
    '-top','window_probe','-o',path.join(build,'simv'),path.join(root,'window_probe.sv')],build));
  const csvs=step('同一个 simv 执行四份输入',()=>families.map(f=>{
    const stdout=exec('simulation-'+f.id,path.join(build,'simv'),['-no_save',
      '+INPUT='+path.join(out,'input-'+f.id+'.txt'),'+OUTPUT='+path.join(out,'windows-'+f.id+'.csv'),
      '+STRIDE='+f.s,'+GROUP='+(f.type==='group'?1:0)],build);
    if(!stdout.includes('PROTOTYPE_WINDOW_PROBE_COMPLETE')||stdout.includes('Fatal:'))throw Error('Incomplete simulation '+f.id);
    return fs.readFileSync(path.join(out,'windows-'+f.id+'.csv'),'utf8').trim().split('\n').filter(Boolean).map(line=>{
      const [caseId,u,t,y,full,known]=line.split(',').map(Number);return {caseId,u,t,y,full:!!full,known:!!known};
    });
  }));
  data=step('窗口独立对照、候选模型、检查器与完整核验',()=>{
    const result={provenance:{window:'真实 VCS 原型滑窗探针输出，非产品 RTL',
      behavior:'Node 执行的候选阶段/检查器行为模型',
      contract:'人工指定阶段归属的定向数值检查；不证明真实阶段豁免正确'},
      families:[],contracts:[],controls:[],candidateSummary:[],windowComparison:{count:0,mismatches:[]},
      limitations:[
        '正式 bw_stats_core / bw_check_report 尚未实现新默认；本证据不能视为产品回归通过。',
        '点/四成员组是固定 1 ns 采样、精确整数计量的原型；未验证实际注册、cfg 创建组、DPI、Verdi、规模、变频或资源上限。',
        '正常平台切换的待判定区间未获得自动豁免；候选仅豁免已独立确认的 RAMP/FALL 区间，可能留下正常过渡误报。',
        '候选 B 相邻配对只评估固定交替输入；没有证明任意随机 ±8% 序列。',
        '全零特判和纯相对系数需要改变内部校验；现有 trend_abs > steady_exit_abs 约束不允许直接套入。',
        '最终窗口按 [阶段起点,阶段终点) 的发布时间归属；结束边界上的窗口不计入离开平台。',
        '候选通过情况基于预先固定窗口参考，失败样本没有删除，未进行失败后调参重跑。'
      ]};
    for(let fi=0;fi<families.length;fi++){
      const f=families[fi], vf={...f,cases:[]};
      const wanted=new Set(f.cases.flatMap(c=>c.rows.filter(r=>r.u%f.s===0).map(r=>c.id+':'+r.u)));
      const actualKeys=csvs[fi].map(r=>r.caseId+':'+r.u);
      if(actualKeys.length!==wanted.size || new Set(actualKeys).size!==wanted.size || actualKeys.some(k=>!wanted.has(k)))
        throw Error('Missing, duplicate, or unexpected VCS publications in '+f.id);
      const byCase=new Map();for(const v of csvs[fi]){if(!byCase.has(v.caseId))byCase.set(v.caseId,[]);byCase.get(v.caseId).push(v);}
      for(const rawCase of f.cases){
        const samples=byCase.get(rawCase.id)||[], at=new Map(samples.map(s=>[s.u,s]));
        let history=[], active=null, quiet=0, epIndex=0, resetEpoch=0;
        const episodes=[], windows=[];
        const close=(end,reason)=>{if(active){active.end=end;active.endReason=reason;active=null;}quiet=0;};
        for(const row of rawCase.rows){
          if(row.reset){close(row.u-1,'复位截断');history=[];resetEpoch++;}
          if(row.known && row.events){
            if(!active){active={id:++epIndex,start:row.u-1,end:null,tail:row.u,reset:resetEpoch};episodes.push(active);}
            active.tail=row.u;quiet=0;
          }else if(!row.known)quiet=0;
          else if(active){quiet++;if(quiet>=f.q)close(active.tail,'正常静默结束');}
          const tagged={...row,episode:active?active.id:null};history.push(tagged);history=history.slice(-f.w);
          if(!at.has(row.u))continue;
          const v=at.get(row.u), expectedY=history.reduce((s,r)=>s+r.members.reduce((a,b)=>a+b,0),0)/history.length;
          const full=history.length===f.w, known=history.every(r=>r.known);
          result.windowComparison.count++;
          if(v.y!==expectedY || v.full!==full || v.known!==known)
            result.windowComparison.mismatches.push({family:f.id,case:rawCase.id,u:row.u,expectedY,actual:v,full,known});
          const foreign=active && history.some(r=>r.events&&r.episode!==active.id);
          const same=history.every(r=>r.key===row.key);
          const eligible=!!active&&full&&known&&!foreign;
          const reason=!active?'尚无活动过程':!full?'窗口预热':!known?'字节观测不完整':foreign?'混入其他过程':'';
          const record={...v,seq:windows.length+1,left:row.u-f.w,eligible,reason,
            episode:active?active.id:null,expectedKey:eligible&&same?row.key:null,
            allowed:eligible&&same?row.allowed:null,delivery:v.t};
          windows.push(record);
          if(active && !active.firstTime)active.firstTime=v.t-(v.u-active.start);
        }
        if(active)close(active.tail,'仿真截断');
        const timeOffset=samples.length?samples[0].t-samples[0].u:0;
        const goals=rawCase.goals.map(g=>({...g,inputTime:timeOffset+g.inputU}));
        const vc={id:rawCase.id,name:rawCase.name,rows:rawCase.rows,goals,windows,episodes,
          expectedChecker:rawCase.expectedChecker,expectedCheckerNote:rawCase.expectedCheckerNote,candidates:{}};
        for(const candidate of P.candidates){
          const config=P.config(candidate.id,f), runs=[];
          for(const ep of episodes){
            const phaseInput=windows.filter(r=>r.episode===ep.id);
            const rr=phaseInput.filter(r=>r.u<ep.end);
            const ph=P.phase(phaseInput,config,ep.end);
            const target=goals.filter(g=>g.inputU>=ep.start&&g.inputU<ep.end);
            const quality=P.assess(rr,ph,target);
            const checker=P.check(rr,ph.phases,config,{end:ep.end,type:f.type,id:f.scope,
              reset:rawCase.id*100+ep.reset,episode:ep.id,
              incomplete:ep.endReason==='正常静默结束'?null:ep.endReason});
            runs.push({episode:ep,phase:ph,quality,checker});
          }
          if(!episodes.length)runs.push({episode:null,phase:{phases:[],trace:[]},
            quality:{expectations:[],wrong:[],extra:[],passed:true},
            checker:P.check([],[],config,{noEpisode:true,end:rawCase.rows.length})});
          const shortOrNone=rawCase.name==='证据不足的三周期短突发'||rawCase.name==='完全没有传输';
          const noInventedPhase=!shortOrNone||runs.every(r=>r.phase.phases.length===0);
          const ledger=runs.flatMap(r=>r.checker.finalRecords), once=P.settle(ledger), replay=P.settle(ledger.concat(ledger));
          const checkerStatus=P.rank(runs.map(r=>r.checker.status));
          vc.candidates[candidate.id]={config,runs,noInventedPhase,
            finalReplayIdempotent:JSON.stringify(once)===JSON.stringify(replay),
            phasePassed:runs.every(r=>r.quality.passed)&&noInventedPhase,
            checkerStatus,checkerMatchesExpected:rawCase.expectedChecker?
              rawCase.expectedChecker.includes(checkerStatus):null,settlement:once};
        }
        vf.cases.push(vc);
      }
      result.families.push(vf);
    }
    for(const s of F.contracts()){
      const actual=P.check(s.records,s.phases,s.config,s.meta);
      result.contracts.push({...s,actual,passed:actual.status===s.expected});
    }
    for(const [episode,phaseEnabled,expected] of [[false,undefined,'STATISTICS_ONLY'],[true,undefined,'ANALYZE'],
      [true,false,'STATISTICS_ONLY'],[true,true,'ANALYZE'],[false,true,'CONFIG_ERROR']]){
      const actual=P.control(episode,phaseEnabled);result.controls.push({episode,phaseEnabled:phaseEnabled===undefined?'omitted':phaseEnabled,expected,actual,passed:actual===expected});
    }
    for(const cand of P.candidates){
      const cases=result.families.flatMap(f=>f.cases.map(c=>c.candidates[cand.id]));
      const q=cases.flatMap(c=>c.runs.map(r=>r.quality));
      result.candidateSummary.push({...cand,cases:cases.length,
        phaseCasesPassed:cases.filter(c=>c.phasePassed).length,
        targetDeadlines:q.flatMap(v=>v.expectations).filter(e=>e.required).length,
        targetDeadlineFailures:q.flatMap(v=>v.expectations).filter(e=>e.result==='FAIL').length,
        wrongConfirmations:q.reduce((s,v)=>s+v.wrong.length,0),
        extraSwitches:q.reduce((s,v)=>s+v.extra.reduce((s,x)=>s+x.extra,0),0),
        checkerExpectationFailures:cases.filter(c=>c.checkerMatchesExpected===false).length,
        finalReplayIdempotent:cases.every(c=>c.finalReplayIdempotent),
        approved:false});
    }
    return result;
  });
  step('保存全部输入、逐窗证据与交互图表',()=>{
    write('results.json',data);
    const escape=s=>s.replace(/<\/script/gi,'<\\/script');
    const template=fs.readFileSync(path.join(root,'demo.template.html'),'utf8');
    const html=template.replace('/*__MODEL__*/',()=>fs.readFileSync(path.join(root,'model.js'),'utf8'))
      .replace('/*__DATA__*/',()=> 'const DATA='+escape(JSON.stringify(data))+';');
    fs.writeFileSync(path.join(root,'demo.html'),html);
    let md='# 默认阶段策略与波动检查：一次固定输入原型记录\n\n';
    md+='本记录是实测结果，不是用户决议。候选失败、质量缺口与定向人工归属均保留。\n\n';
    md+='| 候选 | 阶段场景通过 | 期限失败 | 错误确认 | 多余切换 |\n| --- | --- | --- | --- | --- |\n';
    for(const c of data.candidateSummary)md+=`| ${c.name} | ${c.phaseCasesPassed}/${c.cases} | ${c.targetDeadlineFailures}/${c.targetDeadlines} | ${c.wrongConfirmations} | ${c.extraSwitches} |\n`;
    md+=`\nVCS 窗口独立对照：${data.windowComparison.count} 条，${data.windowComparison.mismatches.length} 处不一致。定向 checker 数值输入：${data.contracts.filter(c=>c.passed).length}/${data.contracts.length} 与预期一致。\n\n`;
    md+='| 输入 | 候选 | 阶段 | checker 预期 | checker 实际 |\n| --- | --- | --- | --- | --- |\n';
    for(const f of data.families)for(const c of f.cases)for(const candidate of P.candidates){
      const r=c.candidates[candidate.id];md+=`| ${f.name} / ${c.name} | ${candidate.id} | ${r.phasePassed?'PASS':'FAIL'} | ${c.expectedChecker?c.expectedChecker.join(' / '):'取决于独立过渡归属'} | ${r.checkerStatus} |\n`;
    }
    md+='\n## 证据边界\n\n'+data.limitations.map(s=>'- '+s).join('\n')+'\n';
    write('REPORT.md',md);
  });
}catch(e){budget.error=e.stack;process.exitCode=1;write('failure.txt',e.stack+'\n');}
finally{
  step('清理冷构建产物',()=>{fs.rmSync(build,{recursive:true,force:true});});
  budget.totalSeconds=elapsed();budget.withinBudget=budget.totalSeconds<=900;
  budget.complete=!!data&&!budget.error;
  write('budget.json',budget);
  if(data)fs.appendFileSync(path.join(out,'REPORT.md'),`\n专项墙钟：${budget.totalSeconds.toFixed(3)} 秒（上限 900 秒）；详见 budget.json。\n`);
  console.log(JSON.stringify({budget,candidates:data&&data.candidateSummary,
    windowComparison:data&&data.windowComparison,
    numericContracts:data&&{passed:data.contracts.filter(c=>c.passed).length,total:data.contracts.length}},null,2));
  if(!budget.withinBudget)process.exitCode=1;
}
