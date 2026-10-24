module bw_mon_setup #(
  parameter logic [63:0] EXPECTED_POINT_COUNT = 0,
  parameter logic [63:0] EXPECTED_GROUP_COUNT = 0,
  parameter logic [63:0] MISSING_RECORD_TIMEOUT_NS = 1,
  parameter logic [63:0] STARTUP_TIMEOUT_NS = 100
) ();
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bit deadline_reached = 0;
  initial begin
    if ($isunknown(STARTUP_TIMEOUT_NS) || STARTUP_TIMEOUT_NS == 0)
      core_error("STARTUP_TIMEOUT_CONFIG","setup","timeout must be positive");
    configure_monitor(EXPECTED_POINT_COUNT,EXPECTED_GROUP_COUNT,MISSING_RECORD_TIMEOUT_NS);
    #(ns_to_ticks(STARTUP_TIMEOUT_NS,"startup timeout"));
    deadline_reached <= 1;
  end
  // Re-evaluation through durable state admits same-slot NBA registration
  // chains before the deferred failure decision; no startup timing barrier.
  always @(deadline_reached or registration_seq or configuration_seq or monitor_ready) begin
    STARTUP_COMPLETE: assert final (!deadline_reached || monitor_ready)
      else core_error("STARTUP_TIMEOUT","setup",startup_status());
  end
endmodule
