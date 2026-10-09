import pathlib,json
B=pathlib.Path(__file__).resolve().parents[2];j=json.loads((B/'contracts/native_bank_pool_rtl_binding.json').read_text())
s='`timescale 1ns/1ps\nmodule smollm2_native_bank_pool (\n'+',\n'.join(' '+v['direction']+' logic '+('' if v['bits']==1 else f"[{v['bits']-1}:0] ")+k for k,v in j['ports'].items())+'\n);\n'
s+='''
 logic[15:0]available_w,unit_epoch_ready_w,epoch_gen_ok_w,unit_pending_w,read_pending_w;
 logic[15:0]write_legal_w,read_legal_w,unit_pub_valid_w,unit_pub_ready_w;
 logic[15:0]unit_data_w,unit_scale_w;
 logic[31:0]unit_comp_w;logic[511:0]unit_gen_w,unit_txn_w;logic[79:0]unit_role_w;
 logic epoch_format_ok_w,epoch_accept_w;logic[15:0]epoch_fire_w;
 logic[3:0]arbiter_r,selected_w;logic selected_valid_w;
 function automatic logic format_ok;
   input logic[3:0]b;input logic[4:0]p;input logic[10:0]rows;input logic[15:0]cols;
   input logic[9:0]pos;input logic[4:0]layer;input logic[1:0]comp;
   input logic[31:0]dataoff,datalen,scaleoff,scalelen;
   logic allowed,shape;logic[11:0]endpos;logic[31:0]data_expected,scale_expected,scale_base,capacity;
   begin allowed=0;shape=0;endpos={2'b0,pos}+{1'b0,rows};scale_expected=0;scale_base=0;
     case(b)
       0:allowed=p==1;1:allowed=p==2;2:allowed=p==3;3:allowed=p==4||p==5||p==6;
       4:allowed=p==7;5:allowed=p==8||p==9;6:allowed=p==10;7:allowed=p==11;
       8:allowed=p==12||p==13;9:allowed=p==14||p==15;10:allowed=p==16||p==17||p==18;
       11:allowed=p==19;12:allowed=p==20;13:allowed=p==21||p==22;14:allowed=p==23;15:allowed=p==4;
       default:allowed=0;
     endcase
     case(p)
       4:shape=rows>=1&&rows<=192&&(cols==576||cols==1536);
       5:shape=rows==1&&cols==576;
       11:shape=cols==64&&((comp==2&&rows==30&&pos==0)||(comp!=2&&rows>=1&&rows<=32&&endpos<=1024));
       12,14:shape=rows>=1&&rows<=1024&&cols==192&&layer<30;
       16,17,22:shape=rows>=1&&rows<=32&&cols>=1&&cols<=1024&&endpos<={1'b0,cols[10:0]};
       21:shape=rows>=1&&rows<=32&&(cols==576||cols==1536);
       20:shape=rows==1&&cols==49152;
       8,10:shape=rows>=1&&rows<=32&&cols==192;
       13,15,18:shape=rows>=1&&rows<=32&&cols==1536;
       default:shape=rows>=1&&rows<=32&&cols==576;
     endcase
     data_expected=32'(rows)*32'(cols);
     if(p==16||p==17||p==22)data_expected=32'(rows)*32'd9*((32'(cols)+32'd15)&32'hfffffff0);
     if(!(p==4||p==6||p==12||p==14||p==21||p==22||p==23))data_expected=data_expected<<1;
     case(p)
       4,21:scale_expected=(( ((32'(rows)+32'd15)>>4)*32'd4+32'd15)&32'hfffffff0);
       6:scale_expected=32'(rows)<<4;
       12:scale_expected=16;
       14:scale_expected=48;
       22,23:scale_expected=(32'd9*((32'(rows)+32'd15)>>4)*32'd4+32'd15)&32'hfffffff0;
       default:scale_expected=0;
     endcase
     case(b)
       3,15:scale_base=294912;8,9:scale_base=196608;13:scale_base=294912;14:scale_base=18432;
       default:scale_base=0;
     endcase
     case(b)
       0:capacity=32'd36864;
       1:capacity=32'd36864;
       2:capacity=32'd36864;
       3:capacity=32'd295424;
       4:capacity=32'd36864;
       5:capacity=32'd36864;
       6:capacity=32'd12288;
       7:capacity=32'd6016;
       8:capacity=32'd196640;
       9:capacity=32'd196672;
       10:capacity=32'd589824;
       11:capacity=32'd36864;
       12:capacity=32'd98304;
       13:capacity=32'd295008;
       14:capacity=32'd18528;
       15:capacity=32'd295040;
       default:capacity=0;
     endcase
     format_ok=allowed&&shape&&(b==7?comp<=2:comp==0)&&
       ((p==11||p==16||p==17||p==22)||pos==0)&&((p==12||p==14)||layer==0);
     if(b==7)begin
       if(comp==2)format_ok=format_ok&&dataoff==4096&&datalen==1920&&scalelen==0;
       else format_ok=format_ok&&dataoff==0&&datalen==(32'(rows)<<7)&&
         (comp==0?(scaleoff==4096&&scalelen==1920):scalelen==0);
     end else format_ok=format_ok&&dataoff==0&&datalen==data_expected&&scalelen==scale_expected&&
       (scale_expected==0||scaleoff==scale_base);
     format_ok=format_ok&&({1'b0,dataoff}+{1'b0,datalen}<={1'b0,capacity})&&
       ({1'b0,scaleoff}+{1'b0,scalelen}<={1'b0,capacity});
   end
 endfunction
 always_comb begin
   epoch_format_ok_w=format_ok(epoch_bank,epoch_profile,epoch_rows,epoch_cols,epoch_position,
     epoch_layer,epoch_component,epoch_data_offset,epoch_data_bytes,epoch_scale_offset,epoch_scale_bytes);
   epoch_error_code=(epoch_format_ok_w&&epoch_gen_ok_w[epoch_bank])?8'd0:8'h07;
   epoch_ready=unit_epoch_ready_w[epoch_bank]&&!read_pending_w[epoch_bank]&&
               !(coverage_valid&&coverage_bank==epoch_bank);
   epoch_accept_w=epoch_valid&&epoch_ready&&epoch_error_code==0;
   epoch_fire_w=0;epoch_fire_w[epoch_bank]=epoch_accept_w;
   unit_pub_ready_w=0;selected_valid_w=0;selected_w=0;
   for(int i=0;i<16;i++)begin
     if(!selected_valid_w&&unit_pub_valid_w[4'(arbiter_r+4'(i))])begin
       selected_valid_w=1;selected_w=4'(arbiter_r+4'(i));
     end
   end
   if((!coverage_valid||coverage_ready)&&selected_valid_w)unit_pub_ready_w[selected_w]=1;
   for(int b=0;b<16;b++)begin
     bank_ready[b]=available_w[b];
     coverage_pending[b]=unit_pending_w[b]||(coverage_valid&&coverage_bank==4'(b));
     wr_pending[b]=coverage_pending[b];
     bank_quiescent[b]=available_w[b]&&!coverage_pending[b]&&!read_pending_w[b];
   end
 end
 always_ff @(posedge clk)begin
   if(!resetn)begin
     coverage_valid<=0;coverage_bank<=0;coverage_component<=0;coverage_generation<=0;
     coverage_transaction_id<=0;coverage_role<=0;coverage_data_complete<=0;coverage_scale_complete<=0;
     fault_valid<=0;fault_bank<=0;fault_error_code<=0;arbiter_r<=0;
   end else begin
     if(!coverage_valid||coverage_ready)begin
       coverage_valid<=selected_valid_w;
       if(selected_valid_w)begin
         coverage_bank<=selected_w;coverage_component<=unit_comp_w[selected_w*2+:2];
         coverage_generation<=unit_gen_w[selected_w*32+:32];coverage_transaction_id<=unit_txn_w[selected_w*32+:32];
         coverage_role<=unit_role_w[selected_w*5+:5];coverage_data_complete<=unit_data_w[selected_w];
         coverage_scale_complete<=unit_scale_w[selected_w];arbiter_r<=selected_w+4'd1;
       end
     end
     if(!fault_valid)begin
       if(epoch_valid&&epoch_ready&&epoch_error_code!=0)begin fault_valid<=1;fault_bank<=epoch_bank;fault_error_code<=8'h07;end
       for(int b=15;b>=0;b--)begin
         if(available_w[b]&&!(epoch_valid&&epoch_bank==4'(b))&&
           ((rd_valid[b]&&!read_legal_w[b])||(wr_valid[b]&&!write_legal_w[b])))begin
           fault_valid<=1;fault_bank<=4'(b);fault_error_code<=8'h07;
         end
       end
     end
   end
 end
'''
for bank,cap in enumerate(j['capacities']):
 w=cap//16;wide=int(bank in j['wide_banks']);ultra=int(bank in j['URAM_banks']);s+=f'''
 localparam integer WORDS_{bank}={w};
 assign read_legal_w[{bank}]=rd_word_address[{bank*19}+:19]<19'd{w}&&
   (!rd_wide[{bank}]||(1'b{wide}&&!rd_word_address[{bank*19}]&&rd_word_address[{bank*19}+:19]+19'd1<19'd{w}));
 assign rd_ready[{bank}]=resetn&&available_w[{bank}]&&read_legal_w[{bank}]&&!(epoch_valid&&epoch_bank==4'd{bank});
 assign wr_ready[{bank}]=resetn&&available_w[{bank}]&&write_legal_w[{bank}]&&!(epoch_valid&&epoch_bank==4'd{bank});
 assign wr_commit[{bank}]=wr_valid[{bank}]&&wr_ready[{bank}];
 smollm2_bank_payload #(.WORDS(WORDS_{bank}),.WIDE(1'b{wide}),.ULTRA(1'b{ultra})) payload_{bank}(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[{bank}]&&rd_ready[{bank}]),
   .rd_address(rd_word_address[{bank*19}+:19]),.rd_wide(rd_wide[{bank}]),
   .wr_fire(wr_commit[{bank}]),.wr_address(wr_word_address[{bank*19}+:19]),
   .wr_data(wr_data[{bank*128}+:128]),.wr_strb(wr_strb[{bank*16}+:16]),
   .rd_data(rd_data[{bank*256}+:256]),.rd_pending(read_pending_w[{bank}]),.rd_resp_valid(rd_resp_valid[{bank}]));
 smollm2_bank_coverage #(.WORDS(WORDS_{bank}),.B7(1'b{int(bank==7)})) coverage_{bank}(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[{bank}]),
   .epoch_ready(unit_epoch_ready_w[{bank}]),.epoch_generation_legal(epoch_gen_ok_w[{bank}]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[{bank}]),.epoch_done_ready(epoch_done_ready[{bank}]),
   .epoch_done_token(epoch_done_token[{bank*32}+:32]),.epoch_done_generation(epoch_done_generation[{bank*32}+:32]),
   .epoch_done_component(epoch_done_component[{bank*2}+:2]),.bank_available(available_w[{bank}]),
   .wr_commit(wr_commit[{bank}]),.wr_address(wr_word_address[{bank*19}+:19]),.wr_strb(wr_strb[{bank*16}+:16]),
   .wr_transaction_id(wr_transaction_id[{bank*32}+:32]),.wr_generation(wr_generation[{bank*32}+:32]),
   .wr_role(wr_role[{bank*5}+:5]),.wr_legal(write_legal_w[{bank}]),.wr_pending(unit_pending_w[{bank}]),
   .pub_valid(unit_pub_valid_w[{bank}]),.pub_ready(unit_pub_ready_w[{bank}]),
   .pub_component(unit_comp_w[{bank*2}+:2]),.pub_generation(unit_gen_w[{bank*32}+:32]),
   .pub_transaction_id(unit_txn_w[{bank*32}+:32]),.pub_role(unit_role_w[{bank*5}+:5]),
   .pub_data_complete(unit_data_w[{bank}]),.pub_scale_complete(unit_scale_w[{bank}]));
'''
s+='endmodule\n';(B/'rtl/smollm2_native_bank_pool.sv').write_text(s)
