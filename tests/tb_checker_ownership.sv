// Public protocol fixture, independent of frozen four-family input files.
// Exact endpoints deliberately coincide with the final tail; no integer-time
// floor is applied to phases or publications.
module tb_checker_ownership;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,valid=1,dummy_reset_n=1,dummy_known=1,dummy_valid=0;
  logic [63:0] bytes=100;
  localparam int STRIDE=`OWNERSHIP_STRIDE;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("ownership"),.WINDOW_WIDTH(10),.UPDATE_STRIDE(STRIDE),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(reset_n),.valid(valid),.size_known(1'b1),.size_bytes(bytes));
  bw_point_mon #(.POINT_ID("ownership.dummy"),.WINDOW_WIDTH(10),.UPDATE_STRIDE(STRIDE),
    .DYNAMIC_BYTES(1)) dummy
    (.clk(clk),.reset_n(dummy_reset_n),.valid(dummy_valid),.size_known(dummy_known),.size_bytes(64'd0));
  bw_group_mon #(.GROUP_ID("ownership"),.WINDOW_WIDTH(10),.UPDATE_STRIDE(STRIDE),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(reset_n));
  initial begin
    add_point_member("ownership","ownership");
    add_point_member("ownership","ownership.dummy");
  end
  initial begin
    int finish_u,change_u;
    bw_u64_t edge_ticks;
    wait(monitor_ready);
    finish_u=($test$plusargs("EARLY_FAIL") || $test$plusargs("LATE_RESET")) ? 320 : (STRIDE==1 ? 100 : 240);
    change_u=($test$plusargs("EARLY_FAIL") || $test$plusargs("LATE_RESET")) ? 160 : (STRIDE==1 ? 80 : 120);
    for(int u=1;u<=finish_u+13;u++)begin
      valid=u<=finish_u;
      if($test$plusargs("MEMBER_RESET") || $test$plusargs("MEMBER_UNKNOWN") || $test$plusargs("MEMBER_GAP"))begin
        dummy_valid=valid;
        if(u>=171)begin
          if($test$plusargs("MEMBER_RESET"))dummy_reset_n=0;
          if($test$plusargs("MEMBER_UNKNOWN"))dummy_reset_n=1'bx;
          if($test$plusargs("MEMBER_GAP"))dummy_known=0;
        end
      end
      bytes=u>change_u ? 200 : 100;
      if($test$plusargs("EARLY_FAIL") && u>120 && u<=140)bytes=106;
      if(STRIDE==1 && u>40 && u<=60)bytes=106;
      // The final empty edge ends the last transfer cycle at an exact NS
      // publication endpoint. Earlier edges preserve the adopted first7.
      edge_ticks=measurement_start_ticks+(u-1)*1000000+(u<=finish_u ? 1 : 0);
      #(edge_ticks-$time);
      if(u==finish_u+1 && ($test$plusargs("RESET") || $test$plusargs("LATE_RESET")))reset_n=0;
      clk=1;#1;clk=0;
      if(u==finish_u+1 && $test$plusargs("TRUNCATED"))begin
        $display("TB_PASS checker_ownership truncated");$finish;
      end
    end
    #1000000;
    $display("TB_PASS checker_ownership");$finish;
  end
endmodule
