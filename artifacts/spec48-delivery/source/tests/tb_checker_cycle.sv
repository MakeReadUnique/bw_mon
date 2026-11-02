module tb_checker_cycle;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  logic [63:0] bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("checker.cycle"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_known(1'b1),.size_bytes(bytes));
  bw_group_mon #(.GROUP_ID("checker.cycle"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial add_point_member("checker.cycle","checker.cycle");
  initial begin
    bw_u64_t tick,sequence_point,sequence_group;
    int next_period;
    bw_report_summary_t result;
    wait(monitor_ready);tick=measurement_start_ticks+500000;
    for(int edge_number=1;edge_number<=29;edge_number++)begin
      if(edge_number==16)begin
        sequence_point=point.result_seq;sequence_group=group_mon.result_seq;
        #10000000;
        result=check_report_summary();
        if(point.result_seq!=sequence_point || group_mon.result_seq!=sequence_group ||
           result.pass_count!=0 || result.fail_count!=0 || result.warning_count!=0)
          $fatal(1,"ten ns of stopped cycle clock must add neither evidence nor a final result");
      end
      #(tick-$time);valid=edge_number<=24;
      // Bytes account for the *following* physical interval, independently of
      // result geometry. Publications remain 92/108 GB/s through clock changes.
      next_period=edge_number==15 ? 20 : (edge_number>=12 ? 2 : 1);
      bytes=($test$plusargs("CONSTANT") ? 100 : (edge_number%2 ? 92 : 108))*next_period;
      clk=1;#1;clk=0;
      if(edge_number>=8 && edge_number<=24 &&
         (point.phase_current!=BW_PHASE_STEADY || group_mon.phase_current!=BW_PHASE_STEADY ||
          point.phase_id!=1 || group_mon.phase_id!=1))
        $fatal(1,"the changing-frequency and stopped-clock platform must remain STEADY");
      tick+=next_period*1000000;
    end
    result=check_report_summary();
    if(result.warning_count!=0 || result.pass_count!=($test$plusargs("CONSTANT") ? 2 : 0) ||
       result.fail_count!=($test$plusargs("CONSTANT") ? 0 : 2))
      $fatal(1,"point/group cycle check must use original cycle locations and physical bandwidth");
    $display("TB_PASS checker_cycle");$finish;
  end
endmodule
