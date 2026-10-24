module tb_credit_timing;
  timeunit 1ns;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,flitv=1,lcrdv=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(4)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_NEXT_CYCLE)) next_credit
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(1),.CREDIT_INITIAL(0),.CREDIT_INITIAL_KNOWN(1),
    .CREDIT_RETURN_TIMING(BW_RETURN_SAME_CYCLE)) same_credit
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(1'b1),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.FIXED_BYTES(64),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),.CREDIT_ENABLE(1)) unsupported
    (.clk(clk),.reset_n(1'b1),.valid(flitv));
  initial begin
    wait(monitor_ready);
    #1ns;clk=1;#1fs;clk=0;
    if(next_credit.credit_trusted || !next_credit.credit_anomaly ||
       next_credit.credit_reason!=BW_CREDIT_NO_CREDIT || next_credit.credit_attempted_balance!==66'sd0 ||
       next_credit.credit_permission_known!==1 || next_credit.credit_send_permitted!==0 ||
       !$isunknown(next_credit.credit_balance))
      $fatal(1,"C=0 S=R=1 next-cycle mode must lose trust for no-credit send");
    if(!same_credit.credit_trusted || same_credit.credit_anomaly || same_credit.credit_balance!==64'd0 ||
       same_credit.credit_send_permitted!==1 || same_credit.credit_available_before!==65'd1)
      $fatal(1,"C=0 S=R=1 same-cycle mode permits send and retains zero balance");
    if(!disabled.credit_supported || disabled.credit_enabled || disabled.credit_trusted ||
       disabled.credit_state!=BW_CREDIT_DISABLED || disabled.credit_anomaly_count!=0)
      $fatal(1,"supported but disabled must remain distinct from trusted ledger");
    if(unsupported.credit_supported || !unsupported.credit_enabled || unsupported.credit_trusted ||
       unsupported.credit_state!=BW_CREDIT_UNSUPPORTED)
      $fatal(1,"unsupported interface is a distinct diagnostic capability");
    #999999fs;clk=1;#1fs;clk=0;
    if(next_credit.credit_anomaly_count!=1 || next_credit.total_bytes!=128 ||
       same_credit.total_bytes!=128 || disabled.total_bytes!=128 || unsupported.total_bytes!=128)
      $fatal(1,"trust loss is sticky, and all definite transfers still count");
    #999999fs;#1fs;
    if(next_credit.window_bytes!=128 || same_credit.window_bytes!=128 || disabled.window_bytes!=128 ||
       !next_credit.bytes_complete || !same_credit.bytes_complete || !disabled.bytes_complete ||
       next_credit.bandwidth_gbps!=64.0)
      $fatal(1,"enabled, disabled and anomalous ledger must have identical known window accounting");
    $display("TB_PASS credit_timing");$finish;
  end
endmodule
