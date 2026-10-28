  function automatic void release_source_prefix(bw_source_state source);
    bw_u64_t frames,controls;
    bw_record_t frame;
    bw_control_frame_t control;
    frames=BW_U64_MAX;controls=BW_U64_MAX;
    foreach(source.active_consumers[g])if(source.active_consumers[g])begin
      if(source.frame_acks[g]<frames)frames=source.frame_acks[g];
      if(source.control_acks[g]<controls)controls=source.control_acks[g];
    end
    while(source.frames.size()!=0 && source.frames[0].record_seq<=frames)frame=source.frames.pop_front();
    while(source.controls.size()!=0 && source.controls[0].transport_seq<=controls)control=source.controls.pop_front();
    if(source.frames.size()!=0)source.frame_base_seq=source.frames[0].record_seq;
    if(source.controls.size()!=0)source.control_base_seq=source.controls[0].transport_seq;
  endfunction
  function automatic bit source_has_consumers(bw_source_state source);
    foreach(source.active_consumers[g])if(source.active_consumers[g])return 1;
    return 0;
  endfunction
  function automatic void cancel_group_subscriptions(string id);
    int group_handle;
    bw_source_state source;
    if(!group_by_id.exists(id))return;
    group_handle=group_by_id[id];
    foreach(registered_groups[group_handle].members[m])begin
      source=registered_sources[registered_groups[group_handle].members[m]];
      source.active_consumers[group_handle]=0;
      release_source_prefix(source);
    end
    // Wake a suspended collector through its durable cancellation predicate.
    registered_groups[group_handle].notification.seq++;
  endfunction
  function automatic void notify_group(int group_handle);
    bw_group_state group;
    group=registered_groups[group_handle];
    if(scope_failed(BW_GROUP,group.id))return;
    if(group.notification.seq==BW_U64_MAX)begin runtime_scope_error(BW_GROUP,group.id,"INTEGER_OVERFLOW","group notification sequence exhausted");return;end
`ifdef BW_MON_TEST_FAULTS
    if(take_group_fault(group.id,"input_notice"))begin
      group_work_requested(group.id,request_slot_settlement(group.id));return;
    end
`endif
    group.notification.seq++;
    group_work_requested(group.id,request_slot_settlement(group.id));
  endfunction

  function automatic void notify_parents(int source_handle);
    foreach (registered_sources[source_handle].parents[p])
      if(registered_sources[source_handle].active_consumers[registered_sources[source_handle].parents[p]])
        notify_group(registered_sources[source_handle].parents[p]);
  endfunction

  function automatic int group_member_count(logic [63:0] group_handle);
    return registered_groups[checked_group_index(group_handle)].members.size();
  endfunction

  function automatic int group_recursive_point_count(logic [63:0] group_handle);
    return $countones(registered_groups[checked_group_index(group_handle)].recursive_points);
  endfunction

  function automatic bw_notification group_notification(logic [63:0] group_handle);
    return registered_groups[checked_group_index(group_handle)].notification;
  endfunction

  // Startup follows the frozen direct graph. A source closes its preparation
  // only after publishing its initial controls. The consumer must then finish
  // every corresponding core receipt, upward publication and direct ACK.
  function automatic bit group_preparation_ready(int group_handle);
    bw_source_state member;
    foreach(registered_groups[group_handle].members[m])begin
      member=registered_sources[registered_groups[group_handle].members[m]];
      if(member.requires_preparation && !member.preparation_complete)return 0;
      if(member.control_acks[group_handle]!=member.last_control_seq)return 0;
    end
    return 1;
  endfunction

  function automatic int member_source(logic [63:0] group_handle,logic [63:0] member_index);
    int group_index;group_index=checked_group_index(group_handle,"member_source");
    if(core_failure_seen || monitoring_shared_disabled)return 0;
    if($isunknown(member_index))begin runtime_scope_error(BW_GROUP,registered_groups[group_index].id,"INTEGER_UNKNOWN",$sformatf("member_index=%h",member_index));return 0;end
    if(member_index>=registered_groups[group_index].members.size())begin
      runtime_scope_error(BW_GROUP,registered_groups[group_index].id,"MEMBER_REFERENCE",$sformatf("member_index=%0d",member_index));return 0;
    end
    return registered_groups[group_index].members[int'(member_index)];
  endfunction

  function automatic void set_source_progress(logic [63:0] source_handle,logic [63:0] watermark);
    bw_source_state source;
    source=registered_sources[checked_source_index(source_handle)];
    if(source_failed(source))return;
    if($isunknown(watermark))begin source_runtime_error(source,"INTEGER_UNKNOWN",source.id,$sformatf("progress_watermark=%h",watermark));
    if(source_failed(source))return;return;end
    if (source.progress_watermark_ticks!=watermark) begin
      source.progress_watermark_ticks=watermark;
      notify_parents(source_handle);
    end
  endfunction

  function automatic bw_u64_t direct_source_watermark(int group_handle);
    bw_u64_t watermark;
    watermark=BW_U64_MAX;
    foreach (registered_groups[group_handle].members[m])
      if (registered_sources[registered_groups[group_handle].members[m]].progress_watermark_ticks<watermark)
        watermark=registered_sources[registered_groups[group_handle].members[m]].progress_watermark_ticks;
    return watermark;
  endfunction

  function automatic void publish_frame(logic [63:0] source_handle,bw_record_t frame);
    bw_source_state source;
    if (!monitor_ready) core_error("NOT_READY",source_name(source_handle),"frame before ready");
    source=registered_sources[checked_source_index(source_handle)];
    if(source_failed(source))return;check_monitor_time($time,source.id);
    if($isunknown({frame.timestamp_ticks,frame.edge_index,frame.record_seq,frame.source_epoch,frame.byte_inc,frame.event_inc,frame.reset_points}))
      source_runtime_error(source,"INTEGER_UNKNOWN",source.id,"unknown numeric frame metadata");
    if(source_failed(source))return;
    if(source_failed(source))return;
    if (frame.record_seq!=source_checked_add(source,source.last_frame_seq,1,source.id))
      source_runtime_error(source,"RECORD_SEQUENCE",source.id,
        $sformatf("source_kind=%s expected=%0d received=%0d edge=%0d",
          source_kind_name(source_handle),source.last_frame_seq+1,frame.record_seq,frame.edge_index));
    if(source_failed(source))return;
    if (frame.edge_index!=source_checked_add(source,source.last_edge,1,source.id))
      source_runtime_error(source,"EDGE_SEQUENCE",source.id,
        $sformatf("source_kind=%s expected=%0d received=%0d record_seq=%0d",
          source_kind_name(source_handle),source.last_edge+1,frame.edge_index,frame.record_seq));
    if(source_failed(source))return;
    if (frame.timestamp_ticks<=measurement_start_ticks || frame.timestamp_ticks!=$time ||
        (source.last_frame_seq!=0 && frame.timestamp_ticks<=source.last_ticks))
      source_runtime_error(source,"RECORD_TIME",source.id,
        $sformatf("source_kind=%s previous=%0d received=%0d edge=%0d actual_ticks=%0d",
          source_kind_name(source_handle),source.last_ticks,frame.timestamp_ticks,frame.edge_index,$time));
    if(source_failed(source))return;
    if (frame.source_epoch<source.last_epoch)
      source_runtime_error(source,"SOURCE_EPOCH",source.id,"raw source generation moved backwards");
    if(source_failed(source))return;
    if (source.kind==BW_POINT && (frame.byte_inc>64'hffffffff || frame.event_inc>1 || frame.reset_points>1))
      source_runtime_error(source,"POINT_INCREMENT",source.id,"invalid normalized single-point increment");
    if(source_failed(source))return;
    if (source_has_consumers(source)) begin
      source_storage_growth(source,source.frames.size(),source.id,"transport.frames",frame.timestamp_ticks,frame.edge_index,frame.record_seq);
      if(source_failed(source))return;
      if (source.frames.size()==0) source.frame_base_seq=frame.record_seq;
      source.frames.push_back(frame);
    end
    source.last_frame_seq=frame.record_seq;source.last_edge=frame.edge_index;
    source.last_ticks=frame.timestamp_ticks;source.last_epoch=frame.source_epoch;
    notify_parents(source_handle);
  endfunction

  function automatic void publish_control(logic [63:0] source_handle,bw_control_t control);
    bw_source_state source;
    bw_control_frame_t envelope;
    int point_handle;
    bw_u64_t expected;
    source=registered_sources[checked_source_index(source_handle)];
    if(source_failed(source))return;
    if (!configuration_sealed) core_error("NOT_READY",source.id,"control before configuration seal");
    check_monitor_time($time,source.id);
    if($isunknown({control.timestamp_ticks,control.control_seq,control.source_epoch,control.point_handle}))
      source_runtime_error(source,"INTEGER_UNKNOWN",source.id,"unknown numeric control metadata");
    if(source_failed(source))return;
    if(source_failed(source))return;
    point_handle=int'(control.point_handle);
    if (control.point_handle>=registered_points.size())
      source_runtime_error(source,"POINT_REFERENCE",source.id,$sformatf("control point_handle=%0d",control.point_handle));
    if(source_failed(source))return;
    if (source.kind==BW_POINT && point_handle!=source.point_handle)
      source_runtime_error(source,"CONTROL_ORIGIN",source.id,"point control identity differs from source");
    if(source_failed(source))return;
    if (source.kind==BW_GROUP && !registered_groups[source.group_handle].recursive_points[point_handle])
      source_runtime_error(source,"CONTROL_ORIGIN",source.id,{"point is outside this group: ",registered_points[point_handle].id});
    if(source_failed(source))return;
    expected=source.origin_control_seq.exists(point_handle) ?
              source_checked_add(source,source.origin_control_seq[point_handle],1,source.id) : 1;
    if (control.control_seq!=expected)
      source_runtime_error(source,"CONTROL_SEQUENCE",source.id,
        $sformatf("source_kind=%s point=%s expected=%0d received=%0d",
         source_kind_name(source_handle),registered_points[point_handle].id,expected,control.control_seq));
    if(source_failed(source))return;
    if (control.timestamp_ticks<measurement_start_ticks || control.timestamp_ticks!=$time ||
        (source.origin_control_ticks.exists(point_handle) && control.timestamp_ticks<source.origin_control_ticks[point_handle]))
      source_runtime_error(source,"CONTROL_TIME",source.id,$sformatf("point=%s received_ticks=%0d",registered_points[point_handle].id,control.timestamp_ticks));
    if(source_failed(source))return;
    if (source.origin_epoch.exists(point_handle) && control.source_epoch<source.origin_epoch[point_handle])
      source_runtime_error(source,"SOURCE_EPOCH",source.id,"control generation moved backwards");
    if(source_failed(source))return;
    if(!source.origin_control_seq.exists(point_handle))begin
      source_storage_growth(source,source.origin_control_seq.num(),source.id,"transport.origins",control.timestamp_ticks,source.last_edge,source.last_frame_seq);
      if(source_failed(source))return;
    end
    envelope.transport_seq=source_checked_add(source,source.last_control_seq,1,source.id);
    if(source_failed(source))return;
    envelope.value=control;
    if (source_has_consumers(source)) begin
      source_storage_growth(source,source.controls.size(),source.id,"transport.controls",control.timestamp_ticks,source.last_edge,source.last_frame_seq);
      if(source_failed(source))return;
      if(source.controls.size()==0)source.control_base_seq=envelope.transport_seq;
      source.controls.push_back(envelope);
    end
    source.origin_control_seq[point_handle]=control.control_seq;
    source.origin_control_ticks[point_handle]=control.timestamp_ticks;source.origin_epoch[point_handle]=control.source_epoch;
    source.last_control_seq=envelope.transport_seq;
    notify_parents(source_handle);
  endfunction

  function automatic bw_u64_t consumer_next(int group_handle,bw_u64_t current);
    if(current==BW_U64_MAX)begin
      runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"INTEGER_OVERFLOW","direct-consumer cursor exhausted");return current;
    end
    return current+1;
  endfunction
  function automatic bit peek_member_frame(logic [63:0] group_handle,logic [63:0] member_index,output bw_record_t frame);
    bw_source_state source;
    bw_u64_t wanted,index;
    int group_index,source_index;
    frame='0;group_index=checked_group_index(group_handle,"peek frame");
    if(core_failure_seen || monitoring_shared_disabled)return 0;
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return 0;
    source_index=member_source(group_handle,member_index);
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return 0;
    source=registered_sources[source_index];
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    if (!source.frame_acks.exists(group_handle))
      runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"CONSUMER_REFERENCE",{"not a consumer of ",source.id});
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    if (source.frame_acks[group_handle]==source.last_frame_seq) return 0;
    wanted=consumer_next(int'(group_handle),source.frame_acks[group_handle]);
    if(scope_failed(BW_GROUP,registered_groups[group_handle].id))return 0;
    if (wanted<source.frame_base_seq || source.frames.size()==0)
      source_runtime_error(source,"RECORD_RELEASE",source.id,"an unread direct-consumer frame was released");
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    index=wanted-source.frame_base_seq;
    if (index>=bw_u64_t'(source.frames.size()))
      source_runtime_error(source,"RECORD_RELEASE",source.id,"published frame is missing from durable storage");
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    frame=source.frames[int'(index)];return 1;
  endfunction

  function automatic bit peek_member_control(logic [63:0] group_handle,logic [63:0] member_index,output bw_control_frame_t control);
    bw_source_state source;
    bw_u64_t wanted,index;
    int group_index,source_index;
    control='0;group_index=checked_group_index(group_handle,"peek control");
    if(core_failure_seen || monitoring_shared_disabled)return 0;
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return 0;
    source_index=member_source(group_handle,member_index);
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return 0;
    source=registered_sources[source_index];
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    if (!source.control_acks.exists(group_handle))
      runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"CONSUMER_REFERENCE",{"not a control consumer of ",source.id});
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    if (source.control_acks[group_handle]==source.last_control_seq) return 0;
    wanted=consumer_next(int'(group_handle),source.control_acks[group_handle]);
    if(scope_failed(BW_GROUP,registered_groups[group_handle].id))return 0;
    if (wanted<source.control_base_seq || source.controls.size()==0)
      source_runtime_error(source,"CONTROL_RELEASE",source.id,"an unread direct-consumer control was released");
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    index=wanted-source.control_base_seq;
    if (index>=bw_u64_t'(source.controls.size()))
      source_runtime_error(source,"CONTROL_RELEASE",source.id,"published control is missing from durable storage");
    if(monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return 0;
    control=source.controls[int'(index)];return 1;
  endfunction

  function automatic void acknowledge_member_frame(logic [63:0] group_handle,logic [63:0] member_index,logic [63:0] consumed_seq);
    bw_record_t frame,discarded;
    bw_source_state source;
    bw_u64_t minimum;
    int group_index,source_index;
    group_index=checked_group_index(group_handle,"acknowledge member");
    if(core_failure_seen || monitoring_shared_disabled)return;
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return;
    source_index=member_source(group_handle,member_index);
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return;
    source=registered_sources[source_index];
    if(core_failure_seen || monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return;
    if($isunknown(consumed_seq))begin runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"INTEGER_UNKNOWN",$sformatf("frame_ack=%h member=%0d",consumed_seq,member_index));
    return;end
    if (!peek_member_frame(group_handle,member_index,frame) || frame.record_seq!=consumed_seq)
      runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"ACK_SEQUENCE",
        $sformatf("source=%s received_ack=%0d current_ack=%0d",source.id,consumed_seq,source.frame_acks[group_handle]));
    if(scope_failed(BW_GROUP,registered_groups[group_handle].id))return;
    source.frame_acks[group_handle]=consumed_seq;release_source_prefix(source);
    notify_group(group_handle);
  endfunction

  function automatic void acknowledge_member_control(logic [63:0] group_handle,logic [63:0] member_index,logic [63:0] consumed_seq);
    bw_control_frame_t control,discarded;
    bw_source_state source;
    bw_u64_t minimum;
    int group_index,source_index;
    group_index=checked_group_index(group_handle,"acknowledge member");
    if(core_failure_seen || monitoring_shared_disabled)return;
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return;
    source_index=member_source(group_handle,member_index);
    if(scope_failed(BW_GROUP,registered_groups[group_index].id))return;
    source=registered_sources[source_index];
    if(core_failure_seen || monitoring_shared_disabled || scope_failed(BW_GROUP,registered_groups[group_handle].id) || !source.active_consumers[group_handle])return;
    if($isunknown(consumed_seq))begin runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"INTEGER_UNKNOWN",$sformatf("control_ack=%h member=%0d",consumed_seq,member_index));
    return;end
    if (!peek_member_control(group_handle,member_index,control) || control.transport_seq!=consumed_seq)
      runtime_scope_error(BW_GROUP,registered_groups[group_handle].id,"ACK_SEQUENCE",
        $sformatf("control source=%s received_ack=%0d current_ack=%0d",source.id,consumed_seq,source.control_acks[group_handle]));
    if(scope_failed(BW_GROUP,registered_groups[group_handle].id))return;
    source.control_acks[group_handle]=consumed_seq;release_source_prefix(source);
    notify_group(group_handle);
  endfunction

  function automatic bw_u64_t group_input_watermark(int group_handle);
    bw_u64_t watermark;
    bw_control_frame_t control;
    watermark=direct_source_watermark(group_handle);
    for (int m=0;m<group_member_count(group_handle);m++)
      if (peek_member_control(group_handle,m,control) && control.value.timestamp_ticks<watermark)
        watermark=control.value.timestamp_ticks;
    return watermark;
  endfunction

  function automatic bit group_frame_inputs_ready(int group_handle,bw_u64_t edge_index,bw_u64_t at_ticks);
    bw_record_t frame;
    bw_control_frame_t control;
    if (direct_source_watermark(group_handle)<at_ticks) return 0;
    for (int m=0;m<group_member_count(group_handle);m++) begin
      if (peek_member_control(group_handle,m,control) && control.value.timestamp_ticks<=at_ticks) return 0;
      if (!peek_member_frame(group_handle,m,frame)) return 0;
      if (frame.edge_index!=edge_index || frame.timestamp_ticks!=at_ticks) return 0;
    end
    return 1;
  endfunction

  function automatic string group_missing_detail(int group_handle,bw_u64_t edge_index,bw_u64_t at_ticks);
    string detail;
    bw_record_t frame;
    bw_control_frame_t control;
    int source;
    detail=$sformatf("group=%s expected_edge=%0d expected_ticks=%0d ",
      registered_groups[group_handle].id,edge_index,at_ticks);
    for (int m=0;m<group_member_count(group_handle);m++) begin
      source=member_source(group_handle,m);
      if (registered_sources[source].progress_watermark_ticks<at_ticks)
        detail={detail,$sformatf(" pending_source=%s watermark=%0d",source_name(source),registered_sources[source].progress_watermark_ticks)};
      if (peek_member_control(group_handle,m,control) && control.value.timestamp_ticks<=at_ticks)
        detail={detail,$sformatf(" pending_control_source=%s control_ticks=%0d",source_name(source),control.value.timestamp_ticks)};
      if (!peek_member_frame(group_handle,m,frame))
        detail={detail,$sformatf(" missing_%s=%s",source_kind_name(source),source_name(source))};
      else if (frame.edge_index!=edge_index || frame.timestamp_ticks!=at_ticks)
        detail={detail,$sformatf(" source=%s received_edge=%0d received_ticks=%0d record_seq=%0d",
          source_name(source),frame.edge_index,frame.timestamp_ticks,frame.record_seq)};
    end
    return detail;
  endfunction

  // Controlled diagnostics for contract tests/reports; no mutable buffers escape.
  function automatic int retained_frame_count(logic [63:0] source_handle);
    return registered_sources[checked_source_index(source_handle)].frames.size();
  endfunction
  function automatic int retained_control_count(logic [63:0] source_handle);
    return registered_sources[checked_source_index(source_handle)].controls.size();
  endfunction
  function automatic bw_u64_t acknowledged_frame_seq(logic [63:0] group_handle,logic [63:0] member_index);
    int index;
    index=checked_group_index(group_handle,"acknowledged frame query");
    if($isunknown(group_handle) || group_handle>=registered_groups.size())return 0;
    if($isunknown(member_index))begin runtime_scope_error(BW_GROUP,registered_groups[index].id,"INTEGER_UNKNOWN","unknown acknowledged frame query member");return 0;end
    if(member_index>=registered_groups[index].members.size())begin
      runtime_scope_error(BW_GROUP,registered_groups[index].id,"MEMBER_REFERENCE","invalid acknowledged frame query member");return 0;
    end
    return registered_sources[registered_groups[index].members[int'(member_index)]].frame_acks[index];
  endfunction
  function automatic bit source_failed(bw_source_state source);
    return scope_failed(source.kind,source.id);
  endfunction
  function automatic void source_runtime_error(bw_source_state source,string code,string context_id,string detail);
    runtime_scope_error(source.kind,source.id,code,{"context=",context_id," ",detail});
  endfunction
  function automatic bw_u64_t source_checked_add(bw_source_state source,logic [63:0] a,logic [63:0] b,string context_id);
    logic [64:0] wide;
    if(source_failed(source))return a;
    if($isunknown({a,b}))begin source_runtime_error(source,"INTEGER_UNKNOWN",context_id,"unknown addition operand");return a;end
    wide={1'b0,a}+{1'b0,b};
    if(wide[64])begin source_runtime_error(source,"INTEGER_OVERFLOW",context_id,"addition overflow");return a;end
    return wide[63:0];
  endfunction
  function automatic void source_storage_growth(bw_source_state source,int size,string context_id,string resource,
      bw_u64_t ticks=0,bw_u64_t edge_index=0,bw_u64_t sequence_number=0);
    if(source_failed(source))return;
    if(size<0 || size==32'sh7fffffff)begin source_runtime_error(source,"STORAGE_RANGE",context_id,{"resource=",resource});return;end
`ifdef BW_MON_TEST_SCHEDULING
    if(!bw_test_storage_peak.exists(resource) || size+1>bw_test_storage_peak[resource])bw_test_storage_peak[resource]=size+1;
`endif
`ifdef BW_MON_TEST_FAULTS
    if(injected_growth_failures.exists(context_id) && injected_growth_failures[context_id].exists(resource))begin
      injected_growth_failures[context_id].delete(resource);
      source_runtime_error(source,"STORAGE_FAILURE",context_id,$sformatf("resource=%s entries=%0d requested=1 edge=%0d record_seq=%0d original_ticks=%0d injected=1",resource,size,edge_index,sequence_number,ticks));
    end
`endif
  endfunction
