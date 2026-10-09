#!/usr/bin/env python3
import json,pathlib
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];b=json.loads((D/'contracts/native_bank_pool_rtl_binding.json').read_text());ports=b['ports'];decl='\n'.join('logic '+(f'[{v["bits"]-1}:0] ' if v['bits']>1 else '')+n+';' for n,v in ports.items());inst=',\n'.join(f'.{n}({n})' for n in ports);init='\n'.join(f'{n}=0;' for n,v in ports.items() if v['direction']=='input' and n not in ['clk','resetn']);caps=b['capacities'];base=[];cur=0
for c in caps:base.append(cur);cur+=c//16
profiles=[(1,1,576,1152,0,0),(2,1,576,1152,0,0),(3,1,576,1152,0,0),(4,1,576,576,294912,16),(7,1,576,1152,0,0),(8,1,192,384,0,0),(10,1,192,384,0,0),(11,1,64,128,4096,1920),(12,1,192,192,196608,16),(14,1,192,192,196608,48),(16,1,1,288,0,0),(19,1,576,1152,0,0),(20,1,49152,98304,0,0),(21,1,576,576,294912,16),(23,1,576,576,18432,48),(4,1,576,576,294912,16)]
configure='\n'.join(f' configure({i},0,1,{p},{rows},{cols},0,{dat}, {so},{sl});' for i,(p,rows,cols,dat,so,sl) in enumerate(profiles));
tb=r'''`timescale 1ns/1ps
module audit_native_leaf_tb;
__DECL__
smollm2_native_bank_pool dut(__INST__);
localparam int WORDS[0:15]='{__WORDS__};
localparam int BASE[0:15]='{__BASE__};
logic [127:0] shadow[0:__TOTAL_LAST__];
logic [15:0] shadow_known[0:__TOTAL_LAST__];
logic [2:0] expect_valid[0:15];
logic [255:0] expect_data[0:15][0:2];
logic [31:0] expect_known[0:15][0:2];
int cycles=0,read_checks=0,write_checks=0,pub_count=0;
int pub_b[0:255],pub_c[0:255];logic[31:0]pub_g[0:255];logic pub_d[0:255],pub_s[0:255];
logic previous_hold;logic[76:0]previous_pub;
wire [76:0] pub_payload={coverage_bank,coverage_component,coverage_generation,coverage_transaction_id,coverage_role,coverage_data_complete,coverage_scale_complete};
always #2.5 clk=~clk;
always @(posedge clk)begin
 cycles++;
 if(cycles>700000)$fatal(1,"AUDIT_LEAF timeout");
 if(!resetn)begin
  for(int b=0;b<16;b++)expect_valid[b]=0;
  previous_hold=0;pub_count=0;
 end else begin
  if(previous_hold&&(!coverage_valid||pub_payload!==previous_pub))$fatal(1,"stalled publication changed");
  previous_hold=coverage_valid&&!coverage_ready;previous_pub=pub_payload;
  if(coverage_valid&&coverage_ready)begin
   if(pub_count>=256)$fatal(1,"pub storage overflow");
   pub_b[pub_count]=int'(coverage_bank);pub_c[pub_count]=int'(coverage_component);pub_g[pub_count]=coverage_generation;pub_d[pub_count]=coverage_data_complete;pub_s[pub_count]=coverage_scale_complete;pub_count++;
   if(coverage_role!=1||coverage_transaction_id!=32'd1000+32'(coverage_bank))$fatal(1,"publication lost writer identity");
   if(coverage_bank==7&&coverage_component==2&&(!coverage_data_complete||!coverage_scale_complete))$fatal(1,"B7static missing controller-compatible flags");
  end
  for(int b=0;b<16;b++)begin
   if(rd_resp_valid[b]!==expect_valid[b][2])$fatal(1,"read latency bank%0d cycle%0d expected%0b got%0b",b,cycles,expect_valid[b][2],rd_resp_valid[b]);
   if(expect_valid[b][2])begin
    for(int q=0;q<32;q++)if(expect_known[b][2][q]&&rd_data[b*256+q*8+:8]!==expect_data[b][2][q*8+:8])$fatal(1,"read byte/order mismatch bank%0d lane%0d got%h expected%h",b,q,rd_data[b*256+q*8+:8],expect_data[b][2][q*8+:8]);
    read_checks++;
   end
   expect_valid[b]={expect_valid[b][1:0],rd_valid[b]&&rd_ready[b]};
   expect_data[b][2]=expect_data[b][1];expect_data[b][1]=expect_data[b][0];
   expect_known[b][2]=expect_known[b][1];expect_known[b][1]=expect_known[b][0];
   if(rd_valid[b]&&rd_ready[b])begin
    int address;address=int'(rd_word_address[b*19+:19]);
    expect_data[b][0][127:0]=shadow[BASE[b]+address];expect_known[b][0][15:0]=shadow_known[BASE[b]+address];
    if(rd_wide[b])begin expect_data[b][0][255:128]=shadow[BASE[b]+address+1];expect_known[b][0][31:16]=shadow_known[BASE[b]+address+1];end
    else begin expect_data[b][0][255:128]=0;expect_known[b][0][31:16]=16'hffff;end
   end
  end
  // Snapshot reads before writes: read-first collision contract.
  for(int b=0;b<16;b++)begin
   if(wr_commit[b] !== (wr_valid[b]&&wr_ready[b]))$fatal(1,"commit not architectural acceptance");
   if(wr_commit[b])begin
    int address;address=int'(wr_word_address[b*19+:19]);
    for(int q=0;q<16;q++)if(wr_strb[b*16+q])begin shadow[BASE[b]+address][q*8+:8]=wr_data[b*128+q*8+:8];shadow_known[BASE[b]+address][q]=1;end
    write_checks++;
   end
  end
 end
end
task automatic ticks(input int n);repeat(n)@(negedge clk);endtask
task automatic initialize;
 resetn=0;rd_valid=0;wr_valid=0;epoch_valid=0;coverage_ready=1;epoch_done_ready=16'hffff;ticks(4);resetn=1;
 begin int t;t=0;while(bank_ready!=16'hffff&&t<40000)begin ticks(1);t++;end if(bank_ready!=16'hffff)$fatal(1,"coverage init timeout");end
 ticks(4);if(fault_valid)$fatal(1,"unexpected init fault");
endtask
task automatic configure(input int b,input int component,input logic[31:0]generation,input int profile,input int rows,input int cols,input int dataoff,input int datalen,input int scaleoff,input int scalelen);
 epoch_valid=1;epoch_bank=4'(b);epoch_component=2'(component);epoch_token=32'd2000+generation;epoch_generation=generation;epoch_profile=5'(profile);epoch_rows=11'(rows);epoch_cols=16'(cols);epoch_position=0;epoch_layer=0;epoch_data_offset=32'(dataoff);epoch_data_bytes=32'(datalen);epoch_scale_offset=32'(scaleoff);epoch_scale_bytes=32'(scalelen);
 do @(posedge clk);while(!epoch_ready);if(epoch_error_code!=0)$fatal(1,"epoch rejected b%0d g%0d error%h",b,generation,epoch_error_code);@(negedge clk);epoch_valid=0;
 begin int t;t=0;while(!bank_ready[b]&&t<40000)begin ticks(1);t++;end if(!bank_ready[b])$fatal(1,"epoch done timeout b%0d",b);end
endtask
task automatic write_word(input int b,input int address,input logic[127:0]value,input logic[15:0]strobe,input logic[31:0]generation);
 wr_word_address[b*19+:19]=19'(address);wr_data[b*128+:128]=value;wr_strb[b*16+:16]=strobe;wr_generation[b*32+:32]=generation;wr_transaction_id[b*32+:32]=32'd1000+32'(b);wr_role[b*5+:5]=1;wr_valid[b]=1;
 do @(posedge clk);while(!wr_ready[b]);@(negedge clk);wr_valid[b]=0;
endtask
task automatic read_word(input int b,input int address,input bit wide);
 rd_word_address[b*19+:19]=19'(address);rd_wide[b]=wide;rd_valid[b]=1;do @(posedge clk);while(!rd_ready[b]);@(negedge clk);rd_valid[b]=0;
endtask
task automatic fill(input int b,input int address,input int words,input logic[31:0]generation);
 for(int k=0;k<words;k++)write_word(b,address+k,{32'(b),32'(k),32'h82736451,32'hdeadbeef},16'hffff,generation);
endtask
function automatic int publications(input int b,input logic[31:0]g,input bit datafull,input bit scalefull);
 int n;begin n=0;for(int k=0;k<pub_count;k++)if(pub_b[k]==b&&pub_g[k]==g&&pub_d[k]==datafull&&pub_s[k]==scalefull)n++;return n;end
endfunction
initial begin
 clk=0;resetn=0;
__INIT__
 for(int k=0;k<=__TOTAL_LAST__;k++)begin shadow_known[k]=0;shadow[k]=0;end
 initialize();
__CONFIGURE__
 // All bank orientations, odd narrow selection, allocated final words and supported wide pairs.
 for(int b=0;b<16;b++)begin
  write_word(b,0,{4{32'h10203040+32'(b)}},16'hffff,1);
  write_word(b,1,{4{32'h90a0b0c0+32'(b)}},16'hffff,1);
  read_word(b,0,0);read_word(b,1,0);read_word(b,WORDS[b]-1,0);
  if(b==3||b==8||b==9||b==13||b==14||b==15)read_word(b,0,1);
 end
 ticks(8);if(fault_valid)$fatal(1,"legal orientation test fault");
 // Byte isolation, collision semantics and sparse reads.
 write_word(0,0,128'h112233445566778899aabbccddeeff00,16'h5555,1);read_word(0,0,0);ticks(6);
 wr_word_address[0+:19]=0;wr_data[0+:128]=128'hf0e0d0c0b0a090807060504030201000;wr_strb[0+:16]=16'hffff;wr_generation[0+:32]=1;wr_transaction_id[0+:32]=1000;wr_role[0+:5]=1;wr_valid[0]=1;rd_word_address[0+:19]=0;rd_wide[0]=0;rd_valid[0]=1;
 @(posedge clk);if(!wr_ready[0]||!rd_ready[0])$fatal(1,"collision not accepted");@(negedge clk);wr_valid[0]=0;rd_valid[0]=0;ticks(5);read_word(0,0,0);ticks(6);
 // Epoch retains payload, duplicate writes do not fill holes, held two completeness transitions lossless.
 configure(13,0,2,21,1,576,0,576,294912,16);read_word(13,0,0);coverage_ready=0;
 for(int k=0;k<36;k++)write_word(13,k,{4{32'hcafe0000+32'(k)}},k==9?16'hff00:16'hffff,2);
 for(int k=0;k<12;k++)write_word(13,9,128'h1122,16'hff00,2);
 write_word(13,9,0,0,2);ticks(8);if(coverage_valid)$fatal(1,"duplicate/zero/gap falsely complete");
 write_word(13,9,128'hffeeddccbbaa99887766554433221100,16'h00ff,2);ticks(8);
 if(!coverage_valid||coverage_bank!=13||!coverage_data_complete||coverage_scale_complete)$fatal(1,"data transition missing");
 write_word(13,294912/16,128'h3f8000003f8000003f8000003f800000,16'hffff,2);ticks(12);
 if(!coverage_pending[13]||bank_quiescent[13])$fatal(1,"held publication absent from quiescence");coverage_ready=1;ticks(12);
 if(publications(13,2,1,0)!=1||publications(13,2,1,1)!=1)$fatal(1,"two transitions lost/coalesced/duplicated");
 begin int n;n=pub_count;write_word(13,294912/16,0,16'hffff,2);ticks(8);if(pub_count!=n)$fatal(1,"duplicate scale publication");end
 read_word(13,9,0);ticks(6);
 // Physical tail canary: embedding64byte sidecar then weight48byte sidecar keeps fourth word unchanged.
 configure(3,0,2,6,4,576,0,2304,294912,64);fill(3,294912/16,4,2);ticks(8);
 configure(3,0,3,4,192,576,0,110592,294912,48);fill(3,294912/16,3,3);read_word(3,294912/16+2,1);ticks(8);
 // B7 per-component epochs, retained opposite masks, both static flags.
 configure(7,0,2,11,1,64,0,128,4096,1920);fill(7,0,8,2);fill(7,256,120,2);ticks(12);
 if(publications(7,2,1,1)!=2)$fatal(1,"B7 full component events");
 configure(7,1,3,11,2,64,0,256,0,0);begin int n;n=pub_count;write_word(7,256,128'h33,16'hffff,2);ticks(8);if(pub_count!=n)$fatal(1,"window epoch cleared static coverage");end
 read_word(7,257,0);fill(7,0,16,3);ticks(12);
 configure(7,2,4,11,30,64,4096,1920,0,0);begin int n;n=pub_count;write_word(7,0,128'h44,16'hffff,3);ticks(8);if(pub_count!=n)$fatal(1,"static epoch cleared window coverage");end
 read_word(7,1,0);fill(7,256,120,4);ticks(12);
 if(publications(7,3,1,1)!=1||publications(7,4,1,1)!=1)$fatal(1,"B7 independent generation events");
 // Q18groups requires80 padded scale bytes; K16/V48 sidecars remain exact.
 configure(14,0,2,23,17,576,0,9792,18432,80);fill(14,0,612,2);fill(14,1152,4,2);ticks(10);
 if(publications(14,2,1,1)!=0)$fatal(1,"Q scale80 falsely complete at64");write_word(14,1156,128'h3f800000,16'hffff,2);ticks(12);if(publications(14,2,1,1)!=1)$fatal(1,"Q scale80 completion absent");read_word(14,1156,1);
 configure(8,0,2,12,1,192,0,192,196608,16);fill(8,0,12,2);fill(8,12288,1,2);
 configure(9,0,2,14,1,192,0,192,196608,48);fill(9,0,12,2);fill(9,12288,3,2);ticks(12);
 if(publications(8,2,1,1)!=1||publications(9,2,1,1)!=1)$fatal(1,"K/V scale completion");
 // Two bank completions under global publication stall are both eventually delivered.
 configure(0,0,2,1,1,576,0,1152,0,0);configure(1,0,2,2,1,576,0,1152,0,0);coverage_ready=0;
 for(int k=0;k<72;k++)begin
  for(int b=0;b<2;b++)begin wr_word_address[b*19+:19]=19'(k);wr_data[b*128+:128]={4{32'(k)}};wr_strb[b*16+:16]=16'hffff;wr_generation[b*32+:32]=2;wr_transaction_id[b*32+:32]=32'd1000+32'(b);wr_role[b*5+:5]=1;end
  wr_valid=3;@(posedge clk);if(wr_ready[1:0]!=3)$fatal(1,"legal II1 concurrency stalled");@(negedge clk);wr_valid=0;
 end
 ticks(12);if(coverage_pending[1:0]!=3)$fatal(1,"simultaneous events lost");coverage_ready=1;ticks(12);if(publications(0,2,1,1)!=1||publications(1,2,1,1)!=1)$fatal(1,"simultaneous publications missing");
 // Disabled native addresses cannot change previously completed read outputs.
 begin logic[4095:0]held;held=rd_data;for(int k=0;k<5;k++)begin rd_word_address=304'(k*17);ticks(1);if(rd_data!==held)$fatal(1,"disabled read output changed");end end
 // Fresh invalid operation witness: stale generation changes neither payload nor coverage.
 if(fault_valid)$fatal(1,"negative witness entered with old fault");
 wr_word_address[0+:19]=0;wr_data[0+:128]='1;wr_strb[0+:16]='1;wr_generation[0+:32]=1;wr_role[0+:5]=1;wr_valid[0]=1;@(posedge clk);if(wr_ready[0]||wr_commit[0])$fatal(1,"stale write accepted");@(negedge clk);wr_valid[0]=0;ticks(3);if(!fault_valid||fault_error_code!=7||fault_bank!=0)$fatal(1,"stale fault diagnostic");read_word(0,0,0);ticks(6);
 initialize();read_word(0,0,0);ticks(6); // RAM survives coordinated metadata reset.
 rd_word_address[3*19+:19]=1;rd_wide[3]=1;rd_valid[3]=1;@(posedge clk);if(rd_ready[3])$fatal(1,"odd wide accepted");@(negedge clk);rd_valid[3]=0;ticks(3);if(!fault_valid||fault_error_code!=7||fault_bank!=3)$fatal(1,"oddwide diagnostic");
 initialize();rd_word_address[9*19+:19]=19'(WORDS[9]);rd_wide[9]=0;rd_valid[9]=1;@(posedge clk);if(rd_ready[9])$fatal(1,"outofrange accepted");@(negedge clk);rd_valid[9]=0;ticks(3);if(!fault_valid||fault_error_code!=7||fault_bank!=9)$fatal(1,"outofrange diagnostic");
 if(read_checks<60||write_checks<1000)$fatal(1,"vacuous leaf audit");
 $display("AUDIT_NATIVE_LEAF_PASS reads=%0d writes=%0d cycles=%0d",read_checks,write_checks,cycles);$finish;
end
endmodule
'''
for key,value in [('__DECL__',decl),('__INST__',inst),('__WORDS__',','.join(str(c//16) for c in caps)),('__BASE__',','.join(map(str,base))),('__TOTAL_LAST__',str(cur-1)),('__INIT__',init),('__CONFIGURE__',configure)]:tb=tb.replace(key,value)
(H/'audit_native_leaf_tb.sv').write_text(tb);print(H/'audit_native_leaf_tb.sv')
