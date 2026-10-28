module tb_hierarchy_config;
  timeunit 1fs;timeprecision 1fs;
  import bw_mon_pkg::*;
  string mode,id;
  int unused_handle,point_count,group_count,target,levels,parents;
  task automatic owner(string name);
    unused_handle=register_group_owner(name,{"component.",name},BW_NS,1,1);
  endtask
  initial begin
    if(!$value$plusargs("MODE=%s",mode))$fatal(1,"MODE required");
    point_count=(mode=="overlap32") ? 33 : (mode=="overlap64") ? 65 : 1;
    target=point_count-1;group_count=3;
    if(mode=="self_cycle" || mode=="missing_group" || mode=="group_prefix" || mode=="unknown_kind" || mode=="invalid_kind" || mode=="hot_group")group_count=1;
    if(mode=="missing_point")group_count=2;
    if(mode=="diamond")group_count=4;
    if(mode=="depth8" || mode=="depth9")begin levels=(mode=="depth8") ? 8 : 9;group_count=levels;end
    if(mode=="fanout16" || mode=="fanout17")begin parents=(mode=="fanout16") ? 16 : 17;group_count=parents;end
    configure_monitor(point_count,group_count);
    for(int p=0;p<point_count;p++)
      unused_handle=register_point($sformatf("p%0d",p),$sformatf("component.p%0d",p),BW_NS,1,1);
    if(mode=="self_cycle")begin
      define_group("A",1);owner("A");add_group_member("A","A");
    end else if(mode=="cycle")begin
      define_group("A",1);define_group("B",1);define_group("C",1);
      owner("A");owner("B");owner("C");
      add_group_member("A","B");add_group_member("B","C");add_group_member("C","A");
    end else if(mode=="missing_group")begin
      define_group("root",1);owner("root");add_group_member("root","p0");
    end else if(mode=="missing_point")begin
      define_group("root",1);define_group("child",1);owner("root");owner("child");
      add_point_member("child","p0");add_point_member("root","child");
    end else if(mode=="group_prefix" || mode=="unknown_kind" || mode=="invalid_kind" || mode=="hot_group")begin
      define_group("root",1);owner("root");
      if(mode=="group_prefix")add_member("root",BW_GROUP,"p0",BW_PREFIX);
      else if(mode=="unknown_kind")add_member("root",2'bxx,"p0");
      else if(mode=="invalid_kind")add_member("root",2'b10,"p0");
      else add_point_member("root","p0");
    end else if(mode=="depth8" || mode=="depth9")begin
      // Parent-first declarations force resolution independent of initial order.
      for(int g=levels-1;g>=0;g--)begin id=$sformatf("g%0d",g);define_group(id,1);owner(id);end
      add_point_member("g0","p0");
      for(int g=1;g<levels;g++)add_group_member($sformatf("g%0d",g),$sformatf("g%0d",g-1));
    end else if(mode=="fanout16" || mode=="fanout17")begin
      for(int g=0;g<parents;g++)begin
        id=$sformatf("g%0d",g);define_group(id,1);owner(id);add_point_member(id,"p0");
      end
    end else begin
      define_group("top",2);define_group("left",1);define_group("right",1);
      owner("top");owner("left");owner("right");
      add_group_member("top","left");
      if(mode=="point_overlap" || mode=="overlap32" || mode=="overlap64")begin
        add_point_member("left",$sformatf("p%0d",target));
        add_point_member("right",$sformatf("p%0d",target));
        add_point_member("top",$sformatf("p%0d",target));
      end else if(mode=="siblings")begin
        add_point_member("left","p0");add_point_member("right","p0");add_group_member("top","right");
      end else if(mode=="diamond")begin
        define_group("base",1);owner("base");add_point_member("base","p0");
        add_group_member("left","base");add_group_member("right","base");add_group_member("top","right");
      end else $fatal(1,"unknown MODE %s",mode);
    end
    finish_configuration();wait(monitor_ready);
    if(mode=="depth8")begin
      if(group_recursive_point_count(group_handle_for_id("g7"))!=1 || group_member_count(group_handle_for_id("g7"))!=1)
        $fatal(1,"depth-eight recursive/direct counts differ");
    end else if(mode=="fanout16")begin
      for(int g=0;g<16;g++)if(group_member_count(group_handle_for_id($sformatf("g%0d",g)))!=1)$fatal(1,"fanout route missing");
    end else if(mode=="hot_group")add_group_member("root","root");
    else $fatal(1,"expected core error did not occur");
    $display("TB_PASS hierarchy_config %s",mode);$finish;
  end
endmodule
