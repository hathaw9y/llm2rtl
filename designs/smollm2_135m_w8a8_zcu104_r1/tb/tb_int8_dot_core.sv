module tb_int8_dot_core;
 logic clk=0; always #2.5 clk=~clk;
 logic resetn=0,step_valid=0,step_ready,result_valid,result_ready=0;
 logic [127:0] step_a;logic[2047:0]step_b;logic[6:0]step_row;
 logic step_first_k,step_last_k;logic[4:0]step_n_valid;logic[95:0]step_tag;logic[31:0]step_scale;
 logic[511:0]result_sums;logic[4:0]result_n_valid;logic[95:0]result_tag;logic[31:0]result_scale;
 int inf,expf,got=0,issued=0,rc,erc,cycles=0;
 logic[511:0]exp_sums;logic[4:0]exp_n;logic[95:0]exp_tag;logic[31:0]exp_scale;
 logic[644:0] stalled_snapshot;logic was_stalled=0;
 logic[31:0] rng=32'h8babc123;logic bubble_mode=1;
 int consecutive=0,max_consecutive=0;
 int8_dot_core dut(.*);
 always @(posedge clk) begin
  if(resetn) begin
   cycles<=cycles+1;
   if(was_stalled && !result_valid)$fatal(1,"result valid dropped while stalled");
   if(was_stalled && {result_sums,result_n_valid,result_tag,result_scale} !== stalled_snapshot)
     $fatal(1,"output changed while stalled");
   was_stalled<=result_valid&&!result_ready;
   stalled_snapshot<={result_sums,result_n_valid,result_tag,result_scale};
   if(step_valid&&step_ready) begin issued<=issued+1;consecutive<=consecutive+1;if(consecutive+1>max_consecutive)max_consecutive<=consecutive+1;end
   else consecutive<=0;
   if(result_valid&&result_ready)begin
    erc=$fscanf(expf,"%h %h %h %h\n",exp_sums,exp_n,exp_tag,exp_scale);
    if(erc!=4)$fatal(1,"unexpected result");
    if({result_sums,result_n_valid,result_tag,result_scale} !== {exp_sums,exp_n,exp_tag,exp_scale})
      $fatal(1,"mismatch result %0d tag=%h expected=%h",got,result_tag,exp_tag);
    got<=got+1;
   end
  end else was_stalled<=0;
 end
 task drive_step;
  begin
   @(negedge clk);
   rc=$fscanf(inf,"%h %h %h %h %h %h %h %h\n",step_a,step_b,step_row,step_first_k,step_last_k,step_n_valid,step_tag,step_scale);
   step_valid=rc==8;
  end
 endtask
 initial begin
  inf=$fopen("inputs.txt","r");expf=$fopen("expected.txt","r");if(!inf||!expf)$fatal(1,"missing vectors");
  repeat(3)@(negedge clk);resetn=1;
  // Reset live work before golden run; no stale completion may survive.
  step_a={16{8'h7f}};step_b={256{8'h7f}};step_row=0;step_first_k=1;step_last_k=1;step_n_valid=16;step_tag='1;step_scale=32'h3f800000;step_valid=1;
  repeat(3)@(negedge clk);resetn=0;step_valid=0;
  repeat(2)@(negedge clk);resetn=1;issued=0;
  repeat(10)@(negedge clk);
  if(result_valid)$fatal(1,"stale result after reset");
  drive_step();
  while(rc==8)begin
   @(posedge clk);
   if(step_valid&&step_ready)begin
    if(issued>300 && rng[3:0]==0)begin @(negedge clk);step_valid=0;@(posedge clk);end
    drive_step();
   end
  end
  @(negedge clk);step_valid=0;result_ready=1;bubble_mode=0;
  repeat(20)@(negedge clk);
  if(got!=250)$fatal(1,"count %0d",got);
  if(max_consecutive<96)$fatal(1,"II1 not demonstrated max=%0d",max_consecutive);
  $display("CORE_PASS inputs=%0d outputs=%0d max_II1_burst=%0d cycles=%0d",issued,got,max_consecutive,cycles);
  $finish;
 end
 always @(negedge clk)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   if(bubble_mode) result_ready=(issued<300)||rng[2:0]!=0;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
