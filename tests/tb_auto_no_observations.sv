module tb_auto_no_observations;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("idle.point"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(10),.PHASE_ENABLE(0)) point_mon
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  initial begin
    wait(monitor_ready);
    if(point_mon.raw_record.record_seq!=0 || point_mon.result_seq!=0 ||
       point_mon.total_bytes!=0 || point_mon.total_events!=0 || point_mon.episode_active)
      $fatal(1,"ready without sampling must not fabricate a record, window or episode");
    $display("TB_PASS auto_no_observations");$finish;
  end
endmodule
