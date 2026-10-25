module tb_numeric_arithmetic;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  logic [63:0] raw_value;
  bw_u64_t value,converted;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="known";
    raw_value=64'hx000000000000001;converted=raw_value;
    $display("NUMERIC_TYPE raw=%h unsigned_longint=%h raw_unknown=%0b typed_unknown=%0b",raw_value,converted,$isunknown(raw_value),$isunknown(converted));
    if(mode=="add_unknown")value=checked_add(raw_value,1,"add.subject");
    else if(mode=="mul_unknown")value=checked_mul(raw_value,2,"mul.subject");
    else if(mode=="known")begin
      if(checked_add(64'hffffffffffffffff,0,"add.known")!=64'hffffffffffffffff ||
         checked_mul(64'hffffffffffffffff,1,"mul.known")!=64'hffffffffffffffff ||
         checked_mul(16384,checked_mul(80001,64'd4294967295,"D16.points"),"D16.total")!=64'd5629569901646561280)
        $fatal(1,"exact unsigned64 arithmetic or independent D16 product failed");
      $display("TB_PASS numeric_arithmetic");$finish;
    end else $fatal(1,"bad MODE");
    $fatal(1,"expected core error did not occur");
  end
endmodule
