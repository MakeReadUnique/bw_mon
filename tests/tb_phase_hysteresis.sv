module tb_phase_hysteresis;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [63:0] bytes[2];
  bw_mon_setup setup();
  for(genvar g=0;g<2;g++)begin:scopes
    bw_point_mon #(.POINT_ID($sformatf("phase.threshold%0d",g)),.WINDOW_WIDTH(1),
      .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_bytes(bytes[g]),.size_known(1'b1));
  end
  initial begin
    wait(monitor_ready);
    for(int u=1;u<=15;u++)begin
      #(measurement_start_ticks+u*1000000-500000-$time);
      bytes[0]=u<=7 ? 980+(u-1)*8 : 1028;
      bytes[1]=u<=8 ? 960 : 960+(u-9)*16;
      clk=1;#1;clk=0;#(measurement_start_ticks+u*1000000+1-$time);
      if(u==6 && (scopes[0].point.phase_candidate!=BW_PHASE_STEADY ||
          scopes[0].point.phase_fit_mean!=1000 || scopes[0].point.phase_fit_delta!=40))
        $fatal(1,"equality at four-percent entry admits the first steady candidate");
      if(u==7 && scopes[0].point.phase_current!=BW_PHASE_STEADY)
        $fatal(1,"relative entry confirms without any absolute threshold");
      if(u==14 && (scopes[1].point.phase_current!=BW_PHASE_STEADY || scopes[1].point.phase_id!=1 ||
         scopes[1].point.phase_fit_mean!=1000 || scopes[1].point.phase_fit_delta!=80 ||
         scopes[1].point.phase_fit_rms!=0 || scopes[1].point.phase_fit_trend_rms!=0))
        $fatal(1,"equality at eight-percent hold preserves steady while four-percent entry is false");
    end
    $display("TB_PASS phase_hysteresis");$finish;
  end
endmodule
