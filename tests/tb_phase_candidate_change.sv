module tb_phase_candidate_change;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [63:0] bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.candidate"),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(bytes),.size_known(1'b1));
  initial begin
    wait(monitor_ready);
    for(int u=1;u<=21;u++)begin
      #(measurement_start_ticks+u*1000000-500000-$time);
      bytes=u<=6 ? 100 : u<=11 ? (u-6)*1000 : u==12 ? 100 : 1000;
      clk=1;#1;clk=0;#(measurement_start_ticks+u*1000000+1-$time);
      if(u==6 && (point.phase_candidate!=BW_PHASE_STEADY || point.phase_candidate_count!=1))
        $fatal(1,"initial six-window steady candidate begins at one");
      if(u==7 && (point.phase_candidate_count!=0 || point.phase_id!=0))
        $fatal(1,"a spike cancels unconfirmed steady without inheriting its count");
      if(u==11 && (point.phase_candidate!=BW_PHASE_RAMP || point.phase_candidate_count!=1 || point.phase_id!=0))
        $fatal(1,"three adjacent-pair points on the rising sequence establish a new ramp candidate");
      if(u==12 && (point.phase_candidate_count!=0 || point.phase_id!=0))
        $fatal(1,"a changed fit cancels the unconfirmed ramp without creating a final phase");
      if(u==18 && (point.phase_candidate!=BW_PHASE_STEADY || point.phase_candidate_count!=1 || point.phase_id!=0))
        $fatal(1,"fresh steady evidence starts its own two-update confirmation");
      if(u==19 && (point.phase_current!=BW_PHASE_STEADY || point.phase_id!=1 ||
         point.phase_start_ticks!=measurement_start_ticks+18000000 || point.phase_result_seq!=0))
        $fatal(1,"only the final consecutive candidate chain confirms");
    end
    $display("TB_PASS phase_candidate_change");$finish;
  end
endmodule
