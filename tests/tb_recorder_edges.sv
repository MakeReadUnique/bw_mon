module tb_recorder_edges;
  timeunit 1ns; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=0,valid=1,ready=1;
  bw_record_t record;
  bw_sample_t sample;
  bit toggled;
  int source_handle;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_recorder #(.FIXED_BYTES(16),.PROTOCOL(BW_VALID_READY)) recorder
    (.scope_id("recorder.component"),.clk(clk),.reset_n(reset_n),.valid(valid),.ready(ready),.size_bytes(64'bx),.size_known(1'b0),
     .record(record),.sampled_view(sample),.record_toggle(toggled),.control(),.control_toggle());
  initial begin
    source_handle=register_point("recorder.component","tb_recorder_edges",BW_NS,10,1,"clk");
    wait(monitor_ready);
    #1ns;clk=1;#1fs;
    if(record.record_seq!=1 || record.reset_points!=1 || record.event_inc!=0 ||
       !record.events_complete || !record.bytes_complete || sample.reset_n!==0)
      $fatal(1,"known reset must still publish a complete reset record without transfer");
    clk=0;reset_n=1'bx;
    #999999fs;clk=1;#1fs;
    if(record.record_seq!=2 || record.reset_n!==1'bx || record.bytes_complete || record.events_complete)
      $fatal(1,"unknown reset must remain a per-edge observation gap");
    clk=0;reset_n=1;
    #999999fs;clk=1;#1fs;
    if(record.record_seq!=3 || record.event_inc!=1 || record.byte_inc!=16 || !record.bytes_complete)
      $fatal(1,"fixed mode ignores dynamic field knownness on a definite handshake");
    clk=0;ready=0;
    #999999fs;clk=1;#1fs;
    if(record.record_seq!=4 || record.timestamp_ticks!=4000000 || record.event_inc!=0 ||
       !record.bytes_complete || !record.events_complete)
      $fatal(1,"idle is a complete new source record, not absence of publication");
    $display("TB_PASS recorder_edges");$finish;
  end
endmodule
