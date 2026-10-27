/* Four fixed inputs, declared before the single measured run. No seeds/sweep. */
const P = require('./model.js');
function fixtures() {
  let serial = 0;
  const steady = (ticks, value, key, extra = {}) => ({ticks,value,label:'STEADY',key,...extra});
  const ramp = (ticks, from, to, key) => ({ticks,from,to,label:to>from?'RAMP':'FALL',key});
  const quiet = ticks => ({ticks,value:0,events:0});
  const families = [
    {id:'continuous',name:'清晰连续变化',type:'point',scope:'tb.point',basis:'ns',w:10,s:10,q:10,base:100,
      description:'单点，每周期 100 字节量级；恒定、阶跃、16 个窗口的升降与重复平台。',cases:[
        {name:'恒定、阶跃、下降、爬坡及重复平台',segments:[
          steady(160,100,'c1',{newPhase:true}),steady(160,200,'c2',{newPhase:true}),
          ramp(160,200,100,'fall'),steady(160,100,'c3',{newPhase:true}),
          ramp(160,100,200,'ramp'),steady(160,200,'c4',{newPhase:true}),quiet(12)]},
        {name:'恰好十二个完整窗口的平台',segments:[steady(120,100,'short1',{newPhase:true}),
          steady(120,200,'short2',{newPhase:true}),quiet(12)]}
      ]},
    {id:'platforms',name:'波动平台',type:'group',scope:'tb.group4',basis:'cycle',w:10,s:10,q:10,base:400,
      description:'一个四成员组，各成员 100 字节量级；窗口口径交替 ±2%、±8%。',cases:[
        {name:'交替 ±2% 长平台',segments:[steady(240,400,'micro',{alternating:.02,noChatter:true}),quiet(12)]},
        {name:'交替 ±8% 长平台',segments:[steady(240,400,'alt8',{alternating:.08,noChatter:true}),quiet(12)]},
        {name:'早期波动失败后出现新平台',segments:[steady(240,400,'firstfail',{alternating:.08,noChatter:true}),
          steady(180,800,'lastpass',{newPhase:true}),quiet(12)]}
      ]},
    {id:'activity',name:'活动与短过程',type:'point',scope:'tb.point',basis:'cycle',w:10,s:1,q:10,base:100,
      description:'显式密集步长 S=1；三周期暂停、短突发、零字节活动与无活动。',cases:[
        {name:'短暂停顿后恢复同一过程',segments:[steady(80,100,'beforepause'),quiet(3),steady(80,100,'afterpause'),quiet(12)]},
        {name:'证据不足的三周期短突发',segments:[steady(3,100,'burst'),quiet(15)]},
        {name:'零字节传输维持零带宽平台',segments:[steady(90,0,'zero',{events:1,noChatter:true}),quiet(12)]},
        {name:'完全没有传输',segments:[quiet(60)]},
        {name:'密集发布的持续升降',segments:[steady(50,100,'dense1'),ramp(27,100,200,'denseup'),
          steady(60,200,'dense2',{newPhase:true}),ramp(27,200,100,'densedown'),steady(60,100,'dense3',{newPhase:true}),quiet(12)]}
      ]},
    {id:'recovery',name:'证据中断与恢复',type:'group',scope:'tb.group4',basis:'ns',w:10,s:1,q:10,base:400,
      description:'同一个四成员组，密集发布；缺口、复位隔离，以及未判定异常回到原平台。',cases:[
        {name:'观测缺口与复位后重新积累',segments:[steady(80,400,'beforegap'),
          {ticks:1,value:400,known:0},steady(90,400,'recover',{newPhase:true}),
          {ticks:1,value:0,events:0,reset:1},steady(90,400,'afterreset',{newPhase:true}),quiet(12)]},
        {name:'偏离后回到原平台的保留证据',segments:[steady(100,400,'base'),
          {ticks:26,value:400,pattern:[0,0,800,800,800,0,800,0,800,800,0,0,0],key:'anomaly'},
          steady(100,400,'return'),quiet(12)]},
        {name:'持续异常跨短平台后回到原平台',segments:[steady(100,400,'sustainedbase'),
          {ticks:52,value:0,pattern:[1200,0,0,0,0,0,0,0,0,0,0,0,0],key:'sustained_anomaly'},
          steady(100,400,'sustainedreturn'),quiet(12)]}
      ]}
  ];
  const expectedChecker=[['PASS'],['PASS','WARNING'],['PASS'],['FAIL'],['FAIL'],
    ['FAIL'],['WARNING'],['WARNING'],['WARNING'],['PASS'],['WARNING'],['PASS'],['FAIL']];
  for (const f of families) for (const c of f.cases) {
    c.id = ++serial; c.rows = []; c.goals = [];
    c.expectedChecker=expectedChecker[serial-1];
    c.expectedCheckerNote=c.expectedChecker?'预先固定的最终检查期望':
      '短暂停顿需依据独立确认的升降归属定稿；不得仅因暂停而豁免，未给定单一结果';
    if(serial===6)c.expectedCheckerNote='旧参考下 u=81…92 连续超限跨度11，短平台不得切断证据';
    if(serial===12)c.expectedCheckerNote='保留第一轮原输入；其实际窗口最大连续超限跨度8<W，纠正错误 FAIL 期望为 PASS';
    if(serial===13)c.expectedCheckerNote='新增固定的持续异常：在完整位于52周期异常块的窗口中，值仅0或120，连续偏离原400参考超过W；不替换旧输入';
    let u = 0;
    for (const seg of c.segments) {
      const start = u;
      if (seg.key && seg.label) c.goals.push({key:seg.key,label:seg.label,inputU:start,
        newPhase:!!seg.newPhase,noChatter:!!seg.noChatter,required:seg.ticks>=f.w+7*f.s});
      for (let i=0;i<seg.ticks;i++) {
        let y = seg.from === undefined ? seg.value : seg.from + (seg.to-seg.from)*(i+.5)/seg.ticks;
        if (seg.alternating) y *= 1 + (Math.floor(i/10)%2 ? seg.alternating : -seg.alternating);
        if (seg.pattern) y = seg.pattern[i%seg.pattern.length];
        // Inputs are actual integer accounted bytes, shared equally by the four members.
        const member = Math.round(y/(f.type==='group'?4:1));
        c.rows.push({u:++u,members:f.type==='group'?[member,member,member,member]:[member,0,0,0],
          events:seg.events===undefined?1:seg.events,known:seg.known===undefined?1:seg.known,
          reset:seg.reset||0,key:seg.key||null,label:seg.label||null,segmentStart:start,
          allowed:seg.label ? [seg.label] : ['STEADY','RAMP','FALL']});
      }
    }
  }
  return families;
}

function contracts() {
  const specs=[];
  const c=P.config('pair6',{w:10,s:10,q:10,basis:'ns'});
  function add(name, values, expected, opt={}) {
    const cc={...c,...opt.config};
    const ys=opt.noPrefix?values:[100,100,100,100,100,100].concat(values);
    let records=ys.map((y,i)=>({seq:i+1,u:(i+1)*cc.s,t:(i+1)*cc.s,left:(i+1)*cc.s-cc.w,
      y:y===null?100:y,eligible:y!==null,reason:y===null?'人工插入的观测缺口':''}));
    if(opt.records)records=opt.records;
    const end=records.length?Math.max(...records.map(r=>r.u))+1:1;
    let phases=opt.phases===undefined?[{id:1,label:'STEADY',start:0,end,confirm:0,confirmTime:0}]:opt.phases;
    specs.push({name,expected,config:cc,records,phases,meta:{end,...opt.meta},
      provenance:'定向检查器输入：平台归属为人工给定，不作为阶段识别证据'});
  }
  add('高侧低于阈值 104.9',[104.9,104.9,100],'PASS');
  add('高侧恰好等于阈值 105',[105,105,100],'PASS');
  add('低侧恰好等于阈值 95',[95,95,100],'PASS');
  add('高侧 105.1 持续恰好 W',[105.1,105.1],'FAIL');
  add('低侧 94.9 持续恰好 W',[94.9,94.9],'FAIL');
  add('单条 106 后恢复',[106,100,100],'PASS');
  add('双向交替 106 和 94',[106,94,106,94],'FAIL');
  add('106、缺口、106 不拼接',[106,null,106],'WARNING');
  add('有效失败之后出现缺口',[106,106,null,100],'FAIL');
  add('参考建立期本身交替 ±8%',[92,108,92,108,92,108,92,108],'FAIL',{noPrefix:true});
  add('零参考',[0,0,0,0,0,0,0,0],'WARNING',{noPrefix:true});
  add('正的近零参考',[1e-12,1e-12,1e-12,1e-12,1e-12,1e-12,1.049e-12,1.049e-12],'PASS',{noPrefix:true});
  add('单个样本没有参考',[100],'WARNING',{noPrefix:true});
  add('短平台无完整参考',[100,100,100,100],'WARNING',{noPrefix:true,phases:[{id:1,label:'STEADY',start:20,end:41,confirm:30}]});
  add('没有稳定平台',[100,100],'WARNING',{phases:[]});
  add('整个范围没有过程',[],'WARNING',{noPrefix:true,phases:[],meta:{noEpisode:true}});
  add('截断且没有独立失败',[100,100],'WARNING',{meta:{incomplete:'仿真截断'}});
  add('复位前已有有效失败',[106,106],'FAIL',{meta:{incomplete:'复位截断'}});
  add('分析关闭无其他规则',[],'STATISTICS_ONLY',{noPrefix:true,meta:{enabled:false}});
  add('显式其他检查 PASS 不覆盖默认 FAIL',[106,106],'FAIL',{meta:{otherStatuses:['PASS']}});
  add('旧快照重复读取不增加证据',[],'WARNING',{noPrefix:true,
    records:[1,2,3,4].map(delivery=>({seq:1,u:10,t:10,left:0,y:106,eligible:true,delivery:delivery*100}))});
  for(const length of [3,11]) {
    const ys=Array(70).fill(100).concat(Array(length).fill(106),Array(15).fill(100));
    add('密集发布连续超限 '+length+' 条',ys,length===11?'FAIL':'PASS',
      {noPrefix:true,config:{s:1,minSpan:5}});
  }
  const delivered=[100,100,100,100,100,100,106,106].map((y,i)=>({seq:i+1,u:(i+1)*10,
    t:(i+1)*10,left:i*10,y,eligible:true,delivery:1000}));
  add('组延迟交付按原逻辑端点检查',[],'FAIL',{noPrefix:true,records:delivered,
    meta:{type:'group',id:'same.id'}});
  add('同名 point 仍独立检查',[100,100],'PASS',{meta:{type:'point',id:'same.id'}});
  const rp=[100,100,100,100,100,100,106,106,110,120,120,120,120,120,120,120,120,120]
    .map((y,i)=>({seq:i+1,u:(i+1)*10,t:(i+1)*10,left:i*10,y,eligible:true}));
  add('先 FAIL 后 PASS 的全部平台',[],'FAIL',{noPrefix:true,records:rp,phases:[
    {id:1,label:'STEADY',start:0,end:90,confirm:10},
    {id:2,label:'RAMP',start:90,end:100,confirm:100},
    {id:3,label:'STEADY',start:100,end:181,confirm:110}]});
  const trans=[100,100,100,100,100,100,105,110,115,120,120,120,120,120,120,120,120,120]
    .map((y,i)=>({seq:i+1,u:(i+1)*10,t:(i+1)*10,left:i*10,y,eligible:true}));
  add('独立确认升降的归属豁免',[],'PASS',{noPrefix:true,records:trans,phases:[
    {id:1,label:'STEADY',start:0,end:70,confirm:10},
    {id:2,label:'RAMP',start:70,end:110,confirm:80},
    {id:3,label:'STEADY',start:110,end:181,confirm:120}]});
  add('退出稳定但未获过渡豁免',[106,106,100,100],'FAIL',{phases:[
    {id:1,label:'STEADY',start:0,end:70,confirm:10}]});
  const records=ys=>ys.map((y,i)=>({seq:i+1,u:(i+1)*10,t:(i+1)*10,left:i*10,y,eligible:true}));
  const stepPhases=[{id:1,label:'STEADY',start:60,end:170,confirm:70},
    {id:2,label:'STEADY',start:220,end:321,confirm:230}];
  add('新平台独立证据支持 100→120 阶跃',[],'PASS',{noPrefix:true,
    records:records(Array(16).fill(100).concat(Array(16).fill(120))),phases:stepPhases});
  add('正常阶跃不能擦掉先前的持续异常',[],'FAIL',{noPrefix:true,
    records:records(Array(12).fill(100).concat([106,106,100,100],Array(16).fill(200))),phases:stepPhases});
  const shortRecords=Array.from({length:162},(_,i)=>{const u=i+1;
    const y=u===81||u===92?90:u===82||u===91?80:u>=83&&u<=90?70:100;
    return {seq:u,u,t:u,left:u-10,y,eligible:u>=10};});
  add('无参考短平台不得切断 u81…92 的持续超限',[],'FAIL',{noPrefix:true,
    config:{s:1,minSpan:5},records:shortRecords,phases:[
      {id:1,label:'STEADY',start:15,end:82,confirm:16},
      {id:2,label:'STEADY',start:88,end:91,confirm:89},
      {id:3,label:'STEADY',start:98,end:163,confirm:99}]});
  add('最终裁剪使新平台不足 W 时撤回交接',[],'FAIL',{noPrefix:true,
    records:records(Array(16).fill(100).concat(Array(16).fill(200))),
    phases:[stepPhases[0],{...stepPhases[1],end:225}],meta:{end:225,incomplete:'仿真截断'}});
  return specs;
}
module.exports={fixtures,contracts};
