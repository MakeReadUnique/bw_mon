module history_trace_fixture #(parameter bw_mon_pkg::bw_basis_t BASIS=bw_mon_pkg::BW_NS);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,valid=1;
  logic [63:0] bytes_now=4;
  int checked_windows=0;
  bw_u64_t ns_bytes[8]='{48,60,24,40,32,56,32,0};
  bw_u64_t ns_events[8]='{8,11,4,5,4,7,5,0};
  bit ns_complete[8]='{1,0,0,1,1,1,1,1};
  bit ns_reset[8]='{0,0,0,0,0,1,1,0};
  bw_u64_t cycle_bytes[8]='{24,36,32,24,32,48,48,40};
  bw_u64_t cycle_events[8]='{4,6,6,5,4,6,6,5};
  bw_u64_t cycle_left[8]='{1,2,4,6,8,10,12,14};
  bw_u64_t cycle_right[8]='{3,5,7,9,11,13,15,17};
  bw_u64_t cycle_left_ticks[8]='{250000,750000,1750000,2750000,3750000,6250000,8250000,10750000};
  bw_u64_t cycle_right_ticks[8]='{1250000,2250000,3250000,5250000,7250000,10250000,11250000,12250000};
  bit cycle_complete[8]='{1,1,1,0,0,1,1,1};
  bit cycle_reset[8]='{0,0,0,0,0,0,1,1};
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("history.variable"),.DYNAMIC_BYTES(1),.WINDOW_BASIS(BASIS),
    .WINDOW_WIDTH(3),.UPDATE_STRIDE(2),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2),
    .PHASE_ENABLE(1)) variable_point
    (.clk(clk),.reset_n(reset_n),.valid(valid),.size_bytes(bytes_now),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("history.fixed"),.FIXED_BYTES(8),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(3),.UPDATE_STRIDE(2)) fixed_point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  bw_group_mon #(.GROUP_ID("history.group"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(3),.UPDATE_STRIDE(2)) group_mon
    (.clk(clk),.reset_n(1'b1));
  task automatic sample(bw_u64_t tick,logic valid_value,logic [63:0] byte_value);
    #(measurement_start_ticks+tick-$time-1);valid=valid_value;bytes_now=byte_value;
    #1;clk=1;#1;clk=0;
    if(group_mon.accepted_record_seq!=group_mon.raw_record.record_seq)
      $fatal(1,"group raw increment must enter its core on the original edge");
  endtask
  task automatic verify_window();
    int i;
    bw_u64_t left_tick,right_tick,expected_bytes,expected_events,expected_cycles;
    bit complete,reset_coverage;
    real expected_gbps;
    i=int'(group_mon.result_seq)-1;
    if(i<0 || i>7 || group_mon.result_seq!=checked_windows+1)$fatal(1,"unexpected publication sequence");
    if(BASIS==BW_NS)begin
      right_tick=measurement_start_ticks+(2*bw_u64_t'(i+1))*BW_TICKS_PER_NS;
      left_tick=(i==0) ? measurement_start_ticks : right_tick-3000000;
      expected_bytes=ns_bytes[i];expected_events=ns_events[i];complete=ns_complete[i];reset_coverage=ns_reset[i];
    end else begin
      left_tick=measurement_start_ticks+cycle_left_ticks[i];right_tick=measurement_start_ticks+cycle_right_ticks[i];
      expected_bytes=cycle_bytes[i];expected_events=cycle_events[i];complete=cycle_complete[i];reset_coverage=cycle_reset[i];
      expected_cycles=cycle_right[i]-cycle_left[i];
      if(group_mon.window_start_cycle!=cycle_left[i] || group_mon.window_end_cycle!=cycle_right[i] ||
         group_mon.coverage_cycles!=expected_cycles ||
         $abs(group_mon.bytes_per_cycle-real'(expected_bytes)/real'(expected_cycles))>1e-10)
        $fatal(1,"cycle literal boundary/run-cut oracle failed at publication%0d",i+1);
    end
    expected_gbps=real'(expected_bytes)*1000000.0/real'(right_tick-left_tick);
    if(group_mon.window_start_ticks!=left_tick || group_mon.window_end_ticks!=right_tick ||
       group_mon.window_bytes!=expected_bytes || group_mon.window_events!=expected_events ||
       group_mon.coverage_ticks!=right_tick-left_tick || group_mon.window_warmup!=(i==0) ||
       group_mon.window_full!=(i!=0) || group_mon.bytes_complete!=complete || group_mon.events_complete!=complete ||
       group_mon.member_reset_coverage!=reset_coverage || !group_mon.denominator_valid ||
       group_mon.window_valid!=((i!=0)&&complete) || $abs(group_mon.bandwidth_gbps-expected_gbps)>1e-10)
      $fatal(1,"event-table oracle basis%0d result%0d: got bytes/events=%0d/%0d quality=%0b/%0b reset=%0b bounds=%0d/%0d",
        BASIS,i+1,group_mon.window_bytes,group_mon.window_events,group_mon.bytes_complete,group_mon.events_complete,
        group_mon.member_reset_coverage,group_mon.window_start_ticks,group_mon.window_end_ticks);
    checked_windows++;
  endtask
  history_trace_checker checker();
  initial begin
    add_point_member("history.group","history.variable");add_point_member("history.group","history.fixed");
    wait(monitor_ready);
    sample(250000,1,4);sample(750000,1,4);sample(1250000,1,4);sample(1750000,1,4);sample(2250000,1,4);
    sample(2750000,1,0);sample(3250000,1,'x);sample(3750000,1'bx,4);sample(5250000,0,'x);
    sample(6250000,1,8);sample(7250000,1,8);sample(8250000,1,8);sample(10250000,1,8);sample(10750000,1,8);
    #(measurement_start_ticks+11100000-$time);reset_n=0;sample(11250000,1,8);
    #(measurement_start_ticks+11500000-$time);reset_n=1;sample(11750000,1,8);sample(12250000,1,0);
    #(measurement_start_ticks+16000001-$time);
    if(checked_windows!=8 || group_mon.raw_record.record_seq!=17 || group_mon.accepted_record_seq!=17 ||
       group_mon.total_bytes!=204 || group_mon.total_events!=31 || group_mon.stats_epoch!=0 ||
       variable_point.total_bytes!=8 || variable_point.total_events!=2 || variable_point.stats_epoch!=1 ||
       variable_point.raw_record.source_epoch!=1 || fixed_point.total_bytes!=136 || fixed_point.total_events!=17)
      $fatal(1,"exact raw totals, zero-byte events, point reset independence or stopped publication count failed");
    $display("TB_PASS history_trace basis=%0d publications=%0d bytes=204 events=31",BASIS,checked_windows);$finish;
  end
endmodule
program history_trace_checker;
  initial forever begin
    @(history_trace_fixture.group_mon.result_seq);
    if(history_trace_fixture.group_mon.result_seq!=0)history_trace_fixture.verify_window();
  end
endprogram
