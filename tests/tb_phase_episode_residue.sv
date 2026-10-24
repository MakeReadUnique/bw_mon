module tb_phase_episode_residue;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [1:0] valid=0;
  logic [63:0] bytes[2];
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.residue%0d",g)),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1),.SILENCE_THRESHOLD(g==0 ? 1 : 3),
      .PHASE_ENABLE(1),.PHASE_N(3),.PHASE_MIN_SPAN(2),.PHASE_K(1),
      .PHASE_STEADY_ENTER_ABS(0.1),.PHASE_STEADY_ENTER_REL(0.0),
      .PHASE_STEADY_EXIT_ABS(0.2),.PHASE_STEADY_EXIT_REL(0.0),
      .PHASE_RMS_ENTER_ABS(1.0),.PHASE_RMS_ENTER_REL(0.0),
      .PHASE_RMS_EXIT_ABS(1.0),.PHASE_RMS_EXIT_REL(0.0),
      .PHASE_TREND_ABS(0.5),.PHASE_TREND_REL(0.0)) point
      (.clk(clk),.reset_n(1'b1),.valid(valid[g]),.size_bytes(bytes[g]),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int t=1;t<=31;t++)begin
      #(ns_to_ticks(t)-$time);
      valid[0]=(t==1 || t==3 || t==5 || (t>=7 && t<=26));
      bytes[0]=(t==1 || t==5) ? 0 : 8;
      valid[1]=(t==1 || (t>=7 && t<=26));if(t==3)valid[1]=1'bx;
      bytes[1]=8;clk=1;#1;clk=0;
      if(t==10 && (scopes[0].point.episode_id!=4 || scopes[0].point.phase_eligible ||
          scopes[0].point.phase_evidence_count!=0))
        $fatal(1,"multiple prior episodes cannot contribute phase evidence to the fourth process");
      if(t==13 && (scopes[1].point.bytes_complete || scopes[1].point.phase_eligible ||
          scopes[1].point.episode_result.last_known || scopes[1].point.episode_result.e2e_valid))
        $fatal(1,"unknown later old activity remains an independent quality exclusion after known old activity expires");
      if(t==14 && (!scopes[1].point.bytes_complete || !scopes[1].point.phase_eligible ||
          scopes[1].point.phase_evidence_count!=1))
        $fatal(1,"new evidence begins only after the old unknown position leaves the window");
      if(t==15 && (!scopes[0].point.window_full || !scopes[0].point.bytes_complete ||
          scopes[0].point.window_start_ticks!=5000000 || scopes[0].point.window_bytes!=64 ||
          scopes[0].point.window_events!=9 || scopes[0].point.phase_eligible ||
          scopes[0].point.phase_evidence_count!=0))
        $fatal(1,"the zero-byte old event at the exact left endpoint still disqualifies this full known window");
      if(t==16 && (!scopes[0].point.phase_eligible || scopes[0].point.phase_evidence_count!=1 ||
          scopes[0].point.window_start_ticks!=6000000 || scopes[0].point.window_bytes!=72))
        $fatal(1,"excluding the last old zero-byte event starts a genuinely new evidence chain");
      if(t==18 && (scopes[0].point.phase_evidence_count!=3 ||
          !scopes[0].point.phase_evidence_sufficient || !scopes[0].point.phase_fit_valid))
        $fatal(1,"three new eligible observations are required after all old activity expires");
    end
    if(scopes[0].point.episode_result_seq!=4 || scopes[1].point.episode_result_seq!=2 ||
       !scopes[0].point.episode_result.e2e_valid || !scopes[1].point.episode_result.e2e_valid)
      $fatal(1,"complete quiet separators restore later episode quality independently of earlier zero/unknown activity");
    $display("TB_PASS phase_episode_residue");$finish;
  end
endmodule
