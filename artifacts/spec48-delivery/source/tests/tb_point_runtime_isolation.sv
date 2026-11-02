module tb_point_runtime_isolation;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_p=1;
  string resource;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("damaged"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(8)) p(.clk(clk),.reset_n(reset_p),.valid(1'b1));
  bw_point_mon #(.POINT_ID("healthy"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(16)) q(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    if(!$value$plusargs("RESOURCE=%s",resource))resource="recorder.samples";
    wait(monitor_ready);
    inject_growth_failure("damaged",resource);
    #1000000;
    if(resource=="scheduler.reset_capture")reset_p=0;
    clk=1;
    #1;
    if(q.total_bytes!=16 || p.total_bytes!=0)$fatal(1,"healthy point must complete after peer storage failure");
    clk=0;reset_p=0;
    #1000000;reset_p=1;clk=1;
    #1;
    if(q.total_bytes!=32 || p.total_bytes!=0)$fatal(1,"reset must not revive damaged point");
    $display("TB_PASS point_runtime_isolation healthy_bytes=32 damaged_bytes=0");$finish;
  end
endmodule
