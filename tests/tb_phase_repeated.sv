module tb_phase_repeated;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] bytes=0;
  bw_u64_t expected_total=0;
  int ramps=0,falls=0,steadies=0;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("phase.repeated"),.WINDOW_BASIS(BW_CYCLE),.WINDOW_WIDTH(10),
    .DYNAMIC_BYTES(1),.EPISODE_ENABLE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(bytes),.size_known(1'b1));
  // Two consecutive copies of the accepted continuous input, without silence
  // at their join: repeated rise/fall transitions belong to one episode.
  function automatic int input_bytes(int u);
    int i;
    i=(u-1)%960;
    if(i<160)return 100;
    if(i<320)return 200;
    if(i<480)return int'($floor(200.0-100.0*(real'(i-320)+0.5)/160.0+0.5));
    if(i<640)return 100;
    if(i<800)return int'($floor(100.0+100.0*(real'(i-640)+0.5)/160.0+0.5));
    return 200;
  endfunction
  always @(point.phase_result_seq)begin
    if(point.phase_result_seq!=0)case(point.phase_result.phase_kind)
      BW_PHASE_RAMP:ramps++;
      BW_PHASE_FALL:falls++;
      BW_PHASE_STEADY:steadies++;
      default:$fatal(1,"undetermined intervals cannot become final phases");
    endcase
  end
  initial begin
    wait(monitor_ready);
    for(int u=1;u<=1932;u++)begin
      #(measurement_start_ticks+250000+(u-1)*1000000-$time);
      valid=u<=1920;bytes=valid ? input_bytes(u) : 0;
      if(valid)expected_total+=bytes;
      clk=1;#1;clk=0;
    end
    if(point.episode_id!=1 || point.episode_result_seq!=1 || ramps!=2 || falls!=2 || steadies!=8 ||
       point.phase_result_seq!=12 || !point.episode_result.e2e_valid ||
       point.episode_result.byte_count!=expected_total || point.episode_result.event_count!=1920 ||
       point.episode_result.duration_ticks!=1920000000 || !point.episode_result.last_steady_selection_valid)
      $fatal(1,"two ramps/two falls and eight platforms must remain one complete exact-byte episode");
    $display("TB_PASS phase_repeated");$finish;
  end
endmodule
