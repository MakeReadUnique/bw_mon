`define FIXED_SCOPE(STRIDE_OVERRIDE) \
    bw_point_mon #(.POINT_ID($sformatf("phase.fixed.point%0d",f)),.WINDOW_BASIS(BASIS), \
      .WINDOW_WIDTH(10),STRIDE_OVERRIDE .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point \
      (.clk(clk),.reset_n(reset_n),.valid(family==f ? valid : 1'b0),.size_bytes(point_bytes),.size_known(known)); \
    for(genvar m=0;m<4;m++)begin:members \
      bw_point_mon #(.POINT_ID($sformatf("phase.fixed.member%0d.%0d",f,m)),.WINDOW_BASIS(BASIS), \
        .WINDOW_WIDTH(10),STRIDE_OVERRIDE .DYNAMIC_BYTES(1)) point \
        (.clk(clk),.reset_n(reset_n),.valid(family==f ? valid : 1'b0),.size_bytes(member_bytes[m]),.size_known(known)); \
      initial add_point_member($sformatf("phase.fixed.group%0d",f),$sformatf("phase.fixed.member%0d.%0d",f,m)); \
    end \
    bw_group_mon #(.GROUP_ID($sformatf("phase.fixed.group%0d",f)),.WINDOW_BASIS(BASIS), \
      .WINDOW_WIDTH(10),STRIDE_OVERRIDE .EPISODE_ENABLE(1)) group_mon \
      (.clk(clk),.reset_n(reset_n)); \
    always @(point.result_seq)begin \
      #1; \
      if(recording && family==f && point.result_seq!=0) \
        $display("FIXED_WINDOW case=%0d kind=point ticks=%0d left=%0d bytes=%0d full=%0b complete=%0b eligible=%0b y=%0.17g current=%s evidence=%0d candidate=%0d reason=%s", \
          case_id,point.window_end_ticks,point.window_start_ticks,point.window_bytes, \
          point.window_full,point.bytes_complete,point.phase_eligible,point.bandwidth_gbps, \
          point.phase_current.name(),point.phase_evidence_count,point.phase_candidate_count,phase_reason_name(point.phase_reason)); \
    end \
    always @(group_mon.result_seq)begin \
      #1; \
      if(recording && family==f && group_mon.result_seq!=0) \
        $display("FIXED_WINDOW case=%0d kind=group ticks=%0d left=%0d bytes=%0d full=%0b complete=%0b eligible=%0b y=%0.17g current=%s evidence=%0d candidate=%0d reason=%s", \
          case_id,group_mon.window_end_ticks,group_mon.window_start_ticks,group_mon.window_bytes, \
          group_mon.window_full,group_mon.bytes_complete,group_mon.phase_eligible,group_mon.bandwidth_gbps, \
          group_mon.phase_current.name(),group_mon.phase_evidence_count,group_mon.phase_candidate_count,phase_reason_name(group_mon.phase_reason)); \
    end

`define FIXED_DENSE .UPDATE_STRIDE(1),
// Spec 48 T4: four frozen input files, one compiled public-product program.
module tb_phase_fixed;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0, reset_n=1, valid=0, known=1;
  logic [63:0] member_bytes[4]='{default:0};
  wire [63:0] point_bytes=member_bytes[0]+member_bytes[1]+member_bytes[2]+member_bytes[3];
  int family,case_id=0,u=0;
  bit recording=0;
  bw_u64_t origin;
  bw_mon_setup setup();
  for(genvar f=0;f<4;f++)begin:families
    localparam logic [1:0] BASIS=(f==1 || f==2) ? BW_CYCLE : BW_NS;
    if(f<2)begin:default_stride
      `FIXED_SCOPE()
    end else begin:dense_stride
      `FIXED_SCOPE(`FIXED_DENSE)
    end
  end
  initial begin
    int fd,rc,next_case,ev,kn,rst;
    string input_path;
    if(!$value$plusargs("INPUT=%s",input_path) || !$value$plusargs("FAMILY=%d",family))$fatal(1,"input/family required");
    fd=$fopen(input_path,"r");if(!fd)$fatal(1,"input missing");
    wait(monitor_ready);origin=measurement_start_ticks;
    $display("FIXED_ENUM STEADY=%0d RAMP=%0d FALL=%0d",BW_PHASE_STEADY,BW_PHASE_RAMP,BW_PHASE_FALL);
    while(!$feof(fd))begin
      rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d\n",next_case,u,
        member_bytes[0],member_bytes[1],member_bytes[2],member_bytes[3],ev,kn,rst);
      if(rc!=9)$fatal(1,"malformed frozen input");
      if(next_case!=case_id)begin
        recording=0;
        if(case_id!=0)begin reset_n=0;#1000000;reset_n=1;origin=$time;end
        case_id=next_case;
        $display("FIXED_CASE case=%0d origin=%0d",case_id,origin);recording=1;
      end
      #(origin+(u-1)*1000000+1-$time);
      valid=ev;known=kn;reset_n=!rst;clk=1;#1;clk=0;
      #(origin+u*1000000-$time);
    end
    #2;recording=0;$fclose(fd);$display("TB_PASS phase_fixed");$finish;
  end
endmodule

`undef FIXED_SCOPE
`undef FIXED_DENSE
