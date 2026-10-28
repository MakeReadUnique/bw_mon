module tb_dynamic_size_error;
  timeunit 1ns; timeprecision 1fs;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.DYNAMIC_BYTES(1),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(64'h100000000),.size_known(1'b1));
  initial begin
    wait(bw_mon_pkg::monitor_ready);#1ns;clk=1;
    #1fs;$fatal(1,"expected core error did not occur");
  end
endmodule
