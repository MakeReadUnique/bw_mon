module tb_variation_pending_retention;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=1;
  bw_mon_setup setup();
  bw_point_mon #(.POINT_ID("pending.subject"),.FIXED_BYTES(8),.WINDOW_WIDTH(1),.UPDATE_STRIDE(1),
    .EPISODE_ENABLE(1),.SILENCE_THRESHOLD(30000),.PHASE_ENABLE(1)) point_mon
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  initial begin
    wait(monitor_ready);
    #250000;
    repeat(6)begin clk=1;#1;clk=0;#499999;end
    valid=0;clk=1;#1;clk=0;
    #(measurement_start_ticks+64'd30003250001-$time);
    if(point_mon.raw_record.record_seq!=7 || point_mon.accepted_record_seq!=7 || point_mon.result_seq!=30003 ||
       point_mon.episode_result_seq!=1 || point_mon.episode_result.status!=BW_EPISODE_COMPLETE ||
       point_mon.episode_result.first_ticks!=250001 || point_mon.episode_result.last_ticks!=2750001 ||
       point_mon.episode_result.tail_ticks!=3250001 || point_mon.episode_result.confirmation_ticks!=measurement_start_ticks+64'd30003250000 ||
       point_mon.episode_result.byte_count!=48 || point_mon.episode_result.event_count!=6 ||
       point_mon.episode_result.duration_ticks!=3000000 || !point_mon.episode_result.e2e_valid ||
       $abs(point_mon.episode_result.e2e_gbps-16.0)>1e-10)
      $fatal(1,"long known quiet must retain the literal six-transfer episode and exact original tail/Q");
    if(point_mon.episode_result.variation.sample_count!=3 ||
       point_mon.episode_result.variation.first_sample_ticks!=measurement_start_ticks+1000000 ||
       point_mon.episode_result.variation.last_sample_ticks!=measurement_start_ticks+3000000 ||
       !point_mon.episode_result.variation.minmax_valid || !point_mon.episode_result.variation.stddev_valid ||
       !point_mon.episode_result.variation.cv_valid || point_mon.episode_result.last_steady_found ||
       $abs(point_mon.episode_result.variation.mean_gbps-16.0)>1e-10 ||
       point_mon.episode_result.variation.stddev_gbps!=0 || point_mon.episode_result.variation.cv_pct!=0)
      $fatal(1,"30000 confirmation-only publications after-tail suffix under fixed K=2 must be excluded without losing the owned prefix");
    $display("TB_PASS variation_pending_retention episode_bytes=48 events=6 selected_samples=3 mean=16 sigma=0");$finish;
  end
endmodule
