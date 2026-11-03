package bw_check_report_pkg;
  timeunit 1fs; timeprecision 1fs;
  import bw_mon_pkg::*;

  typedef struct {
    bw_check_window_t first,last;
    bw_u64_t count;
  } default_run_t;
  typedef struct packed {
    bw_u64_t epoch,episode,platform;
  } default_identity_t;
  `include "bw_stage_ownership.svh"
  class bw_default_scope extends bw_stage_evidence;
    bit enabled=0,have_seq=0;
    // Bounded terminal trust: only the audit-authorized ending settlement of
    // a disabled owner computes counts from frozen verified evidence.
    bit terminal_trust=0;
    bw_u64_t last_seq;
    // Core final streams are synchronous and ordered by logical epoch/episode,
    // then immutable platform ID. Durable logical watermarks survive raw release;
    // delivery counters never stand in for identity and cannot poison a new ID.
    bit have_episode_identity=0,have_phase_identity=0,have_default_identity=0;
    default_identity_t episode_identity,phase_identity,default_identity;
  endclass

  class bw_check_report extends bw_report_sink;
    localparam int E2E_BW=0,STEADY_BW=1,RAMP_TIME=2,FALL_TIME=3,
      STEADY_WINDOW_MIN=4,STEADY_WINDOW_MAX=5,STEADY_STDDEV=6,STEADY_CV=7,
      EPISODE_WINDOW_MIN=8,EPISODE_WINDOW_MAX=9,EPISODE_STDDEV=10,EPISODE_CV=11,
      METRIC_COUNT=12;
    typedef struct {
      bw_scope_t kind;
      string id;
      bit done,saw_episode,have_seq,have_phase_seq;
      bw_u64_t last_seq,last_phase_seq,time_epoch,time_episode;
      bit saw_ramp,saw_fall,ever_ramp,ever_fall;
    } scope_state_t;
    typedef struct {
      bit has_min,has_max,has_abs,has_rel,disabled;
      real minimum,maximum,absolute,relative,effective_min,effective_max;
      int min_line,max_line,abs_line,rel_line;
    } metric_rule_t;
    typedef struct {
      bw_scope_t scope_kind;
      bw_u64_t stats_epoch,episode_id,phase_id,result_seq,phase_result_seq;
      bw_phase_t phase_kind;
      bw_u64_t start_ticks,end_ticks,byte_count,event_count,duration_ticks;
      bit start_known,last_known,end_known,bytes_complete,events_complete,duration_valid,member_reset;
      bw_variation_result_t variation;
    } check_context_t;
    local scope_state_t scopes[$];
    local bw_default_scope default_scopes[$];
    `include "bw_default_check.svh"
    local metric_rule_t rules[$];
    local int scope_by_id[string];
    local bw_report_summary_t totals;
    local string cfg_file;
    local bit configured;

    function new();
      totals='0;
    endfunction

    function automatic string metric_name(int metric);
      case(metric)
        E2E_BW:return "e2e_bw";
        STEADY_BW:return "steady_bw";
        RAMP_TIME:return "ramp_time";
        FALL_TIME:return "fall_time";
        STEADY_WINDOW_MIN:return "steady_window_min";
        STEADY_WINDOW_MAX:return "steady_window_max";
        STEADY_STDDEV:return "steady_stddev";
        STEADY_CV:return "steady_cv";
        EPISODE_WINDOW_MIN:return "episode_window_min";
        EPISODE_WINDOW_MAX:return "episode_window_max";
        EPISODE_STDDEV:return "episode_stddev";
        default:return "episode_cv";
      endcase
    endfunction

    function automatic string metric_unit_key(int metric);
      if(metric inside {RAMP_TIME,FALL_TIME}) return "ns";
      if(metric inside {STEADY_CV,EPISODE_CV}) return "pct";
      return "gbps";
    endfunction

    function automatic string metric_unit(int metric);
      if(metric inside {RAMP_TIME,FALL_TIME}) return "ns";
      if(metric inside {STEADY_CV,EPISODE_CV}) return "%";
      return "GB/s";
    endfunction

    function automatic bit decode_key(string key,output int metric,output int part);
      string name,unit_key;
      metric=-1;part=-1;
      for(int m=0;m<METRIC_COUNT;m++) begin
        name=metric_name(m);unit_key=metric_unit_key(m);
        if(key=={name,"_min_",unit_key}) part=0;
        else if(key=={name,"_max_",unit_key}) part=1;
        else if(key=={name,"_abs_tol_",unit_key}) part=2;
        else if(key=={name,"_rel_tol_pct"}) part=3;
        if(part>=0) begin metric=m;return 1;end
      end
      return 0;
    endfunction

    function automatic bit enabled_rule(int index,int metric);
      int rule;
      rule=index*METRIC_COUNT+metric;
      return !rules[rule].disabled && (rules[rule].has_min || rules[rule].has_max);
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
      check_storage_growth(token.len(),"report","report.token",$time);
      if(core_failure_seen)return 0;
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
      bw_default_scope default_scope;
      metric_rule_t empty_rule;
      int fd,line_no,current,split,read_error,metric,part,rule;
      string line,body,kind,id,key,token,section_id,section_kind,io_detail,argument_suffix;
      bit duplicate,invalid_id,has_argument_suffix;
      real number;
      empty_rule='{default:0};
      for(int k=0;k<2;k++) begin
        for(int i=0;i<registered_scope_count(bw_scope_t'(k));i++) begin
          entry.kind=bw_scope_t'(k);entry.id=registered_scope_id(entry.kind,i);
          entry.done=0;entry.saw_episode=0;entry.have_seq=0;entry.last_seq=0;
          entry.have_phase_seq=0;entry.last_phase_seq=0;
          entry.time_epoch=0;entry.time_episode=0;entry.saw_ramp=0;entry.saw_fall=0;
          entry.ever_ramp=0;entry.ever_fall=0;
          check_storage_growth(scopes.size(),entry.id,"report.scopes",$time);
          if(core_failure_seen)return;
          scope_by_id[{entry.kind==BW_POINT ? "point:" : "group:",entry.id}]=scopes.size();
          scopes.push_back(entry);
          default_scope=new();
          key=scope_key(entry.kind,entry.id);
          if(check_analysis.exists(key))begin
            default_scope.enabled=check_analysis[key].enabled;default_scope.basis=check_analysis[key].basis;
            default_scope.width=check_analysis[key].width;default_scope.stride=check_analysis[key].stride;
          end
          default_scopes.push_back(default_scope);
          for(int m=0;m<METRIC_COUNT;m++) begin
            check_storage_growth(rules.size(),entry.id,"report.rules",$time);
            if(core_failure_seen)return;
            rules.push_back(empty_rule);
          end
        end
      end
      totals.scopes_expected=scopes.size();
      configured=$value$plusargs("BW_EXPECT=%s",cfg_file);
      // An empty %s is a successful match in VCS, but $fopen("") is a
      // simulator runtime error rather than a recoverable cfg warning.
      if(configured && cfg_file.len()==0) begin
        cfg_file="<missing>";cfg_warning(0,"-","-","FILE_PATH_REQUIRED","-");return;
      end
      if(!configured) begin
        // $test$plusargs alone also matches unrelated BW_EXPECTED-style flags.
        has_argument_suffix=$value$plusargs("BW_EXPECT%s",argument_suffix);
        if($test$plusargs("BW_EXPECT=") ||
           ($test$plusargs("BW_EXPECT") && (!has_argument_suffix || argument_suffix.len()==0))) begin
          configured=1;cfg_file="<missing>";cfg_warning(0,"-","-","FILE_PATH_REQUIRED","-");
        end
        return;
      end
      fd=$fopen(cfg_file,"r");
      if(!fd) begin cfg_warning(0,"-","-","FILE_UNREADABLE","-");return;end
      current=-1;line_no=0;section_id="-";section_kind="-";
      forever begin
        check_storage_growth(line.len(),"report","report.cfg-line",$time);
        if(core_failure_seen)return;
        if(!$fgets(line,fd))break;
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
          if(!(kind inside {"point","group"})) begin cfg_warning(line_no,id,"-","UNSUPPORTED_SCOPE",kind);continue;end
          current=find_scope(kind=="point" ? BW_POINT : BW_GROUP,id);
          if(current<0) cfg_warning(line_no,id,"-","UNREGISTERED_SCOPE",kind);
          continue;
        end
        split=-1;
        for(int i=0;i<line.len();i++) if(line[i]==8'd61) begin split=i;break;end
        if(split<1) begin
          cfg_warning(line_no,section_id,line,"EXPECTED_KEY_VALUE",section_kind);
          if(current>=0 && decode_key(line,metric,part)) rules[current*METRIC_COUNT+metric].disabled=1;
          continue;
        end
        key=trim(line.substr(0,split-1));
        token=split==line.len()-1 ? "" : trim(line.substr(split+1,line.len()-1));
        if(current<0) begin cfg_warning(line_no,section_id,key,"NO_VALID_SECTION",section_kind);continue;end
        if(!decode_key(key,metric,part)) begin
          cfg_warning(line_no,scopes[current].id,key,"UNKNOWN_KEY",section_kind);continue;
        end
        rule=current*METRIC_COUNT+metric;duplicate=0;
        case(part)
          0:begin duplicate=rules[rule].has_min;rules[rule].has_min=1;rules[rule].min_line=line_no;end
          1:begin duplicate=rules[rule].has_max;rules[rule].has_max=1;rules[rule].max_line=line_no;end
          2:begin duplicate=rules[rule].has_abs;rules[rule].has_abs=1;rules[rule].abs_line=line_no;end
          3:begin duplicate=rules[rule].has_rel;rules[rule].has_rel=1;rules[rule].rel_line=line_no;end
        endcase
        if(duplicate) begin
          cfg_warning(line_no,scopes[current].id,key,"DUPLICATE_KEY",section_kind);
          rules[rule].disabled=1;continue;
        end
        if(!parse_number(token,number)) begin
          cfg_warning(line_no,scopes[current].id,key,"INVALID_NUMBER",section_kind);
          rules[rule].disabled=1;continue;
        end
        case(part)
          0:rules[rule].minimum=number;
          1:rules[rule].maximum=number;
          2:rules[rule].absolute=number;
          3:rules[rule].relative=number;
        endcase
      end
      read_error=$ferror(fd,io_detail);$fclose(fd);
      if(read_error) begin
        cfg_warning(line_no,"-","-","FILE_READ_ERROR","-");
        foreach(rules[r]) rules[r].disabled=1;
        return;
      end
      foreach(scopes[i]) begin
        for(int m=0;m<METRIC_COUNT;m++) begin
          real effective;
          int location;
          rule=i*METRIC_COUNT+m;kind=scopes[i].kind==BW_POINT ? "point" : "group";
          if(rules[rule].disabled) continue;
          if(rules[rule].has_min) location=rules[rule].min_line;
          else if(rules[rule].has_max) location=rules[rule].max_line;
          else if(rules[rule].has_abs) location=rules[rule].abs_line;
          else location=rules[rule].rel_line;
          if(!(rules[rule].has_min || rules[rule].has_max)) begin
            if(rules[rule].has_abs || rules[rule].has_rel) begin
              cfg_warning(location,scopes[i].id,metric_name(m),"BOUND_REQUIRED",kind);rules[rule].disabled=1;
            end
            continue;
          end
          if(rules[rule].has_min && rules[rule].has_max && rules[rule].minimum>rules[rule].maximum) begin
            cfg_warning(rules[rule].max_line,scopes[i].id,metric_name(m),"CONFLICTING_BOUNDS",kind);
            rules[rule].disabled=1;continue;
          end
          if(rules[rule].has_min) begin
            if(!expand_bound(rules[rule].minimum,rules[rule].absolute,rules[rule].relative,1,effective)) begin
              cfg_warning(location,scopes[i].id,metric_name(m),"TOLERANCE_OVERFLOW",kind);rules[rule].disabled=1;
            end else rules[rule].effective_min=effective;
          end
          if(rules[rule].has_max && !rules[rule].disabled) begin
            if(!expand_bound(rules[rule].maximum,rules[rule].absolute,rules[rule].relative,0,effective)) begin
              cfg_warning(location,scopes[i].id,metric_name(m),"TOLERANCE_OVERFLOW",kind);rules[rule].disabled=1;
            end else rules[rule].effective_max=effective;
          end
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
      if(!result.duration_valid || result.duration_ticks==0 || result.tail_ticks<=result.first_ticks ||
         result.duration_ticks!=result.tail_ticks-result.first_ticks) return "DURATION_UNAVAILABLE";
      if(!result.e2e_valid) return "E2E_UNAVAILABLE";
      if(!finite_real(result.e2e_gbps)) return "ACTUAL_NONFINITE";
      if(result.e2e_gbps<0) return "ACTUAL_NEGATIVE";
      return "NONE";
    endfunction

    function automatic check_context_t episode_context(bw_episode_result_t result);
      check_context_t value;
      value.scope_kind=result.scope_kind;value.stats_epoch=result.stats_epoch;
      value.episode_id=result.episode_id;value.phase_id=0;value.phase_kind=BW_PHASE_UNDETERMINED;
      value.result_seq=result.result_seq;value.phase_result_seq=0;
      value.start_ticks=result.first_ticks;value.end_ticks=result.tail_ticks;
      value.byte_count=result.byte_count;value.event_count=result.event_count;value.duration_ticks=result.duration_ticks;
      value.start_known=result.first_known;value.last_known=result.last_known;value.end_known=result.tail_known;
      value.bytes_complete=result.bytes_complete;value.events_complete=result.events_complete;
      value.duration_valid=result.duration_valid;value.member_reset=result.member_reset_coverage;
      value.variation=result.variation;return value;
    endfunction

    function automatic check_context_t phase_context(bw_phase_result_t result);
      check_context_t value;
      value.scope_kind=result.scope_kind;value.stats_epoch=result.stats_epoch;
      value.episode_id=result.episode_id;value.phase_id=result.phase_id;value.phase_kind=result.phase_kind;
      value.result_seq=result.result_seq;value.phase_result_seq=result.result_seq;
      value.start_ticks=result.start_ticks;value.end_ticks=result.end_ticks;
      value.byte_count=result.byte_count;value.event_count=result.event_count;value.duration_ticks=result.duration_ticks;
      value.start_known=result.start_known;value.last_known=result.end_known;value.end_known=result.end_known;
      value.bytes_complete=result.bytes_complete;value.events_complete=result.events_complete;
      value.duration_valid=result.duration_valid;value.member_reset=result.member_reset_coverage;
      value.variation=result.variation;return value;
    endfunction

    // One configured metric, one conclusion. Backing numbers are read only
    // after the caller established that metric's own evidence.
    function automatic void settle(int index,int metric,check_context_t context_value,
        string record_kind,real measured,string evidence_reason,bit final_settlement=0);
      int r;
      string conclusion,reason,actual;
      if(scope_failed(context_value.scope_kind,scopes[index].id) || (final_settlement && core_failure_pending()))return;
      if(!enabled_rule(index,metric)) return;
      r=index*METRIC_COUNT+metric;reason=evidence_reason;
      if(reason=="NONE" && !finite_real(measured)) reason="ACTUAL_NONFINITE";
      if(reason=="NONE" && measured<0) reason="ACTUAL_NEGATIVE";
      actual=reason=="NONE" ? $sformatf("%.17g",measured) : "UNAVAILABLE";
      if(reason!="NONE") begin
        conclusion="WARNING";totals.warning_count=checked_add(totals.warning_count,1,scopes[index].id);
      end else if((rules[r].has_min && measured<rules[r].effective_min) ||
                  (rules[r].has_max && measured>rules[r].effective_max)) begin
        conclusion="FAIL";totals.fail_count=checked_add(totals.fail_count,1,scopes[index].id);
      end else begin
        conclusion="PASS";totals.pass_count=checked_add(totals.pass_count,1,scopes[index].id);
      end
      if(scope_failed(context_value.scope_kind,scopes[index].id) || (final_settlement && core_failure_pending()))return;
      $display("BW_CHECK scope_kind=%0d scope=%s epoch=%0d episode=%0d result_seq=%0d kind=%s phase=%0d metric=%s unit=%s start_ticks=%0d end_ticks=%0d actual=%s has_min=%0b min=%.17g has_max=%0b max=%.17g abs_tol=%.17g rel_tol_pct=%.17g effective_min=%.17g effective_max=%.17g bytes=%0d events=%0d duration_ticks=%0d bytes_complete=%0b events_complete=%0b first_known=%0b last_known=%0b tail_known=%0b duration_valid=%0b member_reset=%0b phase_kind=%0d phase_result_seq=%0d basis=%0d W=%0d S=%0d samples=%0d first_sample_ticks=%0d last_sample_ticks=%0d sample_span_ticks=%0d mean_gbps=%.17g interval_known=%0b coverage_complete=%0b minmax_valid=%0b stddev_valid=%0b cv_valid=%0b minmax_reason=%s stddev_reason=%s cv_reason=%s excluded_warmup=%0d excluded_foreign=%0d unknown_samples=%0d excluded_denominator=%0d cfg_file=%s min_line=%0d max_line=%0d abs_line=%0d rel_line=%0d conclusion=%s reason=%s",
        context_value.scope_kind,scopes[index].id,context_value.stats_epoch,context_value.episode_id,
        context_value.result_seq,record_kind,context_value.phase_id,metric_name(metric),metric_unit(metric),
        context_value.start_ticks,context_value.end_ticks,actual,rules[r].has_min,rules[r].minimum,
        rules[r].has_max,rules[r].maximum,rules[r].absolute,rules[r].relative,
        rules[r].effective_min,rules[r].effective_max,context_value.byte_count,context_value.event_count,
        context_value.duration_ticks,context_value.bytes_complete,context_value.events_complete,
        context_value.start_known,context_value.last_known,context_value.end_known,
        context_value.duration_valid,context_value.member_reset,context_value.phase_kind,context_value.phase_result_seq,
        context_value.variation.window_basis,context_value.variation.window_width,context_value.variation.update_stride,
        context_value.variation.sample_count,context_value.variation.first_sample_ticks,
        context_value.variation.last_sample_ticks,context_value.variation.sample_span_ticks,
        context_value.variation.mean_gbps,context_value.variation.interval_known,context_value.variation.coverage_complete,
        context_value.variation.minmax_valid,context_value.variation.stddev_valid,context_value.variation.cv_valid,
        metric_reason_name(context_value.variation.minmax_reason),metric_reason_name(context_value.variation.stddev_reason),
        metric_reason_name(context_value.variation.cv_reason),context_value.variation.excluded_warmup,context_value.variation.excluded_foreign,
        context_value.variation.unknown_samples,context_value.variation.excluded_denominator,
        cfg_file,rules[r].min_line,rules[r].max_line,rules[r].abs_line,rules[r].rel_line,conclusion,reason);
    endfunction

    function automatic string metric_evidence_reason(bw_metric_reason_t reason);
      if($isunknown(reason)) return "METRIC_REASON_UNKNOWN";
      return metric_reason_name(reason);
    endfunction

    function automatic string duration_evidence_reason(bw_phase_result_t result);
      if(result.duration_reason!==BW_METRIC_OK) return metric_evidence_reason(result.duration_reason);
      if(!result.duration_valid) return "DURATION_UNAVAILABLE";
      if(!result.start_known || !result.end_known) return "BOUNDARY_UNKNOWN";
      if(result.end_ticks<=result.start_ticks || result.duration_ticks==0 ||
         result.duration_ticks!=result.end_ticks-result.start_ticks) return "DURATION_UNAVAILABLE";
      return "NONE";
    endfunction

    function automatic string variation_evidence_reason(bw_variation_result_t value,int metric);
      bit extrema,deviation;
      bw_metric_reason_t reason;
      extrema=metric inside {STEADY_WINDOW_MIN,STEADY_WINDOW_MAX,EPISODE_WINDOW_MIN,EPISODE_WINDOW_MAX};
      deviation=metric inside {STEADY_STDDEV,EPISODE_STDDEV};
      reason=extrema ? value.minmax_reason : (deviation ? value.stddev_reason : value.cv_reason);
      if(reason!==BW_METRIC_OK) return metric_evidence_reason(reason);
      if(!(extrema ? value.minmax_valid : (deviation ? value.stddev_valid : value.cv_valid)))
        return "VARIATION_UNAVAILABLE";
      if(!value.interval_known) return "BOUNDARY_UNKNOWN";
      if(!value.coverage_complete || value.unknown_samples!=0) return "OBSERVATION_INCOMPLETE";
      if(value.sample_count==0) return "NO_QUALIFIED_SAMPLES";
      if(!extrema && value.sample_count<2) return "TOO_FEW_SAMPLES";
      if(!extrema && !deviation) begin
        if(!finite_real(value.mean_gbps)) return "ACTUAL_NONFINITE";
        if(value.mean_gbps<=0) return "ZERO_MEAN";
      end
      return "NONE";
    endfunction

    function automatic void settle_variation(int index,check_context_t context_value,
        string record_kind,bit steady,string outer_reason="NONE");
      int first;
      real measured;
      string reason;
      first=steady ? STEADY_WINDOW_MIN : EPISODE_WINDOW_MIN;
      for(int m=first;m<first+4;m++) begin
        if(!enabled_rule(index,m)) continue;
        reason=outer_reason;
        if(reason=="NONE" && (!context_value.start_known || !context_value.end_known)) reason="BOUNDARY_UNKNOWN";
        if(reason=="NONE" && context_value.end_ticks<=context_value.start_ticks) reason="DURATION_UNAVAILABLE";
        if(reason=="NONE") reason=variation_evidence_reason(context_value.variation,m);
        measured=0;
        if(reason=="NONE") begin
          case(m-first)
            0:measured=context_value.variation.min_gbps;
            1:measured=context_value.variation.max_gbps;
            2:measured=context_value.variation.stddev_gbps;
            3:measured=context_value.variation.cv_pct;
          endcase
        end
        settle(index,m,context_value,record_kind,measured,reason);
      end
    endfunction

    virtual function void submit_phase(string scope_id,bw_phase_result_t result);
      int index,metric;
      string reason;
      real measured;
      default_identity_t identity,episode_identity;
      if(scope_failed(result.scope_kind,scope_id) || totals.finalized || result.result_seq==0)return;
      if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
      index=find_scope(result.scope_kind,scope_id);
      if(index<0 || scopes[index].done) return;
      identity='{epoch:result.stats_epoch,episode:result.episode_id,platform:result.phase_id};
      episode_identity='{epoch:result.stats_epoch,episode:result.episode_id,platform:0};
      if(default_scopes[index].have_episode_identity && episode_identity<=default_scopes[index].episode_identity)return;
      if(default_scopes[index].have_phase_identity && identity<=default_scopes[index].phase_identity)return;
      if(scopes[index].have_phase_seq && result.result_seq<=scopes[index].last_phase_seq) return;
      default_growth(index,default_scopes[index].phases.size(),"default.phases",result.end_ticks);
      if(scope_failed(result.scope_kind,scope_id))return;
      default_scopes[index].phases.push_back(result);
      if(result.phase_kind===BW_PHASE_RAMP || result.phase_kind===BW_PHASE_FALL)begin
        if(scopes[index].time_epoch!=result.stats_epoch || scopes[index].time_episode!=result.episode_id) begin
          scopes[index].time_epoch=result.stats_epoch;scopes[index].time_episode=result.episode_id;
          scopes[index].saw_ramp=0;scopes[index].saw_fall=0;
        end
        if(result.phase_kind==BW_PHASE_RAMP) begin
          metric=RAMP_TIME;scopes[index].saw_ramp=1;scopes[index].ever_ramp=1;
        end else begin
          metric=FALL_TIME;scopes[index].saw_fall=1;scopes[index].ever_fall=1;
        end
        reason=duration_evidence_reason(result);measured=0;
        if(reason=="NONE") measured=real'(result.duration_ticks)/real'(BW_TICKS_PER_NS);
        settle(index,metric,phase_context(result),"phase",measured,reason);
        if(scope_failed(result.scope_kind,scope_id))return;
      end
      default_scopes[index].have_phase_identity=1;default_scopes[index].phase_identity=identity;
      scopes[index].have_phase_seq=1;scopes[index].last_phase_seq=result.result_seq;
    endfunction

    function automatic string selection_evidence_reason(bw_episode_result_t result);
      if(result.status===BW_EPISODE_RESET_INTERRUPTED) return "RESET_INTERRUPTED";
      if(result.status===BW_EPISODE_TRUNCATED) return "OBSERVATION_TRUNCATED";
      if(result.status!==BW_EPISODE_COMPLETE) return "EPISODE_NOT_COMPLETE";
      if(result.last_steady_reason!==BW_METRIC_OK) return metric_evidence_reason(result.last_steady_reason);
      if(!result.last_steady_selection_valid) return "LAST_STEADY_SELECTION_UNAVAILABLE";
      if(!result.last_steady_found) return "NO_CONFIRMED_STEADY";
      if(result.last_steady.scope_kind!=result.scope_kind || result.last_steady.stats_epoch!=result.stats_epoch ||
         result.last_steady.episode_id!=result.episode_id || result.last_steady.phase_kind!==BW_PHASE_STEADY)
        return "LAST_STEADY_IDENTITY_MISMATCH";
      return "NONE";
    endfunction

    virtual function void submit_episode(string scope_id,bw_episode_result_t result);
      int index;
      check_context_t context_value,steady_context;
      string reason,selection_reason,episode_reason;
      real measured;
      bit same_time_episode;
      default_identity_t identity;
      if(scope_failed(result.scope_kind,scope_id) || totals.finalized || result.result_seq==0)return;
      if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
      index=find_scope(result.scope_kind,scope_id);
      if(index<0 || scopes[index].done) return;
      identity='{epoch:result.stats_epoch,episode:result.episode_id,platform:0};
      if(default_scopes[index].have_episode_identity && identity<=default_scopes[index].episode_identity)return;
      if(scopes[index].have_seq && result.result_seq<=scopes[index].last_seq) return;
      if(!settle_default_episode(index,result))return;
      context_value=episode_context(result);
      reason=e2e_evidence_reason(result);measured=0;
      if(reason=="NONE") measured=result.e2e_gbps;
      settle(index,E2E_BW,context_value,"episode",measured,reason);
      if(scope_failed(result.scope_kind,scope_id))return;
      episode_reason="NONE";
      if(result.status===BW_EPISODE_RESET_INTERRUPTED) episode_reason="RESET_INTERRUPTED";
      else if(result.status===BW_EPISODE_TRUNCATED) episode_reason="OBSERVATION_TRUNCATED";
      else if(result.status!==BW_EPISODE_COMPLETE) episode_reason="EPISODE_NOT_COMPLETE";
      settle_variation(index,context_value,"episode",0,episode_reason);
      if(scope_failed(result.scope_kind,scope_id))return;
      selection_reason=selection_evidence_reason(result);
      steady_context=phase_context(result.last_steady);
      steady_context.scope_kind=result.scope_kind;steady_context.stats_epoch=result.stats_epoch;
      steady_context.episode_id=result.episode_id;steady_context.result_seq=result.result_seq;
      reason=selection_reason;measured=0;
      if(reason=="NONE") begin
        reason=duration_evidence_reason(result.last_steady);
        if(reason=="NONE" && !result.last_steady.bytes_complete) reason="BYTES_INCOMPLETE";
        if(reason=="NONE" && result.last_steady.bandwidth_reason!==BW_METRIC_OK)
          reason=metric_evidence_reason(result.last_steady.bandwidth_reason);
        if(reason=="NONE" && !result.last_steady.bandwidth_valid) reason="STEADY_BW_UNAVAILABLE";
        if(reason=="NONE") measured=result.last_steady.bandwidth_gbps;
      end
      settle(index,STEADY_BW,steady_context,"last_steady",measured,reason);
      if(scope_failed(result.scope_kind,scope_id))return;
      settle_variation(index,steady_context,"last_steady",1,selection_reason);
      if(scope_failed(result.scope_kind,scope_id))return;
      same_time_episode=scopes[index].time_epoch==result.stats_epoch && scopes[index].time_episode==result.episode_id;
      if(!same_time_episode || !scopes[index].saw_ramp)
        settle(index,RAMP_TIME,context_value,"episode",0,episode_reason=="NONE" ? "NO_CONFIRMED_RAMP" : episode_reason);
      if(!same_time_episode || !scopes[index].saw_fall)
        settle(index,FALL_TIME,context_value,"episode",0,episode_reason=="NONE" ? "NO_CONFIRMED_FALL" : episode_reason);
      if(scope_failed(result.scope_kind,scope_id))return;
      default_scopes[index].have_episode_identity=1;default_scopes[index].episode_identity=identity;
      scopes[index].have_seq=1;scopes[index].last_seq=result.result_seq;scopes[index].saw_episode=1;
      default_scopes[index].raw.delete();default_scopes[index].phases.delete();
    endfunction

    virtual function void scope_done(bw_scope_t kind,string scope_id,bw_u64_t stats_epoch);
      int index;
      check_context_t context_value;
      bw_episode_result_t empty_result;
      bw_report_summary_t value;
      string status;
      if(core_failure_pending() || totals.finalized) return;
      if(!monitor_time_supported($time)) begin check_monitor_time($time,scope_id);return;end
      index=find_scope(kind,scope_id);
      if(index<0 || scopes[index].done) return;
      if(scope_disabled(kind,scope_id))begin
        // The still-active episode of a disabled owner gets one terminal
        // settlement from evidence submitted before the failure; it never
        // manufactures a platform, a trusted suffix or a scope PASS. The
        // per-episode default identity is the replay guard.
        if(!settle_terminal_default(index))return;
        totals.warning_count=checked_add(totals.warning_count,1,scope_id);
        $display("BW_CHECK_WARNING scope_kind=%0d scope=%s reason=MONITOR_DISABLED",kind,scope_id);
      end else if(!scopes[index].saw_episode) begin
        // No record numbers are interpreted as zero measurements.
        empty_result.scope_kind=kind;empty_result.stats_epoch=stats_epoch;
        empty_result.variation='{window_basis:BW_NS,minmax_reason:BW_METRIC_NO_SAMPLES,
          stddev_reason:BW_METRIC_NO_SAMPLES,cv_reason:BW_METRIC_NO_SAMPLES,default:0};
        if(!settle_default_episode(index,empty_result))return;
        context_value=episode_context(empty_result);
        for(int m=0;m<METRIC_COUNT;m++) begin
          if(m==RAMP_TIME && scopes[index].ever_ramp) continue;
          if(m==FALL_TIME && scopes[index].ever_fall) continue;
          settle(index,m,context_value,"scope_final",0,"NO_EPISODE",1);
          if(core_failure_pending()) return;
        end
      end
      if(!scope_disabled(kind,scope_id))begin
        if(scope_failed(kind,scope_id))return;
        default_scopes[index].raw.delete();default_scopes[index].phases.delete();
      end
      scopes[index].done=1;totals.scopes_done=checked_add(totals.scopes_done,1,scope_id);
      if(core_failure_pending() || totals.scopes_done!=totals.scopes_expected) return;
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
