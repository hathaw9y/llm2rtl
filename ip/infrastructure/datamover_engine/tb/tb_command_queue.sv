`timescale 1ns/1ps
module tb_command_queue;
 logic clk=0,rstn=0,pause=0,abort_req=0,cv=0,cr;
 logic [31:0] address=0;
 logic [22:0] btt=8,offset=0;
 logic [1:0] bank=0;
 logic dv,dr=1;logic [71:0] dd;
 logic sv=0,sr,sk=1,sl=1;logic [7:0] sd=0;
 logic active,adone=0,afinished,rv,rr=0,faulted;
 logic [1:0] hb,rb;logic [22:0] ho,hl;
 logic [3:0] rt,received_tag;logic [7:0] code,raw;
 integer issued=0;
 logic [71:0] issued_cmd[128];
 always #5 clk=~clk;
 datamover_command_queue #(.BANK_NUM(3),.DEPTH(3),
   .BANK_WORD_BYTES({32'd16,32'd8,32'd8}),
   .BANK_CAPACITY_BYTES({32'd32,32'd16777216,32'd64})) dut(
   .aclk(clk),.aresetn(rstn),.pause(pause),.scheduler_abort(abort_req),
   .cmd_valid(cv),.cmd_ready(cr),.cmd_addr(address),.cmd_btt(btt),.cmd_offset(offset),.cmd_bank(bank),
   .dma_cmd_valid(dv),.dma_cmd_ready(dr),.dma_cmd_data(dd),
   .status_valid(sv),.status_ready(sr),.status_data(sd),.status_keep(sk),.status_last(sl),
   .head_active(active),.head_bank(hb),.head_offset(ho),.head_btt(hl),
   .adapter_done(adone),.adapter_finished(afinished),
   .completion_valid(rv),.completion_ready(rr),.completion_bank(rb),.completion_tag(rt),
   .completion_received_tag(received_tag),.completion_code(code),.completion_raw_status(raw),.faulted(faulted));
 logic ds=0,rs=0;logic [71:0] held_cmd;
 logic [29:0] held_response;
 always @(posedge clk) begin
   if(!rstn) begin ds<=0;rs<=0;end
   else begin
     if(ds && (!dv || dd!==held_cmd)) $fatal(1,"DMA command changed under stall/pause/fault");
     if(rs && (!rv || {rb,rt,received_tag,code,raw}!==held_response)) $fatal(1,"response changed under stall");
     ds<=dv&&!dr;held_cmd<=dd;
     rs<=rv&&!rr;held_response<={rb,rt,received_tag,code,raw};
     if(dv&&dr) begin issued_cmd[issued]=dd;issued=issued+1;end
   end
 end
 task automatic reset_all;
   @(negedge clk);rstn=0;cv=0;sv=0;rr=0;dr=1;pause=0;abort_req=0;adone=0;sk=1;sl=1;
   repeat(3) @(negedge clk);rstn=1;issued=0;
 endtask
 task automatic send(input logic [31:0] a,input logic [22:0] n,o,input logic [1:0] b);
   @(negedge clk);address=a;btt=n;offset=o;bank=b;cv=1;
   do @(posedge clk);while(!cr);
   @(negedge clk);cv=0;
 endtask
 task automatic status(input logic [7:0] s,input logic k,l);
   @(negedge clk);sd=s;sk=k;sl=l;sv=1;
   do @(posedge clk);while(!sr);
   @(negedge clk);sv=0;sk=1;sl=1;
 endtask
 task automatic adapter_finish;
   @(negedge clk);adone=1;@(negedge clk);adone=0;
 endtask
 task automatic response(input logic [7:0] c,input logic [3:0] t);
   wait(rv);@(negedge clk);
   if(code!==c || rt!==t) $fatal(1,"response expected code=%h tag=%h got code=%h tag=%h",c,t,code,rt);
   repeat(4) @(negedge clk);
   rr=1;@(negedge clk);rr=0;
 endtask
 task automatic reject(input logic [31:0] a,input logic [22:0] n,o,input logic [1:0] b,input logic [7:0] c);
   reset_all();send(a,n,o,b);response(c,0);
   if(issued!=0 || active || faulted) $fatal(1,"invalid descriptor dispatched or poisoned channel");
 endtask
 initial begin
   reject(0,0,0,0,8'h01);
   reject(3,8,0,0,8'h02);
   reject(32'hfffffff8,16,0,0,8'h03);
   reject(0,8,0,3,8'h04);
   reject(0,8,8,2,8'h05);
   reject(0,16,56,0,8'h06);
   // Exact DDR and bank upper boundaries are legal.
   reset_all();send(32'hfffffff8,8,56,0);wait(issued==1);
   status(8'h80,1,1);repeat(3) @(negedge clk);
   if(rv) $fatal(1,"success before adapter done");
   adapter_finish();response(0,0);
   send(0,23'h7fffff,0,1);wait(issued==2);adapter_finish();status(8'h81,1,1);response(0,1);
   // Preserve order around a rejected command with normal work queued behind it.
   reset_all();send(0,8,0,0);send(0,0,0,0);send(8,8,8,0);
   wait(issued==2);
   repeat(3) @(negedge clk);if(cr) $fatal(1,"queue overcommitted");
   status(8'h80,1,1);adapter_finish();response(0,0);response(8'h01,1);
   status(8'h82,1,1);adapter_finish();response(0,2);
   if(issued_cmd[0][67:64]!=0 || issued_cmd[1][67:64]!=2) $fatal(1,"issued tag metadata mismatch");
   // Tag wrapping with no outstanding aliasing.
   reset_all();
   for(integer i=0;i<20;i=i+1) begin
     send(0,8,0,0);wait(issued==i+1);
     if(issued_cmd[i][67:64]!==4'(i)) $fatal(1,"tag sequence");
     adapter_finish();status(8'h80|8'(i%16),1,1);response(0,4'(i));
   end
   // Fault must be observable even if the adapter cannot complete.
   reset_all();send(0,8,0,0);wait(issued==1);status(8'h87,1,1);
   wait(rv);if(!faulted || !active || received_tag!=7 || raw!=8'h87) $fatal(1,"tag fault diagnostics");
   response(8'h20,0);
   repeat(4) @(negedge clk);
   if(cr || !active || !faulted) $fatal(1,"fault silently retired/retried");
   reset_all();send(0,8,0,0);wait(issued==1);status(8'hc0,1,1);response(8'h10,0);
   reset_all();send(0,8,0,0);wait(issued==1);status(8'h80,0,1);response(8'h30,0);
   reset_all();send(0,8,0,0);wait(issued==1);status(8'h80,1,0);response(8'h30,0);
   reset_all();status(8'h80,1,1);response(8'h40,0);
   // Scheduler pause/abort cannot retract an already offered DMA command.
   reset_all();dr=0;send(0,8,0,0);wait(dv);@(negedge clk);pause=1;
   repeat(3) @(negedge clk);abort_req=1;
   repeat(3) @(negedge clk);abort_req=0;
   if(!faulted || cr || !dv) $fatal(1,"scheduler abort guard");
   dr=1;response(8'h50,0);
   reset_all();send(0,8,0,0);wait(issued==1);adapter_finish();status(8'h80,1,1);response(0,0);
   $display("PASS command queue descriptor/order/capacity/tag-wrap/status-fault/stall/scheduler-recovery");$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
