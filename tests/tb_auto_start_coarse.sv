// Ticket #50: a coarse 1ns/1ns testbench timescale still seals at the library
// precision's first positive slot and treats actual time correctly.
module tb_auto_start_coarse;
  timeunit 1ns;timeprecision 1ns;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("coarse.p"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    wait(monitor_ready);
    if (measurement_start_ticks!=1) $fatal(1,"T is the library slot, not the TB grid");
    valid=1;
    #2 clk=1; #1 clk=0; valid=0;
    #2 clk=1; #1 clk=0;
    if (p.total_bytes!=8) $fatal(1,"coarse-timescale traffic must count normally");
    $display("TB_PASS auto_start_coarse");$finish;
  end
endmodule
