// Ticket 56 slice 7 (not part of cases.json): a stalled process must be
// expressed by external evidence only. This testbench deliberately enters a
// zero-delay loop; the runner kills it. The log must contain no completion
// marker and no normal summary, and the library must not invent missing-frame
// diagnostics for the kill.
module tb_end_stall;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("stall.p"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2),
    .FIXED_BYTES(8)) p(.clk(clk),.reset_n(1'b1),.valid(1'b1));
  initial begin
    wait(monitor_ready);
    #1000000;clk=1;#1;clk=0;
    // Zero-delay loop: the tool stalls and the runner kills the process.
    forever #0;
  end
endmodule
