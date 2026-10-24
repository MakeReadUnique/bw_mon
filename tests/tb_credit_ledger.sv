module tb_credit_ledger;
  timeunit 1ns;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,reset_n=1,flitv=0,lcrdv=0;
  bw_mon_setup #(.EXPECTED_POINT_COUNT(2)) setup();
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(32),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1),
    .CREDIT_ENABLE(1),.CREDIT_CAPACITY(2),.CREDIT_INITIAL(2),.CREDIT_INITIAL_KNOWN(1)) enabled
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  bw_point_mon #(.PROTOCOL(BW_CREDIT),.FIXED_BYTES(32),.WINDOW_WIDTH(2),.UPDATE_STRIDE(1)) disabled
    (.clk(clk),.reset_n(reset_n),.flitv(flitv),.lcrdv(lcrdv));
  task automatic sample_at(longint unsigned at_ticks,logic send_now,logic return_now);
    #(at_ticks-$time);flitv=send_now;lcrdv=return_now;clk=1;#1fs;clk=0;
  endtask
  task automatic check_balance(logic [63:0] expected_balance);
    if(!enabled.credit_trusted || enabled.credit_balance!==expected_balance || enabled.credit_anomaly)
      $fatal(1,"expected trusted balance=%0d, actual=%0d state=%0d reason=%0d",
        expected_balance,enabled.credit_balance,enabled.credit_state,enabled.credit_reason);
  endtask
  task automatic same_accounting();
    if(enabled.total_bytes!=disabled.total_bytes || enabled.total_events!=disabled.total_events ||
       enabled.window_bytes!=disabled.window_bytes || enabled.bytes_complete!=disabled.bytes_complete ||
       enabled.events_complete!=disabled.events_complete)
      $fatal(1,"credit diagnosis must not affect independently observed raw accounting");
  endtask
  initial begin
    wait(monitor_ready);
    sample_at(1000000,1,0);check_balance(1);
    sample_at(2000000,1,0);check_balance(0);
    if(!enabled.credit_shortage_known || enabled.credit_shortage!==1)
      $fatal(1,"trusted zero available credit must be visible independently of demand");
    sample_at(3000000,0,1);check_balance(1);
    sample_at(4000000,1,1);check_balance(1);
    sample_at(5000000,1,1'bx);
    if(enabled.credit_trusted || enabled.credit_reason!=BW_CREDIT_CONTROL_UNKNOWN ||
       enabled.credit_anomaly_count!=1 || !enabled.raw_record.bytes_complete ||
       enabled.raw_record.byte_inc!=32 || enabled.sampled_lcrdv!==1'bx)
      $fatal(1,"unknown return loses ledger trust but preserves a definite flit and bytes");
    sample_at(6000000,1,0);
    if(enabled.credit_trusted || enabled.credit_anomaly_count!=1 || enabled.total_bytes!=160)
      $fatal(1,"known later traffic cannot repair an untrusted ledger");
    same_accounting();
    #499999fs;reset_n=0;#1fs;
    if(enabled.credit_state!=BW_CREDIT_RESET || enabled.credit_trusted || enabled.credit_epoch!=1)
      $fatal(1,"no-clock known reset must interrupt the ledger and advance its epoch");
    #1ns;reset_n=1;#1fs;check_balance(2);
    sample_at(8000000,1,0);check_balance(1);same_accounting();
    sample_at(9000000,0,1);check_balance(2);
    sample_at(10000000,0,1);
    if(enabled.credit_trusted || enabled.credit_reason!=BW_CREDIT_OVERFLOW ||
       enabled.credit_attempted_balance!==66'sd3 || enabled.credit_last_trusted_balance!==64'd2 ||
       !$isunknown(enabled.credit_balance) || enabled.credit_anomaly_count!=2)
      $fatal(1,"capacity overflow must retain exact attempted value and lose trust without clamping");
    sample_at(11000000,1,0);same_accounting();
    #499999fs;reset_n=0;#250000fs;reset_n=1;#1fs;check_balance(2);
    sample_at(12000000,1'bx,0);
    if(enabled.credit_trusted || enabled.credit_reason!=BW_CREDIT_CONTROL_UNKNOWN ||
       enabled.credit_anomaly_count!=3 || enabled.raw_record.events_complete ||
       enabled.raw_record.bytes_complete)
      $fatal(1,"unknown send interrupts both ledger trust and genuinely unknown activity evidence");
    same_accounting();
    $display("TB_PASS credit_ledger");$finish;
  end
endmodule
