// One parameterless setup installs the unique coordinator. It collects t=0
// registrations and member rules, then seals and starts at the first
// representable positive time slot; no manual counts, timeouts or finish call
// remain public (spec D5).
module bw_mon_setup();
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  import bw_check_report_pkg::*;
  bw_check_report report;
  initial begin
    report=new;
    configure_monitor();
    install_check_report(report);
    // Advance to the first representable positive time step. This is a real
    // time advance, not a delta-count guess; its actual value is published as
    // the common measurement start T.
    #(1);
    seal_configuration();
    wait(prepared_scopes==preparing_scopes);
    start_monitor();
  end
endmodule
