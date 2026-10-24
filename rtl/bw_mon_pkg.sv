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

  localparam bw_u64_t BW_TICKS_PER_NS = 1000000;
  localparam bw_u64_t BW_U64_MAX = 64'hffffffffffffffff;

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
  bit monitor_ready = 0;
  int unsigned expected_point_count;
  bw_u64_t measurement_start_ticks = 0;
  bw_u64_t monitor_start_ticks = 0;
  bw_u64_t registration_seq = 0;

  function automatic void core_error(string code, string scope_id, string detail);
    $fatal(1, "BW_CORE_ERROR code=%s scope=%s time_ticks=%0d %s",
           code, scope_id, $time, detail);
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

  function automatic void check_monitor_time(bw_u64_t at_ticks, string scope_context);
    if (!monitor_configured) return;
    if (at_ticks<monitor_start_ticks)
      core_error("SIM_TIME_LIMIT",scope_context,
        $sformatf("system_start_ticks=%0d received_ticks=%0d precedes monitoring start",
                  monitor_start_ticks,at_ticks));
    else if (at_ticks-monitor_start_ticks>64'd40000000000)
      core_error("SIM_TIME_LIMIT",scope_context,
        $sformatf("system_start_ticks=%0d received_ticks=%0d supported_duration_ticks=%0d",
                  monitor_start_ticks,at_ticks,64'd40000000000));
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
