module tb_credit_reset_unknown;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(8),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(2),.CREDIT_INITIAL(1),.CREDIT_INITIAL_KNOWN(1)) point
    (.clk(clk),.reset_n(reset_n),.flitv(1'b1),.lcrdv(1'b0));
  initial begin
    wait(monitor_ready);
    #500000;reset_n=1'bx;#1;
    if(point.credit_trusted || point.credit_reason!=BW_CREDIT_RESET_UNKNOWN ||
       point.credit_record_seq!=0 || !$isunknown(point.credit_balance))
      $fatal(1,"unknown no-clock reset must interrupt trust without inventing an edge");
    #249999;reset_n=1;#1;
    if(point.credit_trusted || point.credit_reason!=BW_CREDIT_RESET_UNKNOWN)
      $fatal(1,"return from uncertain reset cannot invent a trustworthy initial balance");
    #249999;reset_n=0;#1;
    if(point.credit_state!=BW_CREDIT_RESET || point.credit_epoch!=1 || point.credit_record_seq!=0)
      $fatal(1,"known reset independently restores the configured ledger seed");
    #249999;reset_n=1;#1;
    if(!point.credit_trusted || point.credit_balance!==64'd1 || point.credit_anomaly)
      $fatal(1,"known reset release must recover trusted initial state without sampling");
    #749999;clk=1;#1;
    if(!point.credit_trusted || point.credit_balance!==64'd0 || point.credit_record_seq!=1 ||
       point.total_bytes!=8 || point.credit_anomaly_count!=1)
      $fatal(1,"first resumed edge must use restored balance and preserve diagnostic history");
    $display("TB_PASS credit_reset_unknown");$finish;
  end
endmodule
