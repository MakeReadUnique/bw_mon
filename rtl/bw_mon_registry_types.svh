  typedef enum logic [1:0] {BW_EXACT, BW_PREFIX} bw_match_t;
  typedef struct {
    bw_scope_t kind;
    bw_match_t match_kind;
    string id;
  } bw_member_rule_t;
  typedef struct packed {
    bw_u64_t transport_seq;
    bw_control_t value;
  } bw_control_frame_t;

  class bw_notification;
    bw_u64_t seq=0;
  endclass

  class bw_source_state;
    bw_scope_t kind;
    string id, monitor_path;
    bw_basis_t basis;
    bw_u64_t width, stride;
    int point_handle=-1, group_handle=-1;
    int parents[$];
    bw_record_t frames[$];
    bw_control_frame_t controls[$];
    bw_u64_t frame_acks[int], control_acks[int];
    bw_u64_t last_frame_seq=0, last_edge=0, last_ticks=0, last_epoch=0;
    bw_u64_t frame_base_seq=1, control_base_seq=1, last_control_seq=0;
    bw_u64_t origin_control_seq[int], origin_control_ticks[int], origin_epoch[int];
    bw_u64_t progress_watermark_ticks=BW_U64_MAX;
  endclass

  class bw_group_state;
    string id, owner_path;
    bit declared=0, owner_registered=0;
    int expected_members, source_handle;
    int members[$];
    bw_member_rule_t rules[$];
    bit [16383:0] recursive_points='0;
    int traversal_state=0, depth=0; // unvisited, active, resolved; nested group count
    bw_notification notification;
    function new();
      notification=new;
    endfunction
  endclass

  bw_source_state registered_sources[$];
  bw_group_state registered_groups[$];
  int point_by_id[string], group_by_id[string];
  bit configuration_finished=0;
  int unsigned expected_group_count=0, declared_group_count=0;
  bw_u64_t configuration_seq=0;
  bw_u64_t missing_record_timeout_ticks=BW_TICKS_PER_NS;
