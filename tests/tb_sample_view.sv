module tb_sample_view;
  timeunit 1ns; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1,next_valid=0;
  logic [63:0] size_bytes=8,next_size=999;
  bw_mon_setup setup();
  bw_point_mon #(.DYNAMIC_BYTES(1),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  // DUT-like nonblocking updates change both control and size after an edge.
  always @(posedge clk) begin valid<=next_valid;size_bytes<=next_size;end
  initial begin
    wait(monitor_ready);
    #1ns;clk=1;#1fs;
    if(valid!==0 || size_bytes!=999 || point.sampled_valid!==1 || point.sampled_size_bytes!=8 ||
       point.raw_record.byte_inc!=8 || point.total_bytes!=8)
      $fatal(1,"sample must contain old control and old size across DUT NBA updates");
    clk=0;next_valid=1;next_size=16;
    #999999fs;clk=1;#1fs;
    if(point.sampled_valid!==0 || point.sampled_size_bytes!=999 || point.raw_record.event_inc!=0 ||
       !point.raw_record.bytes_complete || point.total_bytes!=8)
      $fatal(1,"idle old control must not count the new post-edge size");
    clk=0;next_valid=1;next_size=64'hffffffff;
    #999999fs;clk=1;#1fs;
    if(point.raw_record.byte_inc!=16 || point.total_bytes!=24)
      $fatal(1,"following transfer must use its own 16-byte sample");
    clk=0;
    #999999fs;clk=1;#1fs;
    if(point.raw_record.byte_inc!=64'd4294967295 || point.total_bytes!=64'd4294967319 ||
       point.total_events!=3 || !point.raw_record.bytes_complete)
      $fatal(1,"largest valid per-transfer size must remain exact");
    $display("TB_PASS sample_view");$finish;
  end
endmodule
