  function automatic string source_name(int handle);
    if (handle<0 || handle>=registered_sources.size())
      core_error("SOURCE_REFERENCE","transport",$sformatf("source_handle=%0d",handle));
    return registered_sources[handle].id;
  endfunction

  function automatic string source_kind_name(int handle);
    return registered_sources[handle].kind==BW_POINT ? "point" : "group";
  endfunction

  function automatic int create_source(bw_scope_t kind,string id);
    bw_source_state source;
    if (registered_sources.size()>=20480)
      core_error("TOPOLOGY_LIMIT",id,"more than 20480 point/group sources");
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

  function automatic int point_source_handle(int point_handle);
    if (point_handle<0 || point_handle>=registered_points.size())
      core_error("POINT_REFERENCE","transport",$sformatf("point_handle=%0d",point_handle));
    return registered_points[point_handle].transport_source;
  endfunction

  function automatic int group_source_handle(int group_handle);
    if (group_handle<0 || group_handle>=registered_groups.size())
      core_error("GROUP_REFERENCE","transport",$sformatf("group_handle=%0d",group_handle));
    return registered_groups[group_handle].source_handle;
  endfunction

  function automatic int registered_scope_count(bw_scope_t kind);
    if (!monitor_ready) core_error("NOT_READY","registry","scope query before ready");
    return kind==BW_POINT ? registered_points.size() : registered_groups.size();
  endfunction

  function automatic string registered_scope_id(bw_scope_t kind,int index);
    if (index<0 || index>=registered_scope_count(kind))
      core_error("SCOPE_REFERENCE","registry",$sformatf("kind=%0d index=%0d",kind,index));
    return kind==BW_POINT ? registered_points[index].id : registered_groups[index].id;
  endfunction

  function automatic void require_configuration_open(string id);
    if (monitor_ready || configuration_finished)
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
    group.traversal_state=1;group.depth=1;group.recursive_points='0;
    foreach (group.members[m]) begin
      member=registered_sources[group.members[m]];
      if (member.kind==BW_GROUP) begin
        validate_group_tree(member.group_handle,{path," -> group:",member.id});
        if (registered_groups[member.group_handle].depth+1>group.depth)
          group.depth=registered_groups[member.group_handle].depth+1;
      end
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
      if (group.members.size()!=group.expected_members)
        core_error("MEMBER_COUNT",group.id,
          $sformatf("expected=%0d actual=%0d after deduplication",group.expected_members,group.members.size()));
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
        if (member.clock_context!=owner.clock_context || member.basis!=owner.basis ||
            member.width!=owner.width || member.stride!=owner.stride)
          core_error("GROUP_CONTEXT",group.id,
            $sformatf("member=%s clock=%s/%s basis=%0d/%0d W=%0d/%0d S=%0d/%0d",
             member.id,member.clock_context,owner.clock_context,member.basis,owner.basis,
             member.width,owner.width,member.stride,owner.stride));
        if (member.parents.size()>=16)
          core_error("TOPOLOGY_LIMIT",group.id,
            $sformatf("source has more than 16 direct parents: %s kind=%s direct_parents=%0d maximum=16",
              member.id,source_kind_name(source_handle),member.parents.size()+1));
        member.parents.push_back(g);member.frame_acks[g]=0;member.control_acks[g]=0;
      end
    end
  endfunction

  function automatic void try_ready();
    if (!monitor_configured || monitor_ready) return;
    if (registered_points.size()>expected_point_count)
      core_error("POINT_COUNT","setup",
        $sformatf("expected=%0d actual=%0d",expected_point_count,registered_points.size()));
    if (!configuration_finished) return;
    if (declared_group_count!=expected_group_count)
      core_error("GROUP_COUNT","setup",
        $sformatf("expected=%0d declared=%0d",expected_group_count,declared_group_count));
    foreach (registered_groups[g]) begin
      if (!registered_groups[g].declared)
        core_error("GROUP_DEFINITION",registered_groups[g].id,"owner has no group definition");
      if (!registered_groups[g].owner_registered) return;
    end
    if (registered_points.size()!=expected_point_count) return;
    freeze_routing();
    measurement_start_ticks=$time;monitor_ready=1;
    if(report_sink!=null) report_sink.on_ready();
    $display("BW_READY time_ticks=%0d points=%0d groups=%0d",measurement_start_ticks,
             registered_points.size(),declared_group_count);
  endfunction

  function automatic void configure_monitor(logic [63:0] expected,
      logic [63:0] groups=0,logic [63:0] missing_timeout_ns=1);
    if (monitor_configured || monitor_ready)
      core_error("CONFIG_FROZEN","setup","configuration may be completed only once");
    if ($isunknown(expected) || expected==0 || expected>16384)
      core_error("POINT_COUNT","setup","expected_point_count must be 1..16384");
    if ($isunknown(groups) || groups>4096) core_error("GROUP_COUNT","setup","group count must be known and at most 4096");
    if ($isunknown(missing_timeout_ns) || missing_timeout_ns==0)
      core_error("FRAME_TIMEOUT_CONFIG","setup","missing-record timeout must be positive");
    expected_point_count=expected;expected_group_count=groups;
    missing_record_timeout_ticks=ns_to_ticks(missing_timeout_ns,"missing-record timeout");
    monitor_start_ticks=$time;monitor_configured=1;
    if (groups==0) configuration_finished=1;
    configuration_seq=checked_add(configuration_seq,1,"configuration");
    try_ready();
  endfunction

  function automatic int register_point(string id,string monitor_path,logic [1:0] basis,
      logic [63:0] width,logic [63:0] stride,string clock_context);
    bw_point_registration_t entry;
    bw_source_state source;
    int handle,transport;
    if (monitor_ready) core_error("REGISTRATION_FROZEN",id,"registration after ready");
    if (id.len()==0) core_error("POINT_ID",monitor_path,"empty Point ID");
    if (point_by_id.exists(id))
      core_error("DUPLICATE_POINT",id,
        $sformatf("first=%s second=%s",registered_points[point_by_id[id]].monitor_path,monitor_path));
    validate_window(basis,width,stride,id);
    if (clock_context.len()==0) core_error("CLOCK_CONTEXT",id,"empty clock context");
    if (registered_points.size()>=16384) core_error("POINT_COUNT",id,"more than 16384 points");
    transport=create_source(BW_POINT,id);handle=registered_points.size();
    source=registered_sources[transport];source.point_handle=handle;
    source.monitor_path=monitor_path;source.clock_context=clock_context;
    source.basis=bw_basis_t'(basis);source.width=width;source.stride=stride;
    entry.id=id;entry.monitor_path=monitor_path;entry.basis=bw_basis_t'(basis);entry.width=width;
    entry.stride=stride;entry.clock_context=clock_context;entry.transport_source=transport;
    registered_points.push_back(entry);point_by_id[id]=handle;
    registration_seq=checked_add(registration_seq,1,"registration");try_ready();
    return handle;
  endfunction

  function automatic int register_group_owner(string id,string monitor_path,logic [1:0] basis,
      logic [63:0] width,logic [63:0] stride,string clock_context);
    int handle;
    bw_group_state group;
    bw_source_state source;
    if (monitor_ready) core_error("REGISTRATION_FROZEN",id,"group owner after ready");
    if (id.len()==0) core_error("GROUP_ID",monitor_path,"empty Group ID");
    validate_window(basis,width,stride,id);
    if (clock_context.len()==0) core_error("CLOCK_CONTEXT",id,"empty clock context");
    handle=group_handle_for_id(id,!configuration_finished);group=registered_groups[handle];
    if (group.owner_registered)
      core_error("DUPLICATE_OWNER",id,$sformatf("first=%s second=%s",group.owner_path,monitor_path));
    group.owner_registered=1;group.owner_path=monitor_path;source=registered_sources[group.source_handle];
    source.monitor_path=monitor_path;source.clock_context=clock_context;
    source.basis=bw_basis_t'(basis);source.width=width;source.stride=stride;
    registration_seq=checked_add(registration_seq,1,"registration");try_ready();
    return handle;
  endfunction

  function automatic void define_group(string id,logic [63:0] expected_members);
    int handle;
    require_configuration_open(id);
    if ($isunknown(expected_members) || expected_members==0 || expected_members>16384)
      core_error("MEMBER_COUNT",id,"expected direct-member count must be 1..16384");
    handle=group_handle_for_id(id,1);
    if (registered_groups[handle].declared)
      core_error("GROUP_DEFINITION",id,"duplicate group definition");
    registered_groups[handle].declared=1;registered_groups[handle].expected_members=expected_members;
    declared_group_count++;configuration_seq=checked_add(configuration_seq,1,"configuration");
  endfunction

  function automatic void add_member(string group_id,logic [1:0] member_kind,string member_id,
      bw_match_t match_kind=BW_EXACT);
    int handle;
    bw_member_rule_t rule;
    require_configuration_open(group_id);
    handle=group_handle_for_id(group_id);
    if (member_id.len()==0 || $isunknown(member_kind) || !(member_kind inside {BW_POINT,BW_GROUP}) ||
        $isunknown(match_kind) || !(match_kind inside {BW_EXACT,BW_PREFIX}) ||
        (member_kind==BW_GROUP && match_kind!=BW_EXACT))
      core_error("MEMBER_RULE",group_id,"member requires an explicit point/group type and a legal point match or exact Group ID");
    rule.kind=bw_scope_t'(member_kind);rule.match_kind=match_kind;rule.id=member_id;
    check_queue_growth(registered_groups[handle].rules.size(),group_id);
    registered_groups[handle].rules.push_back(rule);
    configuration_seq=checked_add(configuration_seq,1,"configuration");
  endfunction

  function automatic void add_point_member(string group_id,string point_id,bw_match_t match_kind=BW_EXACT);
    add_member(group_id,BW_POINT,point_id,match_kind);
  endfunction

  function automatic void add_group_member(string group_id,string child_group_id);
    add_member(group_id,BW_GROUP,child_group_id,BW_EXACT);
  endfunction

  function automatic void finish_configuration();
    require_configuration_open("setup");configuration_finished=1;
    configuration_seq=checked_add(configuration_seq,1,"configuration");try_ready();
  endfunction

  function automatic string startup_status();
    string detail;
    detail=$sformatf("expected_points=%0d registered_points=%0d expected_groups=%0d declared_groups=%0d configuration_finished=%0d",
      expected_point_count,registered_points.size(),expected_group_count,declared_group_count,configuration_finished);
    foreach (registered_groups[g])
      if (!registered_groups[g].owner_registered) detail={detail," missing_owner=",registered_groups[g].id};
    return detail;
  endfunction
