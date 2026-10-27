module tb_episode_gaps;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [4:0] valid=0;
  logic [63:0] sizes[5];
  bw_mon_setup #(.EXPECTED_POINT_COUNT(5)) setup();
  for (genvar g=0;g<5;g++) begin : scopes
    bw_point_mon #(.POINT_ID($sformatf("episode.gap%0d",g)), .WINDOW_WIDTH(4), .UPDATE_STRIDE(1),
      .DYNAMIC_BYTES(1), .EPISODE_ENABLE(1), .SILENCE_THRESHOLD(4)) point
      (.clk(clk), .reset_n(1'b1), .valid(valid[g]), .size_bytes(sizes[g]), .size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for (int t=1;t<=17;t++) begin
      #(ns_to_ticks(t)-$time);
      valid='0;
      for (int i=0;i<5;i++) sizes[i]=8;
      valid[0]=(t==2 || t==6 || t==12); if (t==4) valid[0]=1'bx;
      if (t==12) sizes[0]=12;
      valid[1]=(t==3 || t==9); if (t==2) valid[1]=1'bx;
      valid[2]=(t==2); if (t==4) valid[2]=1'bx;
      valid[3]=(t==2 || t==4); if (t==4) sizes[3]='x;
      valid[4]=(t==8); if (t==2) valid[4]=1'bx;
      clk=1; #1; clk=0;
      if (t==8) begin
        if (scopes[1].point.episode_result_seq!=1 || scopes[1].point.episode_result.first_known ||
            scopes[1].point.episode_result.bytes_complete || scopes[1].point.episode_result.e2e_valid ||
            scopes[1].point.episode_result.confirmation_ticks!=8000000 ||
            !scopes[2].point.episode_active)
          $fatal(1,"a pre-first gap poisons that episode while a later gap restarts quiet evidence");
      end
      if (t==9) begin
        if (scopes[2].point.episode_result_seq!=1 || scopes[2].point.episode_result.last_known ||
            scopes[2].point.episode_result.confirmation_ticks!=9000000 ||
            scopes[2].point.episode_result.e2e_valid)
          $fatal(1,"unknown after the last definite event retains an ambiguous end and waits from recovery");
        if (scopes[3].point.episode_result_seq!=1 || !scopes[3].point.episode_result.first_known ||
            !scopes[3].point.episode_result.last_known || !scopes[3].point.episode_result.events_complete ||
            scopes[3].point.episode_result.event_count!=2 || scopes[3].point.episode_result.byte_count!=8 ||
            scopes[3].point.episode_result.bytes_complete || scopes[3].point.episode_result.e2e_valid ||
            scopes[3].point.episode_result.tail_ticks!=5000000)
          $fatal(1,"unknown size preserves two definite events and known boundaries but never complete bytes");
        if (!scopes[4].point.episode_first_known || !scopes[4].point.episode_bytes_complete)
          $fatal(1,"a complete quiet separator before new traffic clears earlier pre-episode ambiguity");
      end
      if (t==11) begin
        if (scopes[0].point.episode_result_seq!=1 || !scopes[0].point.episode_result.first_known ||
            !scopes[0].point.episode_result.last_known || scopes[0].point.episode_result.bytes_complete ||
            scopes[0].point.episode_result.events_complete || scopes[0].point.episode_result.byte_count!=16 ||
            scopes[0].point.episode_result.event_count!=2 || scopes[0].point.episode_result.tail_ticks!=7000000 ||
            scopes[0].point.episode_result.confirmation_ticks!=11000000 || !scopes[0].point.bytes_complete)
          $fatal(1,"an internal gap keeps both outer boundaries known; window recovery cannot repair episode totals");
      end
      if (t==13 && (!scopes[4].point.episode_result.e2e_valid ||
          scopes[4].point.episode_result.e2e_gbps!=8.0))
        $fatal(1,"post-separator episode must independently complete");
      if (t==14 && (!scopes[1].point.episode_result.e2e_valid ||
          scopes[1].point.episode_result.episode_id!=2))
        $fatal(1,"a completed separator restores the next episode's first-boundary quality");
    end
    if (scopes[0].point.episode_result_seq!=2 || !scopes[0].point.episode_result.e2e_valid ||
        scopes[0].point.episode_result.e2e_gbps!=12.0)
      $fatal(1,"a later complete episode must not inherit the old episode's sticky gap");
    $display("TB_PASS episode_gaps"); $finish;
  end
endmodule
