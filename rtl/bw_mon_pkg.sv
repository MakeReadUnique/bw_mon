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

  // This is a per-edge record, including idle/unknown/reset edges. Time, edge,
  // record sequence and source epoch remain distinct quantities.
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    bw_u64_t edge_index;
    bw_u64_t record_seq;
    bw_u64_t source_epoch;
    bw_u64_t byte_inc;
    bw_u64_t event_inc;
    bw_u64_t reset_points;
    bit events_complete;
    bit bytes_complete;
    logic reset_n;
  } bw_record_t;

  // Actual point-reset controls are not sampling frames: no edge is invented.
  // point_handle identifies the registered Point ID without copying strings.
  typedef struct packed {
    bw_u64_t timestamp_ticks;
    bw_u64_t control_seq;
    bw_u64_t source_epoch;
    int unsigned point_handle;
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
  } bw_episode_result_t;

  typedef enum logic [1:0] {
    BW_PHASE_UNDETERMINED, BW_PHASE_RAMP, BW_PHASE_STEADY, BW_PHASE_FALL
  } bw_phase_t;
  typedef enum logic [2:0] {
    BW_PHASE_CHANGE, BW_PHASE_EVIDENCE_GAP, BW_PHASE_EPISODE_END
  } bw_phase_end_t;
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
  } bw_phase_result_t;

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
    string clock_context;
    int transport_source;
  } bw_point_registration_t;

  bw_point_registration_t registered_points[$];
  bit monitor_configured = 0;
  bit core_failure_seen = 0;
  bit monitor_ready = 0;
  int unsigned expected_point_count;
  bw_u64_t measurement_start_ticks = 0;
  bw_u64_t monitor_start_ticks = 0;
  bw_u64_t registration_seq = 0;

  function automatic void core_error(string code, string scope_id, string detail);
    // VCS can return from $fatal while executing final blocks. Retain a shared
    // terminal-failure fact before reporting, so no finalizer emits new results.
    core_failure_seen=1;
    $fatal(1, "BW_CORE_ERROR code=%s scope=%s time_ticks=%0d %s",
           code, scope_id, $time, detail);
  endfunction

  function automatic void emit_episode_result(string scope_id, bw_episode_result_t result);
    if (core_failure_seen) return;
    // Type/transport bridge for the dedicated check/report owner. Episode
    // arithmetic stays in bw_stats_core; this entry does no performance check.
    $display("BW_EPISODE scope_kind=%0d scope=%s epoch=%0d episode=%0d result_seq=%0d status=%0d first_ticks=%0d last_ticks=%0d tail_ticks=%0d confirm_ticks=%0d bytes=%0d events=%0d duration_ticks=%0d first_known=%0b last_known=%0b tail_known=%0b bytes_complete=%0b events_complete=%0b member_reset=%0b e2e_valid=%0b e2e_gbps=%0.12g reason=%s",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.result_seq,
      result.status,result.first_ticks,result.last_ticks,result.tail_ticks,result.confirmation_ticks,
      result.byte_count,result.event_count,result.duration_ticks,result.first_known,result.last_known,
      result.tail_known,result.bytes_complete,result.events_complete,result.member_reset_coverage,
      result.e2e_valid,result.e2e_gbps,episode_reason_name(result.reason));
  endfunction

  function automatic void emit_phase_result(string scope_id, bw_phase_result_t result);
    if(core_failure_seen)return;
    $display("BW_PHASE scope_kind=%0d scope=%s epoch=%0d episode=%0d phase=%0d result_seq=%0d kind=%0d start_ticks=%0d end_ticks=%0d confirm_ticks=%0d start_known=%0b end_known=%0b start_bytes=%0d end_bytes=%0d start_events=%0d end_events=%0d delta=%0.17g rms=%0.17g reason=%0d",
      result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.phase_id,result.result_seq,
      result.phase_kind,result.start_ticks,result.end_ticks,result.confirmation_ticks,
      result.start_known,result.end_known,result.start_total_bytes,result.end_total_bytes,
      result.start_total_events,result.end_total_events,result.confirmation_delta,result.confirmation_rms,result.end_reason);
  endfunction

  function automatic void validate_point_protocol(bw_protocol_t protocol, bit dynamic_bytes,
                                                  logic [63:0] fixed_bytes,string id);
    if($isunknown(protocol) || !(protocol inside {BW_VALID_ONLY,BW_VALID_READY,BW_CREDIT}))
      core_error("PROTOCOL_CONFIG",id,"unsupported protocol");
    if(!dynamic_bytes && ($isunknown(fixed_bytes) || fixed_bytes>64'hffffffff))
      core_error("BYTE_CONFIG",id,"fixed byte count must be known and at most 2^32-1");
  endfunction

  function automatic void validate_credit_config(bw_protocol_t protocol,bit enable,
      logic [63:0] capacity,logic [63:0] initial_balance,bit initial_known,
      bw_credit_return_t return_timing,string id);
    if(protocol!=BW_CREDIT || !enable) return;
    if($isunknown(capacity)) core_error("CREDIT_CONFIG",id,"explicit known credit capacity required");
    if($isunknown(return_timing) || !(return_timing inside {BW_RETURN_NEXT_CYCLE,BW_RETURN_SAME_CYCLE}))
      core_error("CREDIT_CONFIG",id,"invalid credit return timing");
    if(initial_known && ($isunknown(initial_balance) || initial_balance>capacity))
      core_error("CREDIT_CONFIG",id,"known initial balance must be specified and within capacity");
  endfunction

  function automatic bw_u64_t checked_add(bw_u64_t a, bw_u64_t b, string scope_context);
    bit [64:0] wide;
    wide = {1'b0,a} + {1'b0,b};
    if (wide[64]) core_error("INTEGER_OVERFLOW", scope_context,
                            $sformatf("addition a=%0d b=%0d", a, b));
    return wide[63:0];
  endfunction

  function automatic bw_u64_t checked_mul(bw_u64_t a, bw_u64_t b, string scope_context);
    bit [127:0] wide;
    wide = {64'b0,a} * {64'b0,b};
    if (wide[127:64] != 0) core_error("INTEGER_OVERFLOW", scope_context,
                                    $sformatf("multiplication a=%0d b=%0d", a, b));
    return wide[63:0];
  endfunction

  function automatic bw_u64_t ns_to_ticks(bw_u64_t ns, string scope_context = "time");
    return checked_mul(ns, BW_TICKS_PER_NS, scope_context);
  endfunction

  function automatic void validate_hint_config(bit supported,bit enabled,
      logic [1:0] basis,logic [63:0] threshold,string id,string hint_name);
    if(!supported || !enabled) return;
    if($isunknown(basis) || !(basis inside {2'd0,2'd1}))
      core_error("HINT_CONFIG",id,{hint_name," requires explicit BW_NS/BW_CYCLE basis"});
    if($isunknown(threshold) || threshold==0)
      core_error("HINT_CONFIG",id,{hint_name," requires explicit positive threshold"});
    if(basis==BW_NS) void'(ns_to_ticks(threshold,{id," ",hint_name}));
  endfunction

  function automatic void validate_episode_config(bit enable, logic [63:0] silence,
                                                   bw_basis_t basis, string id);
    if (!enable) return;
    if ($isunknown(silence) || silence==0)
      core_error("EPISODE_CONFIG",id,"enabled episode analysis requires explicit positive Q");
    if (basis==BW_NS) void'(ns_to_ticks(silence,id));
  endfunction

  function automatic bit finite_nonnegative_real(real value);
    bit [63:0] representation;
    representation=$realtobits(value);
    return representation[62:52]!=11'h7ff && value>=0.0;
  endfunction

  function automatic void validate_phase_config(bit enable,bit episode_enable,bw_basis_t basis,
    logic [63:0] n,logic [63:0] span,logic [63:0] k,
    real steady_enter_abs,real steady_enter_rel,real steady_exit_abs,real steady_exit_rel,
    real rms_enter_abs,real rms_enter_rel,real rms_exit_abs,real rms_exit_rel,
    real trend_abs,real trend_rel,string id);
    if(!enable)return;
    if(!episode_enable)core_error("PHASE_CONFIG",id,"phase analysis requires episode analysis");
    if($isunknown({n,span,k}) || n<3 || span==0 || k==0)
      core_error("PHASE_CONFIG",id,"require explicit N>=3, positive minimum span and K");
    if(n>64'd2147483647)core_error("STORAGE_RANGE",id,
      $sformatf("N=%0d exceeds SV queue-index representation max=2147483647",n));
    if(basis==BW_NS)void'(ns_to_ticks(span,id));
    if(!finite_nonnegative_real(steady_enter_abs) || !finite_nonnegative_real(steady_enter_rel) ||
       !finite_nonnegative_real(steady_exit_abs) || !finite_nonnegative_real(steady_exit_rel) ||
       !finite_nonnegative_real(rms_enter_abs) || !finite_nonnegative_real(rms_enter_rel) ||
       !finite_nonnegative_real(rms_exit_abs) || !finite_nonnegative_real(rms_exit_rel) ||
       !finite_nonnegative_real(trend_abs) || !finite_nonnegative_real(trend_rel))
      core_error("PHASE_CONFIG",id,"all phase coefficients must be explicit nonnegative finite reals");
    if(steady_exit_abs<steady_enter_abs || steady_exit_rel<steady_enter_rel ||
       rms_exit_abs<rms_enter_abs || rms_exit_rel<rms_enter_rel)
      core_error("PHASE_CONFIG",id,"exit tolerances must be no stricter than entry tolerances");
    if(trend_abs<=steady_exit_abs || trend_rel<steady_exit_rel)
      core_error("PHASE_CONFIG",id,"trend must exceed steady exit tolerance for every nonnegative mean");
  endfunction

  function automatic bit monitor_time_supported(bw_u64_t at_ticks);
    if(!monitor_configured) return 1;
    if(at_ticks<monitor_start_ticks) return 0;
    return at_ticks-monitor_start_ticks<=BW_MONITOR_LIMIT_TICKS;
  endfunction

  function automatic void check_monitor_time(bw_u64_t at_ticks, string scope_context);
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

  function automatic void validate_window(bw_basis_t basis, bw_u64_t width,
                                          bw_u64_t stride, string id);
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

  `include "bw_mon_registry.svh"
  `include "bw_mon_transport.svh"
endpackage
