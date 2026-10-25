#!/usr/bin/env python3
"""Independent input/leaf-set reference. Python3.6+, no monitor imports or outputs."""
from collections import Counter
from fractions import Fraction as F
from functools import lru_cache
from hashlib import sha256
import json

NS=1000000
PROFILES={
 'common-ns':dict(basis='ns',width=100,stride=10),
 'common-cycle':dict(basis='cycle',width=200,stride=20),
 'common-ns-unknown':dict(basis='ns',width=100,stride=10,variant='unknown'),
 'common-ns-reset':dict(basis='ns',width=100,stride=10,variant='reset'),
 'smoke-ns':dict(basis='ns',width=100,stride=10,roots=1,duration_ns=240),
 'smoke-cycle':dict(basis='cycle',width=200,stride=20,roots=1,duration_ns=240),
 'smoke-unknown':dict(basis='ns',width=100,stride=10,roots=1,duration_ns=240,variant='unknown'),
 'smoke-reset':dict(basis='ns',width=100,stride=10,roots=1,duration_ns=240,variant='reset'),
}

def common_topology(roots=32):
    groups={};point=0
    for parent in range(roots):
        for child in range(7):
            count=5 if child<4 else 4
            groups[parent*7+child]=[('point',p) for p in range(point,point+count)]
            point+=count
        groups[roots*7+parent]=[('group',parent*7+c) for c in range(7)]
    return point,groups

def maximum_topology():
    groups={0:[('point',p) for p in range(16)]}
    for g in range(1,8):groups[g]=[('group',g-1)]+[('point',16+(g-1)*15+k) for k in range(15)]
    for g in range(8,23):groups[g]=[('point',0)]+[('point',128+(g-8)*15+k) for k in range(15)]
    for g in range(23,4096):groups[g]=[('point',1+((g-23)*16+k)%16382) for k in range(16)]
    return 16384,groups

def topology_summary(points,groups):
    @lru_cache(None)
    def leaves(g):
        result=set()
        for kind,member in groups[g]:
            incoming={member} if kind=='point' else leaves(member)
            if result.intersection(incoming):raise ValueError('recursive overlap in input group '+str(g))
            result.update(incoming)
        return frozenset(result)
    @lru_cache(None)
    def depth(g):return 1+max([depth(m) for k,m in groups[g] if k=='group'] or [0])
    parents=Counter(member for members in groups.values() for member in members)
    leaf_sets={g:leaves(g) for g in groups}
    summary=dict(points=points,groups=len(groups),direct_edges=sum(map(len,groups.values())),
                 depth=max(depth(g) for g in groups),max_direct_parents=max(parents.values()),
                 ungrouped_points=[p for p in range(points) if not parents[('point',p)]],
                 recursive_cardinality_histogram=dict(Counter(map(len,leaf_sets.values()))),
                 graph_sha256=sha256(json.dumps(groups,sort_keys=True).encode()).hexdigest())
    return summary,leaf_sets

class Clock:
    def __init__(self,segments):self.segments=tuple(tuple(s) for s in segments);self.edges=sum(s[2] for s in segments)
    def lt(self,t):return sum(min(n,max(0,(t-first+period-1)//period)) for first,period,n in self.segments)
    def le(self,t):return sum(min(n,max(0,(t-first)//period+1)) for first,period,n in self.segments)
    def between(self,a,b):return self.lt(b)-self.lt(a)
    def at(self,k):
        for first,period,n in self.segments:
            if 1<=k<=n:return first+(k-1)*period
            k-=n
        raise IndexError('clock input has no such actual edge_index')

WINDOW_FIELDS=['seq','epoch','left','right','left_cycle','right_cycle','coverage_ticks','coverage_cycles',
               'bytes','events','warmup','full','bytes_complete','events_complete','denominator_valid','window_valid','reset','gbps','bpc']
RAW_FIELDS=['seq','epoch','tick','edge_index','byte_inc','event_inc','bytes_complete','events_complete','reset_points','total_bytes','total_events','source_epoch']
CSV_FIELDS=['kind','index','scope','cardinality','direct_members','checked_windows','checked_records']+['window_'+f for f in WINDOW_FIELDS]+['raw_'+f for f in RAW_FIELDS]+['diff_count']

class Scenario:
    def __init__(self,name,**overrides):
        c=dict(topology='common',roots=32,duration_ns=40000,variant='baseline')
        c.update(PROFILES[name]);c.update({k:v for k,v in overrides.items() if v is not None})
        self.name=name;self.config=c;self.end=c['duration_ns']*NS;self.basis=c['basis'];self.width=c['width'];self.stride=c['stride'];self.variant=c['variant']
        if not (0<self.stride<=self.width) or not (0<c['duration_ns']<=40000):raise ValueError('invalid width/stride/duration')
        self.points,self.groups=maximum_topology() if c['topology']=='max' else common_topology(c['roots'])
        self.topology,self.leaves=topology_summary(self.points,self.groups)
        self.clock=Clock(c.get('clock_segments',[(250000,500000,c['duration_ns']*2)]))
        self.reset_start=100100000;self.reset_end=101100000;self.unknown_tick=100250000
        self.unknown_edge=self.clock.lt(self.unknown_tick)+1
        if self.variant!='baseline' and self.end<=self.reset_end:raise ValueError('variant duration must include interventions')
    def point_id(self,p):return 'tb_bw_scale.points[{}].slot.mon'.format(p)
    def group_id(self,g):return 'scale.g'+str(g)
    def scopes(self):
        for p in range(self.points):yield 'point',p
        for g in self.groups:yield 'group',g
    def meta(self,kind,index):
        leaves={index} if kind=='point' else self.leaves[index]
        return len(leaves),0 in leaves,kind=='point' and index==0
    def identity(self,kind,index):return self.point_id(index) if kind=='point' else self.group_id(index)
    def interval(self,kind,index,left,right):
        m,affected,own=self.meta(kind,index)
        n=self.clock.between(left,right);events=m*n;size=64*events;bc=ec=1;reset=0
        if affected and self.variant=='unknown' and left<=self.unknown_tick<right:size-=64;bc=0
        if affected and self.variant=='reset':
            overlap_left=max(left,self.reset_start);overlap_right=min(right,self.reset_end)
            if overlap_right>overlap_left:
                missing=self.clock.between(overlap_left,overlap_right);size-=64*missing;events-=missing
                reset=int(not own)
        return dict(bytes=size,events=events,bytes_complete=bc,events_complete=ec,reset=reset)
    def counts(self,kind,index):
        _,_,own=self.meta(kind,index)
        if own and self.variant=='reset':
            if self.basis=='ns':return self.reset_start//(self.stride*NS),max(0,(self.end-self.reset_end)//(self.stride*NS))
            pre=(self.clock.lt(self.reset_start)-1)//self.stride
            origin=self.clock.lt(self.reset_end)+1
            return pre,max(0,(self.clock.edges-origin)//self.stride)
        return (self.end//(self.stride*NS) if self.basis=='ns' else (self.clock.edges-1)//self.stride),0
    def window_count(self,kind,index):return sum(self.counts(kind,index))
    def window(self,kind,index,seq):
        pre,post=self.counts(kind,index);_,_,own=self.meta(kind,index)
        after=own and self.variant=='reset' and seq>pre
        rank=seq-pre if after else seq;origin=self.reset_end if after else 0
        if self.basis=='ns':
            right=origin+rank*self.stride*NS;left=max(origin,right-self.width*NS);lc=rc=cc=0;full=right-origin>=self.width*NS
        else:
            anchor=self.clock.lt(origin)+1;rc=anchor+rank*self.stride;lc=max(anchor,rc-self.width)
            left,right=self.clock.at(lc),self.clock.at(rc);cc=rc-lc;full=cc==self.width
        data=self.interval(kind,index,left,right)
        data.update(seq=seq,epoch=int(after),left=left,right=right,left_cycle=lc,right_cycle=rc,coverage_ticks=right-left,coverage_cycles=cc,
                    warmup=int(not full),full=int(full),denominator_valid=int(right>left),window_valid=int(full and data['bytes_complete'] and right>left),
                    gbps=F(data['bytes']*NS,right-left) if right>left else F(0),bpc=F(data['bytes'],cc) if cc else F(0))
        return data
    def raw(self,kind,index,edge_index):
        m,affected,own=self.meta(kind,index);t=self.clock.at(edge_index);epoch=int(own and self.variant=='reset' and t>=self.reset_start)
        left=self.reset_end if epoch else 0
        if epoch and t<self.reset_end:total=dict(bytes=0,events=0)
        else:total=self.interval(kind,index,left,t+1)
        current=self.interval(kind,index,t,t+1)
        return dict(seq=edge_index,epoch=epoch,tick=t,edge_index=edge_index,byte_inc=current['bytes'],event_inc=current['events'],
                    bytes_complete=current['bytes_complete'],events_complete=current['events_complete'],reset_points=int(affected and self.variant=='reset' and self.reset_start<=t<self.reset_end),
                    total_bytes=total['bytes'],total_events=total['events'],source_epoch=int(own and self.variant=='reset' and t>=self.reset_start))
    def final_scope(self,kind,index):
        m,_,_=self.meta(kind,index);count=self.window_count(kind,index)
        row=dict(kind=kind,index=index,scope=self.identity(kind,index),cardinality=m,direct_members=0 if kind=='point' else len(self.groups[index]),
                 checked_windows=count,checked_records=self.clock.edges,diff_count=0)
        row.update({'window_'+k:v for k,v in self.window(kind,index,count).items()})
        row.update({'raw_'+k:v for k,v in self.raw(kind,index,self.clock.edges).items()})
        return row
    def manifest(self):
        return dict(scenario=self.name,config=self.config,topology=self.topology,groups={g:self.groups[g] for g in self.groups},
                    recursive_leaf_sets={g:sorted(self.leaves[g]) for g in self.groups},clock_segments=self.clock.segments,
                    end_ticks=self.end,expected_edges=self.clock.edges,unknown_tick=self.unknown_tick,unknown_edge=self.unknown_edge,
                    reset_interval=[self.reset_start,self.reset_end],timeunit='1fs',timeprecision='1fs',waveform=False,
                    protocol_by_point='index % 3: valid-only,valid-ready,credit',dynamic_by_point='even indexes dynamic; odd fixed64B',
                    bytes_per_transfer=64,credit=dict(enable='credit points',capacity=16,initial=16,initial_known=1,return_timing='NEXT_CYCLE',send=1,return_every_edge=1),
                    hints=dict(backpressure_enable='valid-ready points',shortage_enable='credit points',basis=self.basis,threshold=4 if self.basis=='ns' else 8,expected_hits=0),
                    analysis=dict(episode_enable=1,phase_enable=1,Q=30 if self.basis=='ns' else 60,N=3,min_span=20 if self.basis=='ns' else 40,K=4,
                      steady_enter_abs=0,steady_enter_rel=0,steady_exit_abs=0,steady_exit_rel=0,rms_enter_abs=1e-6,rms_enter_rel=0,rms_exit_abs=1e-6,rms_exit_rel=0,trend_abs=1,trend_rel=0),
                    report=dict(enabled=True,metrics=12,targets='explicit per-scope original cardinality; continuous flow ends TRUNCATED, no forced PASS'),
                    numeric_tolerance=dict(absolute=1e-9,relative=1e-12),acceptance_profile=self.name.startswith('common-') and self.config['roots']==32 and self.config['topology']=='common' and self.config['duration_ns']==40000)
