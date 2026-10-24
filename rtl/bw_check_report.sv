package bw_check_report_pkg;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;

  class bw_check_report extends bw_report_sink;
    typedef struct {
      bw_scope_t kind;
      string id;
      bit done,saw_episode,have_seq;
      bw_u64_t last_seq;
      bit has_min,has_max,has_abs,has_rel,disabled;
      real minimum,maximum,absolute,relative,effective_min,effective_max;
      int min_line,max_line,abs_line,rel_line;
    } scope_state_t;
    local scope_state_t scopes[$];
    local int scope_by_id[string];
    local bw_report_summary_t totals;
    local string cfg_file;
    local bit configured;

    function new();
      totals='0;
    endfunction

    function automatic string uncomment(string value);
      bit quoted,escaped;
      quoted=0;escaped=0;
      for(int i=0;i<value.len();i++) begin
        if(quoted && escaped) begin escaped=0;continue;end
        if(quoted && value[i]==8'd92) begin escaped=1;continue;end
        if(value[i]==8'd34) quoted=!quoted;
        if(value[i]==8'd35 && !quoted) begin
          if(i==0) return "";
          return value.substr(0,i-1);
        end
      end
      return value;
    endfunction

    function automatic bit decode_id(string token,output string id);
      int pos;
      id="";
      if(token.len()==0) return 0;
      if(token[0]!=8'd34) begin
        for(int i=0;i<token.len();i++) if(token[i]==8'd34) return 0;
        id=token;return 1;
      end
      if(token.len()<3 || token[token.len()-1]!=8'd34) return 0;
      pos=1;
      while(pos<token.len()-1) begin
        if(token[pos]==8'd34) return 0;
        if(token[pos]==8'd92) begin
          pos++;
          if(pos>=token.len()-1) return 0;
          case(token[pos])
            8'd34,8'd92:id={id,token[pos]};
            8'd110:id={id,string'(8'd10)};
            8'd114:id={id,string'(8'd13)};
            8'd116:id={id,string'(8'd9)};
            default:return 0;
          endcase
        end else id={id,token[pos]};
        pos++;
      end
      return id.len()!=0;
    endfunction

    function automatic bit e2e_key(string key);
      return key inside {"e2e_bw_min_gbps","e2e_bw_max_gbps","e2e_bw_abs_tol_gbps","e2e_bw_rel_tol_pct"};
    endfunction

    function automatic string trim(string value);
      int first,last;
      first=0;last=value.len()-1;
      while(first<=last && value[first] inside {8'd9,8'd10,8'd13,8'd32}) first++;
      while(last>=first && value[last] inside {8'd9,8'd10,8'd13,8'd32}) last--;
      if(first>last) return "";
      return value.substr(first,last);
    endfunction

    function automatic int find_scope(bw_scope_t kind,string id);
      string key;
      key={kind==BW_POINT ? "point:" : "group:",id};
      if(scope_by_id.exists(key)) return scope_by_id[key];
      return -1;
    endfunction

    function automatic bit finite_real(real value);
      bit [63:0] representation;
      representation=$realtobits(value);
      return representation[62:52]!=11'h7ff;
    endfunction

    // VCS %f accepts prefixes and clamps overflowing decimals to DBL_MAX.
    // Validate the complete decimal and its exact range before conversion.
    function automatic bit parse_number(string token,output real value);
      string digits,significant,maximum;
      int pos,before_decimal,first_nonzero,limit;
      bit has_digit,negative_exponent;
      longint decimal_order,exponent_magnitude,exponent_limit;
      value=0;pos=0;digits="";before_decimal=0;
      first_nonzero=-1;exponent_magnitude=0;negative_exponent=0;has_digit=0;
      exponent_limit=longint'(token.len())+400;
      if(token.len()==0) return 0;
      if(token[pos]==8'd43) pos++;
      while(pos<token.len() && token[pos]>=8'd48 && token[pos]<=8'd57) begin
        digits={digits,token[pos]};before_decimal++;has_digit=1;pos++;
      end
      if(pos<token.len() && token[pos]==8'd46) begin
        pos++;
        while(pos<token.len() && token[pos]>=8'd48 && token[pos]<=8'd57) begin
          digits={digits,token[pos]};has_digit=1;pos++;
        end
      end
      if(!has_digit) return 0;
      if(pos<token.len() && token[pos] inside {8'd69,8'd101}) begin
        pos++;
        if(pos<token.len() && token[pos] inside {8'd43,8'd45}) begin
          negative_exponent=token[pos]==8'd45;pos++;
        end
        if(pos==token.len()) return 0;
        has_digit=0;
        while(pos<token.len() && token[pos]>=8'd48 && token[pos]<=8'd57) begin
          if(exponent_magnitude<exponent_limit) begin
            exponent_magnitude=exponent_magnitude*10+int'(token[pos])-48;
            if(exponent_magnitude>exponent_limit) exponent_magnitude=exponent_limit;
          end
          has_digit=1;pos++;
        end
        if(!has_digit) return 0;
      end
      if(pos!=token.len()) return 0;
      for(int i=0;i<digits.len();i++) if(digits[i]!=8'd48) begin first_nonzero=i;break;end
      // Zero remains exactly zero even with an exponent too large for %f.
      if(first_nonzero<0) return 1;
      decimal_order=longint'(before_decimal)-longint'(first_nonzero)-1+
        (negative_exponent ? -longint'(exponent_magnitude) : longint'(exponent_magnitude));
      if(decimal_order>308 || decimal_order< -324) return 0;
      if(decimal_order==308) begin
        maximum="179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368";
        significant=digits.substr(first_nonzero,digits.len()-1);
        limit=significant.len()>maximum.len() ? significant.len() : maximum.len();
        for(int i=0;i<limit;i++) begin
          byte actual_digit,max_digit;
          actual_digit=i<significant.len() ? significant[i] : 8'd48;
          max_digit=i<maximum.len() ? maximum[i] : 8'd48;
          if(actual_digit>max_digit) return 0;
          if(actual_digit<max_digit) break;
        end
      end
      if($sscanf(token,"%f",value)!=1 || !finite_real(value) || value==0 || value<0) return 0;
      return 1;
    endfunction

    function automatic void cfg_warning(int line,string id,string key,string reason,string kind="point");
      if(core_failure_seen) return;
      totals.warning_count=checked_add(totals.warning_count,1,"report warnings");
      if(core_failure_seen) return;
      $display("BW_CFG WARNING file=%s line=%0d scope=%s key=%s reason=%s scope_kind=%s",
        cfg_file,line,id,key,reason,kind);
    endfunction

    function automatic bit expand_bound(real bound,real absolute,real relative,
                                        bit lower,output real effective);
      real term,tolerance,scaled;
      scaled=relative/100.0;
      if(relative!=0 && scaled==0) term=(bound/100.0)*relative;
      else term=bound*scaled;
      if(!finite_real(term)) return 0;
      tolerance=absolute+term;
      if(!finite_real(tolerance)) return 0;
      effective=lower ? bound-tolerance : bound+tolerance;
      return finite_real(effective);
    endfunction

    virtual function void on_ready();
      scope_state_t entry;
      int fd,line_no,current,split,read_error;
      string line,body,kind,id,key,token,section_id,section_kind,io_detail;
      bit duplicate,invalid_id;
      real number;
      for(int k=0;k<2;k++) begin
        for(int i=0;i<registered_scope_count(bw_scope_t'(k));i++) begin
          entry.kind=bw_scope_t'(k);entry.id=registered_scope_id(entry.kind,i);
          entry.done=0;entry.saw_episode=0;entry.have_seq=0;entry.last_seq=0;
          entry.has_min=0;entry.has_max=0;entry.has_abs=0;entry.has_rel=0;entry.disabled=0;
          entry.minimum=0;entry.maximum=0;entry.absolute=0;entry.relative=0;
          entry.effective_min=0;entry.effective_max=0;
          entry.min_line=0;entry.max_line=0;entry.abs_line=0;entry.rel_line=0;
          check_queue_growth(scopes.size(),"report scopes");
          scope_by_id[{entry.kind==BW_POINT ? "point:" : "group:",entry.id}]=scopes.size();
          scopes.push_back(entry);
        end
      end
      totals.scopes_expected=scopes.size();
      configured=$value$plusargs("BW_EXPECT=%s",cfg_file);
      if(!configured) begin
        if($test$plusargs("BW_EXPECT")) begin
          configured=1;cfg_file="<missing>";cfg_warning(0,"-","-","FILE_PATH_REQUIRED","-");
        end
        return;
      end
      fd=$fopen(cfg_file,"r");
      if(!fd) begin cfg_warning(0,"-","-","FILE_UNREADABLE","-");return;end
      current=-1;line_no=0;section_id="-";section_kind="-";
      while($fgets(line,fd)) begin
        if(line_no==32'sh7fffffff) begin
          core_error("STORAGE_RANGE","expect cfg","line number cannot be represented");break;
        end
        line_no++;check_queue_growth(line.len(),"expect cfg line");
        line=trim(uncomment(line));
        if(line.len()==0) continue;
        if(line[0]==8'd91) begin
          current=-1;section_id="-";section_kind="-";
          if(line[line.len()-1]!=8'd93 || line.len()<4) begin
            cfg_warning(line_no,"-","-","MALFORMED_HEADER","-");continue;
          end
          body=trim(line.substr(1,line.len()-2));split=-1;
          for(int i=0;i<body.len();i++) if(body[i] inside {8'd9,8'd32}) begin split=i;break;end
          if(split<1) begin cfg_warning(line_no,"-","-","MALFORMED_HEADER","-");continue;end
          kind=body.substr(0,split-1);token=trim(body.substr(split+1,body.len()-1));
          invalid_id=!decode_id(token,id);
          if(invalid_id) begin cfg_warning(line_no,id,"-","MALFORMED_HEADER",kind);continue;end
          section_id=id;section_kind=kind;
          if(kind!="point") begin cfg_warning(line_no,id,"-","UNSUPPORTED_SCOPE",kind);continue;end
          current=find_scope(BW_POINT,id);
          if(current<0) cfg_warning(line_no,id,"-","UNREGISTERED_SCOPE");
          continue;
        end
        split=-1;
        for(int i=0;i<line.len();i++) if(line[i]==8'd61) begin split=i;break;end
        if(split<1) begin
          cfg_warning(line_no,section_id,line,"EXPECTED_KEY_VALUE",section_kind);
          if(current>=0 && e2e_key(line)) scopes[current].disabled=1;
          continue;
        end
        key=trim(line.substr(0,split-1));
        token=split==line.len()-1 ? "" : trim(line.substr(split+1,line.len()-1));
        if(current<0) begin cfg_warning(line_no,section_id,key,"NO_VALID_SECTION",section_kind);continue;end
        if(!e2e_key(key)) begin
          cfg_warning(line_no,scopes[current].id,key,"UNKNOWN_KEY");continue;
        end
        duplicate=0;
        case(key)
          "e2e_bw_min_gbps":begin
            duplicate=scopes[current].has_min;scopes[current].has_min=1;scopes[current].min_line=line_no;
          end
          "e2e_bw_max_gbps":begin
            duplicate=scopes[current].has_max;scopes[current].has_max=1;scopes[current].max_line=line_no;
          end
          "e2e_bw_abs_tol_gbps":begin
            duplicate=scopes[current].has_abs;scopes[current].has_abs=1;scopes[current].abs_line=line_no;
          end
          "e2e_bw_rel_tol_pct":begin
            duplicate=scopes[current].has_rel;scopes[current].has_rel=1;scopes[current].rel_line=line_no;
          end
        endcase
        if(duplicate) begin
          cfg_warning(line_no,scopes[current].id,key,"DUPLICATE_KEY");scopes[current].disabled=1;continue;
        end
        if(!parse_number(token,number)) begin
          cfg_warning(line_no,scopes[current].id,key,"INVALID_NUMBER");
          scopes[current].disabled=1;continue;
        end
        case(key)
          "e2e_bw_min_gbps":scopes[current].minimum=number;
          "e2e_bw_max_gbps":scopes[current].maximum=number;
          "e2e_bw_abs_tol_gbps":scopes[current].absolute=number;
          "e2e_bw_rel_tol_pct":scopes[current].relative=number;
        endcase
      end
      read_error=$ferror(fd,io_detail);
      $fclose(fd);
      if(read_error) begin
        cfg_warning(line_no,"-","-","FILE_READ_ERROR","-");
        foreach(scopes[i]) scopes[i].disabled=1;
        return;
      end
      foreach(scopes[i]) begin
        real effective;
        int location;
        if(scopes[i].disabled) continue;
        if(scopes[i].has_min) location=scopes[i].min_line;
        else if(scopes[i].has_max) location=scopes[i].max_line;
        else if(scopes[i].has_abs) location=scopes[i].abs_line;
        else location=scopes[i].rel_line;
        if(!(scopes[i].has_min || scopes[i].has_max)) begin
          if(scopes[i].has_abs || scopes[i].has_rel) begin
            cfg_warning(location,scopes[i].id,"e2e_bw","BOUND_REQUIRED");scopes[i].disabled=1;
          end
          continue;
        end
        if(scopes[i].has_min && scopes[i].has_max && scopes[i].minimum>scopes[i].maximum) begin
          cfg_warning(scopes[i].max_line,scopes[i].id,"e2e_bw","CONFLICTING_BOUNDS");
          scopes[i].disabled=1;continue;
        end
        if(scopes[i].has_min) begin
          if(!expand_bound(scopes[i].minimum,scopes[i].absolute,scopes[i].relative,1,effective)) begin
            cfg_warning(location,scopes[i].id,"e2e_bw","TOLERANCE_OVERFLOW");scopes[i].disabled=1;
          end else scopes[i].effective_min=effective;
        end
        if(scopes[i].has_max && !scopes[i].disabled) begin
          if(!expand_bound(scopes[i].maximum,scopes[i].absolute,scopes[i].relative,0,effective)) begin
            cfg_warning(location,scopes[i].id,"e2e_bw","TOLERANCE_OVERFLOW");scopes[i].disabled=1;
          end else scopes[i].effective_max=effective;
        end
      end
    endfunction

    virtual function bw_report_summary_t summary();
      bw_report_summary_t value;
      value=totals;
      if(value.fail_count!=0) value.status=BW_REPORT_FAIL;
      else if(value.warning_count!=0) value.status=BW_REPORT_WARNING;
      else if(value.pass_count!=0) value.status=BW_REPORT_PASS;
      else value.status=BW_REPORT_STATISTICS_ONLY;
      return value;
    endfunction

    function automatic string e2e_evidence_reason(bw_episode_result_t result);
      if(result.status===BW_EPISODE_RESET_INTERRUPTED) return "RESET_INTERRUPTED";
      if(result.status===BW_EPISODE_TRUNCATED) return "OBSERVATION_TRUNCATED";
      if(result.status!==BW_EPISODE_COMPLETE) return "EPISODE_NOT_COMPLETE";
      if(!result.first_known) return "FIRST_BOUNDARY_UNKNOWN";
      if(!result.last_known) return "LAST_BOUNDARY_UNKNOWN";
      if(!result.tail_known) return "TAIL_CYCLE_UNKNOWN";
      if(!result.bytes_complete) return "BYTES_INCOMPLETE";
      if(!result.duration_valid || result.duration_ticks==0) return "DURATION_UNAVAILABLE";
      if(!result.e2e_valid) return "E2E_UNAVAILABLE";
      if(!finite_real(result.e2e_gbps)) return "ACTUAL_NONFINITE";
      if(result.e2e_gbps<0) return "ACTUAL_NEGATIVE";
      return "NONE";
    endfunction

    virtual function void submit_episode(string scope_id,bw_episode_result_t result);
      int index;
      string conclusion,reason,actual;
      if(core_failure_seen || totals.finalized) return;
      if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
      index=find_scope(result.scope_kind,scope_id);
      if(index<0) return;
      if(scopes[index].have_seq && result.result_seq<=scopes[index].last_seq) return;
      scopes[index].have_seq=1;scopes[index].last_seq=result.result_seq;
      scopes[index].saw_episode=1;
      if(!(scopes[index].has_min || scopes[index].has_max) || scopes[index].disabled) return;
      reason=e2e_evidence_reason(result);
      actual=reason=="NONE" ? $sformatf("%.17g",result.e2e_gbps) : "UNAVAILABLE";
      if(reason!="NONE") begin
        conclusion="WARNING";totals.warning_count=checked_add(totals.warning_count,1,scope_id);
      end else if((scopes[index].has_min && result.e2e_gbps<scopes[index].effective_min) ||
                  (scopes[index].has_max && result.e2e_gbps>scopes[index].effective_max)) begin
        conclusion="FAIL";totals.fail_count=checked_add(totals.fail_count,1,scope_id);
      end else begin
        conclusion="PASS";totals.pass_count=checked_add(totals.pass_count,1,scope_id);
      end
      if(core_failure_seen) return;
      $display("BW_CHECK scope_kind=%0d scope=%s epoch=%0d episode=%0d result_seq=%0d kind=episode phase=0 metric=e2e_bw unit=GB/s start_ticks=%0d end_ticks=%0d actual=%s has_min=%0b min=%.17g has_max=%0b max=%.17g abs_tol=%.17g rel_tol_pct=%.17g effective_min=%.17g effective_max=%.17g bytes=%0d events=%0d duration_ticks=%0d bytes_complete=%0b events_complete=%0b first_known=%0b last_known=%0b tail_known=%0b duration_valid=%0b member_reset=%0b cfg_file=%s min_line=%0d max_line=%0d abs_line=%0d rel_line=%0d conclusion=%s reason=%s",
        result.scope_kind,scope_id,result.stats_epoch,result.episode_id,result.result_seq,
        result.first_ticks,result.tail_ticks,actual,scopes[index].has_min,scopes[index].minimum,
        scopes[index].has_max,scopes[index].maximum,scopes[index].absolute,
        scopes[index].relative,scopes[index].effective_min,scopes[index].effective_max,
        result.byte_count,result.event_count,result.duration_ticks,result.bytes_complete,result.events_complete,
        result.first_known,result.last_known,result.tail_known,result.duration_valid,result.member_reset_coverage,
        cfg_file,scopes[index].min_line,scopes[index].max_line,scopes[index].abs_line,scopes[index].rel_line,
        conclusion,reason);
    endfunction

    virtual function void scope_done(bw_scope_t kind,string scope_id,bw_u64_t stats_epoch);
      int index;
      bw_report_summary_t value;
      string status;
      if(core_failure_seen || totals.finalized) return;
      if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
      index=find_scope(kind,scope_id);
      // Normalized component fixtures can contain unregistered analysis cores.
      if(index<0 || scopes[index].done) return;
      if((scopes[index].has_min || scopes[index].has_max) && !scopes[index].disabled && !scopes[index].saw_episode) begin
        totals.warning_count=checked_add(totals.warning_count,1,scope_id);
        if(core_failure_seen) return;
        $display("BW_CHECK scope_kind=%0d scope=%s epoch=%0d episode=0 result_seq=0 kind=scope_final phase=0 metric=e2e_bw unit=GB/s start_known=0 end_known=0 observation_end_ticks=%0d actual=UNAVAILABLE has_min=%0b min=%.17g has_max=%0b max=%.17g abs_tol=%.17g rel_tol_pct=%.17g effective_min=%.17g effective_max=%.17g cfg_file=%s min_line=%0d max_line=%0d abs_line=%0d rel_line=%0d conclusion=WARNING reason=NO_EPISODE",
          kind,scope_id,stats_epoch,$time,scopes[index].has_min,scopes[index].minimum,
          scopes[index].has_max,scopes[index].maximum,scopes[index].absolute,
          scopes[index].relative,scopes[index].effective_min,scopes[index].effective_max,
          cfg_file,scopes[index].min_line,scopes[index].max_line,scopes[index].abs_line,scopes[index].rel_line);
      end
      scopes[index].done=1;totals.scopes_done=checked_add(totals.scopes_done,1,scope_id);
      if(core_failure_seen || totals.scopes_done!=totals.scopes_expected) return;
      totals.finalized=1;value=summary();
      case(value.status)
        BW_REPORT_FAIL:status="FAIL";
        BW_REPORT_WARNING:status="WARNING";
        BW_REPORT_PASS:status="PASS";
        default:status="STATISTICS_ONLY";
      endcase
      $display("BW_SUMMARY status=%s pass=%0d fail=%0d warning=%0d scopes_done=%0d scopes_expected=%0d",
        status,value.pass_count,value.fail_count,value.warning_count,value.scopes_done,value.scopes_expected);
    endfunction
  endclass
endpackage
