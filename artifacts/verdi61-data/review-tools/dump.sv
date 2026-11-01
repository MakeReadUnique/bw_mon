// Waveform instrumentation only: run the unchanged public-input fixture and
// its independent checker. No stimulus, phase, or checker result is overridden.
module verdi61_dump;
  timeunit 1fs; timeprecision 1fs;
  initial begin
    string path;
    if (!$value$plusargs("FSDB=%s", path)) $fatal(1, "FSDB path required");
    $fsdbDumpfile(path);
    $fsdbDumpvars(1, tb_checker_default, "+all");
    $fsdbDumpvars(1, tb_checker_default.group_mon, "+all");
    $fsdbDumpvars(1, tb_checker_default.members[0].point, "+all");
  end
endmodule

bind tb_checker_default verdi61_dump wave_dump();
