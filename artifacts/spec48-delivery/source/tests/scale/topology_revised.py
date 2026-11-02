#!/usr/bin/env python3
"""Fixed revised M1–M5 inputs: full topology and independently weighted leaves."""
from fractions import Fraction as F
from pathlib import Path
import argparse
import json
from scenario import Scenario, Clock, NS, topology_summary, maximum_topology

PROFILES = ('topology-quick-ns', 'topology-quick-cycle', 'topology-max-ns', 'topology-max-cycle',
            'topology-quick-cancel-ns', 'topology-max-cancel-ns')


def topology(maximum):
    if maximum:
        points, groups = maximum_topology()
        # Sixteen direct consumers of a real subgroup, including the depth-eight path.
        for g in range(8, 23):
            groups[g] = [('group', 0)] + [('point', 128+(g-8)*15+k) for k in range(15)]
        return points, groups
    groups = {0: [('point', p) for p in range(3)]}
    for g in range(1, 8):
        groups[g] = [('group', g-1), ('point', g+2)]
    for g in range(8, 23):
        groups[g] = [('group', 0), ('point', g+2)]
    for g in range(23, 32):
        groups[g] = [('point', p) for p in range(25+(g-23)*8, 33+(g-23)*8)]
    return 128, groups


class RevisedTopology(Scenario):
    source_module = 'topology_revised'
    compile_options = ['+define+BW_MON_TEST_SCHEDULING']
    active_edges = 384
    group_reset_start = 128100000
    group_reset_end = 129100000
    budget_seconds = 600

    def __init__(self, name):
        if name not in PROFILES:
            raise ValueError(name)
        basis = 'cycle' if name.endswith('cycle') else 'ns'
        super().__init__('common-ns', roots=1, duration_ns=256, basis=basis,
                         width=128 if basis=='cycle' else 16, stride=1, variant='reset',
                         allow_final_steady_selection=True)
        self.name = name
        self.points, self.groups = topology('-max-' in name)
        self.topology, self.leaves = topology_summary(self.points, self.groups)
        self.weights = {g: sum(p+1 for p in leaves) for g, leaves in self.leaves.items()}
        self.unknown_tick = 96250000
        self.unknown_edge = 193
        # M4/H6 same-time consumer-progress interaction, recalibrated for the
        # D7 same-slot settlement: a consumer gate armed inside one sampling
        # slot legally holds that consumer while its fifteen peers consume,
        # and the durable resume continuation finishes the backlog inside the
        # same original slot. A cross-slot pause is impossible by contract
        # (the end-of-slot audit holds the slot open), which is exactly why
        # the pre-spec48 positive-time pause fixture ([99,102)ns, five frames)
        # had to be replaced rather than re-timed.
        self.interaction_source = 0
        self.slow_consumer = 8
        self.gate_edge = 203
        self.cancel_interaction = name.endswith('-cancel-ns')
        self.fast_consumers = sorted(g for g, members in self.groups.items()
                                     if ('group', self.interaction_source) in members
                                     and g != self.slow_consumer)
        self.slow_consumer_ack = self.gate_edge - 1
        self.fast_consumer_ack = self.gate_edge
        self.release_tick = self.clock.at(self.gate_edge)
        # The slow consumer has settled every earlier slot, so exactly the
        # gate slot's own frame is unread there. A member reset control is
        # forwarded in its own stamp slot (point sources never constrain the
        # watermark), so the release control at reset_end is held unread in
        # that slot while no frame exists; the assert control at reset_start
        # settled earlier without any gate.
        self.held_frame_count = 1
        self.control_hold_tick = self.reset_end
        self.held_control_count = 1
        watermark_cap = min(self.release_tick, self.control_hold_tick)
        self.slow_timer_bound_ns = watermark_cap // NS
        self.cancelled_scopes = [self.slow_consumer] if self.cancel_interaction else []
        self.expected_csv_scopes = self.points + len(self.groups) - len(self.cancelled_scopes)
        self.expected_terminal_scopes = self.points + len(self.groups)
        self.config.update(revised_matrix='M1-M5/H6', differentiated_bytes='point_index+1+3*(edge_index%2)',
                           active_edges=self.active_edges, group_reset=[self.group_reset_start,self.group_reset_end],
                           interaction=dict(source='scale.g0', slow_consumer='scale.g8',
                                            fast_consumers=len(self.fast_consumers),
                                            control_hold_tick=self.control_hold_tick,
                                            gate_edge=self.gate_edge,
                                            held_frames=self.held_frame_count,
                                            held_controls=self.held_control_count,
                                            release='each hold released inside its own original slot',
                                            cancellation=('runtime consumer failure after the frame-hold observation; '
                                                          'responsibility cancelled, unread data released, healthy chain continues')
                                            if self.cancel_interaction else None))

    def weight(self, kind, index):
        return index+1 if kind=='point' else self.weights[index]

    def _forward_edge(self, tick):
        """First sampling edge whose slot can forward a control stamped at tick."""
        return self.clock.lt(tick) + 1

    def expected_default_rows(self, kind, index):
        # One row per episode settlement, plus the split the p0 evidence gap
        # forces on every covering scope's first platform (unknown byte at
        # edge 193 and the member reset window both land inside it). Whether
        # the interrupted tail settles as its own row follows the basis'
        # reference width: with W16ns the post-gap platform rebuilds a frozen
        # reference inside the same episode (extra row for every covering
        # scope whose own reset boundary does not already close there), while
        # with W128 cycles the tail cannot build six complete reference
        # windows before the episode ends, so only scopes without their own
        # reset boundary gain the row. Derived from the frozen input graph,
        # reset intervals and the configured width.
        rows = max(len(self.expected_episodes(kind, index)), 1)
        _, hit, _ = self.meta(kind, index)
        own = self.own_reset(kind, index)
        if hit and ((self.basis == 'ns' and own != (self.reset_start, self.reset_end))
                    or (self.basis != 'ns' and own is None)):
            rows += 1
        return rows

    def interrupted_platform_scopes(self):
        """Scopes carrying a WARNING/OBSERVATION_INCOMPLETE default row.

        The interrupted-tail reason only appears in the ns basis; the cycle
        basis settles the same tail as REFERENCE_INSUFFICIENT instead.
        """
        if self.basis != 'ns':
            return set()
        return {self.identity(kind, index) for kind, index in self.scopes()
                if self.meta(kind, index)[1]}

    def own_reset(self, kind, index):
        if index != 0:
            return None
        return ((self.reset_start,self.reset_end) if kind=='point' else
                (self.group_reset_start,self.group_reset_end))

    def reset_owner(self, kind, index):
        return self.own_reset(kind,index) is not None

    def interval(self, kind, index, left, right):
        count, hit, own = self.meta(kind,index)
        before = min(self.active_edges,self.clock.lt(left))
        after = min(self.active_edges,self.clock.lt(right))
        n = max(0,after-before)
        odd = (after+1)//2-(before+1)//2
        size = self.weight(kind,index)*n+3*count*odd
        events = count*n
        complete, reset = 1,0
        if hit and left<=self.unknown_tick<right:
            size -= 4
            complete = 0
        a,b=max(left,self.reset_start),min(right,self.reset_end)
        if hit and a<b:
            lo,hi=self.clock.lt(a),self.clock.lt(b)
            size -= hi-lo+3*((hi+1)//2-(lo+1)//2)
            events -= hi-lo
            reset = int(not own)
        return dict(bytes=size, events=events, bytes_complete=complete, events_complete=1, reset=reset)

    def counts(self, kind, index):
        reset = self.own_reset(kind,index)
        if reset:
            begin,end=reset
            if self.basis=='ns':
                return begin//(self.stride*NS),(self.end-end)//(self.stride*NS)
            return (self.clock.lt(begin)-1)//self.stride,(self.clock.edges-self.clock.lt(end)-1)//self.stride
        return (self.end//(self.stride*NS) if self.basis=='ns' else (self.clock.edges-1)//self.stride),0

    def window(self, kind, index, seq):
        pre,post=self.counts(kind,index)
        after=self.reset_owner(kind,index) and seq>pre
        rank=seq-pre if after else seq
        origin=self.own_reset(kind,index)[1] if after else 0
        lc=rc=cc=0
        if self.basis=='ns':
            right=origin+rank*self.stride*NS;left=max(origin,right-self.width*NS)
            full=right-origin>=self.width*NS
        else:
            anchor=self.clock.lt(origin)+1;rc=anchor+rank*self.stride;lc=max(anchor,rc-self.width)
            left,right=self.clock.at(lc),self.clock.at(rc);cc=rc-lc;full=cc==self.width
        result=self.interval(kind,index,left,right)
        result.update(seq=seq,epoch=int(after),left=left,right=right,left_cycle=lc,right_cycle=rc,
                      coverage_ticks=right-left,coverage_cycles=cc,warmup=int(not full),full=int(full),
                      denominator_valid=int(right>left),window_valid=int(full and result['bytes_complete'] and right>left),
                      gbps=F(result['bytes']*NS,right-left) if right>left else F(0),bpc=F(result['bytes'],cc) if cc else F(0))
        return result

    def raw(self, kind, index, edge_index):
        tick=self.clock.at(edge_index);reset=self.own_reset(kind,index)
        epoch=int(reset is not None and tick>=reset[0])
        origin=reset[1] if epoch else 0
        current=self.interval(kind,index,tick,tick+1)
        total=dict(bytes=0,events=0) if epoch and tick<origin else self.interval(kind,index,origin,tick+1)
        _,hit,own=self.meta(kind,index)
        return dict(seq=edge_index,epoch=epoch,tick=tick,edge_index=edge_index,
                    byte_inc=current['bytes'],event_inc=current['events'],bytes_complete=current['bytes_complete'],events_complete=1,
                    reset_points=int(hit and self.reset_start<=tick<self.reset_end),total_bytes=total['bytes'],total_events=total['events'],
                    source_epoch=int(own and tick>=self.reset_start))

    def expected_episodes(self, kind, index):
        reset=self.own_reset(kind,index)
        tail=self.clock.at(self.active_edges+1)
        intervals=[(0,reset[0],0,3),(reset[1],tail,1,2)] if reset else [(0,tail,0,2)]
        result=[]
        for seq,(left,right,epoch,status) in enumerate(intervals,1):
            counts=self.interval(kind,index,left,right)
            first=self.clock.at(self.clock.lt(left)+1)
            duration=tail-first if status==2 else 0
            valid=status==2 and counts['bytes_complete']
            result.append(dict(epoch=epoch,episode=seq,scope_kind=int(kind=='group'),status=status,
                first_ticks=first,last_ticks=self.clock.at(min(self.active_edges,self.clock.lt(right))),
                bytes=counts['bytes'],events=counts['events'],first_known=1,last_known=1,tail_known=int(status==2),
                tail_ticks=tail if status==2 else 0,e2e_valid=int(valid),duration_ticks=duration,
                confirm_ticks=tail+30*NS if status==2 else right,e2e_gbps=F(counts['bytes']*NS,duration) if valid else F(0),
                bytes_complete=counts['bytes_complete'],events_complete=1,member_reset=counts['reset']))
        return result

    def manifest(self):
        value=super().manifest()
        value.update(schema='revised-topology-v1',acceptance_profile='-max-' in self.name,acceptance_ticket=30,
                     properties=['M1','M2','M3','M4','M5','H6'],point_weight='index+1',
                     active_edges=self.active_edges,unknown_tick=self.unknown_tick,
                     same_time_interaction=dict(source='scale.g0',consumers=16,slow='scale.g8',
                                                control_hold_tick=self.control_hold_tick,
                                                gate_edge=self.gate_edge,
                                                slow_ack_at_hold=self.slow_consumer_ack,
                                                retained_frames=self.held_frame_count,
                                                retained_controls=self.held_control_count,
                                                release_tick=self.release_tick,
                                                release='each hold released inside its own original slot',
                                                cancellation=self.cancel_interaction),
                     source_parent_limit=16,history='alternating bytes, actual bounded short-window growth/expiry')
        value['dynamic_by_point']='all points dynamic; three protocols by index modulo3'
        value['bytes_per_transfer']='index+1+3*(edge_index%2); unknown p0 at edge193'
        value['report']['targets']='explicit per-scope inherited performance targets; correctness independent of performance conclusion'
        return value

    def generate(self, out):
        from topology_revised_generate import generate
        generate(self,out)

    def verify(self, out):
        from topology_revised_generate import verify
        return verify(self,out)


def build_scenario(name):
    return RevisedTopology(name)


def _marker_values(line):
    import re
    return dict(re.findall(r'(\w+)=([^\s]+)', line))


def interaction_diffs(log, s):
    """Log-only check of the M4/H6 interaction markers against the frozen schedule."""
    diffs = []

    def markers(prefix):
        return [_marker_values(l) for l in log.splitlines() if l.startswith(prefix)]
    control_hold = markers('TOPOLOGY_BACKLOG_CONTROL ')
    expected_control = dict(source=s.group_id(s.interaction_source), consumers='16',
                            retained_controls='1', retained_frames='0')
    if len(control_hold) != 1:
        diffs.append(dict(error='control_backlog_marker_count', actual=len(control_hold)))
    elif any(control_hold[0].get(k) != v for k, v in expected_control.items()):
        diffs.append(dict(error='control_backlog_marker_values', expected=expected_control,
                          actual=control_hold[0]))
    control_release = markers('TOPOLOGY_CONTROL_RELEASE ')
    if (len(control_release) != 1 or control_release[0].get('original_time') != '1'
            or control_release[0].get('released_controls') != '1'):
        diffs.append(dict(error='control_release_marker', actual=control_release))
    backlog = markers('TOPOLOGY_BACKLOG ')
    expected = dict(source=s.group_id(s.interaction_source), consumers='16',
                    fast_ack=str(s.fast_consumer_ack), slow_ack=str(s.slow_consumer_ack),
                    retained_frames='1', retained_controls='0')
    if len(backlog) != 1:
        diffs.append(dict(error='backlog_marker_count', actual=len(backlog)))
    elif any(backlog[0].get(k) != v for k, v in expected.items()):
        diffs.append(dict(error='backlog_marker_values', expected=expected, actual=backlog[0]))
    if s.cancel_interaction:
        release = markers('TOPOLOGY_CANCEL_RELEASE ')
        health = markers('TOPOLOGY_CANCEL_HEALTHY ')
        done = markers('TOPOLOGY_CANCEL_PASS ')
        if (len(release) != 1 or release[0].get('root') != s.group_id(s.slow_consumer)
                or release[0].get('frames') != '0' or release[0].get('controls') != '0'
                or release[0].get('slow_ack') != str(s.slow_consumer_ack)):
            diffs.append(dict(error='cancel_release_marker', actual=release))
        if len(health) != 1 or int(health[0].get('accepted', 0)) <= s.gate_edge:
            diffs.append(dict(error='cancel_healthy_marker', actual=health))
        if (len(done) != 1 or done[0].get('cancelled_consumers') != '1'
                or done[0].get('released') != '1'):
            diffs.append(dict(error='cancel_pass_marker', actual=done))
        resumed = markers('TOPOLOGY_INTERACTION_PASS ')
        if resumed:
            diffs.append(dict(error='cancel_profile_has_resume_marker', actual=len(resumed)))
    else:
        done = markers('TOPOLOGY_INTERACTION_PASS ')
        if (len(done) != 1 or done[0].get('original_time') != '1'
                or done[0].get('all_consumers_released') != '1'):
            diffs.append(dict(error='interaction_pass_marker', actual=done))
    return diffs


def main():
    import run
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('profiles',nargs='+',choices=PROFILES)
    p.add_argument('--output-root',type=Path,required=True)
    p.add_argument('--force-compile',action='store_true')
    a=p.parse_args()
    return 0 if all(run.run(build_scenario(n),a.output_root.resolve(),a.force_compile) for n in a.profiles) else 1


if __name__=='__main__':
    raise SystemExit(main())
