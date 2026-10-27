module tb_hierarchy_edge_limit;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  int extra,unused_handle;
  string id;
  initial begin
    if(!$value$plusargs("EXTRA=%d",extra))extra=0;
    configure_monitor(4096,4096);
    for(int p=0;p<4096;p++)unused_handle=register_point($sformatf("p%0d",p),$sformatf("p%0d",p),BW_NS,1,1,"default");
    for(int g=0;g<4096;g++)begin
      id=$sformatf("g%0d",g);define_group(id,(g==0 && extra) ? 17 : 16);
      unused_handle=register_group_owner(id,id,BW_NS,1,1,"default");
      for(int m=0;m<16;m++)add_point_member(id,$sformatf("p%0d",(g+m)%4096));
      if(g==0 && extra)add_point_member(id,"p16");
    end
    finish_configuration();wait(monitor_ready);
    if(extra)$fatal(1,"expected core error did not occur");
    if(group_member_count(group_handle_for_id("g0"))!=16 || group_recursive_point_count(group_handle_for_id("g4095"))!=16)
      $fatal(1,"65536-edge startup must retain all direct and recursive members");
    $display("TB_PASS hierarchy_edge_limit groups=4096 points=4096 edges=65536 fanout=16 startup_only");$finish;
  end
endmodule
