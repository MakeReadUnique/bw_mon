module tb_numeric_subtract;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  bw_u64_t value;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="known";
    if(mode=="underflow")value=checked_sub(0,1,"subtract.subject");
    else if(mode=="unknown")value=checked_sub(64'hx000000000000001,0,"subtract.subject");
    else begin
      if(checked_sub(64'hffffffffffffffff,0,"subtract.subject")!=64'hffffffffffffffff ||
         checked_sub(64'hffffffffffffffff,64'hffffffffffffffff,"subtract.subject")!=0)
        $fatal(1,"unsigned64 exact subtraction failed");
      $display("TB_PASS numeric_subtract");$finish;
    end
    $fatal(1,"expected core error did not occur");
  end
endmodule
