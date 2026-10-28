// Ticket #49: explicit illegal S/Q values are rejected without falling back to
// the new defaults, on points, groups and the shared core. Every CASE must die
// with its core error before any monitor becomes ready.
module cfg_error_fixture #(parameter int CASE=0);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  if (CASE<=3) begin : bad_stride
    bw_point_mon #(.POINT_ID("cfg.error.stride"),.WINDOW_WIDTH(10),
      .UPDATE_STRIDE(CASE==1 ? 64'd0 : CASE==2 ? 64'd11 : 64'bx)) point
      (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  end
  if (CASE>=4 && CASE<=6) begin : bad_q
    bw_point_mon #(.POINT_ID("cfg.error.q"),.WINDOW_WIDTH(10),.EPISODE_ENABLE(1),
      .SILENCE_THRESHOLD(CASE==4 ? 64'd0 : CASE==5 ? 64'bx : 64'd20000000000000)) point
      (.clk(1'b0),.reset_n(1'b1),.valid(1'b0));
  end
  if (CASE==7) begin : bad_group_stride
    bw_group_mon #(.GROUP_ID("cfg.error.group"),.WINDOW_WIDTH(10),
      .UPDATE_STRIDE(64'd0)) group_mon(.clk(1'b0),.reset_n(1'b1));
  end
  if (CASE==8) begin : bad_group_q
    bw_group_mon #(.GROUP_ID("cfg.error.group"),.WINDOW_WIDTH(10),.UPDATE_STRIDE(5),
      .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(64'd0)) group_mon(.clk(1'b0),.reset_n(1'b1));
  end
  if (CASE>=9) begin : bad_core
    bit toggle=0;
    bw_record_t frame='0;
    bw_stats_core #(.WINDOW_WIDTH(10),
      .UPDATE_STRIDE(CASE==9 ? 64'd0 : 64'd5),
      .EPISODE_ENABLE(CASE==10),.SILENCE_THRESHOLD(CASE==10 ? 64'd0 : 64'd5)) core
      (.scope_id("cfg.error.core"),.record(frame),.record_toggle(toggle));
  end
  initial begin
    #1000000;$fatal(1,"expected core error did not occur");
  end
endmodule
