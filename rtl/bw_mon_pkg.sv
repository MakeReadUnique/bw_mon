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

  typedef struct {
    string id;
    string monitor_path;
    bw_basis_t basis;
    bw_u64_t width;
    bw_u64_t stride;
    string clock_context;
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

  function automatic void try_ready();
    if (!monitor_configured || monitor_ready) return;
    if (registered_points.size() > expected_point_count)
      core_error("POINT_COUNT", "setup",
                 $sformatf("expected=%0d actual=%0d",expected_point_count,registered_points.size()));
    if (registered_points.size() != expected_point_count) return;
    measurement_start_ticks = $time;
    monitor_ready = 1;
    $display("BW_READY time_ticks=%0d points=%0d",measurement_start_ticks,registered_points.size());
  endfunction

  function automatic void configure_monitor(int unsigned expected);
    if (monitor_configured || monitor_ready)
      core_error("CONFIG_FROZEN", "setup", "configuration may be completed only once");
    if (expected == 0 || expected > 16384)
      core_error("POINT_COUNT", "setup", "expected_point_count must be 1..16384");
    expected_point_count = expected;
    monitor_start_ticks = $time;
    monitor_configured = 1;
    try_ready();
  endfunction

  function automatic int register_point(string id, string monitor_path,
                                        bw_basis_t basis, bw_u64_t width,
                                        bw_u64_t stride, string clock_context);
    bw_point_registration_t entry;
    if (monitor_ready) core_error("REGISTRATION_FROZEN", id, "registration after ready");
    if (id.len() == 0) core_error("POINT_ID", monitor_path, "empty Point ID");
    foreach (registered_points[i])
      if (registered_points[i].id == id)
        core_error("DUPLICATE_POINT", id,
                   $sformatf("first=%s second=%s",registered_points[i].monitor_path,monitor_path));
    validate_window(basis,width,stride,id);
    if (clock_context.len() == 0) core_error("CLOCK_CONTEXT",id,"empty clock context");
    entry.id=id; entry.monitor_path=monitor_path; entry.basis=basis;
    entry.width=width; entry.stride=stride; entry.clock_context=clock_context;
    registered_points.push_back(entry);
    registration_seq=checked_add(registration_seq,1,"registration");
    try_ready();
    return registered_points.size()-1;
  endfunction

  function automatic int point_handle_for_id(string id);
    foreach (registered_points[i])
      if (registered_points[i].id == id) return i;
    core_error("POINT_REFERENCE", id, "unregistered point control source");
    return -1;
  endfunction
endpackage
