package bw_mon_pkg;
  timeunit 1fs; timeprecision 1fs;

  typedef longint unsigned bw_u64_t;
  typedef enum bit {BW_NS, BW_CYCLE} bw_basis_t;
  typedef enum bit {BW_POINT, BW_GROUP} bw_scope_t;
  typedef enum logic [1:0] {BW_VALID_ONLY, BW_VALID_READY, BW_CREDIT} bw_protocol_t;
  // A single four-state edge snapshot feeds accounting and local diagnostics.
  // Adapter-decoded size is distinct from whether that decode is trustworthy.
  typedef struct packed {
    logic reset_n;
    logic valid;
    logic ready;
    logic flitv;
    logic lcrdv;
    logic [63:0] size_bytes;
    logic size_known;
  } bw_sample_t;
  typedef enum logic [1:0] {BW_RETURN_NEXT_CYCLE, BW_RETURN_SAME_CYCLE} bw_credit_return_t;
  typedef enum logic [2:0] {
    BW_CREDIT_UNSUPPORTED, BW_CREDIT_DISABLED, BW_CREDIT_UNKNOWN,
    BW_CREDIT_KNOWN, BW_CREDIT_RESET
  } bw_credit_state_t;
  typedef enum logic [3:0] {
    BW_CREDIT_NO_ERROR, BW_CREDIT_INITIAL_UNKNOWN, BW_CREDIT_CONTROL_UNKNOWN,
    BW_CREDIT_NO_CREDIT, BW_CREDIT_OVERFLOW, BW_CREDIT_UNDERFLOW,
    BW_CREDIT_RESET_UNKNOWN
  } bw_credit_reason_t;

  function automatic string credit_reason_name(bw_credit_reason_t reason);
    case(reason)
      BW_CREDIT_NO_ERROR: return "NONE";
      BW_CREDIT_INITIAL_UNKNOWN: return "INITIAL_UNKNOWN";
      BW_CREDIT_CONTROL_UNKNOWN: return "CONTROL_UNKNOWN";
      BW_CREDIT_NO_CREDIT: return "SEND_WITHOUT_CREDIT";
      BW_CREDIT_OVERFLOW: return "CAPACITY_OVERFLOW";
      BW_CREDIT_UNDERFLOW: return "CAPACITY_UNDERFLOW";
      BW_CREDIT_RESET_UNKNOWN: return "RESET_UNKNOWN";
      default: return "UNRECOGNIZED";
    endcase
  endfunction

  typedef enum logic [2:0] {
    BW_HINT_NOT_ENDED, BW_HINT_RELEASED, BW_HINT_UNKNOWN, BW_HINT_RESET, BW_HINT_TRUNCATED
  } bw_hint_end_t;
  typedef struct packed {
    bit supported,enabled,trusted,active,hit,cycle_anchor_valid;
    bw_hint_end_t end_reason;
    bw_u64_t epoch,interval_epoch,interval_id,result_seq;
    bw_u64_t start_ticks,trigger_ticks,end_ticks,observed_through_ticks,update_ticks;
    bw_u64_t duration_ticks,start_cycle,end_cycle,duration_cycles;
    bw_u64_t hit_count,interval_count;
  } bw_hint_result_t;
  function automatic bw_hint_result_t inactive_hint_result(bit supported,bit enabled);
    bw_hint_result_t value;
    value='0;value.supported=supported;value.enabled=enabled;
    return value;
  endfunction
  function automatic string hint_end_name(bw_hint_end_t reason);
    case(reason)
      BW_HINT_RELEASED: return "RELEASED";
      BW_HINT_UNKNOWN: return "UNKNOWN";
      BW_HINT_RESET: return "RESET";
      BW_HINT_TRUNCATED: return "TRUNCATED";
      default: return "NOT_ENDED";
    endcase
  endfunction

  localparam bw_u64_t BW_TICKS_PER_NS = 1000000;
  localparam bw_u64_t BW_U64_MAX = 64'hffffffffffffffff;
  localparam bw_u64_t BW_MONITOR_LIMIT_TICKS = 64'd40000000000;
  localparam bw_u64_t BW_DEFAULT_SILENCE_THRESHOLD = 64'd10;

  // This is a per-edge record, including idle/unknown/reset edges. Time, edge,
  // record sequence and source epoch remain distinct quantities.
  typedef struct packed {
    logic [63:0] timestamp_ticks;
    logic [63:0] edge_index;
    logic [63:0] record_seq;
    logic [63:0] source_epoch;
    logic [63:0] byte_inc;
    logic [63:0] event_inc;
    logic [63:0] reset_points;
    bit events_complete;
    bit bytes_complete;
    logic reset_n;
  } bw_record_t;

  // Actual point-reset controls are not sampling frames: no edge is invented.
  // point_handle identifies the registered Point ID without copying strings.
  typedef struct packed {
    logic [63:0] timestamp_ticks;
    logic [63:0] control_seq;
    logic [63:0] source_epoch;
    logic [31:0] point_handle;
    logic reset_n;
  } bw_control_t;

  `include "bw_mon_registry_types.svh"

  typedef enum logic [2:0] {
    BW_EPISODE_NONE, BW_EPISODE_ACTIVE, BW_EPISODE_COMPLETE,
    BW_EPISODE_RESET_INTERRUPTED, BW_EPISODE_TRUNCATED
  } bw_episode_status_t;
  typedef enum logic [3:0] {
    BW_EPISODE_REASON_NONE, BW_EPISODE_RESET, BW_EPISODE_OBSERVATION_END,
    BW_EPISODE_FIRST_UNKNOWN, BW_EPISODE_LAST_UNKNOWN, BW_EPISODE_TAIL_UNKNOWN,
    BW_EPISODE_BYTES_UNKNOWN, BW_EPISODE_DURATION_UNKNOWN
  } bw_episode_reason_t;

  typedef enum logic [1:0] {
    BW_PHASE_UNDETERMINED, BW_PHASE_RAMP, BW_PHASE_STEADY, BW_PHASE_FALL
  } bw_phase_t;
  localparam string BW_PHASE_STRATEGY="PAIR6_R2";
  typedef enum logic [3:0] {
    BW_PHASE_DISABLED, BW_PHASE_NO_EPISODE, BW_PHASE_WINDOW_WARMUP,
    BW_PHASE_BYTES_INCOMPLETE, BW_PHASE_BAD_DENOMINATOR, BW_PHASE_FOREIGN_EPISODE,
    BW_PHASE_NEED_SAMPLES, BW_PHASE_NEED_SPAN, BW_PHASE_CONFIRMING,
    BW_PHASE_NO_MATCH, BW_PHASE_CONFIRMED
  } bw_phase_reason_t;
  function automatic string phase_reason_name(bw_phase_reason_t reason);
    case(reason)
      BW_PHASE_DISABLED:return "DISABLED";
      BW_PHASE_NO_EPISODE:return "NO_EPISODE";
      BW_PHASE_WINDOW_WARMUP:return "WINDOW_WARMUP";
      BW_PHASE_BYTES_INCOMPLETE:return "BYTES_INCOMPLETE";
      BW_PHASE_BAD_DENOMINATOR:return "BAD_DENOMINATOR";
      BW_PHASE_FOREIGN_EPISODE:return "FOREIGN_EPISODE";
      BW_PHASE_NEED_SAMPLES:return "NEED_SAMPLES";
      BW_PHASE_NEED_SPAN:return "NEED_SPAN";
      BW_PHASE_CONFIRMING:return "CONFIRMING";
      BW_PHASE_NO_MATCH:return "NO_MATCH";
      default:return "CONFIRMED";
    endcase
  endfunction

  typedef enum logic [2:0] {
    BW_PHASE_CHANGE, BW_PHASE_EVIDENCE_GAP, BW_PHASE_EPISODE_END
  } bw_phase_end_t;
  // Per-metric evidence: normal exclusions and unknown coverage stay distinct.
  typedef enum logic [3:0] {
    BW_METRIC_OK, BW_METRIC_BOUNDARY_UNKNOWN, BW_METRIC_BYTES_UNKNOWN,
    BW_METRIC_OBSERVATION_UNKNOWN, BW_METRIC_NO_SAMPLES, BW_METRIC_TOO_FEW_SAMPLES,
    BW_METRIC_ZERO_MEAN, BW_METRIC_RESET, BW_METRIC_TRUNCATED, BW_METRIC_NO_STEADY
  } bw_metric_reason_t;
  typedef struct {
    bw_basis_t window_basis;
    bw_u64_t window_width,update_stride;
    bw_u64_t sample_count,first_sample_ticks,last_sample_ticks,sample_span_ticks;
    bw_u64_t excluded_warmup,excluded_foreign,unknown_samples,excluded_denominator;
    bit interval_known,coverage_complete;
    bit minmax_valid,stddev_valid,cv_valid;
    bw_metric_reason_t minmax_reason,stddev_reason,cv_reason;
    real mean_gbps,min_gbps,max_gbps,stddev_gbps,cv_pct;
  } bw_variation_result_t;
  typedef struct {
    bw_scope_t scope_kind;
    bw_u64_t stats_epoch,episode_id,phase_id,result_seq;
    bw_phase_t phase_kind;
    bw_phase_end_t end_reason;
    bw_episode_status_t episode_status;
    bw_u64_t start_ticks,end_ticks,confirmation_ticks;
    bw_u64_t start_total_bytes,end_total_bytes,start_total_events,end_total_events;
    bit start_known,end_known;
    real confirmation_delta,confirmation_rms;
    // Frozen original N+K-1 recognition support; raw members remain in the
    // private checker stream even after the six-row fit ring has advanced.
    bw_u64_t support_first_seq,support_last_seq,support_count;
    real support_min_gbps,support_max_gbps;
    bw_u64_t byte_count,event_count,duration_ticks;
    bw_u64_t start_unknown_records,end_unknown_records,start_unknown_event_records,end_unknown_event_records;
    bw_u64_t start_unknown_ticks,end_unknown_ticks,start_reset_records,end_reset_records;
    bit bytes_complete,events_complete,member_reset_coverage,duration_valid,bandwidth_valid;
    bw_metric_reason_t duration_reason,bandwidth_reason;
    real bandwidth_gbps;
    bw_variation_result_t variation;
  } bw_phase_result_t;
  // Immutable final record. A synchronous delivery function preserves every
  // result even when several source actions are drained in the same time slot.
  typedef struct {
    bw_scope_t scope_kind;
    bw_u64_t stats_epoch;
    bw_u64_t result_seq;
    bw_u64_t episode_id;
    bw_episode_status_t status;
    bw_episode_reason_t reason;
    bw_u64_t first_ticks, last_ticks, tail_ticks, confirmation_ticks;
    bw_u64_t first_cycle, last_cycle, tail_cycle;
    bw_u64_t byte_count, event_count, duration_ticks;
    bw_u64_t start_total_bytes, end_total_bytes;
    bw_u64_t start_total_events, end_total_events;
    bit first_known, last_known, tail_known;
    bit bytes_complete, events_complete, member_reset_coverage;
    bit duration_valid, e2e_valid;
    real e2e_gbps;
    bw_variation_result_t variation;
    bit last_steady_found,last_steady_selection_valid;
    bw_metric_reason_t last_steady_reason;
    bw_phase_result_t last_steady;
  } bw_episode_result_t;



  typedef enum logic [1:0] {
    BW_REPORT_STATISTICS_ONLY, BW_REPORT_PASS, BW_REPORT_WARNING, BW_REPORT_FAIL
  } bw_report_status_t;
  typedef struct packed {
    bw_report_status_t status;
    bw_u64_t pass_count,fail_count,warning_count,scopes_done,scopes_expected;
    bit finalized;
  } bw_report_summary_t;

  // Private lossless evidence transport for the default platform check. Logical
  // positions are original ticks (ns basis) or actual local cycle indices.
  typedef struct {
    bw_scope_t scope_kind;
    bw_u64_t stats_epoch,episode_id,seq,left_ticks,ticks,left_u,u;
    // Actual member-control transitions, separate from held reset coverage.
    // Original event time and generation make reset crossing reconstructible.
    bw_u64_t reset_generation,last_reset_event_ticks;
    real value;
    bit valid,full,bytes_complete,denominator_valid,foreign_activity,reset_coverage;
  } bw_check_window_t;

  typedef struct {
    bit enabled;
    bw_basis_t basis;
    bw_u64_t width,stride;
  } bw_check_analysis_t;
  // Validated effective facts are collected during initialization, independently
  // of report-owner construction order, and consumed before Ready publication.
  bw_check_analysis_t check_analysis[string];

  // Dedicated synchronous report transport. The owner implements all cfg,
  // evidence and comparison state outside this package.
  virtual class bw_report_sink;
    pure virtual function void on_ready();
    virtual function void analysis_scope(bw_scope_t kind,string id,bit enabled,
        bw_basis_t basis,bw_u64_t width,bw_u64_t stride); endfunction
    virtual function void submit_window(string id,bw_check_window_t sample); endfunction
    pure virtual function void submit_episode(string scope_id,bw_episode_result_t result);
    pure virtual function void submit_phase(string scope_id,bw_phase_result_t result);
    pure virtual function void scope_done(bw_scope_t kind,string scope_id,bw_u64_t stats_epoch);
    pure virtual function bw_report_summary_t summary();
  endclass

  function automatic string episode_reason_name(bw_episode_reason_t reason);
    case (reason)
      BW_EPISODE_REASON_NONE: return "NONE";
      BW_EPISODE_RESET: return "RESET_INTERRUPTED";
      BW_EPISODE_OBSERVATION_END: return "OBSERVATION_TRUNCATED";
      BW_EPISODE_FIRST_UNKNOWN: return "FIRST_BOUNDARY_UNKNOWN";
      BW_EPISODE_LAST_UNKNOWN: return "LAST_BOUNDARY_UNKNOWN";
      BW_EPISODE_TAIL_UNKNOWN: return "TAIL_CYCLE_UNKNOWN";
      BW_EPISODE_BYTES_UNKNOWN: return "BYTES_INCOMPLETE";
      default: return "DURATION_UNAVAILABLE";
    endcase
  endfunction


  typedef struct {
    string id;
    string monitor_path;
    bw_basis_t basis;
    bw_u64_t width;
    bw_u64_t stride;
    int transport_source;
  } bw_point_registration_t;

  bw_point_registration_t registered_points[$];
  bit monitor_configured = 0;
  bw_report_sink report_sink;
  bit core_failure_seen = 0;
  bit deferred_core_failures[int];

  // Candidate conditions may be cancelled by later same-slot arrivals. They
  // are consulted only at finalization, never to suppress runtime records.
  function automatic void set_deferred_core_failure(int owner,bit pending);
    if(pending)deferred_core_failures[owner]=1;
    else deferred_core_failures.delete(owner);
  endfunction

  function automatic bit core_failure_pending();
    if(core_failure_seen)return 1;
    foreach(deferred_core_failures[owner])
      if(deferred_core_failures[owner])return 1;
    return 0;
  endfunction

  // Deferred assertion actions execute in Postponed, where writes are illegal.
  // Their current condition was already published by the Active checker.
  function automatic void deferred_core_error(string code,string scope_id,string detail);
    $fatal(1,"BW_CORE_ERROR code=%s scope=%s time_ticks=%0d %s",code,scope_id,$time,detail);
  endfunction
  bit monitor_ready = 0;
  bit configuration_sealed = 0;
  string startup_stage="COLLECTING";
  // Only real module instances declare preparation; directly registered
  // component scopes provide no handshake and must not stall the coordinator.
  int preparing_scopes = 0;
  int prepared_scopes = 0;
  int unsigned expected_point_count;
  bw_u64_t measurement_start_ticks = 0;
  bw_u64_t monitor_start_ticks = 0;
  bw_u64_t registration_seq = 0;

  // A typed owner is never inferred from the spelling of a diagnostic context.
  // Point and group IDs may deliberately be identical.
  bit monitoring_disabled[string];
  string monitoring_root_cause[string];
  string monitoring_failure_code[string];
  bit monitoring_shared_disabled=0;
  string monitoring_shared_failure_code,monitoring_shared_failure_scope,monitoring_shared_failure_detail;
  bw_u64_t monitoring_failure_count=0;
  function automatic string scope_key(bw_scope_t kind,string id);
    return $sformatf("%0d:%s",kind,id);
  endfunction
  function automatic bit scope_disabled(bw_scope_t kind,string id);
    return monitoring_shared_disabled || monitoring_disabled.exists(scope_key(kind,id));
  endfunction
  function automatic bit scope_failed(bw_scope_t kind,string id);
    return core_failure_seen || scope_disabled(kind,id);
  endfunction
  function automatic void runtime_scope_error(bw_scope_t kind,string id,string code,string detail);
    string key;
    int pending_sources[$];
    int source,parent;
    if(!monitor_ready)begin core_error(code,id,detail);return;end
    key=scope_key(kind,id);
    if(scope_disabled(kind,id))return;
    monitoring_disabled[key]=1;monitoring_root_cause[key]=key;monitoring_failure_code[key]=code;
    if(kind==BW_POINT)cancel_point_completion(id);
    else begin cancel_group_subscriptions(id);if(group_batches.exists(id))group_batches[id].cancelled=1;end
    monitoring_failure_count++;
    $warning("BW_CORE_WARNING code=%s scope_kind=%0d scope=%s time_ticks=%0d %s",code,kind,id,$time,detail);
    if(kind==BW_POINT && point_by_id.exists(id))pending_sources.push_back(registered_points[point_by_id[id]].transport_source);
    if(kind==BW_GROUP && group_by_id.exists(id))pending_sources.push_back(registered_groups[group_by_id[id]].source_handle);
    while(pending_sources.size()!=0)begin
      source=pending_sources.pop_front();
      foreach(registered_sources[source].parents[p])begin
        parent=registered_sources[source].parents[p];
        if(!monitoring_disabled.exists(scope_key(BW_GROUP,registered_groups[parent].id)))begin
          monitoring_disabled[scope_key(BW_GROUP,registered_groups[parent].id)]=1;
          monitoring_root_cause[scope_key(BW_GROUP,registered_groups[parent].id)]=key;
          $display("BW_SCOPE_DISABLED scope_kind=1 scope=%s root=%s time_ticks=%0d",registered_groups[parent].id,key,$time);
          cancel_group_subscriptions(registered_groups[parent].id);
          if(group_batches.exists(registered_groups[parent].id))group_batches[registered_groups[parent].id].cancelled=1;
          pending_sources.push_back(registered_groups[parent].source_handle);
        end
      end
    end
  endfunction

  function automatic void runtime_shared_error(string code,string id,string detail);
    if(!monitor_ready)begin core_error(code,id,detail);return;end
    if(monitoring_shared_disabled)return;
    monitoring_shared_disabled=1;monitoring_failure_count++;
    foreach(registered_groups[g])cancel_group_subscriptions(registered_groups[g].id);
    cancel_all_group_completion();
    monitoring_shared_failure_code=code;monitoring_shared_failure_scope=id;monitoring_shared_failure_detail=detail;
    $warning("BW_CORE_WARNING code=%s scope_kind=SHARED scope=%s time_ticks=%0d %s",code,id,$time,detail);
  endfunction

  function automatic void fatal_core_error(string code,string scope_id,string detail);
    core_failure_seen=1;
    if(!monitor_ready)
      $display("BW_STARTUP_FAILURE stage=%s scope=%s %s",startup_stage,scope_id,startup_status());
    $fatal(1,"BW_CORE_ERROR code=%s scope=%s time_ticks=%0d %s",code,scope_id,$time,detail);
  endfunction
  function automatic void core_error(string code, string scope_id, string detail);
    // Lifecycle violations remain fatal even after readiness. Runtime callers
    // without an explicitly typed owner conservatively disable all monitoring.
    if(monitor_ready && !(code inside {"LATE_CONFIG","CONFIG_FROZEN","NOT_READY","REPORT_OWNER",
       "STARTUP_STATE","STARTUP_INCOMPLETE","SETUP_MISSING","WINDOW_CONFIG","PROTOCOL_CONFIG",
       "BYTE_CONFIG","CREDIT_CONFIG","HINT_CONFIG","EPISODE_CONFIG","PHASE_CONFIG"}))begin
      runtime_shared_error(code,scope_id,detail);return;
    end
    // VCS can return from $fatal while executing final blocks. Retain a shared
    // terminal-failure fact before reporting, so no finalizer emits new results.
    fatal_core_error(code,scope_id,detail);
  endfunction

  function automatic string metric_reason_name(bw_metric_reason_t reason);
    case(reason)
      BW_METRIC_OK:return "NONE";
      BW_METRIC_BOUNDARY_UNKNOWN:return "BOUNDARY_UNKNOWN";
      BW_METRIC_BYTES_UNKNOWN:return "BYTES_INCOMPLETE";
      BW_METRIC_OBSERVATION_UNKNOWN:return "OBSERVATION_INCOMPLETE";
      BW_METRIC_NO_SAMPLES:return "NO_QUALIFIED_SAMPLES";
      BW_METRIC_TOO_FEW_SAMPLES:return "TOO_FEW_SAMPLES";
      BW_METRIC_ZERO_MEAN:return "ZERO_MEAN";
      BW_METRIC_RESET:return "RESET_INTERRUPTED";
      BW_METRIC_TRUNCATED:return "OBSERVATION_TRUNCATED";
      default:return "NO_CONFIRMED_STEADY";
    endcase
  endfunction

  function automatic void emit_variation_context(string scope_id,string interval_kind,
      bw_scope_t scope_kind,bw_u64_t epoch,bw_u64_t episode,bw_u64_t phase,bw_u64_t sequence_id,
      bw_u64_t start_ticks,bw_u64_t end_ticks,bw_variation_result_t result);
    if(scope_failed(scope_kind,scope_id))return;
    $display("BW_VARIATION scope_kind=%0d scope=%s epoch=%0d episode=%0d phase=%0d result_seq=%0d interval=%s start_ticks=%0d end_ticks=%0d basis=%0d W=%0d S=%0d samples=%0d first_sample_ticks=%0d last_sample_ticks=%0d sample_span_ticks=%0d mean_gbps=%0.17g min_gbps=%0.17g max_gbps=%0.17g stddev_gbps=%s cv_pct=%s interval_known=%0b coverage_complete=%0b minmax_valid=%0b stddev_valid=%0b cv_valid=%0b minmax_reason=%s stddev_reason=%s cv_reason=%s excluded_warmup=%0d excluded_foreign=%0d unknown_samples=%0d excluded_denominator=%0d",
      scope_kind,scope_id,epoch,episode,phase,sequence_id,interval_kind,start_ticks,end_ticks,
      result.window_basis,result.window_width,result.update_stride,result.sample_count,result.first_sample_ticks,
      result.last_sample_ticks,result.sample_span_ticks,result.mean_gbps,result.min_gbps,result.max_gbps,
      result.stddev_valid ? $sformatf("%0.17g",result.stddev_gbps) : "UNAVAILABLE",
      result.cv_valid ? $sformatf("%0.17g",result.cv_pct) : "UNAVAILABLE",
      result.interval_known,result.coverage_complete,
      result.minmax_valid,result.stddev_valid,result.cv_valid,metric_reason_name(result.minmax_reason),
      metric_reason_name(result.stddev_reason),metric_reason_name(result.cv_reason),result.excluded_warmup,
      result.excluded_foreign,result.unknown_samples,result.excluded_denominator);
  endfunction

  function automatic void install_check_report(bw_report_sink owner);
    if(report_sink!=null || monitor_ready || owner==null)
      core_error("REPORT_OWNER","setup","one report owner must be installed before ready");
    report_sink=owner;
  endfunction

  function automatic bw_report_summary_t check_report_summary();
    if(report_sink==null) return '0;
    return report_sink.summary();
  endfunction

  function automatic void report_scope_done(bw_scope_t kind,string scope_id,bw_u64_t stats_epoch=0);
    if(report_sink!=null && !core_failure_pending()) report_sink.scope_done(kind,scope_id,stats_epoch);
  endfunction

  function automatic void emit_episode_result(string scope_id, bw_episode_result_t result);
    if(scope_failed(result.scope_kind,scope_id))return;
    if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
    // Type/transport bridge for the dedicated check/report owner. Episode
    // arithmetic stays in bw_stats_core; this entry does no performance check.
    $display("BW_EPISODE scope_kind=%0d scope=%s epoch=%0d episode=%0d result_seq=%0d status=%0d first_ticks=%0d last_ticks=%0d tail_ticks=%0d confirm_ticks=%0d bytes=%0d events=%0d duration_ticks=%0d first_known=%0b last_known=%0b tail_known=%0b bytes_complete=%0b events_complete=%0b member_reset=%0b e2e_valid=%0b e2e_gbps=%0.12g reason=%s",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.result_seq,
      result.status,result.first_ticks,result.last_ticks,result.tail_ticks,result.confirmation_ticks,
      result.byte_count,result.event_count,result.duration_ticks,result.first_known,result.last_known,
      result.tail_known,result.bytes_complete,result.events_complete,result.member_reset_coverage,
      result.e2e_valid,result.e2e_gbps,episode_reason_name(result.reason));
    emit_variation_context(scope_id,"EPISODE",result.scope_kind,result.stats_epoch,result.episode_id,0,
      result.result_seq,result.first_ticks,result.tail_ticks,result.variation);
    $display("BW_LAST_STEADY scope_kind=%0d scope=%s epoch=%0d episode=%0d result_seq=%0d found=%0b selection_valid=%0b phase=%0d phase_result_seq=%0d start_ticks=%0d end_ticks=%0d bandwidth_valid=%0b bandwidth_gbps=%0.17g reason=%s",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.result_seq,result.last_steady_found,
      result.last_steady_selection_valid,result.last_steady.phase_id,result.last_steady.result_seq,
      result.last_steady.start_ticks,result.last_steady.end_ticks,result.last_steady.bandwidth_valid,
      result.last_steady.bandwidth_gbps,metric_reason_name(result.last_steady_reason));
    if(report_sink!=null) report_sink.submit_episode(scope_id,result);
  endfunction

  function automatic void emit_phase_result(string scope_id, bw_phase_result_t result);
    if(scope_failed(result.scope_kind,scope_id))return;
    if(!monitor_time_supported($time))begin check_monitor_time($time,scope_id);return;end
    $display("BW_PHASE scope_kind=%0d scope=%s epoch=%0d episode=%0d phase=%0d result_seq=%0d kind=%0d start_ticks=%0d end_ticks=%0d confirm_ticks=%0d start_known=%0b end_known=%0b start_bytes=%0d end_bytes=%0d start_events=%0d end_events=%0d delta=%0.17g rms=%0.17g reason=%0d",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.phase_id,result.result_seq,
      result.phase_kind,result.start_ticks,result.end_ticks,result.confirmation_ticks,
      result.start_known,result.end_known,result.start_total_bytes,result.end_total_bytes,
      result.start_total_events,result.end_total_events,result.confirmation_delta,result.confirmation_rms,result.end_reason);
    $display("BW_PHASE_METRICS scope_kind=%0d scope=%s epoch=%0d episode=%0d phase=%0d result_seq=%0d start_ticks=%0d end_ticks=%0d bytes=%0d events=%0d duration_ticks=%0d bytes_complete=%0b events_complete=%0b member_reset=%0b duration_valid=%0b bandwidth_valid=%0b bandwidth_gbps=%0.17g duration_reason=%s bandwidth_reason=%s start_unknown_records=%0d end_unknown_records=%0d start_unknown_event_records=%0d end_unknown_event_records=%0d start_unknown_ticks=%0d end_unknown_ticks=%0d",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.phase_id,result.result_seq,
      result.start_ticks,result.end_ticks,result.byte_count,result.event_count,result.duration_ticks,
      result.bytes_complete,result.events_complete,result.member_reset_coverage,result.duration_valid,result.bandwidth_valid,result.bandwidth_gbps,
      metric_reason_name(result.duration_reason),metric_reason_name(result.bandwidth_reason),
      result.start_unknown_records,result.end_unknown_records,result.start_unknown_event_records,
      result.end_unknown_event_records,result.start_unknown_ticks,result.end_unknown_ticks);
    emit_variation_context(scope_id,"PHASE",result.scope_kind,result.stats_epoch,result.episode_id,result.phase_id,
      result.result_seq,result.start_ticks,result.end_ticks,result.variation);
    if(report_sink!=null) report_sink.submit_phase(scope_id,result);
  endfunction

  function automatic bit known_binary(logic [1:0] value);
    return !$isunknown(value) && (value inside {2'd0,2'd1});
  endfunction

  function automatic void validate_point_protocol(bw_protocol_t protocol, logic [1:0] dynamic_bytes,
                                                  logic [63:0] fixed_bytes,string id);
    if($isunknown(protocol) || !(protocol inside {BW_VALID_ONLY,BW_VALID_READY,BW_CREDIT}))
      core_error("PROTOCOL_CONFIG",id,"unsupported protocol");
    if(!known_binary(dynamic_bytes))
      core_error("BYTE_CONFIG",id,"dynamic-byte policy must be known 0 or 1");
    if(!dynamic_bytes && ($isunknown(fixed_bytes) || fixed_bytes>64'hffffffff))
      core_error("BYTE_CONFIG",id,"fixed byte count must be known and at most 2^32-1");
  endfunction

  function automatic void validate_credit_config(bw_protocol_t protocol,logic [1:0] enable,
      logic [63:0] capacity,logic [63:0] initial_balance,logic [1:0] initial_known,
      bw_credit_return_t return_timing,string id);
    if($isunknown(protocol) || !(protocol inside {BW_VALID_ONLY,BW_VALID_READY,BW_CREDIT}))
      core_error("PROTOCOL_CONFIG",id,"unsupported protocol");
    if(!known_binary(enable) || !known_binary(initial_known))
      core_error("CREDIT_CONFIG",id,"enable and initial-known policy must be known 0 or 1");
    if(protocol!=BW_CREDIT || !enable) return;
    if($isunknown(capacity)) core_error("CREDIT_CONFIG",id,"explicit known credit capacity required");
    if($isunknown(return_timing) || !(return_timing inside {BW_RETURN_NEXT_CYCLE,BW_RETURN_SAME_CYCLE}))
      core_error("CREDIT_CONFIG",id,"invalid credit return timing");
    if(initial_known && ($isunknown(initial_balance) || initial_balance>capacity))
      core_error("CREDIT_CONFIG",id,"known initial balance must be specified and within capacity");
  endfunction

  function automatic bw_u64_t checked_add(logic [63:0] a, logic [63:0] b, string scope_context);
    bit [64:0] wide;
    if ($isunknown({a,b})) begin
      core_error("INTEGER_UNKNOWN",scope_context,$sformatf("addition a=%h b=%h",a,b));
      return a;
    end
    wide = {1'b0,a} + {1'b0,b};
    if (wide[64]) begin
      core_error("INTEGER_OVERFLOW", scope_context,$sformatf("addition a=%0d b=%0d", a, b));
      return a;
    end
    return wide[63:0];
  endfunction

  function automatic bw_u64_t checked_mul(logic [63:0] a, logic [63:0] b, string scope_context);
    bit [127:0] wide;
    if ($isunknown({a,b})) begin
      core_error("INTEGER_UNKNOWN",scope_context,$sformatf("multiplication a=%h b=%h",a,b));
      return a;
    end
    wide = {64'b0,a} * {64'b0,b};
    if (wide[127:64] != 0) begin
      core_error("INTEGER_OVERFLOW", scope_context,$sformatf("multiplication a=%0d b=%0d", a, b));
      return a;
    end
    return wide[63:0];
  endfunction

  function automatic bw_u64_t checked_sub(logic [63:0] a,logic [63:0] b,string scope_context);
    if($isunknown({a,b}))begin
      core_error("INTEGER_UNKNOWN",scope_context,$sformatf("subtraction a=%h b=%h",a,b));
      return a;
    end
    if(b>a)begin
      core_error("INTEGER_UNDERFLOW",scope_context,$sformatf("subtraction a=%0d b=%0d",a,b));
      return a;
    end
    return a-b;
  endfunction

  function automatic bw_u64_t ns_to_ticks(logic [63:0] ns, string scope_context = "time");
    return checked_mul(ns, BW_TICKS_PER_NS, scope_context);
  endfunction

  // Numeric metadata must remain four-state until this boundary. Unknown raw
  // reset levels are legitimate quality; known partial increments stay numeric.
  function automatic void validate_record_numeric(bw_record_t value,string id);
    if($isunknown({value.timestamp_ticks,value.edge_index,value.record_seq,value.source_epoch,
                   value.byte_inc,value.event_inc,value.reset_points}))
      core_error("INTEGER_UNKNOWN",id,
        $sformatf("record ticks=%h edge=%h sequence=%h epoch=%h bytes=%h events=%h reset_points=%h",
          value.timestamp_ticks,value.edge_index,value.record_seq,value.source_epoch,
          value.byte_inc,value.event_inc,value.reset_points));
  endfunction

  function automatic void validate_control_numeric(bw_control_t value,string id);
    if($isunknown({value.timestamp_ticks,value.control_seq,value.source_epoch,value.point_handle}))
      core_error("INTEGER_UNKNOWN",id,
        $sformatf("control ticks=%h sequence=%h epoch=%h point=%h",
          value.timestamp_ticks,value.control_seq,value.source_epoch,value.point_handle));
  endfunction

  function automatic void validate_hint_config(logic [1:0] supported,logic [1:0] enabled,
      logic [1:0] basis,logic [63:0] threshold,string id,string hint_name);
    if(!known_binary(supported) || !known_binary(enabled))
      core_error("HINT_CONFIG",id,{hint_name," support and enable policy must be known 0 or 1"});
    if(!supported || !enabled) return;
    if($isunknown(basis) || !(basis inside {2'd0,2'd1}))
      core_error("HINT_CONFIG",id,{hint_name," requires explicit BW_NS/BW_CYCLE basis"});
    if($isunknown(threshold) || threshold==0)
      core_error("HINT_CONFIG",id,{hint_name," requires explicit positive threshold"});
    if(basis==BW_NS) void'(ns_to_ticks(threshold,{id," ",hint_name}));
  endfunction

  function automatic void validate_episode_config(logic [1:0] enable, logic [63:0] silence,
                                                   logic [1:0] basis, string id);
    if(!known_binary(enable))core_error("EPISODE_CONFIG",id,"episode enable policy must be known 0 or 1");
    if (!enable) return;
    if($isunknown(basis) || !(basis inside {BW_NS,BW_CYCLE}))
      core_error("EPISODE_CONFIG",id,"episode basis must be known BW_NS/BW_CYCLE");
    if ($isunknown(silence) || silence==0)
      core_error("EPISODE_CONFIG",id,"enabled episode analysis requires explicit positive Q");
    if (basis==BW_NS) void'(ns_to_ticks(silence,id));
  endfunction

  function automatic bit finite_nonnegative_real(real value);
    bit [63:0] representation;
    representation=$realtobits(value);
    return representation[62:52]!=11'h7ff && value>=0.0;
  endfunction

  function automatic void validate_phase_config(logic [1:0] enable,logic [1:0] episode_enable,
      logic [1:0] basis,string id);
    if(!known_binary(enable))core_error("PHASE_CONFIG",id,"phase enable policy must be known 0 or 1");
    if(!enable)return;
    if($isunknown(basis) || !(basis inside {BW_NS,BW_CYCLE}))
      core_error("PHASE_CONFIG",id,"phase basis must be known BW_NS/BW_CYCLE");
    if(!known_binary(episode_enable) || !episode_enable)
      core_error("PHASE_CONFIG",id,"phase analysis requires known enabled episode analysis");
  endfunction

  function automatic bit monitor_time_supported(logic [63:0] at_ticks);
    if($isunknown(at_ticks))return 0;
    if(!monitor_configured) return 1;
    if(at_ticks<monitor_start_ticks) return 0;
    return at_ticks-monitor_start_ticks<=BW_MONITOR_LIMIT_TICKS;
  endfunction

  function automatic void check_monitor_time(logic [63:0] at_ticks, string scope_context);
    if($isunknown(at_ticks))begin
      core_error("INTEGER_UNKNOWN",scope_context,$sformatf("time_ticks=%h",at_ticks));return;
    end
    if(monitor_time_supported(at_ticks)) return;
    if(at_ticks<monitor_start_ticks)
      core_error("SIM_TIME_LIMIT",scope_context,
        $sformatf("system_start_ticks=%0d received_ticks=%0d precedes monitoring start",
                  monitor_start_ticks,at_ticks));
    else core_error("SIM_TIME_LIMIT",scope_context,
        $sformatf("system_start_ticks=%0d received_ticks=%0d supported_duration_ticks=%0d",
                  monitor_start_ticks,at_ticks,BW_MONITOR_LIMIT_TICKS));
  endfunction

  function automatic void check_queue_growth(int current_size, string scope_context);
    if (current_size<0 || current_size==32'sh7fffffff)
      core_error("STORAGE_RANGE",scope_context,
        $sformatf("queue_entries=%0d next entry cannot be represented",current_size));
  endfunction

`ifdef BW_MON_TEST_FAULTS
  // One-shot semantic allocation rejection for contract tests only. It is not
  // a capacity limit, module parameter or ordinary-build configuration API.
  bit injected_growth_failures[string][string];
  bit injected_group_faults[string][string];
  function automatic void inject_group_fault(string id,string stage);injected_group_faults[id][stage]=1;endfunction
  function automatic bit take_group_fault(string id,string stage);
    if(!injected_group_faults.exists(id) || !injected_group_faults[id].exists(stage))return 0;
    injected_group_faults[id].delete(stage);return 1;
  endfunction
  bit injected_point_faults[string][string];
  function automatic void inject_point_fault(string id,string stage);
    injected_point_faults[id][stage]=1;
  endfunction
  function automatic bit take_point_fault(string id,string stage);
    if(!injected_point_faults.exists(id) || !injected_point_faults[id].exists(stage))return 0;
    injected_point_faults[id].delete(stage);return 1;
  endfunction
  function automatic void inject_growth_failure(string id,string resource);
    injected_growth_failures[id][resource]=1;
  endfunction
`endif

`ifdef BW_MON_TEST_SCHEDULING
  // Read-only acceptance telemetry of real growth requests. This records the
  // largest individual queue of each resource, not a sum or memory estimate.
  int bw_test_storage_peak[string];
`endif
  function automatic void check_storage_growth(int current_size,string id,string resource,
      bw_u64_t at_ticks=0,bw_u64_t edge_index=0,bw_u64_t record_number=0);
    if(core_failure_seen)return;
    check_queue_growth(current_size,{id," ",resource});
    if(core_failure_seen)return;
`ifdef BW_MON_TEST_SCHEDULING
    if(!bw_test_storage_peak.exists(resource) || current_size+1>bw_test_storage_peak[resource])
      bw_test_storage_peak[resource]=current_size+1;
`endif
`ifdef BW_MON_TEST_FAULTS
    if(injected_growth_failures.exists(id) && injected_growth_failures[id].exists(resource))begin
      injected_growth_failures[id].delete(resource);
      core_error("STORAGE_FAILURE",id,
        $sformatf("resource=%s entries=%0d requested=1 edge=%0d record_seq=%0d original_ticks=%0d injected=1",
          resource,current_size,edge_index,record_number,at_ticks));
    end
`endif
  endfunction

  function automatic void record_check_analysis(bw_scope_t kind,string id,bit enabled,
      bw_basis_t basis,bw_u64_t width,bw_u64_t stride);
    string key;
    if(core_failure_pending())return;
    key=scope_key(kind,id);
    if(!check_analysis.exists(key))check_storage_growth(check_analysis.num(),id,"report.analysis",$time);
    if(core_failure_pending())return;
    check_analysis[key]='{enabled:enabled,basis:basis,width:width,stride:stride};
  endfunction

  function automatic bw_u64_t resolve_silence_threshold(logic [63:0] silence,
                                                        logic [1:0] episode_enable);
    // Unused Q is not validated or used at runtime.
    if ($isunknown(episode_enable) || !episode_enable) return 0;
    return silence;
  endfunction

  function automatic void validate_window(logic [1:0] basis, logic [63:0] width,
                                          logic [63:0] stride, string id);
    if ($isunknown({basis,width,stride}) || !(basis inside {BW_NS,BW_CYCLE}))
      core_error("WINDOW_CONFIG",id,"basis, W and S must be known; basis must be BW_NS/BW_CYCLE");
    if (width == 0 || stride == 0 || stride > width)
      core_error("WINDOW_CONFIG", id,
                 $sformatf("require 0<S<=W; W=%0d S=%0d", width, stride));
    if (basis == BW_NS) begin
      if (width > 40000)
        core_error("WINDOW_CONFIG", id, "ns width exceeds 40000 ns");
      void'(ns_to_ticks(width, id));
      void'(ns_to_ticks(stride, id));
    end else if (width > 80000)
      core_error("WINDOW_CONFIG", id, "cycle width exceeds 80000 cycles");
  endfunction

`ifdef BW_MON_TEST_SCHEDULING
  // Acceptance-only scheduling control: delays the real collector task without
  // changing records, counters, acknowledgements, clocks or statistics state.
  class bw_test_consumer_gate;
    bit paused=0;
    // Explicit test continuation depends on a named consumer receipt, rather
    // than elapsed time or a chosen number of scheduler rounds.
    string resume_after_group="";
    string resume_after_groups[$];
    bw_u64_t resume_after_seq=0;
  endclass
  bw_test_consumer_gate bw_test_consumer_gates[string];
  function automatic bw_test_consumer_gate bw_test_gate_for(string id);
    if(!bw_test_consumer_gates.exists(id))bw_test_consumer_gates[id]=new;
    return bw_test_consumer_gates[id];
  endfunction
`endif
  `include "bw_slot_settlement.svh"
  `include "bw_mon_registry.svh"
  `include "bw_mon_transport.svh"
  `include "bw_point_completion.svh"
  `include "bw_group_completion.svh"
endpackage
