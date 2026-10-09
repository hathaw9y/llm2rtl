`timescale 1ns/1ps
module tb_attention_executor;
  import attention_tensor_pkg::*;
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic cmd_valid=0;wire cmd_ready;logic[15:0]cmd_id=0;logic[7:0]cmd_opcode=0;
  logic[4:0]cmd_src0=0,cmd_src1=0,cmd_dst=0;logic[255:0]cmd_src0_desc=0,cmd_src1_desc=0,cmd_dst_desc=0;
  wire resp_valid;logic resp_ready=0;wire[15:0]resp_id;wire resp_error;wire[7:0]resp_error_code;
  logic[5:0]ctx_tokens,ctx_query_count;logic[2:0]ctx_heads;logic[6:0]ctx_head_dim;logic ctx_causal;logic[31:0]ctx_qk_factor;
  wire[4:0]query_lookup_index;logic[4:0]query_lookup_value;logic[31:0]query[0:31];
  wire src0_read_valid,src1_read_valid;logic src0_read_ready,src1_read_ready;
  wire[4:0]src0_read_bank,src1_read_bank;wire[31:0]src0_read_addr,src1_read_addr;
  logic src0_resp_valid=0,src1_resp_valid=0;logic[4:0]src0_resp_bank=0,src1_resp_bank=0;logic[127:0]src0_resp_data=0,src1_resp_data=0;
  wire dst_write_valid;logic dst_write_ready;wire[4:0]dst_write_bank;wire[31:0]dst_write_addr;wire[127:0]dst_write_data;wire[15:0]dst_write_strb;
  attention_tensor_executor dut(.*);
  localparam integer WORDS=4096;
  logic[127:0]memory[0:19*WORDS-1],expected[0:WORDS-1],instructions[0:20];
  logic[255:0]descriptors[0:18];logic[31:0]context_words[0:5];
  integer cycle=0,count0=0,count1=0,reads=0,writes=0,cases=0;
  logic[4:0]bank0,bank1;logic[127:0]data0,data1;
  logic[159:0]held0,held1;logic[180:0]heldw;logic stalled0=0,stalled1=0,stalledw=0;
  logic inject_wrong=0;
  assign query_lookup_value=5'(query[query_lookup_index]);
  always_comb begin src0_read_ready=cycle%7!=0;src1_read_ready=cycle%5!=0;dst_write_ready=cycle%6!=0;end
  always @(posedge aclk)begin
    if(!aresetn)begin count0=0;count1=0;src0_resp_valid<=0;src1_resp_valid<=0;cycle=0;stalled0=0;stalled1=0;stalledw=0;end
    else begin
      cycle++;
      if(stalled0 && (!src0_read_valid || {src0_read_bank,src0_read_addr}!==held0[36:0]))$fatal(1,"src0 stalled request changed");
      if(stalled1 && (!src1_read_valid || {src1_read_bank,src1_read_addr}!==held1[36:0]))$fatal(1,"src1 stalled request changed");
      if(stalledw && (!dst_write_valid || {dst_write_bank,dst_write_addr,dst_write_data,dst_write_strb}!==heldw))$fatal(1,"stalled destination changed");
      stalled0=src0_read_valid&&!src0_read_ready;held0={123'b0,src0_read_bank,src0_read_addr};
      stalled1=src1_read_valid&&!src1_read_ready;held1={123'b0,src1_read_bank,src1_read_addr};
      stalledw=dst_write_valid&&!dst_write_ready;heldw={dst_write_bank,dst_write_addr,dst_write_data,dst_write_strb};
      src0_resp_valid<=0;src1_resp_valid<=0;
      if(count0>0)begin count0--;if(count0==0)begin src0_resp_valid<=1;src0_resp_bank<=inject_wrong?bank0+5'd1:bank0;src0_resp_data<=data0;end end
      if(count1>0)begin count1--;if(count1==0)begin src1_resp_valid<=1;src1_resp_bank<=bank1;src1_resp_data<=data1;end end
      if(src0_read_valid&&src0_read_ready)begin
        if(count0||src0_resp_valid||src0_read_bank>=19||src0_read_addr>=WORDS)$fatal(1,"src0 read protocol/range");
        count0=1+cycle%4;bank0=src0_read_bank;data0=memory[int'(src0_read_bank)*WORDS+int'(src0_read_addr)];reads++;
      end
      if(src1_read_valid&&src1_read_ready)begin
        if(count1||src1_resp_valid||src1_read_bank>=19||src1_read_addr>=WORDS)$fatal(1,"src1 read protocol/range");
        count1=1+cycle%5;bank1=src1_read_bank;data1=memory[int'(src1_read_bank)*WORDS+int'(src1_read_addr)];reads++;
      end
      if(dst_write_valid&&dst_write_ready)begin
        if(dst_write_bank>=19||dst_write_addr>=WORDS)$fatal(1,"write range");
        for(integer b=0;b<16;b++)if(dst_write_strb[b])memory[int'(dst_write_bank)*WORDS+int'(dst_write_addr)][8*b+:8]=dst_write_data[8*b+:8];writes++;
      end
      if(resp_valid&&(count0||count1||src0_read_valid||src1_read_valid||dst_write_valid))$fatal(1,"response before quiescence");
    end
  end
  task automatic tick;@(posedge aclk);#1;@(negedge aclk);endtask
  task automatic reset_dut;aresetn=0;cmd_valid=0;resp_ready=0;inject_wrong=0;repeat(3)tick();aresetn=1;tick();endtask
  task automatic issue(input integer op,a,b,d,id);
    cmd_opcode=8'(op);cmd_src0=5'(a);cmd_src1=5'(b);cmd_dst=5'(d);cmd_id=16'(id);
    cmd_src0_desc=descriptors[a];cmd_src1_desc=descriptors[b];cmd_dst_desc=descriptors[d];cmd_valid=1;
    while(!cmd_ready)tick();tick();cmd_valid=0;
  endtask
  task automatic result(input bit error,input integer code,id);
    integer n;n=0;while(!resp_valid&&n<15000000)begin tick();n++;end
    if(!resp_valid||resp_error!==error||resp_id!=16'(id)||(error&&resp_error_code!=8'(code)))$fatal(1,"executor response mismatch op%0d state%0d err%0d code%0d cycles%0d",cmd_opcode,dut.state_r,resp_error,resp_error_code,n);
    repeat(3)begin tick();if(!resp_valid||resp_error!==error||resp_id!=16'(id))$fatal(1,"response unstable under stall");end
    resp_ready=1;tick();resp_ready=0;repeat(2)tick();if(resp_valid||!cmd_ready)$fatal(1,"response/reissue state");
  endtask
  initial begin
    tensor_desc_t descriptor_value;
    integer capacity,before_writes;
    $readmemh("descriptor.mem",descriptors);$readmemh("context.mem",context_words);$readmemh("query.mem",query);$readmemh("program.mem",instructions);
    ctx_tokens=6'(context_words[0]);ctx_heads=3'(context_words[1]);ctx_head_dim=7'(context_words[2]);ctx_query_count=6'(context_words[3]);ctx_causal=context_words[4][0];ctx_qk_factor=context_words[5];
    for(integer i=0;i<19*WORDS;i++)memory[i]=128'hfeedcafe_deadbeef_01234567_89abcdef;
    for(integer bank=0;bank<6;bank++)begin descriptor_value=tensor_desc_t'(descriptors[bank]);$readmemh($sformatf("input_bank%02d.mem",bank),memory,bank*WORDS,bank*WORDS+int'(descriptor_value.capacity_bytes/16)-1);end
    reset_dut();
    for(integer pc=0;pc<21;pc++)begin
      if(instructions[pc][127:120]>=3&&instructions[pc][127:120]<=7)begin
        $display("EXECUTOR_START pc%0d op%0d",pc,instructions[pc][127:120]);
        issue(int'(instructions[pc][127:120]),int'(instructions[pc][111:104]),int'(instructions[pc][103:96]),int'(instructions[pc][119:112]),pc);
        result(0,0,pc);descriptor_value=tensor_desc_t'(descriptors[cmd_dst]);capacity=int'(descriptor_value.capacity_bytes/16);
        $readmemh($sformatf("expected_bank%02d.mem",cmd_dst),expected,0,capacity-1);
        for(integer w=0;w<capacity;w++)if(memory[int'(cmd_dst)*WORDS+w]!==expected[w])$fatal(1,"payload mismatch pc%0d bank%0d word%0d got%h expected%h",pc,cmd_dst,w,memory[int'(cmd_dst)*WORDS+w],expected[w]);
        if(memory[int'(cmd_dst)*WORDS+capacity]!==128'hfeedcafe_deadbeef_01234567_89abcdef)$fatal(1,"write beyond descriptor capacity");cases++;
      end
    end
    // Invalid metadata must not even clear a destination.
    before_writes=writes;cmd_opcode=3;cmd_src0=0;cmd_src1=0;cmd_dst=6;cmd_src0_desc=descriptors[0];cmd_src1_desc=descriptors[0];descriptor_value=tensor_desc_t'(descriptors[6]);descriptor_value.capacity_bytes+=16;cmd_dst_desc=descriptor_value;cmd_id=100;cmd_valid=1;tick();cmd_valid=0;result(1,2,100);if(writes!=before_writes)$fatal(1,"illegal descriptor touched destination");cases++;
    // Reserved INT4 nibble is a clean consumed-data error, never success.
    memory[6*WORDS][3:0]=4'h8;issue(4,6,1,7,101);result(1,4,101);cases++;
    reset_dut();
    // Wrong response identity is unclean: no completion, reset is mandatory.
    inject_wrong=1;issue(3,0,0,6,102);while(!src0_read_valid)tick();repeat(20)tick();
    if(resp_valid||cmd_ready||src0_read_valid||src1_read_valid||dst_write_valid)$fatal(1,"wrongbank protocol fault certified completion");reset_dut();cases++;
    // Reset while a real read is outstanding, and while a destination is stalled.
    issue(3,0,0,6,103);while(count0==0)tick();reset_dut();repeat(10)tick();if(resp_valid||!cmd_ready)$fatal(1,"reset outstanding read cancellation");cases++;
    force dst_write_ready=0;issue(3,0,0,6,104);repeat(4)tick();if(!dst_write_valid)$fatal(1,"write reset phase not reached");reset_dut();release dst_write_ready;repeat(5)tick();if(resp_valid||!cmd_ready)$fatal(1,"reset stalled write cancellation");cases++;
    $display("ATTENTION_EXECUTOR_CASES=%0d reads=%0d writes=%0d cycles=%0d",cases,reads,writes,cycle);
    $display("ATTENTION_EXECUTOR_XSIM_PASS");$finish;
  end
  initial begin #1000000000;$fatal(1,"executor simulation timeout state%0d",dut.state_r);end
endmodule
