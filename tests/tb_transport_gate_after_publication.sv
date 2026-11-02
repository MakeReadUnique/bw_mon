// Pause a real group collector after publication while it waits for its core.
// Completing that commit must publish progress before waiting at the gate.
module tb_transport_gate_after_publication;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  int point,source;
  bit checked=0;
  bw_test_consumer_gate gate;
  bw_mon_setup setup();
  bw_group_mon #(.GROUP_ID("gate.group"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(2)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    bw_record_t frame;
    point=register_point("gate.point","controlled.point",BW_CYCLE,2,2);
    source=point_source_handle(point);add_point_member("gate.group","gate.point");
    gate=bw_test_gate_for("gate.group");
    wait(monitor_ready);
    #1000000;clk=1;
    frame='0;frame.timestamp_ticks=$time;frame.record_seq=1;frame.edge_index=1;
    frame.byte_inc=8;frame.event_inc=1;frame.bytes_complete=1;frame.events_complete=1;frame.reset_n=1;
    publish_frame(source,frame);
    #1;clk=0;
    if(!checked || scope_disabled(BW_GROUP,"gate.group") || !group_batch_complete("gate.group"))
      $fatal(1,"gate commit did not settle at original time");
    $display("TB_PASS transport_gate_after_publication");$finish;
  end
  task automatic observe();
    wait(group_mon.raw_record.record_seq==1);
    gate.paused=1;
    wait(group_batches["gate.group"].acked==1);
    if(!gate.paused || group_mon.expected_edges.size()!=0 ||
       group_mon.progress_watermark_ticks!=BW_U64_MAX || retained_frame_count(source)!=0)
      $fatal(1,"completed commit progress blocked behind consumer gate");
    checked=1;gate.paused=0;
  endtask
  gate_after_publication_observer observer();
endmodule
program gate_after_publication_observer;
  initial tb_transport_gate_after_publication.observe();
endprogram
