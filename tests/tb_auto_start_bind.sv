// Ticket #50: one module-type bind discovers every actual instance; changing
// the instance count needs no configuration change.
module auto_link #(parameter int WIDTH=8) (input logic clk, input logic valid);
  logic unused;assign unused=valid;
endmodule

module auto_start_bind_fixture #(parameter int INSTANCES=3);
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  logic clk=0,valid=0;
  auto_link #(.WIDTH(8)) links[INSTANCES](.clk(clk),.valid(valid));
  bind auto_link bw_point_mon #(.WINDOW_WIDTH(4),.UPDATE_STRIDE(4),.FIXED_BYTES(8),.PHASE_ENABLE(0)) u_bw
    (.clk(clk),.reset_n(1'b1),.valid(valid));
  bw_mon_setup setup();
  for(genvar i=0;i<INSTANCES;i++)begin : verify_bound
    initial begin
      wait(monitor_ready);#1000002;
      if(links[i].u_bw.total_bytes!=8 || links[i].u_bw.raw_record.edge_index!=1)
        $fatal(1,"each actual bind instance must count the first legal edge");
    end
  end
  initial begin
    bw_report_summary_t summary;
    wait(monitor_ready);
    summary=check_report_summary();
    if (registered_scope_count(BW_POINT)!=INSTANCES || summary.scopes_expected!=INSTANCES)
      $fatal(1,"bind instances must be discovered without manual counts");
    #1000000;valid=1;clk=1;#1;clk=0;
    #2;
    $display("TB_PASS auto_start_bind instances=%0d",INSTANCES);$finish;
  end
endmodule
module tb_auto_start_bind;
  auto_start_bind_fixture fixture();
endmodule
