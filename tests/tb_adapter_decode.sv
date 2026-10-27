// Example DUT-specific integration wrapper: size_code is this interface's
// encoding for the current beat, rather than the whole transaction length.
module bw_encoded_adapter(input logic clk, input logic valid, input logic ready,
                          input logic [1:0] size_code);
  import bw_mon_pkg::*;
  logic [63:0] accounted_bytes;
  logic decode_known;
  always_comb begin
    decode_known=1;
    case(size_code)
      0: accounted_bytes=16;
      1: accounted_bytes=32;
      2: accounted_bytes=64;
      3: accounted_bytes=128;
      default: begin accounted_bytes='x;decode_known=0;end
    endcase
  end
  bw_point_mon #(.PROTOCOL(BW_VALID_READY),.DYNAMIC_BYTES(1),
                 .WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) bw
    (.clk(clk),.reset_n(1'b1),.valid(valid),.ready(ready),
     .size_bytes(accounted_bytes),.size_known(decode_known));
endmodule
module tb_adapter_decode;
  timeunit 1ns;timeprecision 1fs;
  logic clk=0,valid=1,ready=1;
  logic [1:0] size_code=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_encoded_adapter target(clk,valid,ready,size_code);
  initial begin
    wait(bw_mon_pkg::monitor_ready);
    #1ns;clk=1;#1fs;clk=0;
    if(target.bw.total_bytes!=32 || target.bw.sampled_size_bytes!=32 || size_code!=1)
      $fatal(1,"adapter must decode one encoded beat to accounted bytes");
    #999999fs;clk=1;#1fs;clk=0;
    if(target.bw.total_bytes!=64 || target.bw.total_events!=2)
      $fatal(1,"per-beat decode must count each beat once");
    size_code='x;
    #999999fs;clk=1;#1fs;clk=0;
    if(target.bw.raw_record.event_inc!=1 || target.bw.raw_record.bytes_complete ||
       target.bw.sampled_size_known!==0)
      $fatal(1,"unknown encoding must preserve activity but mark byte decode incomplete");
    valid=0;
    #999999fs;clk=1;#1fs;
    if(!target.bw.raw_record.bytes_complete || target.bw.raw_record.event_inc!=0)
      $fatal(1,"unused unknown adapter encoding must not contaminate idle accounting");
    $display("TB_PASS adapter_decode");$finish;
  end
endmodule
