// Tool-capability probe only. This is not bw_mon's parser or statistics engine.
package probe_pkg;
  timeunit 1ns; timeprecision 1ps;
  typedef enum logic [1:0] {UNUSED, WARMUP, FULL} probe_state_t;
  class group_state;
    string id;
    string member[2];
    int history[$];
    int raw_bytes;
    longint unsigned result_seq = 0;
    longint unsigned window_bytes = 0;
    real bandwidth_gbps = 0.0;
    bit window_full = 0;
    bit bytes_complete = 1;
    function new(string name, string a, string b);
      id = name; member[0] = a; member[1] = b;
    endfunction
    function void publish();
      int discarded;
      history.push_back(raw_bytes);
      if (history.size() > 4) discarded = history.pop_front();
      window_bytes = 0;
      foreach (history[i]) window_bytes += history[i];
      // One toy interval is exactly 2 ns; B/ns is decimal GB/s.
      bandwidth_gbps = real'(window_bytes) / (2.0 * history.size());
      result_seq++;
      window_full = history.size() == 4;
    endfunction
  endclass
  group_state groups[$];
endpackage

module tb_cfg_group_probe;
  timeunit 1ns; timeprecision 1ps;
  import probe_pkg::*;
  localparam int OBSERVATION_CAPACITY = 4;
  int publish_seq = 0;
  int p0_bytes, p1_bytes;
  string cfg_path, fsdb_path;

  // Only anonymous ordinary scalar wave carriers exist at compile time.
  // Group IDs and statistical objects are created from the startup file.
  for (genvar i = 0; i < OBSERVATION_CAPACITY; i++) begin : wave_slots
    bit active = 0;
    string group_id = "";
    real bandwidth_gbps = 0.0;
    longint unsigned result_seq = 0;
    longint unsigned window_bytes = 0;
    bit window_full = 0;
    bit bytes_complete = 0;
    probe_state_t probe_state = UNUSED;
    always @(publish_seq) begin
      active = i < groups.size();
      if (active) begin
        group_id = groups[i].id;
        bandwidth_gbps = groups[i].bandwidth_gbps;
        result_seq = groups[i].result_seq;
        window_bytes = groups[i].window_bytes;
        window_full = groups[i].window_full;
        bytes_complete = groups[i].bytes_complete;
        probe_state = window_full ? FULL : WARMUP;
      end
    end
  end

  function automatic int aggregate(string id, int depth = 0);
    int value;
    if (id == "-") return 0;
    if (id == "p0") return p0_bytes;
    if (id == "p1") return p1_bytes;
    if (depth > groups.size()) $fatal(1, "cycle in probe cfg");
    foreach (groups[i]) begin
      if (groups[i].id == id) begin
        value = 0;
        foreach (groups[i].member[j])
          value += aggregate(groups[i].member[j], depth + 1);
        return value;
      end
    end
    $fatal(1, "unknown member %s", id);
    return 0;
  endfunction

  initial begin : run_probe
    int fd, count, consumed;
    string line, id, a, b;
    group_state object;
    if (!$value$plusargs("CFG=%s", cfg_path)) $fatal(1, "missing CFG");
    if (!$value$plusargs("FSDB=%s", fsdb_path)) $fatal(1, "missing FSDB");
    fd = $fopen(cfg_path, "r");
    if (!fd) $fatal(1, "cannot open cfg");
    while ($fgets(line, fd)) begin
      count = $sscanf(line, "%s %s %s", id, a, b);
      if (count != 3) $fatal(1, "probe cfg requires id member member-or-dash");
      if (groups.size() == OBSERVATION_CAPACITY) $fatal(1, "probe observation capacity exceeded");
      foreach (groups[i]) if (groups[i].id == id) $fatal(1, "duplicate id");
      object = new(id, a, b);
      groups.push_back(object);
    end
    $fclose(fd);
    if (!groups.size()) $fatal(1, "empty cfg");
    foreach (groups[i]) begin
      consumed = aggregate(groups[i].id);
      $display("MAP group_id=%s path=/tb_cfg_group_probe/wave_slots[%0d]", groups[i].id, i);
    end
    $fsdbDumpfile(fsdb_path);
    $fsdbDumpvars(0, tb_cfg_group_probe, "+all");
    publish_seq++;
    for (int k = 1; k <= 24; k++) begin
      #2ns;
      p0_bytes = k <= 4 ? 8 : k <= 12 ? 32 : k <= 16 ? 0 : k <= 20 ? 16 : 0;
      p1_bytes = k <= 8 ? 16 : k <= 16 ? 0 : k <= 20 ? 8 : 0;
      foreach (groups[i]) begin
        groups[i].raw_bytes = aggregate(groups[i].id);
        groups[i].publish();
      end
      publish_seq++;
    end
    #1ns;
    $display("PROBE_PASS groups=%0d samples=24", groups.size());
    $finish;
  end
endmodule
