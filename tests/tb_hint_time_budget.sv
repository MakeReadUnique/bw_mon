module tb_hint_time_budget;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  // With cycle windows and no clock, only the independent ns hint timer can
  // reach an action beyond the immutable 40us monitor-system budget.
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(40001)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  initial begin
    wait(monitor_ready);#(64'd40002000000);
    if(!scope_disabled(BW_POINT,point.scope_id))$fatal(1,"out-of-budget hint timer must disable its owner");
    $display("TB_PASS hint_time_budget quarantined");$finish;
  end
  final if(scope_disabled(BW_POINT,point.scope_id))$display("MONITOR_DISABLED");
endmodule
