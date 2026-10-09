module audit_quant_terminal_fault_tb;
logic clk;
logic resetn;
logic cmd_valid;
logic [3:0] cmd_opcode;
logic [111:0] cmd_payload;
logic [11:0] cmd_bank_ids;
logic [31:0] cmd_transaction_id;
logic [95:0] cmd_generations;
logic cmd_ready;
logic [2:0] cmd_desc_present;
logic [14:0] cmd_profiles;
logic [32:0] cmd_rows;
logic [47:0] cmd_cols;
logic [29:0] cmd_positions;
logic [14:0] cmd_layers;
logic [95:0] cmd_desc_generations;
logic [2:0] cmd_data_valid;
logic [2:0] cmd_scale_valid;
logic [2:0] cmd_desc_busy;
logic [14:0] cmd_desc_owner;
logic cmd_b7_static_valid;
logic [63:0] cmd_embedding_lanes;
logic [31:0] cmd_embedding_lane_valid;
logic [4:0] a_role;
logic [4:0] b_role;
logic [4:0] c_role;
logic a_rd_valid;
logic [3:0] a_rd_bank;
logic [18:0] a_rd_address;
logic a_rd_wide;
logic b_rd_valid;
logic [3:0] b_rd_bank;
logic [18:0] b_rd_address;
logic b_rd_wide;
logic a_rd_ready;
logic a_rd_resp_valid;
logic [127:0] a_rd_data;
logic b_rd_ready;
logic b_rd_resp_valid;
logic [127:0] b_rd_data;
logic c_wr_valid;
logic [3:0] c_wr_bank;
logic [18:0] c_wr_address;
logic [127:0] c_wr_data;
logic [15:0] c_wr_strb;
logic c_wr_ready;
logic resp_valid;
logic [31:0] resp_transaction_id;
logic [2:0] resp_used_bank_mask;
logic [1:0] resp_used_bank_count;
logic [11:0] resp_bank_ids;
logic [95:0] resp_generations;
logic [7:0] resp_error_code;
logic resp_ready;
logic dst_begin_valid;
logic [3:0] dst_begin_bank;
logic [31:0] dst_begin_accepted_generation;
logic [31:0] dst_begin_generation;
logic [4:0] dst_begin_profile;
logic [10:0] dst_begin_rows;
logic [15:0] dst_begin_cols;
logic [9:0] dst_begin_position;
logic [4:0] dst_begin_layer;
logic dst_begin_ready;
logic [7:0] dst_begin_error_code;
logic dst_invalidate_valid;
logic [3:0] dst_invalidate_bank;
logic [31:0] dst_invalidate_generation;
logic dst_invalidate_ready;

smollm2_quantization_executor dut(.*);
initial clk=0;always #2.5 clk=~clk;
logic[127:0] amem[0:36863],bmem[0:36863],cmem[0:36863],expected[0:36863],mask[0:36863],written[0:36863];
logic[2:0]av,bv;logic[127:0]ad[0:2],bd[0:2];
integer acap,bcap,ccap,status,begin_expected,cgen,ep,er,ec,eq,el;
integer audit_scale_offers=0,audit_c_offers=0;
 always @(posedge clk)if(resetn)begin if(dut.q_sv&&(dut.state_r==dut.SCALE_GEN||dut.state_r==dut.SCALE_DRAIN))audit_scale_offers<=audit_scale_offers+1;if(c_wr_valid)audit_c_offers<=audit_c_offers+1;end
 integer fault=0,hold_count=0;logic saw_fault_stall=0;integer f,rc,cycles=0,writes=0,begins=0,invalidations=0,ca=0,cb=0;
logic[31:0]rng=32'hcab0fe21;string path;
logic[31:0]txn;logic[95:0]gens;logic[11:0]banks;
logic ah,bh,ch,qh,dh;logic[18:0]aa,ba;logic[162:0]cp;logic[292:0]qp;logic[259:0]dp;
assign a_rd_resp_valid=av[2];assign a_rd_data=ad[2];assign b_rd_resp_valid=bv[2];assign b_rd_data=bd[2];
always @(negedge clk)begin
 rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 a_rd_ready=rng[2:0]!=0;b_rd_ready=rng[5:3]!=0;c_wr_ready=rng[8:6]!=0;
 if((fault==1||fault==18)&&c_wr_valid&&c_wr_address<100&&hold_count<200)begin c_wr_ready=0;hold_count=hold_count+1;end
 dst_begin_ready=rng[11:9]!=0;dst_invalidate_ready=rng[14:12]!=0;
end
always @(posedge clk)begin
 if(!resetn)begin av<=0;bv<=0;ca<=0;cb<=0;ah<=0;bh<=0;ch<=0;qh<=0;dh<=0;end
 else begin
 cycles<=cycles+1;if(dut.numeric_fault_w&&c_wr_valid&&!c_wr_ready)saw_fault_stall<=1;
 av<={av[1:0],a_rd_valid&&a_rd_ready};bv<={bv[1:0],b_rd_valid&&b_rd_ready};
 ad[1]<=ad[0];ad[2]<=ad[1];bd[1]<=bd[0];bd[2]<=bd[1];
 if(ah&&(!a_rd_valid||a_rd_address!==aa))$fatal(1,"A offer withdrawn");
 if(bh&&(!b_rd_valid||b_rd_address!==ba))$fatal(1,"B offer withdrawn");
 if(ch&&(!c_wr_valid||{c_wr_address,c_wr_data,c_wr_strb}!==cp))$fatal(1,"C offer withdrawn");
 if(qh&&(!dut.q_sv||{dut.q_bf16,dut.q_scale,dut.q_unsigned,dut.q_mask,dut.q_tag}!==qp))$fatal(1,"quant input withdrawn");
 if(dh&&(!dut.d_sv||{dut.d_int8,dut.d_scale,dut.d_mask,dut.d_tag}!==dp))$fatal(1,"dequant input withdrawn");
 ah<=a_rd_valid&&!a_rd_ready;aa<=a_rd_address;bh<=b_rd_valid&&!b_rd_ready;ba<=b_rd_address;
 ch<=c_wr_valid&&!c_wr_ready;cp<={c_wr_address,c_wr_data,c_wr_strb};
 qh<=dut.q_sv&&!dut.q_sr;qp<={dut.q_bf16,dut.q_scale,dut.q_unsigned,dut.q_mask,dut.q_tag};
 dh<=dut.d_sv&&!dut.d_sr;dp<={dut.d_int8,dut.d_scale,dut.d_mask,dut.d_tag};
 if(a_rd_valid&&a_rd_ready)begin if(a_rd_bank!=banks[3:0]||a_rd_address>=acap||a_rd_wide)$fatal(1,"bad A request");ad[0]<=amem[a_rd_address];end
 if(b_rd_valid&&b_rd_ready)begin if(b_rd_bank!=banks[7:4]||b_rd_address>=bcap||b_rd_wide)$fatal(1,"bad B request");bd[0]<=bmem[b_rd_address];end
 ca<=ca+integer'(a_rd_valid&&a_rd_ready)-integer'(a_rd_resp_valid);cb<=cb+integer'(b_rd_valid&&b_rd_ready)-integer'(b_rd_resp_valid);
 if(ca<0||ca>4||cb<0||cb>4||dut.src_credit_w>4||dut.table_credit_w>4)$fatal(1,"credits");
 if(c_wr_valid&&c_wr_ready)begin
  if(c_wr_bank!=banks[11:8]||c_wr_address>=ccap)$fatal(1,"bad C address");
  for(integer j=0;j<16;j=j+1)if(c_wr_strb[j])begin
   if(written[c_wr_address][j*8+:8]!=0||mask[c_wr_address][j*8+:8]!=1)$fatal(1,"write coverage addr=%0d j=%0d",c_wr_address,j);
   if(c_wr_data[j*8+:8]!==expected[c_wr_address][j*8+:8])$fatal(1,"data addr=%0d j=%0d got=%h expected=%h state=%0d",c_wr_address,j,c_wr_data[j*8+:8],expected[c_wr_address][j*8+:8],dut.state_r);
   written[c_wr_address][j*8+:8]<=1;cmem[c_wr_address][j*8+:8]<=c_wr_data[j*8+:8];
  end
  writes<=writes+1;
 end
 if(dst_begin_valid&&dst_begin_ready)begin
  begins<=begins+1;
  if(!begin_expected||dst_begin_bank!=banks[11:8]||dst_begin_accepted_generation!=gens[95:64]||dst_begin_generation!=cgen||dst_begin_profile!=ep||dst_begin_rows!=er||dst_begin_cols!=ec||dst_begin_position!=eq||dst_begin_layer!=el)$fatal(1,"producer identity");
 end
 if(dst_invalidate_valid&&dst_invalidate_ready)begin invalidations<=invalidations+1;if(!dut.drain_w||ca||cb)$fatal(1,"early invalidate");if(dst_invalidate_bank!=banks[11:8]||dst_invalidate_generation!=(begin_expected&&fault!=16?32'(cgen):gens[95:64]))$fatal(1,"invalidation identity");end
 if(cycles>1000)$fatal(1,"timeout state=%0d credit=%0d qp=%0d dp=%0d holdq=%b holda=%b wv=%b pack=%0d",dut.state_r,dut.src_credit_w,dut.q_pending_r,dut.d_pending_r,dut.qhold_r,dut.ahold_r,dut.write_valid_r,dut.pack_bytes_r);
 end
end
initial begin
 if(!$value$plusargs("CASE=%s",path))$fatal(1,"case missing");f=$fopen({path,"/stim.hex"},"r");
 rc=$fscanf(f,"%h %h %h %h %h %h %h %h %h %h %h\n",acap,bcap,ccap,status,begin_expected,cgen,ep,er,ec,eq,el);
 rc=$fscanf(f,"%h\n",cmd_opcode);
 rc=$fscanf(f,"%h\n",cmd_payload);
 rc=$fscanf(f,"%h\n",cmd_bank_ids);
 rc=$fscanf(f,"%h\n",cmd_transaction_id);
 rc=$fscanf(f,"%h\n",cmd_generations);
 rc=$fscanf(f,"%h\n",cmd_desc_present);
 rc=$fscanf(f,"%h\n",cmd_profiles);
 rc=$fscanf(f,"%h\n",cmd_rows);
 rc=$fscanf(f,"%h\n",cmd_cols);
 rc=$fscanf(f,"%h\n",cmd_positions);
 rc=$fscanf(f,"%h\n",cmd_layers);
 rc=$fscanf(f,"%h\n",cmd_desc_generations);
 rc=$fscanf(f,"%h\n",cmd_data_valid);
 rc=$fscanf(f,"%h\n",cmd_scale_valid);
 rc=$fscanf(f,"%h\n",cmd_desc_busy);
 rc=$fscanf(f,"%h\n",cmd_desc_owner);
 rc=$fscanf(f,"%h\n",cmd_b7_static_valid);
 rc=$fscanf(f,"%h\n",cmd_embedding_lanes);
 rc=$fscanf(f,"%h\n",cmd_embedding_lane_valid);
 $fclose(f);txn=cmd_transaction_id;gens=cmd_generations;banks=cmd_bank_ids;
 $readmemh({path,"/A.hex"},amem,0,acap-1);$readmemh({path,"/B.hex"},bmem,0,bcap-1);$readmemh({path,"/C.hex"},cmem,0,ccap-1);
 $readmemh({path,"/expected.hex"},expected,0,ccap-1);$readmemh({path,"/expected_write_mask.hex"},mask,0,ccap-1);
 for(integer j=0;j<ccap;j=j+1)written[j]=0;

 resetn=0;cmd_valid=0;resp_ready=0;dst_begin_error_code=0;
 rc=$value$plusargs("FAULT=%d",fault);status=5;
 case(fault)
 1:amem[3][15:0]=16'h7fc1;
 2:amem[0][15:0]=16'h7f80;
 3:bmem[(4096+integer'(cmd_payload[51:47])*64)/16][31:0]=0;
 4:bmem[(4096+integer'(cmd_payload[51:47])*64)/16][31:0]=32'hbf800000;
 5:bmem[(4096+integer'(cmd_payload[51:47])*64)/16][31:0]=32'h7f800000;
 6:bmem[(4096+integer'(cmd_payload[51:47])*64+16)/16+2][127:96]=0;
 7:amem[294912/16][integer'(cmd_embedding_lanes[1:0])*32+:32]=32'h7fc00001;
 8:amem[0][7:0]=8'h80;
 9:begin cmd_embedding_lane_valid[0]=0;status=4;begin_expected=0;end
 10:begin cmd_b7_static_valid=0;status=4;begin_expected=0;end
 11:begin cmd_desc_generations[31:0]=cmd_desc_generations[31:0]+1;status=7;begin_expected=0;end
 12:begin cmd_generations[95:64]=32'hffffffff;cmd_desc_generations[95:64]=32'hffffffff;status=7;begin_expected=0;end
 13:begin cmd_payload[111]=1;status=1;begin_expected=0;end
 14:begin cmd_rows[10:0]=0;status=3;begin_expected=0;end
 15:begin cmd_profiles[4:0]=0;status=2;begin_expected=0;end
 16:begin dst_begin_error_code=7;status=7;end
 17:amem[71][127:112]=16'h7fc1;
 18:amem[0][71:64]=8'h80;
 default:$fatal(1,"bad fault");
 endcase
 gens=cmd_generations;

 repeat(5)@(negedge clk);resetn=1;repeat(2)@(negedge clk);cmd_valid=1;
 do @(posedge clk);while(!cmd_ready);@(negedge clk);cmd_valid=0;cmd_payload=0;cmd_bank_ids=0;cmd_generations=0;cmd_rows=0;cmd_b7_static_valid=0;
 wait(resp_valid);@(negedge clk);
 if(resp_error_code!=status||resp_transaction_id!=txn||resp_bank_ids!=banks||resp_generations!=gens)$fatal(1,"response status=%0d expected=%0d",resp_error_code,status);
 if(ca||cb||!dut.drain_w||begins!=begin_expected||invalidations!=(status!=0))$fatal(1,"finish not quiescent");
 for(integer j=0;j<ccap;j=j+1)if(status==0&&(cmem[j]!==expected[j]||written[j]!==mask[j]))$fatal(1,"full allocation mismatch word=%0d got=%h expected=%h written=%h mask=%h",j,cmem[j],expected[j],written[j],mask[j]);
 repeat(5)@(negedge clk);resp_ready=1;@(negedge clk);resp_ready=0;repeat(3)@(negedge clk);
 if((fault==1||fault==18)&&!saw_fault_stall)$fatal(1,"late numeric fault did not coincide with stalled C offer");
 if(fault==1)begin
 path="/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/tb/quant_executor_vectors/direct_A1_context_K576";
 f=$fopen({path,"/stim.hex"},"r");
 rc=$fscanf(f,"%h %h %h %h %h %h %h %h %h %h %h\n",acap,bcap,ccap,status,begin_expected,cgen,ep,er,ec,eq,el);
 rc=$fscanf(f,"%h\n",cmd_opcode);
 rc=$fscanf(f,"%h\n",cmd_payload);
 rc=$fscanf(f,"%h\n",cmd_bank_ids);
 rc=$fscanf(f,"%h\n",cmd_transaction_id);
 rc=$fscanf(f,"%h\n",cmd_generations);
 rc=$fscanf(f,"%h\n",cmd_desc_present);
 rc=$fscanf(f,"%h\n",cmd_profiles);
 rc=$fscanf(f,"%h\n",cmd_rows);
 rc=$fscanf(f,"%h\n",cmd_cols);
 rc=$fscanf(f,"%h\n",cmd_positions);
 rc=$fscanf(f,"%h\n",cmd_layers);
 rc=$fscanf(f,"%h\n",cmd_desc_generations);
 rc=$fscanf(f,"%h\n",cmd_data_valid);
 rc=$fscanf(f,"%h\n",cmd_scale_valid);
 rc=$fscanf(f,"%h\n",cmd_desc_busy);
 rc=$fscanf(f,"%h\n",cmd_desc_owner);
 rc=$fscanf(f,"%h\n",cmd_b7_static_valid);
 rc=$fscanf(f,"%h\n",cmd_embedding_lanes);
 rc=$fscanf(f,"%h\n",cmd_embedding_lane_valid);

 $fclose(f);txn=cmd_transaction_id;gens=cmd_generations;banks=cmd_bank_ids;
 $readmemh({path,"/A.hex"},amem,0,acap-1);$readmemh({path,"/B.hex"},bmem,0,bcap-1);$readmemh({path,"/C.hex"},cmem,0,ccap-1);
 $readmemh({path,"/expected.hex"},expected,0,ccap-1);$readmemh({path,"/expected_write_mask.hex"},mask,0,ccap-1);
 for(integer j=0;j<ccap;j=j+1)written[j]=0;
 begins=0;invalidations=0;writes=0;repeat(2)@(negedge clk);cmd_valid=1;do @(posedge clk);while(!cmd_ready);@(negedge clk);cmd_valid=0;
 wait(resp_valid);@(negedge clk);
 if(resp_error_code!=0||resp_generations!=gens||resp_transaction_id!=txn||!dut.drain_w||begins!=1||invalidations!=0)$fatal(1,"post error dynamic response");
 for(integer j=0;j<ccap;j=j+1)if(cmem[j]!==expected[j]||written[j]!==mask[j])$fatal(1,"post error dynamic allocation");
 resp_ready=1;@(negedge clk);resp_ready=0;repeat(2)@(negedge clk);
 end
 if(fault==17&&(writes!=0||audit_scale_offers!=0||audit_c_offers!=0))$fatal(1,"terminal dynamic NaN wrote scale/data before fault");
 $display("AUDIT_TERMINAL_REDUCE_PASS writes=%0d",writes);
 $display("QUANT_EXECUTOR_FAULT_PASS fault=%0d stall=%0d",fault,saw_fault_stall);
 $display("QUANT_EXECUTOR_PASS case=%s cycles=%0d writes=%0d",path,cycles,writes);$finish;
end
endmodule
