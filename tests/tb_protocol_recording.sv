module tb_protocol_recording;
  timeunit 1ns; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic vv=0,vrv=0,vrr=0,cf=0,cr=0;
  logic [63:0] vs=0,vrs=0,cs=0;
  logic ck=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("valid"),.PROTOCOL(BW_VALID_ONLY),.DYNAMIC_BYTES(1),
    .WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) vo
    (.clk(clk),.reset_n(1'b1),.valid(vv),.size_bytes(vs),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("ready"),.PROTOCOL(BW_VALID_READY),.DYNAMIC_BYTES(1),
    .WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) vr
    (.clk(clk),.reset_n(1'b1),.valid(vrv),.ready(vrr),.size_bytes(vrs),.size_known(1'b1));
  bw_point_mon #(.POINT_ID("credit"),.PROTOCOL(BW_CREDIT),.DYNAMIC_BYTES(1),
    .WINDOW_WIDTH(4),.UPDATE_STRIDE(1)) credit
    (.clk(clk),.reset_n(1'b1),.valid(1'b0),.flitv(cf),.lcrdv(cr),.size_bytes(cs),.size_known(ck));
  task automatic edge_now();
    clk=1;#1fs;clk=0;
  endtask
  initial begin
    wait(monitor_ready);
    #1ns;vv=1;vs=0;vrv=1;vrr=0;vrs='x;cf=1;cr=0;cs=16;edge_now();
    if(vo.raw_record.event_inc!=1 || vo.raw_record.byte_inc!=0 || !vo.raw_record.bytes_complete)
      $fatal(1,"zero-byte transfer must remain a known event");
    if(vr.raw_record.event_inc!=0 || !vr.raw_record.bytes_complete || !vr.raw_record.events_complete)
      $fatal(1,"ready-low excludes transfer and ignores unknown unused size");
    if(credit.raw_record.byte_inc!=16 || credit.raw_record.event_inc!=1 ||
       !credit.credit_supported || credit.credit_enabled || credit.credit_trusted)
      $fatal(1,"flitv counts without simultaneous return");
    #999999fs;vv=0;vs='x;vrv=1'bx;vrr=0;cf=1;cr=1'bx;cs=8;edge_now();
    if(!vo.raw_record.bytes_complete || vo.raw_record.event_inc!=0)
      $fatal(1,"unused size X must not contaminate known idle");
    if(!vr.raw_record.events_complete || vr.raw_record.event_inc!=0)
      $fatal(1,"ready=0 determines no transfer even if valid unknown");
    if(credit.raw_record.byte_inc!=8 || !credit.raw_record.bytes_complete ||
       credit.sampled_lcrdv!==1'bx)
      $fatal(1,"unknown return is retained but cannot erase known flit bytes");
    #999999fs;vv=1;vs='z;vrv=1;vrr=1'bx;cf=0;cs='x;edge_now();
    if(vo.raw_record.event_inc!=1 || !vo.raw_record.events_complete || vo.raw_record.bytes_complete ||
       vo.sampled_size_bytes!==64'bz)
      $fatal(1,"unknown size preserves known transfer event");
    if(vr.raw_record.events_complete || vr.raw_record.bytes_complete || vr.raw_record.event_inc!=0)
      $fatal(1,"ambiguous handshake must remain observation gap");
    if(!credit.raw_record.bytes_complete || credit.raw_record.event_inc!=0)
      $fatal(1,"flitv=0 ignores unknown return and size for accounting");
    #999999fs;vv=1'bz;vs=64;vrv=0;vrr=1'bx;cf=1;cs=4;ck=1'bx;edge_now();
    if(vo.raw_record.events_complete || vo.raw_record.bytes_complete)
      $fatal(1,"unknown valid remains an observation gap");
    if(!vr.raw_record.events_complete || vr.raw_record.event_inc!=0)
      $fatal(1,"valid=0 determines idle despite ready unknown");
    if(credit.raw_record.event_inc!=1 || credit.raw_record.bytes_complete)
      $fatal(1,"unknown adapter decode preserves activity and marks bytes incomplete");
    #999999fs;vv=1;vs=8;vrv=1;vrr=1;vrs=32;cf=1;cs=0;ck=1;edge_now();
    if(credit.raw_record.event_inc!=1 || credit.raw_record.byte_inc!=0)
      $fatal(1,"credit zero-byte transfer is still an event");
    #999999fs;#1fs; // T6: [2,6)
    if(vo.window_bytes!=8 || vo.window_events!=2 || vo.bytes_complete || vo.events_complete)
      $fatal(1,"window must preserve known bytes/events through gaps");
    if(vr.window_bytes!=32 || vr.window_events!=1 || vr.bytes_complete || vr.events_complete)
      $fatal(1,"handshake window quality incorrect");
    if(credit.window_bytes!=8 || credit.window_events!=3 || credit.bytes_complete || !credit.events_complete)
      $fatal(1,"credit byte completeness is independent of event completeness");
    #3ns; // T9: [5,9), all unknown positions expired
    if(!vo.bytes_complete || !vo.events_complete || !vr.bytes_complete ||
       !vr.events_complete || !credit.bytes_complete || !credit.events_complete)
      $fatal(1,"window completeness must recover after unknown positions expire");
    if(vo.total_bytes!=8 || vo.total_events!=3 || vr.total_bytes!=32 || vr.total_events!=1 ||
       credit.total_bytes!=24 || credit.total_events!=4)
      $fatal(1,"known cumulative protocol totals incorrect");
    if(vo.raw_record.record_seq!=5 || credit.raw_record.record_seq!=5)
      $fatal(1,"idle and unknown sampling edges must each publish a record");
    $display("TB_PASS protocol_recording");$finish;
  end
endmodule
