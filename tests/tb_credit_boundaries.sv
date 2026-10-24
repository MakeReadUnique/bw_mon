module tb_credit_boundaries;
  timeunit 1ns;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,hf=1,hr=1,zf=0,zr=0,ur=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(3)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(64'hffffffffffffffff),.CREDIT_INITIAL(64'hffffffffffffffff),
    .CREDIT_INITIAL_KNOWN(1),.CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE)) huge
    (.clk(clk),.reset_n(1'b1),.flitv(hf),.lcrdv(hr));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(0),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(0),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE)) zero
    (.clk(clk),.reset_n(1'b1),.flitv(zf),.lcrdv(zr));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(4),.CREDIT_INITIAL(4),.CREDIT_INITIAL_KNOWN(0)) unknown_initial
    (.clk(clk),.reset_n(1'b1),.flitv(1'b1),.lcrdv(ur));
  initial begin
    wait(monitor_ready);
    #1ns;clk=1;#1fs;clk=0;
    if(!huge.credit_trusted || huge.credit_balance!==64'hffffffffffffffff ||
       huge.credit_available_before!==65'd18446744073709551616 ||
       huge.credit_attempted_balance!==66'sd18446744073709551615)
      $fatal(1,"maximum 64-bit credit with simultaneous S/R needs exact widened arithmetic");
    if(!zero.credit_trusted || zero.credit_balance!==64'd0 || zero.credit_shortage!==1)
      $fatal(1,"explicit zero capacity is legal and must not be replaced with a default");
    if(unknown_initial.credit_trusted || !$isunknown(unknown_initial.credit_balance) ||
       unknown_initial.credit_reason!=BW_CREDIT_INITIAL_UNKNOWN || unknown_initial.credit_anomaly_count!=0)
      $fatal(1,"untrusted initial value must not become an assumed zero or inferred balance");
    hf=0;zf=1;zr=1;
    #999999fs;clk=1;#1fs;clk=0;
    if(huge.credit_trusted || huge.credit_reason!=BW_CREDIT_OVERFLOW ||
       huge.credit_attempted_balance!==66'sd18446744073709551616 || huge.total_bytes!=64)
      $fatal(1,"credit beyond 64-bit capacity is protocol overflow, not wrapped statistics or fatal core error");
    if(!zero.credit_trusted || zero.credit_balance!==64'd0 || zero.total_events!=1 || zero.total_bytes!=0)
      $fatal(1,"one zero-byte flit still consumes one same-cycle returned credit");
    zr=0;ur=1'bz;
    #999999fs;clk=1;#1fs;
    if(zero.credit_trusted || zero.credit_reason!=BW_CREDIT_NO_CREDIT ||
       zero.credit_attempted_balance!==-66'sd1 || !$isunknown(zero.credit_balance) ||
       zero.total_events!=2 || zero.total_bytes!=0)
      $fatal(1,"negative attempted balance must stay exact, untrusted and independent of zero-byte activity");
    if(unknown_initial.credit_reason!=BW_CREDIT_CONTROL_UNKNOWN || unknown_initial.credit_trusted ||
       unknown_initial.total_bytes!=192 || !unknown_initial.raw_record.bytes_complete)
      $fatal(1,"unknown return remains diagnosable while known flits keep accumulating");
    $display("TB_PASS credit_boundaries");$finish;
  end
endmodule
