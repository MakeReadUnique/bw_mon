// Ticket #50: one module-type bind discovers every actual instance; changing
// the instance count needs no configuration change.
module auto_link #(parameter int WIDTH=8) (input logic clk, input logic valid);
  logic unused;assign unused=valid;
endmodule

module tb_auto_start_bind;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  // 三个实例；若数目改为 5，本测试bench 不需要任何修改。
  auto_link #(.WIDTH(8)) u0(.clk(clk),.valid(valid));
  auto_link #(.WIDTH(8)) u1(.clk(clk),.valid(valid));
  auto_link #(.WIDTH(8)) u2(.clk(clk),.valid(valid));
  bind auto_link bw_point_mon #(.WINDOW_WIDTH(4),.FIXED_BYTES(8)) u_bw
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_mon_setup setup();
  initial begin
    wait(monitor_ready);
    if (registered_scope_count(BW_POINT)!=3)
      $fatal(1,"bind instances must be discovered without manual counts");
    $display("TB_PASS auto_start_bind");$finish;
  end
endmodule
