module tb_numeric_policy;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode;
  logic [1:0] policy;
  int point_handle;
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="dynamic_x";
    policy=(mode.substr(mode.len()-1,mode.len()-1)=="x") ? 2'b0x : 2'b10;
    if(mode=="dynamic_x" || mode=="dynamic_2")validate_point_protocol(BW_VALID_ONLY,policy,0,"dynamic.policy");
    else if(mode=="credit_x" || mode=="credit_2")validate_credit_config(BW_CREDIT,policy,4,0,0,BW_RETURN_NEXT_CYCLE,"credit.policy");
    else if(mode=="initial_x" || mode=="initial_2")validate_credit_config(BW_CREDIT,1,4,'x,policy,BW_RETURN_NEXT_CYCLE,"initial.policy");
    else if(mode=="episode_x" || mode=="episode_2")validate_episode_config(policy,1,BW_NS,"episode.policy");
    else if(mode=="phase_x" || mode=="phase_2")validate_phase_config(policy,1,BW_NS,"phase.policy");
    else if(mode=="hint_x" || mode=="hint_2")validate_hint_config(1,policy,BW_NS,1,"hint.policy","backpressure");
    else if(mode=="basis_x" || mode=="basis_2")point_handle=register_point("basis.policy","component",policy,1,1);
    else if(mode=="stride_x")point_handle=register_point("stride.policy","component",BW_NS,1,64'hx000000000000001);
    else if(mode=="disabled")begin
      validate_point_protocol(BW_VALID_ONLY,0,0,"fixed.zero");
      validate_credit_config(BW_CREDIT,0,'x,'x,0,bw_credit_return_t'(2'bxx),"credit.disabled");
      validate_credit_config(BW_CREDIT,1,4,'x,0,BW_RETURN_NEXT_CYCLE,"credit.unknown_initial");
      validate_episode_config(0,'x,BW_NS,"episode.disabled");
      validate_hint_config(1,0,2'bxx,'x,"hint.disabled","backpressure");
      $display("TB_PASS numeric_policy disabled");$finish;
    end else $fatal(1,"bad MODE");
    $fatal(1,"expected core error did not occur");
  end
endmodule
