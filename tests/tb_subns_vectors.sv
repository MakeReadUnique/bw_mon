module tb_subns_vectors;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  logic [63:0] size_bytes=0;
  bw_mon_setup setup();
  bw_point_mon #(.DYNAMIC_BYTES(1),.WINDOW_WIDTH(10),.UPDATE_STRIDE(1)) point
    (.clk(clk),.reset_n(1'b1),.valid(valid),.size_bytes(size_bytes),.size_known(1'b1));
  task automatic send_at(bw_u64_t at_ticks, bw_u64_t bytes_now);
    #(at_ticks+1-$time);size_bytes=bytes_now;valid=1;clk=1;
    #1;clk=0;valid=0;
  endtask
  task automatic check(bw_u64_t at_ticks, bw_u64_t expected_bytes,real expected_gbps);
    #(at_ticks+1-$time);#1;
    if(point.window_end_ticks!=at_ticks || point.window_start_ticks!=at_ticks-10000000 ||
       point.window_bytes!=expected_bytes || !point.window_valid ||
       $abs(point.bandwidth_gbps-expected_gbps)>1e-10)
      $fatal(1,"T5-E2 table at relative T=%0.3f ns expected=%0dB/%0.12fGB/s actual=%0dB/%0.12fGB/s",
        real'(at_ticks-1000000)/1000000.0,expected_bytes,expected_gbps,
        point.window_bytes,point.bandwidth_gbps);
  endtask
  initial begin
    wait(monitor_ready);
    // Spec T5-E2 is translated by +1 ns so its relative-zero event is
    // strictly after the common measurement start, on a legal actual edge.
    fork
      begin
        send_at(1000000,64);send_at(3000000,64);send_at(5000000,128);
        send_at(8500000,64);send_at(11000000,128);send_at(13000000,64);
        send_at(17000000,64);send_at(21000000,128);
      end
      begin
        check(11000000,320,32.0);check(12000000,384,38.4);check(13000000,384,38.4);
        check(21000000,256,25.6);check(23000000,256,25.6);
      end
    join
    if(point.total_bytes!=704 || point.total_events!=8 || point.sampled_size_bytes!=128)
      $fatal(1,"T5-E2 dynamic raw cumulative/sample result incorrect");
    $display("TB_PASS subns_vectors");$finish;
  end
endmodule
