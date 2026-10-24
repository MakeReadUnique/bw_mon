module tb_cycle_edge_error;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_record_t record;
  bit record_toggle=0;
  int source_handle;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_stats_core #(.WINDOW_BASIS(BW_CYCLE), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1)) core
    (.scope_id("cycle.component"), .record(record), .record_toggle(record_toggle));
  initial begin
    source_handle=register_point("cycle.component","tb_cycle_edge_error.core",BW_CYCLE,2,1,"clk");
    wait(monitor_ready);
    #1000000;
    record='0;
    record.timestamp_ticks=$time;
    record.record_seq=1;
    record.edge_index=11;
    record.events_complete=1;
    record.bytes_complete=1;
    record.reset_n=1;
    record_toggle<=!record_toggle;
    #1000000;
    record.timestamp_ticks=$time;
    record.record_seq=2;
    record.edge_index=13;
    record_toggle<=!record_toggle;
    #1;
    $fatal(1,"expected core error did not occur");
  end
endmodule
