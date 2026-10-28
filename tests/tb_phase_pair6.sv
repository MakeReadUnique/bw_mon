module tb_phase_pair6;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0;
  logic [63:0] bytes=92;
  bw_mon_setup setup();
  for(genvar m=0;m<4;m++)begin:members
    bw_point_mon #(.POINT_ID($sformatf("pair6.p%0d",m)),.WINDOW_WIDTH(1),.DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
      (.clk(clk),.reset_n(1'b1),.valid(1'b1),.size_known(1'b1),.size_bytes(bytes));
    initial add_point_member("pair6.group",$sformatf("pair6.p%0d",m));
  end
  bw_group_mon #(.GROUP_ID("pair6.group"),.WINDOW_WIDTH(1),.EPISODE_ENABLE(1)) group_mon
    (.clk(clk),.reset_n(1'b1));
  initial begin
    wait(monitor_ready);
    for(int update=1;update<=24;update++)begin
      bytes=(update%2) ? 92 : 108;
      #(measurement_start_ticks+update*1000000-500000-$time);clk=1;#1;clk=0;
      #(measurement_start_ticks+update*1000000+1-$time);
      if(update>=7 && (members[0].point.phase_current!=BW_PHASE_STEADY || group_mon.phase_current!=BW_PHASE_STEADY ||
          members[0].point.phase_id!=1 || group_mon.phase_id!=1 ||
          members[0].point.phase_fit_delta!=0 || group_mon.phase_fit_delta!=0 ||
          members[0].point.phase_fit_rms!=8 || group_mon.phase_fit_rms!=32 ||
          members[0].point.window_bytes!=bytes || group_mon.window_bytes!=4*bytes))
        $fatal(1,"adjacent-pair fit must retain an alternating eight-percent plateau and every raw sample");
    end
    $display("TB_PASS phase_pair6");$finish;
  end
endmodule
