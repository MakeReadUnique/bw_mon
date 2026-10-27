module tb_report_hint_deferred;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bit deferred_finish=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("hint.deferred"),.PROTOCOL(BW_VALID_READY),
    .WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(1)) point
    (.clk(1'b0),.reset_n(1'b1),.valid(1'b1),.ready(1'b0));
  initial begin
    wait(monitor_ready);
    #500000;set_deferred_core_failure(0,1);
    #600001;
    if(core_failure_seen || !core_failure_pending() || !point.backpressure_hit ||
       point.backpressure_hit_count!=1)
      $fatal(1,"transient candidates cannot suppress a valid runtime hint hit");
    set_deferred_core_failure(0,0);
    #899999;set_deferred_core_failure(0,1);deferred_finish=1;$finish;
  end
  final if(deferred_finish) begin
    $display("REPORT_HINT_FACT seen=%0b pending=%0b",core_failure_seen,core_failure_pending());
    deferred_core_error("REPORT_HINT_DEFERRED","hint.fixture","unresolved final failure");
  end
endmodule
