module tb_hierarchy_t4_overlap;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  bw_mon_setup setup();
  int unused_handle;
  string names[5]='{"die0_dmc","die1_dmc","all_dmc","mixed","combined"};
  initial begin
    foreach(names[g])begin
      unused_handle=register_group_owner(names[g],names[g],BW_NS,10,1);
    end
    for(int p=0;p<12;p++)unused_handle=register_point($sformatf("p%0d",p),$sformatf("p%0d",p),BW_NS,10,1);
    for(int p=0;p<4;p++)add_point_member("die0_dmc",$sformatf("p%0d",p));
    for(int p=4;p<8;p++)add_point_member("die1_dmc",$sformatf("p%0d",p));
    add_group_member("all_dmc","die0_dmc");add_group_member("all_dmc","die1_dmc");
    add_group_member("mixed","die0_dmc");add_point_member("mixed","p8");add_point_member("mixed","p9");
    add_group_member("combined","all_dmc");add_group_member("combined","mixed");
    #2;$fatal(1,"expected core error did not occur");
  end
endmodule
