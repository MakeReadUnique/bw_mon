// Ticket #50: the final startup contract's rejection cases. Every CASE must
// die with its core error.
module auto_error_fixture #(parameter int CASE=0);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  if (CASE==1) begin : empty_setup
    bw_mon_setup setup();
  end
  if (CASE==2) begin : missing_setup
    bw_point_mon #(.POINT_ID("err.p"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p
      (.clk(clk),.reset_n(1'b1),.valid(1'b0));
  end
  if (CASE==3) begin : duplicate_setup
    bw_mon_setup first();
    bw_mon_setup second();
  end
  if (CASE==4) begin : ghost_owner
    bw_mon_setup setup();
    bw_point_mon #(.POINT_ID("err.p"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p
      (.clk(clk),.reset_n(1'b1),.valid(1'b0));
    initial add_point_member("err.ghost","err.p");
  end
  if (CASE==5) begin : late_member
    bw_mon_setup setup();
    bw_point_mon #(.POINT_ID("err.p"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p
      (.clk(clk),.reset_n(1'b1),.valid(1'b0));
    bw_group_mon #(.GROUP_ID("err.g"),.WINDOW_WIDTH(4)) g (.clk(clk),.reset_n(1'b1));
    initial begin
      add_point_member("err.g","err.p");
      wait(monitor_ready);#1;
      add_group_member("err.g","err.g");
    end
  end
  if (CASE==6) begin : late_register
    bw_mon_setup setup();
    bw_point_mon #(.POINT_ID("err.p"),.WINDOW_WIDTH(4),.FIXED_BYTES(8)) p
      (.clk(clk),.reset_n(1'b1),.valid(1'b0));
    initial begin
      wait(monitor_ready);#1;
      void'(register_point("err.late","auto_error_fixture.late",BW_NS,4,4));
    end
  end
  if (CASE==7) begin : duplicate_point
    bw_mon_setup setup();
    bw_point_mon #(.POINT_ID("err.duplicate"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) first
      (.clk(clk),.reset_n(1'b1));
    bw_point_mon #(.POINT_ID("err.duplicate"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) second
      (.clk(clk),.reset_n(1'b1));
  end
  if (CASE==8) begin : duplicate_group
    bw_mon_setup setup();
    bw_group_mon #(.GROUP_ID("err.duplicate"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) first
      (.clk(clk),.reset_n(1'b1));
    bw_group_mon #(.GROUP_ID("err.duplicate"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) second
      (.clk(clk),.reset_n(1'b1));
  end
  if (CASE==9) begin : empty_group
    bw_mon_setup setup();
    bw_group_mon #(.GROUP_ID("err.empty"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) group_mon
      (.clk(clk),.reset_n(1'b1));
  end
  if (CASE==10) begin : missing_group_setup
    bw_group_mon #(.GROUP_ID("err.uncoordinated"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) group_mon
      (.clk(clk),.reset_n(1'b1));
  end
  if (CASE==11) begin : group_cycle
    bw_mon_setup setup();
    bw_group_mon #(.GROUP_ID("err.a"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) first
      (.clk(clk),.reset_n(1'b1));
    bw_group_mon #(.GROUP_ID("err.b"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) second
      (.clk(clk),.reset_n(1'b1));
    initial begin
      add_group_member("err.a","err.b");
      add_group_member("err.b","err.a");
    end
  end
  if (CASE==12) begin : missing_reference
    bw_mon_setup setup();
    bw_group_mon #(.GROUP_ID("err.reference"),.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.PHASE_ENABLE(0)) group_mon
      (.clk(clk),.reset_n(1'b1));
    initial add_point_member("err.reference","absent.point");
  end
  initial begin
    #100000;$fatal(1,"expected core error did not occur");
  end
endmodule
