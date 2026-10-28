  // Ticket 56 end protocol. One persistent global audit runs before any owner
  // performs final settlement: the first final block to arrive freezes the
  // durable responsibility ledger, so no settlement can depend on which owner
  // finalized first. Every registered core/hint/owner role must then leave a
  // typed terminal receipt; one native end-of-simulation callback (after all
  // SV finals) verifies the receipts and emits the unique completion marker.
  // Nothing here waits, schedules NBAs, creates edges or advances time.
  import "DPI-C" context function void bw_end_coordinate_init();
  typedef enum {BW_END_ROLE_ACTIVE,BW_END_ROLE_DONE,BW_END_ROLE_CANCELLED} bw_end_role_state_t;
  string end_role_registry[string];
  bw_end_role_state_t end_role_state[string];
  bit end_audit_done=0;
  bw_u64_t end_audit_ticks=0;
  bw_u64_t end_audit_pending=0;
  bit end_marker_emitted=0;
  bit end_marker_settled_incomplete=0;

  function automatic void register_end_role(string owner_key,string role);
    string token;
    token={owner_key,":",role};
    if(end_role_registry.exists(token))return;
    end_role_registry[token]=token;
    end_role_state[token]=BW_END_ROLE_ACTIVE;
    bw_end_coordinate_init();
  endfunction

`ifdef BW_MON_TEST_END_FAULTS
  string end_receipt_suppressions[string];
  function automatic void suppress_end_receipt(string owner_key,string role);
    end_receipt_suppressions[{owner_key,":",role}]=1;
  endfunction
`endif

  // A role reaches exactly one terminal receipt; retries never duplicate.
  function automatic void note_role_receipt(string owner_key,string role,bit cancelled=0);
    string token;
    token={owner_key,":",role};
    if(!end_role_registry.exists(token))return;
    if(end_role_state[token]!=BW_END_ROLE_ACTIVE)return;
`ifdef BW_MON_TEST_END_FAULTS
    if(end_receipt_suppressions.exists(token))return;
`endif
    end_role_state[token]=cancelled ? BW_END_ROLE_CANCELLED : BW_END_ROLE_DONE;
  endfunction

  // Persistent pending-responsibility snapshot from the durable ledgers.
  // Queue lengths and requested==consumed are supplementary evidence owned
  // by each finalizer; this inventory is the frozen global audit base.
  function automatic bw_u64_t end_pending_responsibilities();
    bw_u64_t pending;
    pending=0;
    foreach(point_batches[id])
      if(!scope_disabled(BW_POINT,id) && !point_batches[id].cancelled &&
         (point_batches[id].captured!=point_batches[id].expected ||
          point_batches[id].inflight!=point_batches[id].expected ||
          point_batches[id].published!=point_batches[id].expected ||
          point_batches[id].accepted!=point_batches[id].expected ||
          point_batches[id].closed_generation!=point_batches[id].input_generation))
        pending++;
    foreach(group_batches[id])
      if(!scope_disabled(BW_GROUP,id) && !group_batches[id].cancelled &&
         (group_batches[id].captured!=group_batches[id].expected ||
          group_batches[id].held!=group_batches[id].expected ||
          group_batches[id].published!=group_batches[id].expected ||
          group_batches[id].accepted!=group_batches[id].expected ||
          group_batches[id].acked!=group_batches[id].expected ||
          group_batches[id].reset_captured!=group_batches[id].reset_expected ||
          group_batches[id].closed_generation!=group_batches[id].input_generation))
        pending++;
    return pending;
  endfunction

  // Idempotent audit gate: the first finalizer freezes the global evidence.
  function automatic void ensure_end_audit();
    if(end_audit_done)return;
    end_audit_done=1;
    end_audit_ticks=$time;
    end_audit_pending=end_pending_responsibilities();
    $display("BW_END_AUDIT ready=%0b owners=%0d pending_responsibilities=%0d time_ticks=%0d",
      monitor_ready,end_role_registry.num(),end_audit_pending,$time);
  endfunction

  function automatic bit end_missing_receipt(output string owner_key,output string role);
    int split;
    foreach(end_role_registry[token])
      if(end_role_state[token]==BW_END_ROLE_ACTIVE)begin
        split=token.len()-1;
        while(split>0 && token[split]!=8'd58)split--;
        owner_key=token.substr(0,split-1);
        role=token.substr(split+1,token.len()-1);
        return 1;
      end
    return 0;
  endfunction

  function automatic bit end_missing_terminal(output string scope_name);
    for(int k=0;k<2;k++) begin
      for(int i=0;i<registered_scope_count(bw_scope_t'(k));i++)
        if(!scope_terminals.exists(scope_key(bw_scope_t'(k),registered_scope_id(bw_scope_t'(k),i))))begin
          scope_name=registered_scope_id(bw_scope_t'(k),i);
          return 1;
        end
    end
    return 0;
  endfunction

  function automatic string end_integrity_state();
    foreach(scope_terminals[key])
      if(scope_terminals[key]==BW_SCOPE_DISABLED || scope_terminals[key]==BW_SCOPE_INTERRUPTED)
        return "INCOMPLETE";
    return "COMPLETE";
  endfunction

  // Runs from the native end-of-simulation callback, strictly after every SV
  // final block. It only reads frozen evidence and prints one verdict line.
  export "DPI-C" function bw_end_coordinate_verify;
  function automatic void bw_end_coordinate_verify();
    string owner_key,role,scope_name;
    int terminals,expected_scopes,done_roles;
    string integrity,performance;
    bw_report_summary_t value;
    if(end_marker_emitted || end_marker_settled_incomplete)return;
    if(!monitor_configured)return;
    if(core_failure_seen)begin
      end_marker_settled_incomplete=1;
      $display("BW_REPORT_INCOMPLETE reason=CORE_FAILURE time_ticks=%0d",$time);
      return;
    end
    if(!end_audit_done)begin
      end_marker_settled_incomplete=1;
      $display("BW_REPORT_INCOMPLETE reason=NO_END_AUDIT time_ticks=%0d",$time);
      return;
    end
    if(!monitor_ready)begin
      end_marker_settled_incomplete=1;
      $display("BW_REPORT_INCOMPLETE reason=NOT_READY stage=%s time_ticks=%0d",startup_stage,$time);
      return;
    end
    if(end_missing_receipt(owner_key,role))begin
      end_marker_settled_incomplete=1;
      $display("BW_REPORT_INCOMPLETE reason=MISSING_ROLE_RECEIPT owner=%s role=%s time_ticks=%0d",
        owner_key,role,$time);
      return;
    end
    if(end_missing_terminal(scope_name))begin
      end_marker_settled_incomplete=1;
      $display("BW_REPORT_INCOMPLETE reason=MISSING_SCOPE_TERMINAL scope=%s time_ticks=%0d",
        scope_name,$time);
      return;
    end
    expected_scopes=registered_scope_count(BW_POINT)+registered_scope_count(BW_GROUP);
    terminals=scope_terminals.num();
    done_roles=0;
    foreach(end_role_registry[token])
      if(end_role_state[token]!=BW_END_ROLE_ACTIVE)done_roles++;
    value=check_report_summary();
    if(value.scopes_done==value.scopes_expected && value.scopes_expected!=0)
      case(value.status)
        BW_REPORT_FAIL:performance="FAIL";
        BW_REPORT_WARNING:performance="WARNING";
        BW_REPORT_PASS:performance="PASS";
        default:performance="STATISTICS_ONLY";
      endcase
    else performance="NONE";
    integrity=end_integrity_state();
    end_marker_emitted=1;
    $display("BW_REPORT_COMPLETE audit=1 roles=%0d/%0d terminals=%0d/%0d summary=%0d integrity=%s performance=%s time_ticks=%0d",
      done_roles,end_role_registry.num(),terminals,expected_scopes,
      value.scopes_done==value.scopes_expected && value.scopes_expected!=0,integrity,performance,$time);
  endfunction
