module tb_dynamic_size_error;
  timeunit 1ns; timeprecision 1fs;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.DYNAMIC_BYTES(1),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(64'h100000000),.size_known(1'b1));
  initial begin
    wait(bw_mon_pkg::monitor_ready);#1ns;clk=1;
    #1fs;
    if(!bw_mon_pkg::scope_disabled(bw_mon_pkg::BW_POINT,point.scope_id) || point.accepted_record_seq!=0)
      $fatal(1,"oversized transfer must disable before publication/acceptance");
    $display("TB_PASS dynamic_size_error quarantined");$finish;
  end
endmodule
