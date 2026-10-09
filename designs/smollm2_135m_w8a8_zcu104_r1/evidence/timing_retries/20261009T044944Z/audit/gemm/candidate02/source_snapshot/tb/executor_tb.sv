module executor_tb;
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
logic [255:0] a_rd_data;
logic b_rd_ready;
logic b_rd_resp_valid;
logic [255:0] b_rd_data;
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
logic [3:0] cmd_opcode_saved;
logic [111:0] cmd_payload_saved;
logic [11:0] cmd_bank_ids_saved;
logic [31:0] cmd_transaction_id_saved;
logic [95:0] cmd_generations_saved;
logic [2:0] cmd_desc_present_saved;
logic [14:0] cmd_profiles_saved;
logic [32:0] cmd_rows_saved;
logic [47:0] cmd_cols_saved;
logic [29:0] cmd_positions_saved;
logic [14:0] cmd_layers_saved;
logic [95:0] cmd_desc_generations_saved;
logic [2:0] cmd_data_valid_saved;
logic [2:0] cmd_scale_valid_saved;
logic [2:0] cmd_desc_busy_saved;
logic [14:0] cmd_desc_owner_saved;
smollm2_int8_gemm_executor dut(.*);
initial clk=0;always #2.5 clk=~clk;
logic[127:0] amem[0:36863],bmem[0:36863],cmem[0:36863],expected[0:36863];
logic[127:0] write_expected[0:36863],written[0:36863];
logic[2:0] av,bv;logic[255:0]ad[0:2],bd[0:2];
int acap,bcap,ccap,f,rc,cycles=0,writes=0,begin_count=0,issued=0,maxburst=0,burst=0;
int ca=0,cb=0;logic[31:0] rng=32'hb838abb1;
string path,configpath;int old_c=0;int repeats=1;int reset_probe=0;int fault=0,invalidations=0,areqs=0,breqs=0;logic[127:0]record;logic[31:0] expected_txn;logic[95:0]expected_gen;
logic[11:0]expected_banks;int expected_status;int expect_begin;int expected_cgen;
assign a_rd_resp_valid=av[2];assign a_rd_data=ad[2];
assign b_rd_resp_valid=bv[2];assign b_rd_data=bd[2];
always @(negedge clk)begin
 rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 a_rd_ready=rng[2:0]!=0;b_rd_ready=rng[5:3]!=0;c_wr_ready=rng[8:6]!=0;
 dst_begin_ready=rng[11:9]!=0;dst_invalidate_ready=1;
end
always @(posedge clk)begin
 if(!resetn)begin av<=0;bv<=0;ca<=0;cb<=0;end
 else begin
  cycles<=cycles+1;
  av<={av[1:0],a_rd_valid&&a_rd_ready};bv<={bv[1:0],b_rd_valid&&b_rd_ready};
  ad[1]<=ad[0];ad[2]<=ad[1];bd[1]<=bd[0];bd[2]<=bd[1];
  if(a_rd_valid&&a_rd_ready)begin
   if(a_rd_bank!=expected_banks[3:0]||a_rd_address>=acap||a_rd_wide&&(a_rd_address[0]||a_rd_address+1>=acap))$fatal(1,"bad A request");
   areqs<=areqs+1;ad[0]<=a_rd_wide?{amem[a_rd_address+1],amem[a_rd_address]}:{128'd0,amem[a_rd_address]};
  end
  if(b_rd_valid&&b_rd_ready)begin
   if(b_rd_bank!=expected_banks[7:4]||b_rd_address>=bcap||b_rd_wide&&(b_rd_address[0]||b_rd_address+1>=bcap))$fatal(1,"bad B request");
   breqs<=breqs+1;bd[0]<=b_rd_wide?{bmem[b_rd_address+1],bmem[b_rd_address]}:{128'd0,bmem[b_rd_address]};
  end
  ca<=ca+(a_rd_valid&&a_rd_ready)-(a_rd_resp_valid);
  cb<=cb+(b_rd_valid&&b_rd_ready)-(b_rd_resp_valid);
  if(ca<0||ca>4||cb<0||cb>4)$fatal(1,"credit violation %0d %0d",ca,cb);
  if(c_wr_valid&&c_wr_ready)begin
   if(c_wr_bank!=expected_banks[11:8]||c_wr_address>=ccap)$fatal(1,"bad C request");
   for(int j=0;j<16;j++)if(c_wr_strb[j])begin
    if(written[c_wr_address][j*8+:8])$fatal(1,"duplicate selected byte write");
    if(!write_expected[c_wr_address][j*8+:8])$fatal(1,"unexpected byte write address=%0d byte=%0d",c_wr_address,j);
    if(c_wr_data[j*8+:8]!==expected[c_wr_address][j*8+:8])$fatal(1,"write mismatch addr=%0d byte=%0d got=%h expected=%h tag=%h",c_wr_address,j,c_wr_data[j*8+:8],expected[c_wr_address][j*8+:8],dut.epi_mtag);
    cmem[c_wr_address][j*8+:8]<=c_wr_data[j*8+:8];written[c_wr_address][j*8+:8]<=1;
   end
   writes<=writes+1;
  end
  if(dst_invalidate_valid&&dst_invalidate_ready)begin
   invalidations<=invalidations+1;
   if(ca||cb||dut.core_quiet_r||dut.core_pending_r||dut.fifo_count_r||dut.epi_pending_r)$fatal(1,"invalidate before quiescence");
   if(dst_invalidate_bank!=expected_banks[11:8]||dst_invalidate_generation!=(expect_begin&&fault!=11?expected_cgen:integer'(expected_gen[95:64])))$fatal(1,"bad invalidation identity");
  end
  if(dst_begin_valid&&dst_begin_ready)begin
   begin_count<=begin_count+1;
   if(!expect_begin||dst_begin_bank!=expected_banks[11:8]||dst_begin_generation!=expected_cgen)$fatal(1,"bad producer begin");
  end
  if(dut.core_sv&&dut.core_sr)begin issued<=issued+1;burst<=burst+1;if(burst+1>maxburst)maxburst<=burst+1;end else burst<=0;
 end
end
initial begin
 if(!$value$plusargs("CASE=%s",path))$fatal(1,"CASE missing");
 configpath={path,"/stim.hex"};f=$fopen(configpath,"r");if(!f)$fatal(1,"config missing");
 rc=$fscanf(f,"%h %h %h %h %h %h\n",acap,bcap,ccap,expected_status,expect_begin,expected_cgen);
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
expected_txn=cmd_transaction_id;expected_gen=cmd_generations;expected_banks=cmd_bank_ids;
 $readmemh({path,"/A.hex"},amem,0,acap-1);$readmemh({path,"/B.hex"},bmem,0,bcap-1);$readmemh({path,"/C.hex"},cmem,0,ccap-1);
 $readmemh({path,"/expected.hex"},expected,0,ccap-1);$readmemh({path,"/expected_write_mask.hex"},write_expected,0,ccap-1);
 for(int j=0;j<ccap;j++)written[j]=0;
 rc=$value$plusargs("OLD_C=%d",old_c);
 if(old_c)begin
  cmd_desc_present[2]=1;cmd_profiles[14:10]=17;cmd_rows[32:22]=1;cmd_cols[47:32]=33;cmd_positions[29:20]=32;cmd_layers[14:10]=0;
 end
 resetn=0;cmd_valid=0;resp_ready=0;dst_begin_error_code=0;
 rc=$value$plusargs("FAULT=%d",fault);
 if(fault)begin
  if(fault!=15)for(int j=0;j<ccap;j++)begin expected[j]=cmem[j];write_expected[j]=0;end
  expected_status=5;
  case(fault)
   1:amem[(cmd_opcode==6?18432:294912)/16][31:0]=0;
   2:amem[(cmd_opcode==6?18432:294912)/16][31:0]=32'h7f800000;
   3:amem[(cmd_opcode==6?18432:294912)/16][31:0]=32'hbf800000;
   4:amem[integer'(cmd_payload[30:25])*integer'(cmd_payload[18:8])/16][7:0]=8'h80;
   5:bmem[0][7:0]=8'h80;
   6:begin cmd_rows[10:0]=33;expected_status=3;expect_begin=0;end
   7:begin cmd_payload[63]=1;expected_status=1;expect_begin=0;end
   8:begin cmd_desc_generations[31:0]=cmd_desc_generations[31:0]+1;expected_status=7;expect_begin=0;end
   9:begin cmd_data_valid[0]=0;expected_status=4;expect_begin=0;end
   10:begin amem[294912/16][63:0]={2{32'h7e800000}};bmem[294912/16][31:0]=32'h7e800000;end
   11:begin dst_begin_error_code=6;expected_status=6;end
   12:amem[0][7:0]=8'hff;
   13:begin amem[294912/16][63:0]={2{32'h7b800000}};bmem[294912/16][31:0]=32'h3f800000;end
   14:begin cmd_payload[24:19]=2;cmd_rows[10:0]=2;cmd_rows[32:22]=2;expected_status=3;expect_begin=0;end
   15:begin
    amem[294912/16][63:32]=32'h7f000000;
    for(int word=0;word<ccap;word++)for(int byte_lane=0;byte_lane<16;byte_lane++)begin
     if(!((word*8+byte_lane/2)/576<16 && (word*8+byte_lane/2)%576>=64 && (word*8+byte_lane/2)%576<80))begin
      expected[word][byte_lane*8+:8]=cmem[word][byte_lane*8+:8];write_expected[word][byte_lane*8+:8]=0;
     end
    end
   end
   default:$fatal(1,"unknown fault");
  endcase
 end
 cmd_opcode_saved=cmd_opcode;
 cmd_payload_saved=cmd_payload;
 cmd_bank_ids_saved=cmd_bank_ids;
 cmd_transaction_id_saved=cmd_transaction_id;
 cmd_generations_saved=cmd_generations;
 cmd_desc_present_saved=cmd_desc_present;
 cmd_profiles_saved=cmd_profiles;
 cmd_rows_saved=cmd_rows;
 cmd_cols_saved=cmd_cols;
 cmd_positions_saved=cmd_positions;
 cmd_layers_saved=cmd_layers;
 cmd_desc_generations_saved=cmd_desc_generations;
 cmd_data_valid_saved=cmd_data_valid;
 cmd_scale_valid_saved=cmd_scale_valid;
 cmd_desc_busy_saved=cmd_desc_busy;
 cmd_desc_owner_saved=cmd_desc_owner;
 rc=$value$plusargs("RESET_PROBE=%d",reset_probe);
 if(reset_probe)begin
  repeat(4)@(negedge clk);resetn=1;cmd_valid=1;
  do @(posedge clk);while(!cmd_ready);
  @(negedge clk);cmd_valid=0;
  wait(dut.core_sv&&dut.core_sr);repeat(10)@(negedge clk);
  resetn=0;repeat(4)@(negedge clk);
  begin_count=0;invalidations=0;issued=0;maxburst=0;burst=0;writes=0;areqs=0;breqs=0;
  $readmemh({path,"/C.hex"},cmem,0,ccap-1);
  for(int j=0;j<ccap;j++)written[j]=0;
  cmd_opcode=cmd_opcode_saved;
  cmd_payload=cmd_payload_saved;
  cmd_bank_ids=cmd_bank_ids_saved;
  cmd_transaction_id=cmd_transaction_id_saved;
  cmd_generations=cmd_generations_saved;
  cmd_desc_present=cmd_desc_present_saved;
  cmd_profiles=cmd_profiles_saved;
  cmd_rows=cmd_rows_saved;
  cmd_cols=cmd_cols_saved;
  cmd_positions=cmd_positions_saved;
  cmd_layers=cmd_layers_saved;
  cmd_desc_generations=cmd_desc_generations_saved;
  cmd_data_valid=cmd_data_valid_saved;
  cmd_scale_valid=cmd_scale_valid_saved;
  cmd_desc_busy=cmd_desc_busy_saved;
  cmd_desc_owner=cmd_desc_owner_saved;
 end
 rc=$value$plusargs("REPEATS=%d",repeats);
 repeat(4)@(negedge clk);resetn=1;
 for(int job=0;job<repeats;job++)begin
  cmd_opcode=cmd_opcode_saved;
  cmd_payload=cmd_payload_saved;
  cmd_bank_ids=cmd_bank_ids_saved;
  cmd_transaction_id=cmd_transaction_id_saved;
  cmd_generations=cmd_generations_saved;
  cmd_desc_present=cmd_desc_present_saved;
  cmd_profiles=cmd_profiles_saved;
  cmd_rows=cmd_rows_saved;
  cmd_cols=cmd_cols_saved;
  cmd_positions=cmd_positions_saved;
  cmd_layers=cmd_layers_saved;
  cmd_desc_generations=cmd_desc_generations_saved;
  cmd_data_valid=cmd_data_valid_saved;
  cmd_scale_valid=cmd_scale_valid_saved;
  cmd_desc_busy=cmd_desc_busy_saved;
  cmd_desc_owner=cmd_desc_owner_saved;
  cmd_transaction_id=cmd_transaction_id_saved+32'(job);expected_txn=cmd_transaction_id;
  begin_count=0;invalidations=0;
  for(int j=0;j<ccap;j++)written[j]=0;
  cmd_valid=1;
 do @(posedge clk);while(!cmd_ready);
 @(negedge clk);cmd_valid=0;cmd_payload='1;cmd_generations='1;cmd_transaction_id='1;
 wait(resp_valid);@(negedge clk);
 if(resp_error_code!=expected_status||resp_transaction_id!=expected_txn||resp_generations!=expected_gen||resp_bank_ids!=expected_banks||resp_used_bank_mask!=7||resp_used_bank_count!=3)$fatal(1,"response mismatch error=%0d",resp_error_code);
 if(ca||cb||(|av)||(|bv))$fatal(1,"response before read drain");
 if(fault&&invalidations!=1)$fatal(1,"missing matched invalidation");
 if(!fault&&invalidations)$fatal(1,"unexpected invalidation");
 if((fault>=6&&fault<=9||fault==14) && (areqs||breqs))$fatal(1,"invalid descriptor accessed memory");
 if(begin_count!=expect_begin)$fatal(1,"begin count mismatch");
 for(int j=0;j<ccap;j++)begin
  if(cmem[j]!==expected[j])$fatal(1,"C allocation mismatch word%0d",j);
  if(written[j]!==write_expected[j])$fatal(1,"coverage mismatch word%0d",j);
 end
 repeat(10)@(negedge clk);
 if(!resp_valid||cmd_ready)$fatal(1,"response hold");
 resp_ready=1;@(negedge clk);resp_ready=0;
 if(resp_valid||!cmd_ready)$fatal(1,"response retirement");
 if(expect_begin&&expected_status==0)begin
  cmd_generations_saved[95:64]=expected_cgen;cmd_desc_generations_saved[95:64]=expected_cgen;
  expected_gen[95:64]=expected_cgen;expected_cgen=expected_cgen+1;
  cmd_desc_present_saved[2]=1;cmd_profiles_saved[14:10]=dst_begin_profile;
  cmd_rows_saved[32:22]=dst_begin_rows;cmd_cols_saved[47:32]=dst_begin_cols;
  cmd_positions_saved[29:20]=dst_begin_position;cmd_layers_saved[14:10]=dst_begin_layer;
  cmd_data_valid_saved[2]=1;cmd_scale_valid_saved[2]=0;
 end
 end
 $display("EXECUTOR_PASS case=%s fault=%0d jobs=%0d writes=%0d core_issues=%0d max_II1_burst=%0d cycles=%0d",path,fault,repeats,writes,issued,maxburst,cycles);$finish;
end
initial begin #10000000;$fatal(1,"timeout state=%0d ai=%0d ar=%0d bi=%0d br=%0d cp=%0d fifo=%0d epi=%0d",dut.state_r,dut.ai_r,dut.ar_r,dut.bi_r,dut.br_r,dut.core_pending_r,dut.fifo_count_r,dut.epi_pending_r);end
logic ah=0,bh=0,ch=0,sh=0,eh=0,rh=0;
logic[19:0]asnap,bsnap;logic[162:0]csnap;logic[2317:0]ssnap;
logic[355:0]esnap;logic[152:0]rsnap;
always @(posedge clk)if(resetn)begin
 if(ah&&(!a_rd_valid||{a_rd_wide,a_rd_address}!==asnap))$fatal(1,"A stalled request changed");
 if(bh&&(!b_rd_valid||{b_rd_wide,b_rd_address}!==bsnap))$fatal(1,"B stalled request changed");
 if(ch&&(!c_wr_valid||{c_wr_address,c_wr_data,c_wr_strb}!==csnap))$fatal(1,"C stalled write changed");
 if(sh&&(!dut.core_sv||{dut.core_a,dut.core_b,dut.core_row,dut.core_first,dut.core_last,dut.core_nv,dut.core_tag,dut.core_scale}!==ssnap))$fatal(1,"core stalled input changed");
 if(eh&&(!dut.epi_sv||{dut.epi_sums,dut.epi_scales,dut.epi_mask,dut.epi_tag}!==esnap))$fatal(1,"epilogue stalled input changed");
 if(rh&&(!resp_valid||{resp_transaction_id,resp_used_bank_mask,resp_used_bank_count,resp_bank_ids,resp_generations,resp_error_code}!==rsnap))$fatal(1,"response stalled identity changed");
 ah<=a_rd_valid&&!a_rd_ready;asnap<={a_rd_wide,a_rd_address};bh<=b_rd_valid&&!b_rd_ready;bsnap<={b_rd_wide,b_rd_address};
 ch<=c_wr_valid&&!c_wr_ready;csnap<={c_wr_address,c_wr_data,c_wr_strb};
 sh<=dut.core_sv&&!dut.core_sr;ssnap<={dut.core_a,dut.core_b,dut.core_row,dut.core_first,dut.core_last,dut.core_nv,dut.core_tag,dut.core_scale};
 eh<=dut.epi_sv&&!dut.epi_sr;esnap<={dut.epi_sums,dut.epi_scales,dut.epi_mask,dut.epi_tag};
 rh<=resp_valid&&!resp_ready;rsnap<={resp_transaction_id,resp_used_bank_mask,resp_used_bank_count,resp_bank_ids,resp_generations,resp_error_code};
end else begin ah<=0;bh<=0;ch<=0;sh<=0;eh<=0;rh<=0;end
endmodule

