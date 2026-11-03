module tb_startup_errors;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  string which;
  int unused_handle;
  initial begin
    if(!$value$plusargs("CASE=%s",which)) $fatal(1,"test requires CASE");
    case(which)
      "empty": unused_handle=register_point("","tb.point",BW_NS,10,1);
      "bad_width": unused_handle=register_point("p0","tb.p0",BW_NS,0,1);
      "bad_stride": unused_handle=register_point("p0","tb.p0",BW_NS,10,11);
      "ns_width_limit": unused_handle=register_point("p0","tb.p0",BW_NS,40001,1);
      "cycle_width_limit": unused_handle=register_point("p0","tb.p0",BW_CYCLE,80001,1);
      "cycle_bad_stride": unused_handle=register_point("p0","tb.p0",BW_CYCLE,10,11);
      default: begin
        unused_handle=register_point("p0","tb.p0",BW_NS,10,1);
        if(which=="duplicate") unused_handle=register_point("p0","tb.p1",BW_NS,10,1);
        else begin
          unused_handle=register_point("p1","tb.p1",BW_NS,10,1);
          wait(monitor_ready);
          #1000000;
          if(which=="late") unused_handle=register_point("p2","tb.p2",BW_NS,10,1);
          else if(which=="reconfigure") configure_monitor();
        end
      end
    endcase
    $fatal(1,"expected core error did not occur");
  end
endmodule
