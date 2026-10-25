  function automatic void notify_group(int group_handle);
    bw_group_state group;
    group=registered_groups[group_handle];
    group.notification.seq=checked_add(group.notification.seq,1,group.id);
  endfunction

  function automatic void notify_parents(int source_handle);
    foreach (registered_sources[source_handle].parents[p])
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

  function automatic int member_source(logic [63:0] group_handle,logic [63:0] member_index);
    int group_index;group_index=checked_group_index(group_handle,"member_source");
    if(core_failure_seen)return 0;
    if($isunknown(member_index))begin core_error("INTEGER_UNKNOWN",registered_groups[group_index].id,$sformatf("member_index=%h",member_index));return 0;end
    if(member_index>=registered_groups[group_index].members.size())begin
      core_error("MEMBER_REFERENCE",registered_groups[group_index].id,$sformatf("member_index=%0d",member_index));return 0;
    end
    return registered_groups[group_index].members[int'(member_index)];
  endfunction

  function automatic void set_source_progress(logic [63:0] source_handle,logic [63:0] watermark);
    bw_source_state source;
    source=registered_sources[checked_source_index(source_handle)];
    if(core_failure_seen)return;
    if($isunknown(watermark))begin core_error("INTEGER_UNKNOWN",source.id,$sformatf("progress_watermark=%h",watermark));return;end
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
    if(core_failure_seen)return;check_monitor_time($time,source.id);
    validate_record_numeric(frame,source.id);
    if(core_failure_seen)return;
    if (frame.record_seq!=checked_add(source.last_frame_seq,1,source.id))
      core_error("RECORD_SEQUENCE",source.id,
        $sformatf("source_kind=%s expected=%0d received=%0d edge=%0d",
          source_kind_name(source_handle),source.last_frame_seq+1,frame.record_seq,frame.edge_index));
    if (frame.edge_index!=checked_add(source.last_edge,1,source.id))
      core_error("EDGE_SEQUENCE",source.id,
        $sformatf("source_kind=%s expected=%0d received=%0d record_seq=%0d",
          source_kind_name(source_handle),source.last_edge+1,frame.edge_index,frame.record_seq));
    if (frame.timestamp_ticks<=measurement_start_ticks || frame.timestamp_ticks>$time ||
        (source.last_frame_seq!=0 && frame.timestamp_ticks<=source.last_ticks))
      core_error("RECORD_TIME",source.id,
        $sformatf("source_kind=%s previous=%0d received=%0d edge=%0d actual_ticks=%0d",
          source_kind_name(source_handle),source.last_ticks,frame.timestamp_ticks,frame.edge_index,$time));
    if (frame.source_epoch<source.last_epoch)
      core_error("SOURCE_EPOCH",source.id,"raw source generation moved backwards");
    if (source.kind==BW_POINT && (frame.byte_inc>64'hffffffff || frame.event_inc>1 || frame.reset_points>1))
      core_error("POINT_INCREMENT",source.id,"invalid normalized single-point increment");
    source.last_frame_seq=frame.record_seq;source.last_edge=frame.edge_index;
    source.last_ticks=frame.timestamp_ticks;source.last_epoch=frame.source_epoch;
    if (source.parents.size()!=0) begin
      if (source.frames.size()==0) source.frame_base_seq=frame.record_seq;
      check_storage_growth(source.frames.size(),source.id,"transport.frames",frame.timestamp_ticks,frame.edge_index,frame.record_seq);
      if(core_failure_seen)return;
      source.frames.push_back(frame);
    end
    notify_parents(source_handle);
  endfunction

  function automatic void publish_control(logic [63:0] source_handle,bw_control_t control);
    bw_source_state source;
    bw_control_frame_t envelope;
    int point_handle;
    bw_u64_t expected;
    source=registered_sources[checked_source_index(source_handle)];
    if(core_failure_seen)return;
    if (!monitor_ready) core_error("NOT_READY",source.id,"control before ready");
    check_monitor_time($time,source.id);
    validate_control_numeric(control,source.id);
    if(core_failure_seen)return;
    point_handle=int'(control.point_handle);
    if (control.point_handle>=registered_points.size())
      core_error("POINT_REFERENCE",source.id,$sformatf("control point_handle=%0d",control.point_handle));
    if (source.kind==BW_POINT && point_handle!=source.point_handle)
      core_error("CONTROL_ORIGIN",source.id,"point control identity differs from source");
    if (source.kind==BW_GROUP && !registered_groups[source.group_handle].recursive_points[point_handle])
      core_error("CONTROL_ORIGIN",source.id,{"point is outside this group: ",registered_points[point_handle].id});
    expected=source.origin_control_seq.exists(point_handle) ?
              checked_add(source.origin_control_seq[point_handle],1,source.id) : 1;
    if (control.control_seq!=expected)
      core_error("CONTROL_SEQUENCE",source.id,
        $sformatf("source_kind=%s point=%s expected=%0d received=%0d",
         source_kind_name(source_handle),registered_points[point_handle].id,expected,control.control_seq));
    if (control.timestamp_ticks<measurement_start_ticks || control.timestamp_ticks>$time ||
        (source.origin_control_ticks.exists(point_handle) && control.timestamp_ticks<source.origin_control_ticks[point_handle]))
      core_error("CONTROL_TIME",source.id,$sformatf("point=%s received_ticks=%0d",registered_points[point_handle].id,control.timestamp_ticks));
    if (source.origin_epoch.exists(point_handle) && control.source_epoch<source.origin_epoch[point_handle])
      core_error("SOURCE_EPOCH",source.id,"control generation moved backwards");
    if(!source.origin_control_seq.exists(point_handle))begin
      check_storage_growth(source.origin_control_seq.num(),source.id,"transport.origins",control.timestamp_ticks,source.last_edge,source.last_frame_seq);
      if(core_failure_seen)return;
    end
    source.origin_control_seq[point_handle]=control.control_seq;
    source.origin_control_ticks[point_handle]=control.timestamp_ticks;source.origin_epoch[point_handle]=control.source_epoch;
    source.last_control_seq=checked_add(source.last_control_seq,1,source.id);
    envelope.transport_seq=source.last_control_seq;envelope.value=control;
    if (source.parents.size()!=0) begin
      if (source.controls.size()==0) source.control_base_seq=envelope.transport_seq;
      check_storage_growth(source.controls.size(),source.id,"transport.controls",control.timestamp_ticks,source.last_edge,source.last_frame_seq);
      if(core_failure_seen)return;
      source.controls.push_back(envelope);
    end
    notify_parents(source_handle);
  endfunction

  function automatic bit peek_member_frame(logic [63:0] group_handle,logic [63:0] member_index,output bw_record_t frame);
    bw_source_state source;
    bw_u64_t wanted,index;
    source=registered_sources[member_source(group_handle,member_index)];frame='0;
    if (!source.frame_acks.exists(group_handle))
      core_error("CONSUMER_REFERENCE",registered_groups[group_handle].id,{"not a consumer of ",source.id});
    if (source.frame_acks[group_handle]==source.last_frame_seq) return 0;
    wanted=checked_add(source.frame_acks[group_handle],1,source.id);
    if (wanted<source.frame_base_seq || source.frames.size()==0)
      core_error("RECORD_RELEASE",source.id,"an unread direct-consumer frame was released");
    index=wanted-source.frame_base_seq;
    if (index>=bw_u64_t'(source.frames.size()))
      core_error("RECORD_RELEASE",source.id,"published frame is missing from durable storage");
    frame=source.frames[int'(index)];return 1;
  endfunction

  function automatic bit peek_member_control(logic [63:0] group_handle,logic [63:0] member_index,output bw_control_frame_t control);
    bw_source_state source;
    bw_u64_t wanted,index;
    source=registered_sources[member_source(group_handle,member_index)];control='0;
    if (!source.control_acks.exists(group_handle))
      core_error("CONSUMER_REFERENCE",registered_groups[group_handle].id,{"not a control consumer of ",source.id});
    if (source.control_acks[group_handle]==source.last_control_seq) return 0;
    wanted=checked_add(source.control_acks[group_handle],1,source.id);
    if (wanted<source.control_base_seq || source.controls.size()==0)
      core_error("CONTROL_RELEASE",source.id,"an unread direct-consumer control was released");
    index=wanted-source.control_base_seq;
    if (index>=bw_u64_t'(source.controls.size()))
      core_error("CONTROL_RELEASE",source.id,"published control is missing from durable storage");
    control=source.controls[int'(index)];return 1;
  endfunction

  function automatic void acknowledge_member_frame(logic [63:0] group_handle,logic [63:0] member_index,logic [63:0] consumed_seq);
    bw_record_t frame,discarded;
    bw_source_state source;
    bw_u64_t minimum;
    source=registered_sources[member_source(group_handle,member_index)];
    if(core_failure_seen)return;
    if($isunknown(consumed_seq))begin core_error("INTEGER_UNKNOWN",registered_groups[group_handle].id,$sformatf("frame_ack=%h member=%0d",consumed_seq,member_index));return;end
    if (!peek_member_frame(group_handle,member_index,frame) || frame.record_seq!=consumed_seq)
      core_error("ACK_SEQUENCE",registered_groups[group_handle].id,
        $sformatf("source=%s received_ack=%0d current_ack=%0d",source.id,consumed_seq,source.frame_acks[group_handle]));
    source.frame_acks[group_handle]=consumed_seq;minimum=BW_U64_MAX;
    foreach (source.parents[p])
      if (source.frame_acks[source.parents[p]]<minimum) minimum=source.frame_acks[source.parents[p]];
    while (source.frames.size()!=0 && source.frames[0].record_seq<=minimum)
      discarded=source.frames.pop_front();
    if (source.frames.size()!=0) source.frame_base_seq=source.frames[0].record_seq;
    notify_group(group_handle);
  endfunction

  function automatic void acknowledge_member_control(logic [63:0] group_handle,logic [63:0] member_index,logic [63:0] consumed_seq);
    bw_control_frame_t control,discarded;
    bw_source_state source;
    bw_u64_t minimum;
    source=registered_sources[member_source(group_handle,member_index)];
    if(core_failure_seen)return;
    if($isunknown(consumed_seq))begin core_error("INTEGER_UNKNOWN",registered_groups[group_handle].id,$sformatf("control_ack=%h member=%0d",consumed_seq,member_index));return;end
    if (!peek_member_control(group_handle,member_index,control) || control.transport_seq!=consumed_seq)
      core_error("ACK_SEQUENCE",registered_groups[group_handle].id,
        $sformatf("control source=%s received_ack=%0d current_ack=%0d",source.id,consumed_seq,source.control_acks[group_handle]));
    source.control_acks[group_handle]=consumed_seq;minimum=BW_U64_MAX;
    foreach (source.parents[p])
      if (source.control_acks[source.parents[p]]<minimum) minimum=source.control_acks[source.parents[p]];
    while (source.controls.size()!=0 && source.controls[0].transport_seq<=minimum)
      discarded=source.controls.pop_front();
    if (source.controls.size()!=0) source.control_base_seq=source.controls[0].transport_seq;
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
    detail=$sformatf("group=%s expected_edge=%0d expected_ticks=%0d deadline_ticks=%0d",
      registered_groups[group_handle].id,edge_index,at_ticks,checked_add(at_ticks,missing_record_timeout_ticks,"frame deadline"));
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
    return registered_sources[member_source(group_handle,member_index)].frame_acks[group_handle];
  endfunction
