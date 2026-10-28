module storage_failure_fixture #(parameter bw_mon_pkg::bw_basis_t BASIS=bw_mon_pkg::BW_NS);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,valid=1,ready=1;
  string resource,owner;
  int final_mode;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("fault.point"),.PROTOCOL(BW_VALID_READY),.FIXED_BYTES(8),
    .WINDOW_BASIS(BASIS),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),.PHASE_ENABLE(1),
    .BACKPRESSURE_ENABLE(1),.BACKPRESSURE_BASIS(BW_NS),.BACKPRESSURE_THRESHOLD(2)) point_mon
    (.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready));
  bw_group_mon #(.GROUP_ID("fault.group"),.WINDOW_BASIS(BASIS),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(4),.PHASE_ENABLE(1)) group_mon (.clk(clk),.reset_n(1'b1));
  initial forever #250000 clk=~clk;
  initial begin
    if(!$value$plusargs("RESOURCE=%s",resource))resource="history.events";
    void'($value$plusargs("FINAL=%d",final_mode));
    owner="fault.point";
    if(resource inside {"core.controls","quality.episode","group.expected"})owner="fault.group";
    if(resource inside {"report.cfg-line","report.token"})owner="report";
    add_point_member("fault.group","fault.point");
    inject_growth_failure(owner,resource);wait(monitor_ready);
    if(final_mode)begin #10100000;$display("TB_PASS storage_failure final-requested");$finish;end
    if(resource=="hint.backpressure.timers")begin #100000;ready=0;end
    if(resource inside {"quality.window","quality.episode"})begin
      #(3100002-$time);reset_n=0;#400000;reset_n=1;
    end else if(resource=="phase.pending")begin #(measurement_start_ticks+10100000-$time);valid=0;end
    #(measurement_start_ticks+20000000-$time);
    if(!scope_disabled(owner=="fault.group" ? BW_GROUP : BW_POINT,owner))
      $fatal(1,"runtime storage failure did not quarantine the owning scope");
    $display("TB_PASS storage_failure resource=%s owner=%s quarantined=1",resource,owner);$finish;
  end
endmodule
