module tb_numeric_queries;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  string mode,id;
  int handle,count;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="time";
    handle=register_point("query.subject","component",BW_NS,1,1);wait(monitor_ready);
    if(mode=="time")check_monitor_time(64'hx000000000000001,"time.subject");
    else if(mode=="scope_kind")count=registered_scope_count(2'b0x);
    else if(mode=="scope_index")id=registered_scope_id(BW_POINT,64'hx000000000000000);
    else if(mode=="scope_invalid")count=registered_scope_count(2'b10);
    else if(mode=="pure_time")begin
      if(monitor_time_supported(64'hx000000000000001))$fatal(1,"unknown time cannot satisfy a pure range predicate");
      if(core_failure_seen)$fatal(1,"pure range predicate cannot latch failure");
      $display("TB_PASS numeric_queries pure_time");$finish;
    end else if(mode=="known")begin
      if(!monitor_time_supported(measurement_start_ticks+64'd40000000000) || monitor_time_supported(measurement_start_ticks+64'd40000000001) ||
         registered_scope_count(BW_POINT)!=1 || registered_scope_count(BW_GROUP)!=0 ||
         registered_scope_id(BW_POINT,0)!="query.subject")$fatal(1,"exact immutable budget or typed registry query failed");
      $display("TB_PASS numeric_queries known");$finish;
    end else $fatal(1,"bad MODE");
    if(!monitoring_shared_disabled)$fatal(1,"unowned invalid query must conservatively disable monitoring");
    $display("TB_PASS numeric_queries shared_quarantined mode=%s",mode);$finish;
  end
endmodule
