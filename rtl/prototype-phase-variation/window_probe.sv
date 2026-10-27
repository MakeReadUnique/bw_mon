// THROWAWAY window arithmetic probe. This is NOT bw_stats_core or bw_check_report.
`timescale 1ns/1ps
module window_probe;
  integer input_fd, output_fd, rc, case_id, previous_case, u, ev, known, rst;
  integer w, stride, group_mode, count, slot, j, complete;
  real b0,b1,b2,b3, sample, total;
  real history[0:9];
  integer quality[0:9];
  string input_path,output_path;
  initial begin
    if (!$value$plusargs("INPUT=%s",input_path) || !$value$plusargs("OUTPUT=%s",output_path)) $fatal(1,"paths");
    if (!$value$plusargs("STRIDE=%d",stride) || !$value$plusargs("GROUP=%d",group_mode)) $fatal(1,"config");
    input_fd=$fopen(input_path,"r"); output_fd=$fopen(output_path,"w");
    if (!input_fd || !output_fd) $fatal(1,"files");
    previous_case=-1; w=10; count=0; slot=0;
    while (!$feof(input_fd)) begin
      rc=$fscanf(input_fd,"%d %d %f %f %f %f %d %d %d\n",case_id,u,b0,b1,b2,b3,ev,known,rst);
      if (rc==9) begin
        if (case_id!=previous_case || rst) begin
          count=0; slot=0;
          for(j=0;j<w;j=j+1)begin history[j]=0.0;quality[j]=1;end
          previous_case=case_id;
        end
        sample=group_mode ? b0+b1+b2+b3 : b0;
        history[slot]=sample;quality[slot]=known;
        slot=(slot+1)%w;count=count+1;
        #1;
        if(u%stride==0)begin
          total=0.0;complete=1;
          for(j=0;j<w;j=j+1)begin total=total+history[j];complete=complete && quality[j];end
          $fwrite(output_fd,"%0d,%0d,%0.17g,%0.17g,%0d,%0d\n",case_id,u,$realtime,total/real'(count<w?count:w),count>=w,complete);
        end
      end else if(rc!=-1) $fatal(1,"malformed stimulus");
    end
    $fclose(input_fd);$fclose(output_fd);$display("PROTOTYPE_WINDOW_PROBE_COMPLETE");$finish;
  end
endmodule
