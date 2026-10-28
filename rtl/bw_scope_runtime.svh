  function automatic bit runtime_failed();
    return scope_failed(bw_scope_t'(scope_kind),scope_id);
  endfunction
  function automatic bw_u64_t request_slot_settlement(string context_id);
    bw_u64_t grant;
    grant=bw_mon_pkg::request_slot_settlement(context_id);
    if(scope_kind==BW_POINT)point_work_requested(scope_id,grant);
    return grant;
  endfunction
  // Private typed runtime adapter. Configuration validation stays in the
  // package's fatal lifecycle path; runtime helpers carry this owner's type.
  function automatic void core_error(string code,string context_id,string detail);
    if($isunknown(scope_kind))begin runtime_shared_error(code,context_id,detail);return;end
    runtime_scope_error(bw_scope_t'(scope_kind),scope_id,code,{"context=",context_id," ",detail});
  endfunction
  function automatic bw_u64_t checked_add(logic [63:0] a,logic [63:0] b,string context_id);
    logic [64:0] wide;
    if(runtime_failed())return a;
    if($isunknown({a,b}))begin core_error("INTEGER_UNKNOWN",context_id,$sformatf("addition a=%h b=%h",a,b));return a;end
    wide={1'b0,a}+{1'b0,b};
    if(wide[64])begin core_error("INTEGER_OVERFLOW",context_id,$sformatf("addition a=%0d b=%0d",a,b));return a;end
    return wide[63:0];
  endfunction
  function automatic bw_u64_t checked_sub(logic [63:0] a,logic [63:0] b,string context_id);
    if(runtime_failed())return a;
    if($isunknown({a,b}))begin core_error("INTEGER_UNKNOWN",context_id,$sformatf("subtraction a=%h b=%h",a,b));return a;end
    if(b>a)begin core_error("INTEGER_UNDERFLOW",context_id,$sformatf("subtraction a=%0d b=%0d",a,b));return a;end
    return a-b;
  endfunction
  function automatic bw_u64_t checked_mul(logic [63:0] a,logic [63:0] b,string context_id);
    logic [127:0] wide;
    if(runtime_failed())return a;
    if($isunknown({a,b}))begin core_error("INTEGER_UNKNOWN",context_id,$sformatf("multiplication a=%h b=%h",a,b));return a;end
    wide={64'b0,a}*{64'b0,b};
    if(wide[127:64]!=0)begin core_error("INTEGER_OVERFLOW",context_id,$sformatf("multiplication a=%0d b=%0d",a,b));return a;end
    return wide[63:0];
  endfunction
  function automatic void check_storage_growth(int current_size,string context_id,string resource,
      bw_u64_t at_ticks=0,bw_u64_t edge_index=0,bw_u64_t record_number=0,bit preparation=0);
    if(runtime_failed())return;
    if(current_size<0 || current_size==32'sh7fffffff)begin
      if(preparation)fatal_core_error("STORAGE_RANGE",scope_id,$sformatf("resource=%s entries=%0d preparation=1",resource,current_size));
      else core_error("STORAGE_RANGE",context_id,$sformatf("resource=%s entries=%0d cannot grow",resource,current_size));return;
    end
`ifdef BW_MON_TEST_SCHEDULING
    if(!bw_test_storage_peak.exists(resource) || current_size+1>bw_test_storage_peak[resource])
      bw_test_storage_peak[resource]=current_size+1;
`endif
`ifdef BW_MON_TEST_FAULTS
    if(injected_growth_failures.exists(context_id) && injected_growth_failures[context_id].exists(resource))begin
      injected_growth_failures[context_id].delete(resource);
      if(preparation)fatal_core_error("STORAGE_FAILURE",scope_id,$sformatf("resource=%s entries=%0d requested=1 original_ticks=%0d injected=1 preparation=1",resource,current_size,at_ticks));
      else core_error("STORAGE_FAILURE",context_id,$sformatf("resource=%s entries=%0d requested=1 edge=%0d record_seq=%0d original_ticks=%0d injected=1",resource,current_size,edge_index,record_number,at_ticks));
    end
`endif
  endfunction
  function automatic void check_monitor_time(logic [63:0] ticks,string context_id);
    if($isunknown(ticks))core_error("INTEGER_UNKNOWN",context_id,$sformatf("time_ticks=%h",ticks));
    else if(!monitor_time_supported(ticks))core_error("SIM_TIME_LIMIT",context_id,$sformatf("received_ticks=%0d",ticks));
  endfunction
  function automatic void validate_record_numeric(bw_record_t value,string context_id);
    if($isunknown({value.timestamp_ticks,value.edge_index,value.record_seq,value.source_epoch,value.byte_inc,value.event_inc,value.reset_points}))
      core_error("INTEGER_UNKNOWN",context_id,"unknown numeric frame metadata");
  endfunction
  function automatic void validate_control_numeric(bw_control_t value,string context_id);
    if($isunknown({value.timestamp_ticks,value.control_seq,value.source_epoch,value.point_handle}))
      core_error("INTEGER_UNKNOWN",context_id,"unknown numeric control metadata");
  endfunction
