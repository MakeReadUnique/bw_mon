module tb_point_four_state_edges;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("fourstate"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),.FIXED_BYTES(8))
    p(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);
    #100;clk=1'bx;#1;
    if(p.total_bytes!=8)$fatal(1,"0 to X is a SystemVerilog sampling posedge");
    #100;clk=1;#1;
    if(p.total_bytes!=16)$fatal(1,"X to 1 is a SystemVerilog sampling posedge");
    #100;clk=1'bz;#100;clk=0;#100;clk=1'bz;#1;
    if(p.total_bytes!=24)$fatal(1,"0 to Z is a SystemVerilog sampling posedge");
    #100;clk=1;#1;
    if(p.total_bytes!=32 || scope_disabled(BW_POINT,"fourstate"))$fatal(1,"Z to 1 is a sampling posedge; no falling edge is expected work");
    $display("TB_PASS point_four_state_edges actual_edges=4 bytes=32");$finish;
  end
endmodule
