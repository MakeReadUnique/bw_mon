module tb_storage_registry_failure;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string resource;
  int point_handle,group_handle;
  initial begin
    if(!$value$plusargs("RESOURCE=%s",resource))resource="registry.source";
    if(resource inside {"registry.source","registry.points"})begin
      inject_growth_failure("fault.registry",resource);
      point_handle=register_point("fault.registry","component",BW_NS,1,1,"clk");
    end else if(resource=="registry.groups")begin
      inject_growth_failure("fault.registry",resource);define_group("fault.registry",1);
    end else begin
      define_group("fault.registry",1);
      if(resource=="registry.rules")inject_growth_failure("fault.registry",resource);
      add_point_member("fault.registry","fault.registry");
      point_handle=register_point("fault.registry","component",BW_NS,1,1,"clk");
      group_handle=register_group_owner("fault.registry","component.group",BW_NS,1,1,"clk");
      if(resource inside {"registry.members","registry.parents"})inject_growth_failure("fault.registry",resource);
      configure_monitor(1,1);finish_configuration();
    end
    #1;$fatal(1,"expected core error did not occur");
  end
endmodule
