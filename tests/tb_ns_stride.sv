module tb_ns_stride;
  timeunit 1ns; timeprecision 1fs;
  logic clk=0, valid=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.POINT_ID("explicit.point"),.WINDOW_WIDTH(10),.UPDATE_STRIDE(3),
                 .FIXED_BYTES(8)) point(.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    wait(bw_mon_pkg::monitor_ready);
    if(point.scope_id!="explicit.point" || point.monitor_path!="tb_ns_stride.point")
      $fatal(1,"explicit identity/path incorrect");
    if(point.coverage_ticks!=0 || point.denominator_valid || point.window_full)
      $fatal(1,"zero-coverage initial quality incorrect");
    #250000fs; valid=1; clk=1;
    #1fs; clk=0;
    #2499999fs; clk=1;
    #1fs; clk=0;valid=0;
    #249999fs; // T=3 ns, publication after 0.25 and 2.75 ns events
    #1fs;
    if(point.result_seq!=1 || point.window_bytes!=16 || !point.window_warmup ||
       point.window_full || point.coverage_ticks!=3000000 || !point.denominator_valid)
      $fatal(1,"3 ns warmup result incorrect");
    if($abs(point.bandwidth_gbps-5.333333333333333)>1e-10)
      $fatal(1,"warmup must use actual 3 ns denominator");
    #6999999fs; // T=10 ns: no extra publication when W is first covered
    #1fs;
    if(point.result_seq!=3 || point.window_full || point.window_end_ticks!=9000000)
      $fatal(1,"W not divisible by S inserted an off-schedule full result");
    #1999999fs;
    #1fs;
    if(point.result_seq!=4 || !point.window_full || point.window_warmup ||
       point.window_start_ticks!=2000000 || point.window_end_ticks!=12000000 ||
       point.window_bytes!=8 || $abs(point.bandwidth_gbps-0.8)>1e-10)
      $fatal(1,"first scheduled full [2,12) window incorrect");
    $display("TB_PASS ns_stride");$finish;
  end
endmodule
