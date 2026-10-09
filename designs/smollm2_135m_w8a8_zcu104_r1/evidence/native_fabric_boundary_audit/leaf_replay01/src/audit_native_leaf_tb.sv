`timescale 1ns/1ps
module audit_native_leaf_tb;
logic clk;
logic resetn;
logic [15:0] rd_valid;
logic [15:0] rd_ready;
logic [303:0] rd_word_address;
logic [15:0] rd_wide;
logic [15:0] rd_resp_valid;
logic [4095:0] rd_data;
logic [15:0] wr_valid;
logic [15:0] wr_ready;
logic [303:0] wr_word_address;
logic [2047:0] wr_data;
logic [255:0] wr_strb;
logic [511:0] wr_transaction_id;
logic [511:0] wr_generation;
logic [79:0] wr_role;
logic [15:0] wr_commit;
logic [15:0] wr_pending;
logic [15:0] coverage_pending;
logic [15:0] bank_quiescent;
logic [15:0] bank_ready;
logic epoch_valid;
logic epoch_ready;
logic [7:0] epoch_error_code;
logic [3:0] epoch_bank;
logic [1:0] epoch_component;
logic [31:0] epoch_token;
logic [31:0] epoch_generation;
logic [4:0] epoch_profile;
logic [10:0] epoch_rows;
logic [15:0] epoch_cols;
logic [9:0] epoch_position;
logic [4:0] epoch_layer;
logic [31:0] epoch_data_offset;
logic [31:0] epoch_data_bytes;
logic [31:0] epoch_scale_offset;
logic [31:0] epoch_scale_bytes;
logic [15:0] epoch_done_valid;
logic [15:0] epoch_done_ready;
logic [511:0] epoch_done_token;
logic [511:0] epoch_done_generation;
logic [31:0] epoch_done_component;
logic coverage_valid;
logic coverage_ready;
logic [3:0] coverage_bank;
logic [1:0] coverage_component;
logic [31:0] coverage_generation;
logic [31:0] coverage_transaction_id;
logic [4:0] coverage_role;
logic coverage_data_complete;
logic coverage_scale_complete;
logic fault_valid;
logic [3:0] fault_bank;
logic [7:0] fault_error_code;
smollm2_native_bank_pool dut(.clk(clk),
.resetn(resetn),
.rd_valid(rd_valid),
.rd_ready(rd_ready),
.rd_word_address(rd_word_address),
.rd_wide(rd_wide),
.rd_resp_valid(rd_resp_valid),
.rd_data(rd_data),
.wr_valid(wr_valid),
.wr_ready(wr_ready),
.wr_word_address(wr_word_address),
.wr_data(wr_data),
.wr_strb(wr_strb),
.wr_transaction_id(wr_transaction_id),
.wr_generation(wr_generation),
.wr_role(wr_role),
.wr_commit(wr_commit),
.wr_pending(wr_pending),
.coverage_pending(coverage_pending),
.bank_quiescent(bank_quiescent),
.bank_ready(bank_ready),
.epoch_valid(epoch_valid),
.epoch_ready(epoch_ready),
.epoch_error_code(epoch_error_code),
.epoch_bank(epoch_bank),
.epoch_component(epoch_component),
.epoch_token(epoch_token),
.epoch_generation(epoch_generation),
.epoch_profile(epoch_profile),
.epoch_rows(epoch_rows),
.epoch_cols(epoch_cols),
.epoch_position(epoch_position),
.epoch_layer(epoch_layer),
.epoch_data_offset(epoch_data_offset),
.epoch_data_bytes(epoch_data_bytes),
.epoch_scale_offset(epoch_scale_offset),
.epoch_scale_bytes(epoch_scale_bytes),
.epoch_done_valid(epoch_done_valid),
.epoch_done_ready(epoch_done_ready),
.epoch_done_token(epoch_done_token),
.epoch_done_generation(epoch_done_generation),
.epoch_done_component(epoch_done_component),
.coverage_valid(coverage_valid),
.coverage_ready(coverage_ready),
.coverage_bank(coverage_bank),
.coverage_component(coverage_component),
.coverage_generation(coverage_generation),
.coverage_transaction_id(coverage_transaction_id),
.coverage_role(coverage_role),
.coverage_data_complete(coverage_data_complete),
.coverage_scale_complete(coverage_scale_complete),
.fault_valid(fault_valid),
.fault_bank(fault_bank),
.fault_error_code(fault_error_code));
localparam int WORDS[0:15]='{2304,2304,2304,18464,2304,2304,768,376,12290,12292,36864,2304,6144,18438,1158,18440};
localparam int BASE[0:15]='{0,2304,4608,6912,25376,27680,29984,30752,31128,43418,55710,92574,94878,101022,119460,120618};
logic [127:0] shadow[0:139057];
logic [15:0] shadow_known[0:139057];
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
rd_valid=0;
rd_word_address=0;
rd_wide=0;
wr_valid=0;
wr_word_address=0;
wr_data=0;
wr_strb=0;
wr_transaction_id=0;
wr_generation=0;
wr_role=0;
epoch_valid=0;
epoch_bank=0;
epoch_component=0;
epoch_token=0;
epoch_generation=0;
epoch_profile=0;
epoch_rows=0;
epoch_cols=0;
epoch_position=0;
epoch_layer=0;
epoch_data_offset=0;
epoch_data_bytes=0;
epoch_scale_offset=0;
epoch_scale_bytes=0;
epoch_done_ready=0;
coverage_ready=0;
 for(int k=0;k<=139057;k++)begin shadow_known[k]=0;shadow[k]=0;end
 initialize();
 configure(0,0,1,1,1,576,0,1152, 0,0);
 configure(1,0,1,2,1,576,0,1152, 0,0);
 configure(2,0,1,3,1,576,0,1152, 0,0);
 configure(3,0,1,4,1,576,0,576, 294912,16);
 configure(4,0,1,7,1,576,0,1152, 0,0);
 configure(5,0,1,8,1,192,0,384, 0,0);
 configure(6,0,1,10,1,192,0,384, 0,0);
 configure(7,0,1,11,1,64,0,128, 4096,1920);
 configure(8,0,1,12,1,192,0,192, 196608,16);
 configure(9,0,1,14,1,192,0,192, 196608,48);
 configure(10,0,1,16,1,1,0,288, 0,0);
 configure(11,0,1,19,1,576,0,1152, 0,0);
 configure(12,0,1,20,1,49152,0,98304, 0,0);
 configure(13,0,1,21,1,576,0,576, 294912,16);
 configure(14,0,1,23,1,576,0,576, 18432,48);
 configure(15,0,1,4,1,576,0,576, 294912,16);
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
