module group_analysis_config_fixture #(parameter int CASE=0);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("config.leaf"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1)) point
    (.clk(1'b0),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("config.group"),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(CASE==5 ? 2'bxx : CASE==6 ? 2'd2 : CASE!=1),.SILENCE_THRESHOLD(CASE==4 ? 64'bx : 64'd2),
    .PHASE_ENABLE(CASE==7 ? 2'bxx : CASE==8 ? 2'd2 : CASE inside {5,6} ? 2'd0 : 2'd1)) group_mon
    (.clk(1'b0),.reset_n(1'b1));
  initial begin
    add_point_member("config.group","config.leaf");
    if(CASE==0)begin wait(monitor_ready);#1;end else #2;
    if(CASE!=0)$fatal(1,"expected core error did not occur");
    if(!monitor_ready)$fatal(1,"explicit group analysis configuration failed to become ready");
    $display("TB_PASS group_analysis_config");$finish;
  end
endmodule
