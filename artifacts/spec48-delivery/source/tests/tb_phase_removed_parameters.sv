// Removed public tuning must receive the simulator's native elaboration error.
module tb_phase_removed_parameters;
  bw_point_mon #(.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.PHASE_N(6)) point
    (.clk(1'b0),.reset_n(1'b1));
  bw_group_mon #(.GROUP_ID("removed"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1),.PHASE_K(2)) group_mon
    (.clk(1'b0),.reset_n(1'b1));
  bw_stats_core #(.WINDOW_WIDTH(1),.PHASE_STEADY_ENTER_REL(0.04)) core
    (.scope_id("removed.core"),.record('0),.record_toggle(1'b0));
endmodule
