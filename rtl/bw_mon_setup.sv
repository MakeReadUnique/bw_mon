module bw_mon_setup #(
  parameter int unsigned EXPECTED_POINT_COUNT = 0,
  parameter bw_mon_pkg::bw_u64_t STARTUP_TIMEOUT_NS = 100
) ();
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bit deadline_reached = 0;
  initial begin
    if (STARTUP_TIMEOUT_NS == 0)
      core_error("STARTUP_TIMEOUT_CONFIG","setup","timeout must be positive");
    configure_monitor(EXPECTED_POINT_COUNT);
  end
  // Completion is driven by explicit configuration and registration state,
  // independent of initial-process ordering. NBA lets active-region arrivals
  // at the deadline participate before the missing-point decision.
  initial begin
    #(ns_to_ticks(STARTUP_TIMEOUT_NS,"startup timeout"));
    deadline_reached <= 1;
  end
  always @(deadline_reached) begin
    if (deadline_reached && !monitor_ready) begin
      try_ready();
      if (!monitor_ready)
        core_error("STARTUP_TIMEOUT","setup",
          $sformatf("expected_points=%0d registered_points=%0d deadline_ticks=%0d",
                    expected_point_count,registered_points.size(),$time));
    end
  end
endmodule
