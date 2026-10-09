`timescale 1ns/1ps
// Independent testbench: external PS/DDR signals only. All tensor storage and
// numerical execution reside in the actual DUT's pinned XPM/compute children.
module audit_projection_negative_tb;
logic clk;
logic resetn;
logic start;
logic program_wr_valid;
logic [3:0] program_wr_address;
logic [127:0] program_wr_data;
logic [15:0] program_wr_strb;
logic m_axis_mm2s_cmd_tready;
logic [127:0] s_axis_mm2s_tdata;
logic [15:0] s_axis_mm2s_tkeep;
logic s_axis_mm2s_tvalid;
logic s_axis_mm2s_tlast;
logic [7:0] s_axis_mm2s_sts_tdata;
logic s_axis_mm2s_sts_tkeep;
logic s_axis_mm2s_sts_tvalid;
logic s_axis_mm2s_sts_tlast;
logic m_axis_s2mm_cmd_tready;
logic m_axis_s2mm_tready;
logic [7:0] s_axis_s2mm_sts_tdata;
logic s_axis_s2mm_sts_tkeep;
logic s_axis_s2mm_sts_tvalid;
logic s_axis_s2mm_sts_tlast;
logic start_ready;
logic program_wr_ready;
logic initialized;
logic busy;
logic done;
logic error;
logic [7:0] error_code;
logic [3:0] current_pc;
logic [71:0] m_axis_mm2s_cmd_tdata;
logic m_axis_mm2s_cmd_tvalid;
logic s_axis_mm2s_tready;
logic s_axis_mm2s_sts_tready;
logic [71:0] m_axis_s2mm_cmd_tdata;
logic m_axis_s2mm_cmd_tvalid;
logic [127:0] m_axis_s2mm_tdata;
logic [15:0] m_axis_s2mm_tkeep;
logic m_axis_s2mm_tvalid;
logic m_axis_s2mm_tlast;
logic s_axis_s2mm_sts_tready;
logic [1:0] dma_faulted;
logic [15:0] dma_fault_reason;
logic [7:0] dma_fault_bank;
logic [63:0] dma_fault_transaction_id;
logic [15:0] dma_fault_raw_status;
logic [7:0] dma_fault_received_tag;
logic [7:0] dma_fault_internal_tag;
smollm2_execution_fabric dut(.clk(clk),
.resetn(resetn),
.start(start),
.program_wr_valid(program_wr_valid),
.program_wr_address(program_wr_address),
.program_wr_data(program_wr_data),
.program_wr_strb(program_wr_strb),
.m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
.s_axis_mm2s_tdata(s_axis_mm2s_tdata),
.s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),
.s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),
.s_axis_mm2s_tlast(s_axis_mm2s_tlast),
.s_axis_mm2s_sts_tdata(s_axis_mm2s_sts_tdata),
.s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),
.s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid),
.s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),
.m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready),
.m_axis_s2mm_tready(m_axis_s2mm_tready),
.s_axis_s2mm_sts_tdata(s_axis_s2mm_sts_tdata),
.s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),
.s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid),
.s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),
.start_ready(start_ready),
.program_wr_ready(program_wr_ready),
.initialized(initialized),
.busy(busy),
.done(done),
.error(error),
.error_code(error_code),
.current_pc(current_pc),
.m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
.m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
.s_axis_mm2s_tready(s_axis_mm2s_tready),
.s_axis_mm2s_sts_tready(s_axis_mm2s_sts_tready),
.m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
.m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),
.m_axis_s2mm_tdata(m_axis_s2mm_tdata),
.m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),
.m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
.m_axis_s2mm_tlast(m_axis_s2mm_tlast),
.s_axis_s2mm_sts_tready(s_axis_s2mm_sts_tready),
.dma_faulted(dma_faulted),
.dma_fault_reason(dma_fault_reason),
.dma_fault_bank(dma_fault_bank),
.dma_fault_transaction_id(dma_fault_transaction_id),
.dma_fault_raw_status(dma_fault_raw_status),
.dma_fault_received_tag(dma_fault_received_tag),
.dma_fault_internal_tag(dma_fault_internal_tag));
localparam integer ASSETS=20, MAX_BYTES=36864, STAGES=4;
logic [7:0] asset_bytes[ASSETS][MAX_BYTES];
bit asset_written[ASSETS][MAX_BYTES];
integer asset_base[ASSETS],asset_size[ASSETS];
bit asset_output[ASSETS];
logic [127:0] programs[STAGES][16];
integer cycle=0,checks=0,read_bytes=0,stored_bytes=0;
integer load_commands=0,store_commands=0,load_bubbles=0,store_stalls=0;
integer command_stalls=0,status_delay_cycles=0;
integer expected_load_address[128],expected_load_length[128],expected_load_tag[128];
integer expected_store_address[128],expected_store_length[128],expected_store_tag[128];
integer la[128],ln[128],lt[128],sa[128],sn[128],st[128];
integer lw=0,lr=0,sw=0,sr=0,lo=0,so=0;
integer load_status_wait=0,store_status_wait=0,load_cmd_wait=0,store_cmd_wait=0;
bit load_status_phase=0,store_status_phase=0;
bit cmd_load_hold=0,cmd_store_hold=0,data_store_hold=0;
logic [71:0] held_load_cmd,held_store_cmd;
logic [127:0] held_store_data;
logic [15:0] held_store_keep;
bit held_store_last;
integer witness_b15_overlap=0,witness_b3_active_writes=0; bit expect_reject=0;
// Optional read-only monitor is added after exact implementation source freeze.
// A prepared TB does not claim this witness before the hook has been bound.
function automatic integer find_asset(input integer address,input integer length,input bit output_kind);
 integer found;
 begin
  found=-1;
  for(integer i=0;i<ASSETS;i=i+1)
   if(asset_output[i]==output_kind && address>=asset_base[i] &&
      longint'(address)+length<=longint'(asset_base[i])+asset_size[i])found=i;
  find_asset=found;
 end
endfunction
function automatic logic[7:0] read_ddr(input integer address);
 integer a;
 begin
  a=find_asset(address,1,0);
  if(a<0)$fatal(1,"DDR read outside immutable input image at %h",address);
  read_ddr=asset_bytes[a][address-asset_base[a]];
 end
endfunction
initial begin clk=0;forever #2.5 clk=~clk;end
// Only the external testbench uses blocking procedural state. Drive on negedge,
// sample on posedge, separating every acceptance from subsequent payload update.
always @(negedge clk) begin
 if(!resetn)begin
  m_axis_mm2s_cmd_tready=0;m_axis_s2mm_cmd_tready=0;
  s_axis_mm2s_tvalid=0;s_axis_mm2s_tdata=0;s_axis_mm2s_tkeep=0;s_axis_mm2s_tlast=0;
  s_axis_mm2s_sts_tvalid=0;s_axis_mm2s_sts_tdata=0;
  s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;
  s_axis_s2mm_sts_tvalid=0;s_axis_s2mm_sts_tdata=0;
  s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;m_axis_s2mm_tready=0;
 end else begin
  m_axis_mm2s_cmd_tready=(load_cmd_wait>=3 && lw<128);
  m_axis_s2mm_cmd_tready=(store_cmd_wait>=3 && sw<128);
  m_axis_s2mm_tready=(sr<sw && !store_status_phase && cycle%11>=4);
  if(!(s_axis_mm2s_tvalid && !s_axis_mm2s_tready))begin
   s_axis_mm2s_tvalid=0;
   if(lr<lw && !load_status_phase && cycle%9>=3)begin
    s_axis_mm2s_tvalid=1;s_axis_mm2s_tkeep=16'hffff;
    s_axis_mm2s_tlast=(lo+16==ln[lr]);
    for(integer b=0;b<16;b=b+1)s_axis_mm2s_tdata[b*8+:8]=read_ddr(la[lr]+lo+b);
   end
  end
  // Status is issued only after all accepted bytes, with five explicit delay
  // cycles; its valid/data remain unchanged until actual status acceptance.
  if(!(s_axis_mm2s_sts_tvalid && !s_axis_mm2s_sts_tready))begin
   s_axis_mm2s_sts_tvalid=(load_status_phase && load_status_wait>=5);
   if(s_axis_mm2s_sts_tvalid)s_axis_mm2s_sts_tdata=8'h80|8'(lt[lr]);
  end
  if(!(s_axis_s2mm_sts_tvalid && !s_axis_s2mm_sts_tready))begin
   s_axis_s2mm_sts_tvalid=(store_status_phase && store_status_wait>=5);
   if(s_axis_s2mm_sts_tvalid)s_axis_s2mm_sts_tdata=8'h80|8'(st[sr]);
  end
 end
end
always @(posedge clk)begin
 integer address,length,a;
 if(resetn)begin
  cycle=cycle+1;
  if(cycle>80000000)$fatal(1,"timeout suite=projection_fragments pc=%0d busy=%b",current_pc,busy);
  if((error&&!expect_reject)||(|dma_faulted))$fatal(1,"unexpected error suite=projection_fragments cycle=%0d pc=%0d code=%h DMA=%h",cycle,current_pc,error_code,dma_faulted);
  if(m_axis_s2mm_cmd_tvalid||m_axis_s2mm_tvalid)$fatal(1,"partial GEMMprojection issued external STORE");
  if(cmd_load_hold && (!m_axis_mm2s_cmd_tvalid||m_axis_mm2s_cmd_tdata!==held_load_cmd))$fatal(1,"MM2S command stalled change");
  if(cmd_store_hold && (!m_axis_s2mm_cmd_tvalid||m_axis_s2mm_cmd_tdata!==held_store_cmd))$fatal(1,"S2MM command stalled change");
  if(data_store_hold && (!m_axis_s2mm_tvalid||m_axis_s2mm_tdata!==held_store_data||m_axis_s2mm_tkeep!==held_store_keep||m_axis_s2mm_tlast!==held_store_last))$fatal(1,"S2MM data stalled change");
  cmd_load_hold=m_axis_mm2s_cmd_tvalid&&!m_axis_mm2s_cmd_tready;held_load_cmd=m_axis_mm2s_cmd_tdata;
  cmd_store_hold=m_axis_s2mm_cmd_tvalid&&!m_axis_s2mm_cmd_tready;held_store_cmd=m_axis_s2mm_cmd_tdata;
  data_store_hold=m_axis_s2mm_tvalid&&!m_axis_s2mm_tready;held_store_data=m_axis_s2mm_tdata;held_store_keep=m_axis_s2mm_tkeep;held_store_last=m_axis_s2mm_tlast;
  if(cmd_load_hold||cmd_store_hold)command_stalls=command_stalls+1;
  if(data_store_hold)store_stalls=store_stalls+1;
  if(m_axis_mm2s_cmd_tvalid)load_cmd_wait=load_cmd_wait+1;
  if(m_axis_s2mm_cmd_tvalid)store_cmd_wait=store_cmd_wait+1;
  if(m_axis_mm2s_cmd_tvalid&&m_axis_mm2s_cmd_tready)begin
   address=int'(m_axis_mm2s_cmd_tdata[63:32]);length=int'(m_axis_mm2s_cmd_tdata[22:0]);
   if(length==0||(address%16)||(length%16)||find_asset(address,length,0)<0)$fatal(1,"invalid MM2S command %h",m_axis_mm2s_cmd_tdata);
   if(m_axis_mm2s_cmd_tdata[71:68]!==0 || m_axis_mm2s_cmd_tdata[31:23]!==9'b010000001)$fatal(1,"MM2S command control bits");
   if(lw>=19||address!=expected_load_address[lw]||length!=expected_load_length[lw]||int'(m_axis_mm2s_cmd_tdata[67:64])!=expected_load_tag[lw])$fatal(1,"MM2S ISA address/length/bank tag mismatch command%0d",lw);
   la[lw]=address;ln[lw]=length;lt[lw]=int'(m_axis_mm2s_cmd_tdata[67:64]);lw=lw+1;load_commands=load_commands+1;load_cmd_wait=0;checks=checks+1;
  end
  if(m_axis_s2mm_cmd_tvalid&&m_axis_s2mm_cmd_tready)begin
   address=int'(m_axis_s2mm_cmd_tdata[63:32]);length=int'(m_axis_s2mm_cmd_tdata[22:0]);
   if(length==0||(address%16)||(length%16)||find_asset(address,length,1)<0)$fatal(1,"invalid S2MM command %h",m_axis_s2mm_cmd_tdata);
   if(m_axis_s2mm_cmd_tdata[71:68]!==0 || m_axis_s2mm_cmd_tdata[31:23]!==9'b010000001)$fatal(1,"S2MM command control bits");
   if(sw>=1||address!=expected_store_address[sw]||length!=expected_store_length[sw]||int'(m_axis_s2mm_cmd_tdata[67:64])!=expected_store_tag[sw])$fatal(1,"S2MM ISA address/length/bank tag mismatch command%0d",sw);
   sa[sw]=address;sn[sw]=length;st[sw]=int'(m_axis_s2mm_cmd_tdata[67:64]);sw=sw+1;store_commands=store_commands+1;store_cmd_wait=0;checks=checks+1;
  end
  if(load_status_phase)begin load_status_wait=load_status_wait+1;status_delay_cycles=status_delay_cycles+1;end
  if(store_status_phase)begin store_status_wait=store_status_wait+1;status_delay_cycles=status_delay_cycles+1;end
  if(lr<lw&&!load_status_phase&&!s_axis_mm2s_tvalid)load_bubbles=load_bubbles+1;
  if(s_axis_mm2s_tvalid&&s_axis_mm2s_tready)begin
   if(lr>=lw||load_status_phase)$fatal(1,"uncommanded MM2S acceptance");
   if(s_axis_mm2s_tkeep!==16'hffff||s_axis_mm2s_tlast!==(lo+16==ln[lr]))$fatal(1,"MM2S BFM span");
   lo=lo+16;read_bytes=read_bytes+16;
   if(lo==ln[lr])begin load_status_phase=1;load_status_wait=0;end
  end
  if(m_axis_s2mm_tvalid&&m_axis_s2mm_tready)begin
   if(sr>=sw||store_status_phase||so+16>sn[sr])$fatal(1,"uncommanded/extra S2MM data");
   if(m_axis_s2mm_tkeep!==16'hffff||m_axis_s2mm_tlast!==(so+16==sn[sr]))$fatal(1,"S2MM KEEP/TLAST wrong at byte%0d",so);
   a=find_asset(sa[sr]+so,16,1);if(a<0)$fatal(1,"S2MM touched canary beyond output image");
   for(integer b=0;b<16;b=b+1)begin
    if(m_axis_s2mm_tdata[b*8+:8]!==asset_bytes[a][sa[sr]+so+b-asset_base[a]])$fatal(1,"numeric mismatch asset%0d byte%0d actual%h expected%h",a,sa[sr]+so+b-asset_base[a],m_axis_s2mm_tdata[b*8+:8],asset_bytes[a][sa[sr]+so+b-asset_base[a]]);
    asset_written[a][sa[sr]+so+b-asset_base[a]]=1;checks=checks+1;
   end
   so=so+16;stored_bytes=stored_bytes+16;
   if(so==sn[sr])begin store_status_phase=1;store_status_wait=0;end
  end
  if(s_axis_mm2s_sts_tvalid&&s_axis_mm2s_sts_tready)begin
   if(!load_status_phase||lo!=ln[lr])$fatal(1,"early MM2S success");
   lr=lr+1;lo=0;load_status_phase=0;load_status_wait=0;
  end
  if(s_axis_s2mm_sts_tvalid&&s_axis_s2mm_sts_tready)begin
   if(!store_status_phase||so!=sn[sr])$fatal(1,"early S2MM success");
   sr=sr+1;so=0;store_status_phase=0;store_status_wait=0;
  end
 end
end
initial begin
 resetn=0;start=0;program_wr_valid=0;program_wr_address=0;program_wr_data=0;program_wr_strb=0;
 for(integer a=0;a<ASSETS;a=a+1)for(integer b=0;b<MAX_BYTES;b=b+1)asset_written[a][b]=0;
 asset_base[0]=32'h00100000; asset_size[0]=1152; asset_output[0]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/activation.bytehex",asset_bytes[0],0,1151);
asset_base[1]=32'h00200000; asset_size[1]=36864; asset_output[1]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_0.bytehex",asset_bytes[1],0,36863);
asset_base[2]=32'h00600000; asset_size[2]=16; asset_output[2]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_0.bytehex",asset_bytes[2],0,15);
asset_base[3]=32'h00210000; asset_size[3]=36864; asset_output[3]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_1.bytehex",asset_bytes[3],0,36863);
asset_base[4]=32'h00600100; asset_size[4]=16; asset_output[4]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_1.bytehex",asset_bytes[4],0,15);
asset_base[5]=32'h00220000; asset_size[5]=36864; asset_output[5]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_2.bytehex",asset_bytes[5],0,36863);
asset_base[6]=32'h00600200; asset_size[6]=16; asset_output[6]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_2.bytehex",asset_bytes[6],0,15);
asset_base[7]=32'h00230000; asset_size[7]=36864; asset_output[7]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_3.bytehex",asset_bytes[7],0,36863);
asset_base[8]=32'h00600300; asset_size[8]=16; asset_output[8]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_3.bytehex",asset_bytes[8],0,15);
asset_base[9]=32'h00240000; asset_size[9]=36864; asset_output[9]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_4.bytehex",asset_bytes[9],0,36863);
asset_base[10]=32'h00600400; asset_size[10]=16; asset_output[10]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_4.bytehex",asset_bytes[10],0,15);
asset_base[11]=32'h00250000; asset_size[11]=36864; asset_output[11]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_5.bytehex",asset_bytes[11],0,36863);
asset_base[12]=32'h00600500; asset_size[12]=16; asset_output[12]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_5.bytehex",asset_bytes[12],0,15);
asset_base[13]=32'h00260000; asset_size[13]=36864; asset_output[13]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_6.bytehex",asset_bytes[13],0,36863);
asset_base[14]=32'h00600600; asset_size[14]=16; asset_output[14]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_6.bytehex",asset_bytes[14],0,15);
asset_base[15]=32'h00270000; asset_size[15]=36864; asset_output[15]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_7.bytehex",asset_bytes[15],0,36863);
asset_base[16]=32'h00600700; asset_size[16]=16; asset_output[16]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_7.bytehex",asset_bytes[16],0,15);
asset_base[17]=32'h00280000; asset_size[17]=36864; asset_output[17]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/weight_8.bytehex",asset_bytes[17],0,36863);
asset_base[18]=32'h00600800; asset_size[18]=16; asset_output[18]=0;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/scale_8.bytehex",asset_bytes[18],0,15);
asset_base[19]=32'h00700000; asset_size[19]=1152; asset_output[19]=1;
$readmemh("/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/native_fabric_boundary_audit/projection_negative_missing_last_tile/output.bytehex",asset_bytes[19],0,1151);
expected_load_address[0]=32'h00100000; expected_load_length[0]=1152; expected_load_tag[0]=2;
expected_load_address[1]=32'h00200000; expected_load_length[1]=36864; expected_load_tag[1]=3;
expected_load_address[2]=32'h00600000; expected_load_length[2]=16; expected_load_tag[2]=3;
expected_load_address[3]=32'h00210000; expected_load_length[3]=36864; expected_load_tag[3]=15;
expected_load_address[4]=32'h00600100; expected_load_length[4]=16; expected_load_tag[4]=15;
expected_load_address[5]=32'h00220000; expected_load_length[5]=36864; expected_load_tag[5]=3;
expected_load_address[6]=32'h00600200; expected_load_length[6]=16; expected_load_tag[6]=3;
expected_load_address[7]=32'h00230000; expected_load_length[7]=36864; expected_load_tag[7]=15;
expected_load_address[8]=32'h00600300; expected_load_length[8]=16; expected_load_tag[8]=15;
expected_load_address[9]=32'h00240000; expected_load_length[9]=36864; expected_load_tag[9]=3;
expected_load_address[10]=32'h00600400; expected_load_length[10]=16; expected_load_tag[10]=3;
expected_load_address[11]=32'h00250000; expected_load_length[11]=36864; expected_load_tag[11]=15;
expected_load_address[12]=32'h00600500; expected_load_length[12]=16; expected_load_tag[12]=15;
expected_load_address[13]=32'h00260000; expected_load_length[13]=36864; expected_load_tag[13]=3;
expected_load_address[14]=32'h00600600; expected_load_length[14]=16; expected_load_tag[14]=3;
expected_load_address[15]=32'h00270000; expected_load_length[15]=36864; expected_load_tag[15]=15;
expected_load_address[16]=32'h00600700; expected_load_length[16]=16; expected_load_tag[16]=15;
expected_load_address[17]=32'h00280000; expected_load_length[17]=36864; expected_load_tag[17]=3;
expected_load_address[18]=32'h00600800; expected_load_length[18]=16; expected_load_tag[18]=3;
expected_store_address[0]=32'h00700000; expected_store_length[0]=1152; expected_store_tag[0]=4;
programs[0][0]=128'hf2000000000000000002000002400023;
programs[0][1]=128'h12000000000000090000200000000000;
programs[0][2]=128'hd20d0000000000000000000001200200;
programs[0][3]=128'hf4000000000000000002000002400027;
programs[0][4]=128'hf3000000000000000002000002400804;
programs[0][5]=128'h13000000000001200000400000000000;
programs[0][6]=128'h13000004800000002000c00000000000;
programs[0][7]=128'h3d3400000000000000000120000a4040;
programs[0][8]=128'hff000000000000000002000002400804;
programs[0][9]=128'h1f000000000001200000420000000000;
programs[0][10]=128'h1f000004800000002000c00200000000;
programs[0][11]=128'h3df400000000000000200120000a4040;
programs[0][12]=128'hf3000000000000000004000002400804;
programs[0][13]=128'h13000000000001200000440000000000;
programs[0][14]=128'h13000004800000002000c00400000000;
programs[0][15]=128'h00000000000000000000000000000000;
programs[1][0]=128'h3d3400000000000000400120000a4040;
programs[1][1]=128'hff000000000000000004000002400804;
programs[1][2]=128'h1f000000000001200000460000000000;
programs[1][3]=128'h1f000004800000002000c00600000000;
programs[1][4]=128'h3df400000000000000600120000a4040;
programs[1][5]=128'hf3000000000000000006000002400804;
programs[1][6]=128'h13000000000001200000480000000000;
programs[1][7]=128'h13000004800000002000c00800000000;
programs[1][8]=128'h3d3400000000000000800120000a4040;
programs[1][9]=128'hff000000000000000006000002400804;
programs[1][10]=128'h1f0000000000012000004a0000000000;
programs[1][11]=128'h1f000004800000002000c00a00000000;
programs[1][12]=128'h3df400000000000000a00120000a4040;
programs[1][13]=128'hf3000000000000000008000002400804;
programs[1][14]=128'h130000000000012000004c0000000000;
programs[1][15]=128'h00000000000000000000000000000000;
programs[2][0]=128'h13000004800000002000c00c00000000;
programs[2][1]=128'h3d3400000000000000c00120000a4040;
programs[2][2]=128'hff000000000000000008000002400804;
programs[2][3]=128'h1f0000000000012000004e0000000000;
programs[2][4]=128'h1f000004800000002000c00e00000000;
programs[2][5]=128'h3df400000000000000e00120000a4040;
programs[2][6]=128'hf300000000000000000a000002400804;
programs[2][7]=128'h13000000000001200000500000000000;
programs[2][8]=128'h13000004800000002000c01000000000;
programs[2][9]=128'h00000000000000000000000000000000;
programs[2][10]=128'h00000000000000000000000000000000;
programs[2][11]=128'h00000000000000000000000000000000;
programs[2][12]=128'h00000000000000000000000000000000;
programs[2][13]=128'h00000000000000000000000000000000;
programs[2][14]=128'h00000000000000000000000000000000;
programs[2][15]=128'h00000000000000000000000000000000;
programs[3][0]=128'h24000000000000010000e00000000000;
programs[3][1]=128'h00000000000000000000000000000000;
programs[3][2]=128'h00000000000000000000000000000000;
programs[3][3]=128'h00000000000000000000000000000000;
programs[3][4]=128'h00000000000000000000000000000000;
programs[3][5]=128'h00000000000000000000000000000000;
programs[3][6]=128'h00000000000000000000000000000000;
programs[3][7]=128'h00000000000000000000000000000000;
programs[3][8]=128'h00000000000000000000000000000000;
programs[3][9]=128'h00000000000000000000000000000000;
programs[3][10]=128'h00000000000000000000000000000000;
programs[3][11]=128'h00000000000000000000000000000000;
programs[3][12]=128'h00000000000000000000000000000000;
programs[3][13]=128'h00000000000000000000000000000000;
programs[3][14]=128'h00000000000000000000000000000000;
programs[3][15]=128'h00000000000000000000000000000000;
 repeat(8)@(negedge clk);resetn=1;
 wait(initialized===1 && start_ready===1);
 for(integer stage=0;stage<STAGES;stage=stage+1)begin
  for(integer p=0;p<16;p=p+1)begin
   @(negedge clk);program_wr_valid=1;program_wr_address=4'(p);program_wr_data=programs[stage][p];program_wr_strb=16'hffff;
   do @(posedge clk);while(!program_wr_ready);
  end
  @(negedge clk);program_wr_valid=0;
  expect_reject=(stage==STAGES-1);wait(start_ready===1);@(negedge clk);start=1;@(posedge clk);
  if(!start_ready)$fatal(1,"START not accepted");
  @(negedge clk);start=0;
  if(expect_reject)begin wait(error===1 && busy===0);if(error_code!=4||dma_faulted!=0)$fatal(1,"partialprojection wrongerror %h",error_code);end
  else begin wait(done===1);if(busy||error)$fatal(1,"done/error mismatch");end
  if(lr!=lw||sr!=sw||load_status_phase||store_status_phase)$fatal(1,"done precedes DDR drain");
  $display("STAGE_COMPLETE suite=projection_fragments stage=%0d cycle=%0d checks=%0d",stage,cycle,checks);
  repeat(8)@(negedge clk);
 end
 if(lw!=19||sw!=0)$fatal(1,"missing DMA commands");
 if(command_stalls==0||load_bubbles==0||status_delay_cycles==0)$fatal(1,"stall coverage missing");
 $display("NUMERICAL_COUNTS checks=%0d read_bytes=%0d stored_bytes=%0d load_commands=%0d store_commands=%0d cycles=%0d cmdstall=%0d loadbubble=%0d storestall=%0d statusdelay=%0d",checks,read_bytes,stored_bytes,load_commands,store_commands,cycle,command_stalls,load_bubbles,store_stalls,status_delay_cycles);
 $display("AUDIT_PROJECTION_NEGATIVE_PASS_missing_last_tile");$finish;
end
endmodule
