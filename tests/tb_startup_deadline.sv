module tb_startup_deadline;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  int unused_handle;
  initial begin
    unused_handle=register_point("p0","tb.p0",BW_NS,10,1);
    #5000000;
    unused_handle=register_point("p1","tb.p1",BW_NS,10,1);
    #1;
    if(!monitor_ready || measurement_start_ticks!=5000001)
      $fatal(1,"arrival at startup deadline must complete before timeout decision");
    $display("TB_PASS startup_deadline");$finish;
  end
endmodule
