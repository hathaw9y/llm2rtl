`timescale 1ns/1ps
// Independent testbench: external PS/DDR signals only. All tensor storage and
// numerical execution reside in the actual DUT's pinned XPM/compute children.
module audit_fabric_tb;
@DECLARATIONS@
smollm2_execution_fabric dut(@CONNECTIONS@);
localparam integer ASSETS=@ASSETS@, MAX_BYTES=@MAX_BYTES@, STAGES=@STAGES@;
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
integer witness_b15_overlap=0,witness_b3_active_writes=0;
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
  if(cycle>80000000)$fatal(1,"timeout suite=@SUITE@ pc=%0d busy=%b",current_pc,busy);
  if(error||(|dma_faulted))$fatal(1,"unexpected error suite=@SUITE@ cycle=%0d pc=%0d code=%h DMA=%h",cycle,current_pc,error_code,dma_faulted);
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
   if(lw>=@LOAD_COMMANDS@||address!=expected_load_address[lw]||length!=expected_load_length[lw]||int'(m_axis_mm2s_cmd_tdata[67:64])!=expected_load_tag[lw])$fatal(1,"MM2S ISA address/length/bank tag mismatch command%0d",lw);
   la[lw]=address;ln[lw]=length;lt[lw]=int'(m_axis_mm2s_cmd_tdata[67:64]);lw=lw+1;load_commands=load_commands+1;load_cmd_wait=0;checks=checks+1;
  end
  if(m_axis_s2mm_cmd_tvalid&&m_axis_s2mm_cmd_tready)begin
   address=int'(m_axis_s2mm_cmd_tdata[63:32]);length=int'(m_axis_s2mm_cmd_tdata[22:0]);
   if(length==0||(address%16)||(length%16)||find_asset(address,length,1)<0)$fatal(1,"invalid S2MM command %h",m_axis_s2mm_cmd_tdata);
   if(m_axis_s2mm_cmd_tdata[71:68]!==0 || m_axis_s2mm_cmd_tdata[31:23]!==9'b010000001)$fatal(1,"S2MM command control bits");
   if(sw>=@STORE_COMMANDS@||address!=expected_store_address[sw]||length!=expected_store_length[sw]||int'(m_axis_s2mm_cmd_tdata[67:64])!=expected_store_tag[sw])$fatal(1,"S2MM ISA address/length/bank tag mismatch command%0d",sw);
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
 @INITIALIZE@
 repeat(8)@(negedge clk);resetn=1;
 wait(initialized===1 && start_ready===1);
 for(integer stage=0;stage<STAGES;stage=stage+1)begin
  for(integer p=0;p<16;p=p+1)begin
   @(negedge clk);program_wr_valid=1;program_wr_address=4'(p);program_wr_data=programs[stage][p];program_wr_strb=16'hffff;
   do @(posedge clk);while(!program_wr_ready);
  end
  @(negedge clk);program_wr_valid=0;
  wait(start_ready===1);@(negedge clk);start=1;@(posedge clk);
  if(!start_ready)$fatal(1,"START not accepted");
  @(negedge clk);start=0;wait(done===1);
  if(busy||error)$fatal(1,"done/error mismatch");
  if(lr!=lw||sr!=sw||load_status_phase||store_status_phase)$fatal(1,"done precedes DDR drain");
  $display("STAGE_COMPLETE suite=@SUITE@ stage=%0d cycle=%0d checks=%0d",stage,cycle,checks);
  repeat(8)@(negedge clk);
 end
 for(integer a=0;a<ASSETS;a=a+1)if(asset_output[a])for(integer b=0;b<asset_size[a];b=b+1)if(!asset_written[a][b])$fatal(1,"missing output byte asset%0d byte%0d",a,b);
 if(lw!=@LOAD_COMMANDS@||sw!=@STORE_COMMANDS@)$fatal(1,"missing DMA commands");
 if(command_stalls==0||load_bubbles==0||store_stalls==0||status_delay_cycles==0)$fatal(1,"stall coverage missing");
 $display("NUMERICAL_COUNTS checks=%0d read_bytes=%0d stored_bytes=%0d load_commands=%0d store_commands=%0d cycles=%0d cmdstall=%0d loadbubble=%0d storestall=%0d statusdelay=%0d",checks,read_bytes,stored_bytes,load_commands,store_commands,cycle,command_stalls,load_bubbles,store_stalls,status_delay_cycles);
 $display("PASS_INDEPENDENT_FABRIC_NUMERICAL_@SUITE@");$finish;
end
endmodule
