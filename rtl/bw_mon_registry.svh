  function automatic int checked_source_index(logic [63:0] handle,string operation="transport");
    if($isunknown(handle))begin core_error("INTEGER_UNKNOWN","transport",{operation,$sformatf(" source_handle=%h",handle)});return 0;end
    if(handle>=registered_sources.size())begin core_error("SOURCE_REFERENCE","transport",{operation,$sformatf(" source_handle=%0d",handle)});return 0;end
    return int'(handle);
  endfunction

  function automatic int checked_group_index(logic [63:0] handle,string operation="transport");
    if($isunknown(handle))begin core_error("INTEGER_UNKNOWN","transport",{operation,$sformatf(" group_handle=%h",handle)});return 0;end
    if(handle>=registered_groups.size())begin core_error("GROUP_REFERENCE","transport",{operation,$sformatf(" group_handle=%0d",handle)});return 0;end
    return int'(handle);
  endfunction

  function automatic int checked_point_index(logic [63:0] handle,string operation="transport");
    if($isunknown(handle))begin core_error("INTEGER_UNKNOWN","transport",{operation,$sformatf(" point_handle=%h",handle)});return 0;end
    if(handle>=registered_points.size())begin core_error("POINT_REFERENCE","transport",{operation,$sformatf(" point_handle=%0d",handle)});return 0;end
    return int'(handle);
  endfunction

  function automatic string source_name(logic [63:0] handle);
    int index;index=checked_source_index(handle,"source_name");
    return core_failure_seen ? "" : registered_sources[index].id;
  endfunction

  function automatic string source_kind_name(logic [63:0] handle);
    int index;index=checked_source_index(handle,"source_kind");
    if(core_failure_seen)return "";
    return registered_sources[index].kind==BW_POINT ? "point" : "group";
  endfunction

  function automatic int create_source(bw_scope_t kind,string id);
    bw_source_state source;
    if (registered_sources.size()>=20480)
      core_error("TOPOLOGY_LIMIT",id,"more than 20480 point/group sources");
    check_storage_growth(registered_sources.size(),id,"registry.source",$time);
    if(core_failure_seen)return 0;
    source=new;
    source.kind=kind;source.id=id;
    registered_sources.push_back(source);
    return registered_sources.size()-1;
  endfunction

  function automatic int group_handle_for_id(string id,bit create=0);
    bw_group_state group;
    int handle;
    if (id.len()==0) core_error("GROUP_ID","registration","empty Group ID");
    if (group_by_id.exists(id)) return group_by_id[id];
    if (!create) core_error("GROUP_REFERENCE",id,"group is not declared");
    if (registered_groups.size()>=4096)
      core_error("TOPOLOGY_LIMIT",id,"more than 4096 groups");
    check_storage_growth(registered_groups.size(),id,"registry.groups",$time);
    if(core_failure_seen)return 0;
    group=new;group.id=id;
    group.source_handle=create_source(BW_GROUP,id);
    handle=registered_groups.size();
    registered_sources[group.source_handle].group_handle=handle;
    registered_groups.push_back(group);group_by_id[id]=handle;
    return handle;
  endfunction

  function automatic int point_handle_for_id(string id);
    if (point_by_id.exists(id)) return point_by_id[id];
    core_error("POINT_REFERENCE",id,"unregistered Point ID");
    return -1;
  endfunction

  function automatic int point_source_handle(logic [63:0] handle);
    int index;index=checked_point_index(handle,"point_source");
    return core_failure_seen ? 0 : registered_points[index].transport_source;
  endfunction

  function automatic int group_source_handle(logic [63:0] handle);
    int index;index=checked_group_index(handle,"group_source");
    return core_failure_seen ? 0 : registered_groups[index].source_handle;
  endfunction

  function automatic int registered_scope_count(logic [1:0] kind);
    if (!configuration_sealed) core_error("NOT_READY","registry","scope query before configuration is sealed");
    if($isunknown(kind))begin core_error("INTEGER_UNKNOWN","registry",$sformatf("scope_kind=%b",kind));return 0;end
    if(!(kind inside {BW_POINT,BW_GROUP}))begin core_error("SCOPE_REFERENCE","registry",$sformatf("scope_kind=%0d",kind));return 0;end
    return kind==BW_POINT ? registered_points.size() : registered_groups.size();
  endfunction

  function automatic string registered_scope_id(logic [1:0] kind,logic [63:0] index);
    int count;
    count=registered_scope_count(kind);
    if(core_failure_seen)return "";
    if($isunknown(index))begin core_error("INTEGER_UNKNOWN","registry",$sformatf("scope_index=%h",index));return "";end
    if (index>=count)
      core_error("SCOPE_REFERENCE","registry",$sformatf("kind=%0d index=%0d",kind,index));
    return kind==BW_POINT ? registered_points[int'(index)].id : registered_groups[int'(index)].id;
  endfunction

  // Actual time is the seal: registration and member rules are legal only in
  // the t=0 collection slot. A positive-time call is late even if it precedes
  // the coordinator's own seal action in that slot.
  function automatic void require_configuration_open(string id);
    if ($time>0)
      core_error("LATE_CONFIG",id,
        "registration and membership are only legal at actual time zero");
    if (configuration_sealed || monitor_ready)
      core_error("CONFIG_FROZEN",id,"membership/configuration is sealed");
  endfunction

  function automatic bit point_prefix_matches(string id,string prefix);
    int length;
    length=prefix.len();
    if (id.len()<length || id.substr(0,length-1)!=prefix) return 0;
    if (id.len()==length) return 1;
    return prefix.getc(length-1)==8'h2e || id.getc(length)==8'h2e;
  endfunction

  function automatic void select_member(bw_group_state group,int source_handle,ref bit selected[int]);
    if (!selected.exists(source_handle)) begin
      check_storage_growth(group.members.size(),group.id,"registry.members",$time);
      if(core_failure_seen)return;
      selected[source_handle]=1;group.members.push_back(source_handle);
    end
  endfunction

  function automatic bit [16383:0] source_point_mask(int source_handle);
    bit [16383:0] mask;
    bw_source_state source;
    source=registered_sources[source_handle];mask='0;
    if (source.kind==BW_POINT) mask[source.point_handle]=1;
    else mask=registered_groups[source.group_handle].recursive_points;
    return mask;
  endfunction

  function automatic string source_point_path(int source_handle,int point_handle);
    bw_source_state source;
    bw_group_state group;
    bit [16383:0] mask;
    source=registered_sources[source_handle];
    if (source.kind==BW_POINT) return {"point:",source.id};
    group=registered_groups[source.group_handle];
    foreach (group.members[m]) begin
      mask=source_point_mask(group.members[m]);
      if (mask[point_handle])
        return {"group:",source.id," -> ",source_point_path(group.members[m],point_handle)};
    end
    core_error("TOPOLOGY_STATE",source.id,"recursive point path is absent");
    return "";
  endfunction

  function automatic string group_depth_path(int group_handle);
    bw_group_state group;
    bw_source_state member;
    group=registered_groups[group_handle];
    foreach (group.members[m]) begin
      member=registered_sources[group.members[m]];
      if (member.kind==BW_GROUP && registered_groups[member.group_handle].depth+1==group.depth)
        return {"group:",group.id," -> ",group_depth_path(member.group_handle)};
    end
    return {"group:",group.id};
  endfunction

  function automatic void validate_group_tree(int group_handle,string path);
    bw_group_state group;
    bw_source_state member;
    bit [16383:0] mask,overlap;
    int point_handle,prior_source;
    group=registered_groups[group_handle];
    if (group.traversal_state==1)
      core_error("GROUP_CYCLE",group.id,{"path=",path});
    if (group.traversal_state==2) return;
    group.traversal_state=1;group.depth=1;group.recursive_points='0;group.initial_control_count=0;
    foreach (group.members[m]) begin
      member=registered_sources[group.members[m]];
      if (member.kind==BW_GROUP) begin
        validate_group_tree(member.group_handle,{path," -> group:",member.id});
        if (registered_groups[member.group_handle].depth+1>group.depth)
          group.depth=registered_groups[member.group_handle].depth+1;
        group.initial_control_count+=registered_groups[member.group_handle].initial_control_count;
      end else if(member.requires_preparation) group.initial_control_count++;
      mask=source_point_mask(group.members[m]);overlap=group.recursive_points & mask;
      if (overlap!='0) begin
        point_handle=0;
        while (!overlap[point_handle]) point_handle++;
        prior_source=-1;
        for (int p=0;p<m;p++) begin
          mask=source_point_mask(group.members[p]);
          if (mask[point_handle]) begin prior_source=group.members[p];break;end
        end
        core_error("GROUP_OVERLAP",group.id,
          {"point=",registered_points[point_handle].id,
           " path1=group:",group.id," -> ",source_point_path(prior_source,point_handle),
           " path2=group:",group.id," -> ",source_point_path(group.members[m],point_handle)});
      end
      group.recursive_points|=source_point_mask(group.members[m]);
    end
    if (group.depth>8)
      core_error("GROUP_DEPTH",group.id,
        $sformatf("depth=%0d maximum=8 path=%s",group.depth,group_depth_path(group_handle)));
    group.traversal_state=2;
  endfunction

  function automatic void freeze_routing();
    bw_group_state group;
    bw_source_state owner,member;
    bw_member_rule_t rule;
    bit selected[int];
    bw_u64_t edge_count;
    int source_handle,match_count,child_handle;
    edge_count=0;
    // Resolve the entire typed graph before traversing forward subgroup rules.
    foreach (registered_groups[g]) begin
      group=registered_groups[g];
      group.members.delete();group.recursive_points='0;selected.delete();
      foreach (group.rules[r]) begin
        rule=group.rules[r];
        if (rule.kind==BW_GROUP) begin
          if (!group_by_id.exists(rule.id))
            core_error("GROUP_REFERENCE",group.id,{"missing group=",rule.id," path=group:",group.id," -> group:",rule.id});
          child_handle=group_by_id[rule.id];
          select_member(group,group_source_handle(child_handle),selected);
        end else if (rule.match_kind==BW_EXACT) begin
          if (!point_by_id.exists(rule.id))
            core_error("GROUP_REFERENCE",group.id,{"missing point=",rule.id," path=group:",group.id," -> point:",rule.id});
          select_member(group,point_source_handle(point_by_id[rule.id]),selected);
        end else begin
          match_count=0;
          foreach (registered_points[p]) begin
            if (point_prefix_matches(registered_points[p].id,rule.id)) begin
              select_member(group,point_source_handle(p),selected);match_count++;
            end
          end
          if (match_count==0) core_error("GROUP_REFERENCE",group.id,{"point prefix matched no points: ",rule.id});
        end
      end
      if (group.members.size()==0)
        core_error("EMPTY_GROUP",group.id,"group has no direct members");
      edge_count=checked_add(edge_count,bw_u64_t'(group.members.size()),group.id);
      if (edge_count>65536) core_error("TOPOLOGY_LIMIT",group.id,
        $sformatf("more than 65536 direct-member edges: direct_edges=%0d maximum=65536",edge_count));
    end
    foreach (registered_groups[g])
      validate_group_tree(g,{"group:",registered_groups[g].id});
    // Install direct-consumer positions only after the graph is validated.
    foreach (registered_groups[g]) begin
      group=registered_groups[g];owner=registered_sources[group.source_handle];
      foreach (group.members[m]) begin
        source_handle=group.members[m];member=registered_sources[source_handle];
        // CLOCK_CONTEXT is gone: a shared sampling clock remains a documented
        // usage prerequisite, not a declared or checked integration item. The
        // non-clock topology and window consistency checks are unchanged.
        if (member.basis!=owner.basis || member.width!=owner.width || member.stride!=owner.stride)
          core_error("GROUP_CONTEXT",group.id,
            $sformatf("member=%s basis=%0d/%0d W=%0d/%0d S=%0d/%0d",
             member.id,member.basis,owner.basis,
             member.width,owner.width,member.stride,owner.stride));
        if (member.parents.size()>=16)
          core_error("TOPOLOGY_LIMIT",group.id,
            $sformatf("source has more than 16 direct parents: %s kind=%s direct_parents=%0d maximum=16",
              member.id,source_kind_name(source_handle),member.parents.size()+1));
        check_storage_growth(member.parents.size(),member.id,"registry.parents",$time);
        if(core_failure_seen)return;
        member.parents.push_back(g);member.frame_acks[g]=0;member.control_acks[g]=0;
      end
    end
  endfunction

  // Seal resolves the collected graph. It runs in the first positive time
  // slot: forward references are resolved, duplicates removed, counts derived
  // and routing frozen before any participant may observe readiness.
  function automatic void seal_configuration();
    if (!monitor_configured || monitor_ready || configuration_sealed) return;
    // Initial reset/control preparation uses the same origin as later work.
    // Set T before waking participants, while public readiness remains false.
    measurement_start_ticks=$time;monitor_start_ticks=$time;
    startup_stage="VALIDATING";
    configuration_sealed=1;configuration_finished=1;
    if (registered_points.size()+registered_groups.size()==0)
      core_error("EMPTY_SCOPE","setup",
        "a setup with no registered point or group cannot start");
    foreach (registered_groups[g])
      if (!registered_groups[g].owner_registered)
        core_error("GROUP_OWNER",registered_groups[g].id,
          "member rules exist but no bw_group_mon instance declared this group");
    expected_point_count=registered_points.size();
    freeze_routing();
    startup_stage="PREPARING";
    configuration_seq=checked_add(configuration_seq,1,"configuration");
  endfunction

  function automatic void declare_scope_preparation(int source_handle);
    registered_sources[source_handle].requires_preparation=1;
    preparing_scopes=checked_add(preparing_scopes,1,"setup");
  endfunction

  function automatic void note_scope_prepared();
    prepared_scopes=checked_add(prepared_scopes,1,"setup");
  endfunction

  // Ready is published once, after every scope and report participant is
  // prepared. T is the actual seal slot; the supported budget ends at T+40us.
  function automatic void start_monitor();
    if (monitor_ready || !configuration_sealed) return;
    if ($time!=measurement_start_ticks || prepared_scopes!=preparing_scopes)
      core_error("STARTUP_STATE","setup","all preparation must complete in the seal time slot");
    // Report registration is a participant of preparation, not a ready
    // consumer: it completes before the single ready publication.
    startup_stage="REPORTING";
    if(report_sink!=null) report_sink.on_ready();
    startup_stage="READY";
    monitor_ready=1;
    $display("BW_READY time_ticks=%0d points=%0d groups=%0d budget_ticks=%0d timescale=1fs deadline_ticks=%0d",
             measurement_start_ticks,registered_points.size(),registered_groups.size(),
             BW_MONITOR_LIMIT_TICKS,checked_add(measurement_start_ticks,BW_MONITOR_LIMIT_TICKS,"setup"));
  endfunction

  function automatic void configure_monitor();
    if (monitor_configured || monitor_ready)
      core_error("CONFIG_FROZEN","setup","only one bw_mon_setup may be installed");
    if ($time>0)
      core_error("LATE_CONFIG","setup","the coordinator must be installed at actual time zero");
    monitor_start_ticks=$time;monitor_configured=1;
    configuration_seq=checked_add(configuration_seq,1,"configuration");
  endfunction

  function automatic int register_point(string id,string monitor_path,logic [1:0] basis,
      logic [63:0] width,logic [63:0] stride);
    bw_point_registration_t entry;
    bw_source_state source;
    int handle,transport;
    require_configuration_open(id);
    if (id.len()==0) core_error("POINT_ID",monitor_path,"empty Point ID");
    if (point_by_id.exists(id))
      core_error("DUPLICATE_POINT",id,
        $sformatf("first=%s second=%s",registered_points[point_by_id[id]].monitor_path,monitor_path));
    validate_window(basis,width,stride,id);
    if (registered_points.size()>=16384) core_error("POINT_COUNT",id,"more than 16384 points");
    transport=create_source(BW_POINT,id);handle=registered_points.size();
    source=registered_sources[transport];source.point_handle=handle;
    source.monitor_path=monitor_path;
    source.basis=bw_basis_t'(basis);source.width=width;source.stride=stride;
    entry.id=id;entry.monitor_path=monitor_path;entry.basis=bw_basis_t'(basis);entry.width=width;
    entry.stride=stride;entry.transport_source=transport;
    check_storage_growth(registered_points.size(),id,"registry.points",$time);
    if(core_failure_seen)return 0;
    registered_points.push_back(entry);point_by_id[id]=handle;
    registration_seq=checked_add(registration_seq,1,"registration");
    return handle;
  endfunction

  function automatic int register_group_owner(string id,string monitor_path,logic [1:0] basis,
      logic [63:0] width,logic [63:0] stride);
    int handle;
    bw_group_state group;
    bw_source_state source;
    require_configuration_open(id);
    if (id.len()==0) core_error("GROUP_ID",monitor_path,"empty Group ID");
    validate_window(basis,width,stride,id);
    // A real bw_group_mon instance is itself the group declaration.
    handle=group_handle_for_id(id,1);group=registered_groups[handle];
    if (group.owner_registered)
      core_error("DUPLICATE_OWNER",id,$sformatf("first=%s second=%s",group.owner_path,monitor_path));
    group.owner_registered=1;group.owner_path=monitor_path;source=registered_sources[group.source_handle];
    source.monitor_path=monitor_path;
    source.basis=bw_basis_t'(basis);source.width=width;source.stride=stride;
    registration_seq=checked_add(registration_seq,1,"registration");
    return handle;
  endfunction

  function automatic void add_member(string group_id,logic [1:0] member_kind,string member_id,
      bw_match_t match_kind=BW_EXACT);
    int handle;
    bw_member_rule_t rule;
    require_configuration_open(group_id);
    // Member rules may arrive before the owning instance registers.
    handle=group_handle_for_id(group_id,1);
    if (member_id.len()==0 || $isunknown(member_kind) || !(member_kind inside {BW_POINT,BW_GROUP}) ||
        $isunknown(match_kind) || !(match_kind inside {BW_EXACT,BW_PREFIX}) ||
        (member_kind==BW_GROUP && match_kind!=BW_EXACT))
      core_error("MEMBER_RULE",group_id,"member requires an explicit point/group type and a legal point match or exact Group ID");
    rule.kind=bw_scope_t'(member_kind);rule.match_kind=match_kind;rule.id=member_id;
    check_storage_growth(registered_groups[handle].rules.size(),group_id,"registry.rules",$time);
    if(core_failure_seen)return;
    registered_groups[handle].rules.push_back(rule);
    configuration_seq=checked_add(configuration_seq,1,"configuration");
  endfunction

  function automatic void add_point_member(string group_id,string point_id,bw_match_t match_kind=BW_EXACT);
    add_member(group_id,BW_POINT,point_id,match_kind);
  endfunction

  function automatic void add_group_member(string group_id,string child_group_id);
    add_member(group_id,BW_GROUP,child_group_id,BW_EXACT);
  endfunction

  function automatic string startup_status();
    string detail;
    detail=$sformatf("setup_installed=%0b sealed=%0b ready=%0b registered_points=%0d registered_groups=%0d prepared_scopes=%0d preparing_scopes=%0d",
      monitor_configured,configuration_sealed,monitor_ready,registered_points.size(),
      registered_groups.size(),prepared_scopes,preparing_scopes);
    foreach (registered_groups[g])
      if (!registered_groups[g].owner_registered) detail={detail," missing_owner=",registered_groups[g].id};
    return detail;
  endfunction
