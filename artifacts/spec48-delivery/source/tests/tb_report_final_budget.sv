module tb_report_final_budget;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("tb.raw[0].bw"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),
    .UPDATE_STRIDE(1),.FIXED_BYTES(152),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(2)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);#1000000;clk=1;#1;clk=0;
    #(measurement_start_ticks+40001000000-$time);
    if($test$plusargs("SUBMIT_LATE")) emit_episode_result(point.scope_id,point.episode_result);
    $display("TB_PASS report_final_budget final-requested");$finish;
  end
endmodule
