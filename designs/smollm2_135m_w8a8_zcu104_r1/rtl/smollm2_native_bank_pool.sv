`timescale 1ns/1ps
module smollm2_native_bank_pool (
 input logic clk,
 input logic resetn,
 input logic [15:0] rd_valid,
 output logic [15:0] rd_ready,
 input logic [303:0] rd_word_address,
 input logic [15:0] rd_wide,
 output logic [15:0] rd_resp_valid,
 output logic [4095:0] rd_data,
 input logic [15:0] wr_valid,
 output logic [15:0] wr_ready,
 input logic [303:0] wr_word_address,
 input logic [2047:0] wr_data,
 input logic [255:0] wr_strb,
 input logic [511:0] wr_transaction_id,
 input logic [511:0] wr_generation,
 input logic [79:0] wr_role,
 output logic [15:0] wr_commit,
 output logic [15:0] wr_pending,
 output logic [15:0] coverage_pending,
 output logic [15:0] bank_quiescent,
 output logic [15:0] bank_ready,
 input logic epoch_valid,
 output logic epoch_ready,
 output logic [7:0] epoch_error_code,
 input logic [3:0] epoch_bank,
 input logic [1:0] epoch_component,
 input logic [31:0] epoch_token,
 input logic [31:0] epoch_generation,
 input logic [4:0] epoch_profile,
 input logic [10:0] epoch_rows,
 input logic [15:0] epoch_cols,
 input logic [9:0] epoch_position,
 input logic [4:0] epoch_layer,
 input logic [31:0] epoch_data_offset,
 input logic [31:0] epoch_data_bytes,
 input logic [31:0] epoch_scale_offset,
 input logic [31:0] epoch_scale_bytes,
 output logic [15:0] epoch_done_valid,
 input logic [15:0] epoch_done_ready,
 output logic [511:0] epoch_done_token,
 output logic [511:0] epoch_done_generation,
 output logic [31:0] epoch_done_component,
 output logic coverage_valid,
 input logic coverage_ready,
 output logic [3:0] coverage_bank,
 output logic [1:0] coverage_component,
 output logic [31:0] coverage_generation,
 output logic [31:0] coverage_transaction_id,
 output logic [4:0] coverage_role,
 output logic coverage_data_complete,
 output logic coverage_scale_complete,
 output logic fault_valid,
 output logic [3:0] fault_bank,
 output logic [7:0] fault_error_code
);

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

 localparam integer WORDS_0=2304;
 assign read_legal_w[0]=rd_word_address[0+:19]<19'd2304&&
   (!rd_wide[0]||(1'b0&&!rd_word_address[0]&&rd_word_address[0+:19]+19'd1<19'd2304));
 assign rd_ready[0]=resetn&&available_w[0]&&read_legal_w[0]&&!(epoch_valid&&epoch_bank==4'd0);
 assign wr_ready[0]=resetn&&available_w[0]&&write_legal_w[0]&&!(epoch_valid&&epoch_bank==4'd0);
 assign wr_commit[0]=wr_valid[0]&&wr_ready[0];
 smollm2_bank_payload #(.WORDS(WORDS_0),.WIDE(1'b0),.ULTRA(1'b0)) payload_0(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[0]&&rd_ready[0]),
   .rd_address(rd_word_address[0+:19]),.rd_wide(rd_wide[0]),
   .wr_fire(wr_commit[0]),.wr_address(wr_word_address[0+:19]),
   .wr_data(wr_data[0+:128]),.wr_strb(wr_strb[0+:16]),
   .rd_data(rd_data[0+:256]),.rd_pending(read_pending_w[0]),.rd_resp_valid(rd_resp_valid[0]));
 smollm2_bank_coverage #(.WORDS(WORDS_0),.B7(1'b0)) coverage_0(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[0]),
   .epoch_ready(unit_epoch_ready_w[0]),.epoch_generation_legal(epoch_gen_ok_w[0]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[0]),.epoch_done_ready(epoch_done_ready[0]),
   .epoch_done_token(epoch_done_token[0+:32]),.epoch_done_generation(epoch_done_generation[0+:32]),
   .epoch_done_component(epoch_done_component[0+:2]),.bank_available(available_w[0]),
   .wr_commit(wr_commit[0]),.wr_address(wr_word_address[0+:19]),.wr_strb(wr_strb[0+:16]),
   .wr_transaction_id(wr_transaction_id[0+:32]),.wr_generation(wr_generation[0+:32]),
   .wr_role(wr_role[0+:5]),.wr_legal(write_legal_w[0]),.wr_pending(unit_pending_w[0]),
   .pub_valid(unit_pub_valid_w[0]),.pub_ready(unit_pub_ready_w[0]),
   .pub_component(unit_comp_w[0+:2]),.pub_generation(unit_gen_w[0+:32]),
   .pub_transaction_id(unit_txn_w[0+:32]),.pub_role(unit_role_w[0+:5]),
   .pub_data_complete(unit_data_w[0]),.pub_scale_complete(unit_scale_w[0]));

 localparam integer WORDS_1=2304;
 assign read_legal_w[1]=rd_word_address[19+:19]<19'd2304&&
   (!rd_wide[1]||(1'b0&&!rd_word_address[19]&&rd_word_address[19+:19]+19'd1<19'd2304));
 assign rd_ready[1]=resetn&&available_w[1]&&read_legal_w[1]&&!(epoch_valid&&epoch_bank==4'd1);
 assign wr_ready[1]=resetn&&available_w[1]&&write_legal_w[1]&&!(epoch_valid&&epoch_bank==4'd1);
 assign wr_commit[1]=wr_valid[1]&&wr_ready[1];
 smollm2_bank_payload #(.WORDS(WORDS_1),.WIDE(1'b0),.ULTRA(1'b0)) payload_1(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[1]&&rd_ready[1]),
   .rd_address(rd_word_address[19+:19]),.rd_wide(rd_wide[1]),
   .wr_fire(wr_commit[1]),.wr_address(wr_word_address[19+:19]),
   .wr_data(wr_data[128+:128]),.wr_strb(wr_strb[16+:16]),
   .rd_data(rd_data[256+:256]),.rd_pending(read_pending_w[1]),.rd_resp_valid(rd_resp_valid[1]));
 smollm2_bank_coverage #(.WORDS(WORDS_1),.B7(1'b0)) coverage_1(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[1]),
   .epoch_ready(unit_epoch_ready_w[1]),.epoch_generation_legal(epoch_gen_ok_w[1]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[1]),.epoch_done_ready(epoch_done_ready[1]),
   .epoch_done_token(epoch_done_token[32+:32]),.epoch_done_generation(epoch_done_generation[32+:32]),
   .epoch_done_component(epoch_done_component[2+:2]),.bank_available(available_w[1]),
   .wr_commit(wr_commit[1]),.wr_address(wr_word_address[19+:19]),.wr_strb(wr_strb[16+:16]),
   .wr_transaction_id(wr_transaction_id[32+:32]),.wr_generation(wr_generation[32+:32]),
   .wr_role(wr_role[5+:5]),.wr_legal(write_legal_w[1]),.wr_pending(unit_pending_w[1]),
   .pub_valid(unit_pub_valid_w[1]),.pub_ready(unit_pub_ready_w[1]),
   .pub_component(unit_comp_w[2+:2]),.pub_generation(unit_gen_w[32+:32]),
   .pub_transaction_id(unit_txn_w[32+:32]),.pub_role(unit_role_w[5+:5]),
   .pub_data_complete(unit_data_w[1]),.pub_scale_complete(unit_scale_w[1]));

 localparam integer WORDS_2=2304;
 assign read_legal_w[2]=rd_word_address[38+:19]<19'd2304&&
   (!rd_wide[2]||(1'b0&&!rd_word_address[38]&&rd_word_address[38+:19]+19'd1<19'd2304));
 assign rd_ready[2]=resetn&&available_w[2]&&read_legal_w[2]&&!(epoch_valid&&epoch_bank==4'd2);
 assign wr_ready[2]=resetn&&available_w[2]&&write_legal_w[2]&&!(epoch_valid&&epoch_bank==4'd2);
 assign wr_commit[2]=wr_valid[2]&&wr_ready[2];
 smollm2_bank_payload #(.WORDS(WORDS_2),.WIDE(1'b0),.ULTRA(1'b0)) payload_2(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[2]&&rd_ready[2]),
   .rd_address(rd_word_address[38+:19]),.rd_wide(rd_wide[2]),
   .wr_fire(wr_commit[2]),.wr_address(wr_word_address[38+:19]),
   .wr_data(wr_data[256+:128]),.wr_strb(wr_strb[32+:16]),
   .rd_data(rd_data[512+:256]),.rd_pending(read_pending_w[2]),.rd_resp_valid(rd_resp_valid[2]));
 smollm2_bank_coverage #(.WORDS(WORDS_2),.B7(1'b0)) coverage_2(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[2]),
   .epoch_ready(unit_epoch_ready_w[2]),.epoch_generation_legal(epoch_gen_ok_w[2]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[2]),.epoch_done_ready(epoch_done_ready[2]),
   .epoch_done_token(epoch_done_token[64+:32]),.epoch_done_generation(epoch_done_generation[64+:32]),
   .epoch_done_component(epoch_done_component[4+:2]),.bank_available(available_w[2]),
   .wr_commit(wr_commit[2]),.wr_address(wr_word_address[38+:19]),.wr_strb(wr_strb[32+:16]),
   .wr_transaction_id(wr_transaction_id[64+:32]),.wr_generation(wr_generation[64+:32]),
   .wr_role(wr_role[10+:5]),.wr_legal(write_legal_w[2]),.wr_pending(unit_pending_w[2]),
   .pub_valid(unit_pub_valid_w[2]),.pub_ready(unit_pub_ready_w[2]),
   .pub_component(unit_comp_w[4+:2]),.pub_generation(unit_gen_w[64+:32]),
   .pub_transaction_id(unit_txn_w[64+:32]),.pub_role(unit_role_w[10+:5]),
   .pub_data_complete(unit_data_w[2]),.pub_scale_complete(unit_scale_w[2]));

 localparam integer WORDS_3=18464;
 assign read_legal_w[3]=rd_word_address[57+:19]<19'd18464&&
   (!rd_wide[3]||(1'b1&&!rd_word_address[57]&&rd_word_address[57+:19]+19'd1<19'd18464));
 assign rd_ready[3]=resetn&&available_w[3]&&read_legal_w[3]&&!(epoch_valid&&epoch_bank==4'd3);
 assign wr_ready[3]=resetn&&available_w[3]&&write_legal_w[3]&&!(epoch_valid&&epoch_bank==4'd3);
 assign wr_commit[3]=wr_valid[3]&&wr_ready[3];
 smollm2_bank_payload #(.WORDS(WORDS_3),.WIDE(1'b1),.ULTRA(1'b1)) payload_3(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[3]&&rd_ready[3]),
   .rd_address(rd_word_address[57+:19]),.rd_wide(rd_wide[3]),
   .wr_fire(wr_commit[3]),.wr_address(wr_word_address[57+:19]),
   .wr_data(wr_data[384+:128]),.wr_strb(wr_strb[48+:16]),
   .rd_data(rd_data[768+:256]),.rd_pending(read_pending_w[3]),.rd_resp_valid(rd_resp_valid[3]));
 smollm2_bank_coverage #(.WORDS(WORDS_3),.B7(1'b0)) coverage_3(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[3]),
   .epoch_ready(unit_epoch_ready_w[3]),.epoch_generation_legal(epoch_gen_ok_w[3]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[3]),.epoch_done_ready(epoch_done_ready[3]),
   .epoch_done_token(epoch_done_token[96+:32]),.epoch_done_generation(epoch_done_generation[96+:32]),
   .epoch_done_component(epoch_done_component[6+:2]),.bank_available(available_w[3]),
   .wr_commit(wr_commit[3]),.wr_address(wr_word_address[57+:19]),.wr_strb(wr_strb[48+:16]),
   .wr_transaction_id(wr_transaction_id[96+:32]),.wr_generation(wr_generation[96+:32]),
   .wr_role(wr_role[15+:5]),.wr_legal(write_legal_w[3]),.wr_pending(unit_pending_w[3]),
   .pub_valid(unit_pub_valid_w[3]),.pub_ready(unit_pub_ready_w[3]),
   .pub_component(unit_comp_w[6+:2]),.pub_generation(unit_gen_w[96+:32]),
   .pub_transaction_id(unit_txn_w[96+:32]),.pub_role(unit_role_w[15+:5]),
   .pub_data_complete(unit_data_w[3]),.pub_scale_complete(unit_scale_w[3]));

 localparam integer WORDS_4=2304;
 assign read_legal_w[4]=rd_word_address[76+:19]<19'd2304&&
   (!rd_wide[4]||(1'b0&&!rd_word_address[76]&&rd_word_address[76+:19]+19'd1<19'd2304));
 assign rd_ready[4]=resetn&&available_w[4]&&read_legal_w[4]&&!(epoch_valid&&epoch_bank==4'd4);
 assign wr_ready[4]=resetn&&available_w[4]&&write_legal_w[4]&&!(epoch_valid&&epoch_bank==4'd4);
 assign wr_commit[4]=wr_valid[4]&&wr_ready[4];
 smollm2_bank_payload #(.WORDS(WORDS_4),.WIDE(1'b0),.ULTRA(1'b0)) payload_4(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[4]&&rd_ready[4]),
   .rd_address(rd_word_address[76+:19]),.rd_wide(rd_wide[4]),
   .wr_fire(wr_commit[4]),.wr_address(wr_word_address[76+:19]),
   .wr_data(wr_data[512+:128]),.wr_strb(wr_strb[64+:16]),
   .rd_data(rd_data[1024+:256]),.rd_pending(read_pending_w[4]),.rd_resp_valid(rd_resp_valid[4]));
 smollm2_bank_coverage #(.WORDS(WORDS_4),.B7(1'b0)) coverage_4(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[4]),
   .epoch_ready(unit_epoch_ready_w[4]),.epoch_generation_legal(epoch_gen_ok_w[4]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[4]),.epoch_done_ready(epoch_done_ready[4]),
   .epoch_done_token(epoch_done_token[128+:32]),.epoch_done_generation(epoch_done_generation[128+:32]),
   .epoch_done_component(epoch_done_component[8+:2]),.bank_available(available_w[4]),
   .wr_commit(wr_commit[4]),.wr_address(wr_word_address[76+:19]),.wr_strb(wr_strb[64+:16]),
   .wr_transaction_id(wr_transaction_id[128+:32]),.wr_generation(wr_generation[128+:32]),
   .wr_role(wr_role[20+:5]),.wr_legal(write_legal_w[4]),.wr_pending(unit_pending_w[4]),
   .pub_valid(unit_pub_valid_w[4]),.pub_ready(unit_pub_ready_w[4]),
   .pub_component(unit_comp_w[8+:2]),.pub_generation(unit_gen_w[128+:32]),
   .pub_transaction_id(unit_txn_w[128+:32]),.pub_role(unit_role_w[20+:5]),
   .pub_data_complete(unit_data_w[4]),.pub_scale_complete(unit_scale_w[4]));

 localparam integer WORDS_5=2304;
 assign read_legal_w[5]=rd_word_address[95+:19]<19'd2304&&
   (!rd_wide[5]||(1'b0&&!rd_word_address[95]&&rd_word_address[95+:19]+19'd1<19'd2304));
 assign rd_ready[5]=resetn&&available_w[5]&&read_legal_w[5]&&!(epoch_valid&&epoch_bank==4'd5);
 assign wr_ready[5]=resetn&&available_w[5]&&write_legal_w[5]&&!(epoch_valid&&epoch_bank==4'd5);
 assign wr_commit[5]=wr_valid[5]&&wr_ready[5];
 smollm2_bank_payload #(.WORDS(WORDS_5),.WIDE(1'b0),.ULTRA(1'b0)) payload_5(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[5]&&rd_ready[5]),
   .rd_address(rd_word_address[95+:19]),.rd_wide(rd_wide[5]),
   .wr_fire(wr_commit[5]),.wr_address(wr_word_address[95+:19]),
   .wr_data(wr_data[640+:128]),.wr_strb(wr_strb[80+:16]),
   .rd_data(rd_data[1280+:256]),.rd_pending(read_pending_w[5]),.rd_resp_valid(rd_resp_valid[5]));
 smollm2_bank_coverage #(.WORDS(WORDS_5),.B7(1'b0)) coverage_5(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[5]),
   .epoch_ready(unit_epoch_ready_w[5]),.epoch_generation_legal(epoch_gen_ok_w[5]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[5]),.epoch_done_ready(epoch_done_ready[5]),
   .epoch_done_token(epoch_done_token[160+:32]),.epoch_done_generation(epoch_done_generation[160+:32]),
   .epoch_done_component(epoch_done_component[10+:2]),.bank_available(available_w[5]),
   .wr_commit(wr_commit[5]),.wr_address(wr_word_address[95+:19]),.wr_strb(wr_strb[80+:16]),
   .wr_transaction_id(wr_transaction_id[160+:32]),.wr_generation(wr_generation[160+:32]),
   .wr_role(wr_role[25+:5]),.wr_legal(write_legal_w[5]),.wr_pending(unit_pending_w[5]),
   .pub_valid(unit_pub_valid_w[5]),.pub_ready(unit_pub_ready_w[5]),
   .pub_component(unit_comp_w[10+:2]),.pub_generation(unit_gen_w[160+:32]),
   .pub_transaction_id(unit_txn_w[160+:32]),.pub_role(unit_role_w[25+:5]),
   .pub_data_complete(unit_data_w[5]),.pub_scale_complete(unit_scale_w[5]));

 localparam integer WORDS_6=768;
 assign read_legal_w[6]=rd_word_address[114+:19]<19'd768&&
   (!rd_wide[6]||(1'b0&&!rd_word_address[114]&&rd_word_address[114+:19]+19'd1<19'd768));
 assign rd_ready[6]=resetn&&available_w[6]&&read_legal_w[6]&&!(epoch_valid&&epoch_bank==4'd6);
 assign wr_ready[6]=resetn&&available_w[6]&&write_legal_w[6]&&!(epoch_valid&&epoch_bank==4'd6);
 assign wr_commit[6]=wr_valid[6]&&wr_ready[6];
 smollm2_bank_payload #(.WORDS(WORDS_6),.WIDE(1'b0),.ULTRA(1'b0)) payload_6(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[6]&&rd_ready[6]),
   .rd_address(rd_word_address[114+:19]),.rd_wide(rd_wide[6]),
   .wr_fire(wr_commit[6]),.wr_address(wr_word_address[114+:19]),
   .wr_data(wr_data[768+:128]),.wr_strb(wr_strb[96+:16]),
   .rd_data(rd_data[1536+:256]),.rd_pending(read_pending_w[6]),.rd_resp_valid(rd_resp_valid[6]));
 smollm2_bank_coverage #(.WORDS(WORDS_6),.B7(1'b0)) coverage_6(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[6]),
   .epoch_ready(unit_epoch_ready_w[6]),.epoch_generation_legal(epoch_gen_ok_w[6]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[6]),.epoch_done_ready(epoch_done_ready[6]),
   .epoch_done_token(epoch_done_token[192+:32]),.epoch_done_generation(epoch_done_generation[192+:32]),
   .epoch_done_component(epoch_done_component[12+:2]),.bank_available(available_w[6]),
   .wr_commit(wr_commit[6]),.wr_address(wr_word_address[114+:19]),.wr_strb(wr_strb[96+:16]),
   .wr_transaction_id(wr_transaction_id[192+:32]),.wr_generation(wr_generation[192+:32]),
   .wr_role(wr_role[30+:5]),.wr_legal(write_legal_w[6]),.wr_pending(unit_pending_w[6]),
   .pub_valid(unit_pub_valid_w[6]),.pub_ready(unit_pub_ready_w[6]),
   .pub_component(unit_comp_w[12+:2]),.pub_generation(unit_gen_w[192+:32]),
   .pub_transaction_id(unit_txn_w[192+:32]),.pub_role(unit_role_w[30+:5]),
   .pub_data_complete(unit_data_w[6]),.pub_scale_complete(unit_scale_w[6]));

 localparam integer WORDS_7=376;
 assign read_legal_w[7]=rd_word_address[133+:19]<19'd376&&
   (!rd_wide[7]||(1'b0&&!rd_word_address[133]&&rd_word_address[133+:19]+19'd1<19'd376));
 assign rd_ready[7]=resetn&&available_w[7]&&read_legal_w[7]&&!(epoch_valid&&epoch_bank==4'd7);
 assign wr_ready[7]=resetn&&available_w[7]&&write_legal_w[7]&&!(epoch_valid&&epoch_bank==4'd7);
 assign wr_commit[7]=wr_valid[7]&&wr_ready[7];
 smollm2_bank_payload #(.WORDS(WORDS_7),.WIDE(1'b0),.ULTRA(1'b0)) payload_7(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[7]&&rd_ready[7]),
   .rd_address(rd_word_address[133+:19]),.rd_wide(rd_wide[7]),
   .wr_fire(wr_commit[7]),.wr_address(wr_word_address[133+:19]),
   .wr_data(wr_data[896+:128]),.wr_strb(wr_strb[112+:16]),
   .rd_data(rd_data[1792+:256]),.rd_pending(read_pending_w[7]),.rd_resp_valid(rd_resp_valid[7]));
 smollm2_bank_coverage #(.WORDS(WORDS_7),.B7(1'b1)) coverage_7(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[7]),
   .epoch_ready(unit_epoch_ready_w[7]),.epoch_generation_legal(epoch_gen_ok_w[7]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[7]),.epoch_done_ready(epoch_done_ready[7]),
   .epoch_done_token(epoch_done_token[224+:32]),.epoch_done_generation(epoch_done_generation[224+:32]),
   .epoch_done_component(epoch_done_component[14+:2]),.bank_available(available_w[7]),
   .wr_commit(wr_commit[7]),.wr_address(wr_word_address[133+:19]),.wr_strb(wr_strb[112+:16]),
   .wr_transaction_id(wr_transaction_id[224+:32]),.wr_generation(wr_generation[224+:32]),
   .wr_role(wr_role[35+:5]),.wr_legal(write_legal_w[7]),.wr_pending(unit_pending_w[7]),
   .pub_valid(unit_pub_valid_w[7]),.pub_ready(unit_pub_ready_w[7]),
   .pub_component(unit_comp_w[14+:2]),.pub_generation(unit_gen_w[224+:32]),
   .pub_transaction_id(unit_txn_w[224+:32]),.pub_role(unit_role_w[35+:5]),
   .pub_data_complete(unit_data_w[7]),.pub_scale_complete(unit_scale_w[7]));

 localparam integer WORDS_8=12290;
 assign read_legal_w[8]=rd_word_address[152+:19]<19'd12290&&
   (!rd_wide[8]||(1'b1&&!rd_word_address[152]&&rd_word_address[152+:19]+19'd1<19'd12290));
 assign rd_ready[8]=resetn&&available_w[8]&&read_legal_w[8]&&!(epoch_valid&&epoch_bank==4'd8);
 assign wr_ready[8]=resetn&&available_w[8]&&write_legal_w[8]&&!(epoch_valid&&epoch_bank==4'd8);
 assign wr_commit[8]=wr_valid[8]&&wr_ready[8];
 smollm2_bank_payload #(.WORDS(WORDS_8),.WIDE(1'b1),.ULTRA(1'b1)) payload_8(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[8]&&rd_ready[8]),
   .rd_address(rd_word_address[152+:19]),.rd_wide(rd_wide[8]),
   .wr_fire(wr_commit[8]),.wr_address(wr_word_address[152+:19]),
   .wr_data(wr_data[1024+:128]),.wr_strb(wr_strb[128+:16]),
   .rd_data(rd_data[2048+:256]),.rd_pending(read_pending_w[8]),.rd_resp_valid(rd_resp_valid[8]));
 smollm2_bank_coverage #(.WORDS(WORDS_8),.B7(1'b0)) coverage_8(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[8]),
   .epoch_ready(unit_epoch_ready_w[8]),.epoch_generation_legal(epoch_gen_ok_w[8]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[8]),.epoch_done_ready(epoch_done_ready[8]),
   .epoch_done_token(epoch_done_token[256+:32]),.epoch_done_generation(epoch_done_generation[256+:32]),
   .epoch_done_component(epoch_done_component[16+:2]),.bank_available(available_w[8]),
   .wr_commit(wr_commit[8]),.wr_address(wr_word_address[152+:19]),.wr_strb(wr_strb[128+:16]),
   .wr_transaction_id(wr_transaction_id[256+:32]),.wr_generation(wr_generation[256+:32]),
   .wr_role(wr_role[40+:5]),.wr_legal(write_legal_w[8]),.wr_pending(unit_pending_w[8]),
   .pub_valid(unit_pub_valid_w[8]),.pub_ready(unit_pub_ready_w[8]),
   .pub_component(unit_comp_w[16+:2]),.pub_generation(unit_gen_w[256+:32]),
   .pub_transaction_id(unit_txn_w[256+:32]),.pub_role(unit_role_w[40+:5]),
   .pub_data_complete(unit_data_w[8]),.pub_scale_complete(unit_scale_w[8]));

 localparam integer WORDS_9=12292;
 assign read_legal_w[9]=rd_word_address[171+:19]<19'd12292&&
   (!rd_wide[9]||(1'b1&&!rd_word_address[171]&&rd_word_address[171+:19]+19'd1<19'd12292));
 assign rd_ready[9]=resetn&&available_w[9]&&read_legal_w[9]&&!(epoch_valid&&epoch_bank==4'd9);
 assign wr_ready[9]=resetn&&available_w[9]&&write_legal_w[9]&&!(epoch_valid&&epoch_bank==4'd9);
 assign wr_commit[9]=wr_valid[9]&&wr_ready[9];
 smollm2_bank_payload #(.WORDS(WORDS_9),.WIDE(1'b1),.ULTRA(1'b1)) payload_9(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[9]&&rd_ready[9]),
   .rd_address(rd_word_address[171+:19]),.rd_wide(rd_wide[9]),
   .wr_fire(wr_commit[9]),.wr_address(wr_word_address[171+:19]),
   .wr_data(wr_data[1152+:128]),.wr_strb(wr_strb[144+:16]),
   .rd_data(rd_data[2304+:256]),.rd_pending(read_pending_w[9]),.rd_resp_valid(rd_resp_valid[9]));
 smollm2_bank_coverage #(.WORDS(WORDS_9),.B7(1'b0)) coverage_9(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[9]),
   .epoch_ready(unit_epoch_ready_w[9]),.epoch_generation_legal(epoch_gen_ok_w[9]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[9]),.epoch_done_ready(epoch_done_ready[9]),
   .epoch_done_token(epoch_done_token[288+:32]),.epoch_done_generation(epoch_done_generation[288+:32]),
   .epoch_done_component(epoch_done_component[18+:2]),.bank_available(available_w[9]),
   .wr_commit(wr_commit[9]),.wr_address(wr_word_address[171+:19]),.wr_strb(wr_strb[144+:16]),
   .wr_transaction_id(wr_transaction_id[288+:32]),.wr_generation(wr_generation[288+:32]),
   .wr_role(wr_role[45+:5]),.wr_legal(write_legal_w[9]),.wr_pending(unit_pending_w[9]),
   .pub_valid(unit_pub_valid_w[9]),.pub_ready(unit_pub_ready_w[9]),
   .pub_component(unit_comp_w[18+:2]),.pub_generation(unit_gen_w[288+:32]),
   .pub_transaction_id(unit_txn_w[288+:32]),.pub_role(unit_role_w[45+:5]),
   .pub_data_complete(unit_data_w[9]),.pub_scale_complete(unit_scale_w[9]));

 localparam integer WORDS_10=36864;
 assign read_legal_w[10]=rd_word_address[190+:19]<19'd36864&&
   (!rd_wide[10]||(1'b0&&!rd_word_address[190]&&rd_word_address[190+:19]+19'd1<19'd36864));
 assign rd_ready[10]=resetn&&available_w[10]&&read_legal_w[10]&&!(epoch_valid&&epoch_bank==4'd10);
 assign wr_ready[10]=resetn&&available_w[10]&&write_legal_w[10]&&!(epoch_valid&&epoch_bank==4'd10);
 assign wr_commit[10]=wr_valid[10]&&wr_ready[10];
 smollm2_bank_payload #(.WORDS(WORDS_10),.WIDE(1'b0),.ULTRA(1'b1)) payload_10(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[10]&&rd_ready[10]),
   .rd_address(rd_word_address[190+:19]),.rd_wide(rd_wide[10]),
   .wr_fire(wr_commit[10]),.wr_address(wr_word_address[190+:19]),
   .wr_data(wr_data[1280+:128]),.wr_strb(wr_strb[160+:16]),
   .rd_data(rd_data[2560+:256]),.rd_pending(read_pending_w[10]),.rd_resp_valid(rd_resp_valid[10]));
 smollm2_bank_coverage #(.WORDS(WORDS_10),.B7(1'b0)) coverage_10(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[10]),
   .epoch_ready(unit_epoch_ready_w[10]),.epoch_generation_legal(epoch_gen_ok_w[10]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[10]),.epoch_done_ready(epoch_done_ready[10]),
   .epoch_done_token(epoch_done_token[320+:32]),.epoch_done_generation(epoch_done_generation[320+:32]),
   .epoch_done_component(epoch_done_component[20+:2]),.bank_available(available_w[10]),
   .wr_commit(wr_commit[10]),.wr_address(wr_word_address[190+:19]),.wr_strb(wr_strb[160+:16]),
   .wr_transaction_id(wr_transaction_id[320+:32]),.wr_generation(wr_generation[320+:32]),
   .wr_role(wr_role[50+:5]),.wr_legal(write_legal_w[10]),.wr_pending(unit_pending_w[10]),
   .pub_valid(unit_pub_valid_w[10]),.pub_ready(unit_pub_ready_w[10]),
   .pub_component(unit_comp_w[20+:2]),.pub_generation(unit_gen_w[320+:32]),
   .pub_transaction_id(unit_txn_w[320+:32]),.pub_role(unit_role_w[50+:5]),
   .pub_data_complete(unit_data_w[10]),.pub_scale_complete(unit_scale_w[10]));

 localparam integer WORDS_11=2304;
 assign read_legal_w[11]=rd_word_address[209+:19]<19'd2304&&
   (!rd_wide[11]||(1'b0&&!rd_word_address[209]&&rd_word_address[209+:19]+19'd1<19'd2304));
 assign rd_ready[11]=resetn&&available_w[11]&&read_legal_w[11]&&!(epoch_valid&&epoch_bank==4'd11);
 assign wr_ready[11]=resetn&&available_w[11]&&write_legal_w[11]&&!(epoch_valid&&epoch_bank==4'd11);
 assign wr_commit[11]=wr_valid[11]&&wr_ready[11];
 smollm2_bank_payload #(.WORDS(WORDS_11),.WIDE(1'b0),.ULTRA(1'b0)) payload_11(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[11]&&rd_ready[11]),
   .rd_address(rd_word_address[209+:19]),.rd_wide(rd_wide[11]),
   .wr_fire(wr_commit[11]),.wr_address(wr_word_address[209+:19]),
   .wr_data(wr_data[1408+:128]),.wr_strb(wr_strb[176+:16]),
   .rd_data(rd_data[2816+:256]),.rd_pending(read_pending_w[11]),.rd_resp_valid(rd_resp_valid[11]));
 smollm2_bank_coverage #(.WORDS(WORDS_11),.B7(1'b0)) coverage_11(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[11]),
   .epoch_ready(unit_epoch_ready_w[11]),.epoch_generation_legal(epoch_gen_ok_w[11]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[11]),.epoch_done_ready(epoch_done_ready[11]),
   .epoch_done_token(epoch_done_token[352+:32]),.epoch_done_generation(epoch_done_generation[352+:32]),
   .epoch_done_component(epoch_done_component[22+:2]),.bank_available(available_w[11]),
   .wr_commit(wr_commit[11]),.wr_address(wr_word_address[209+:19]),.wr_strb(wr_strb[176+:16]),
   .wr_transaction_id(wr_transaction_id[352+:32]),.wr_generation(wr_generation[352+:32]),
   .wr_role(wr_role[55+:5]),.wr_legal(write_legal_w[11]),.wr_pending(unit_pending_w[11]),
   .pub_valid(unit_pub_valid_w[11]),.pub_ready(unit_pub_ready_w[11]),
   .pub_component(unit_comp_w[22+:2]),.pub_generation(unit_gen_w[352+:32]),
   .pub_transaction_id(unit_txn_w[352+:32]),.pub_role(unit_role_w[55+:5]),
   .pub_data_complete(unit_data_w[11]),.pub_scale_complete(unit_scale_w[11]));

 localparam integer WORDS_12=6144;
 assign read_legal_w[12]=rd_word_address[228+:19]<19'd6144&&
   (!rd_wide[12]||(1'b0&&!rd_word_address[228]&&rd_word_address[228+:19]+19'd1<19'd6144));
 assign rd_ready[12]=resetn&&available_w[12]&&read_legal_w[12]&&!(epoch_valid&&epoch_bank==4'd12);
 assign wr_ready[12]=resetn&&available_w[12]&&write_legal_w[12]&&!(epoch_valid&&epoch_bank==4'd12);
 assign wr_commit[12]=wr_valid[12]&&wr_ready[12];
 smollm2_bank_payload #(.WORDS(WORDS_12),.WIDE(1'b0),.ULTRA(1'b1)) payload_12(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[12]&&rd_ready[12]),
   .rd_address(rd_word_address[228+:19]),.rd_wide(rd_wide[12]),
   .wr_fire(wr_commit[12]),.wr_address(wr_word_address[228+:19]),
   .wr_data(wr_data[1536+:128]),.wr_strb(wr_strb[192+:16]),
   .rd_data(rd_data[3072+:256]),.rd_pending(read_pending_w[12]),.rd_resp_valid(rd_resp_valid[12]));
 smollm2_bank_coverage #(.WORDS(WORDS_12),.B7(1'b0)) coverage_12(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[12]),
   .epoch_ready(unit_epoch_ready_w[12]),.epoch_generation_legal(epoch_gen_ok_w[12]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[12]),.epoch_done_ready(epoch_done_ready[12]),
   .epoch_done_token(epoch_done_token[384+:32]),.epoch_done_generation(epoch_done_generation[384+:32]),
   .epoch_done_component(epoch_done_component[24+:2]),.bank_available(available_w[12]),
   .wr_commit(wr_commit[12]),.wr_address(wr_word_address[228+:19]),.wr_strb(wr_strb[192+:16]),
   .wr_transaction_id(wr_transaction_id[384+:32]),.wr_generation(wr_generation[384+:32]),
   .wr_role(wr_role[60+:5]),.wr_legal(write_legal_w[12]),.wr_pending(unit_pending_w[12]),
   .pub_valid(unit_pub_valid_w[12]),.pub_ready(unit_pub_ready_w[12]),
   .pub_component(unit_comp_w[24+:2]),.pub_generation(unit_gen_w[384+:32]),
   .pub_transaction_id(unit_txn_w[384+:32]),.pub_role(unit_role_w[60+:5]),
   .pub_data_complete(unit_data_w[12]),.pub_scale_complete(unit_scale_w[12]));

 localparam integer WORDS_13=18438;
 assign read_legal_w[13]=rd_word_address[247+:19]<19'd18438&&
   (!rd_wide[13]||(1'b1&&!rd_word_address[247]&&rd_word_address[247+:19]+19'd1<19'd18438));
 assign rd_ready[13]=resetn&&available_w[13]&&read_legal_w[13]&&!(epoch_valid&&epoch_bank==4'd13);
 assign wr_ready[13]=resetn&&available_w[13]&&write_legal_w[13]&&!(epoch_valid&&epoch_bank==4'd13);
 assign wr_commit[13]=wr_valid[13]&&wr_ready[13];
 smollm2_bank_payload #(.WORDS(WORDS_13),.WIDE(1'b1),.ULTRA(1'b1)) payload_13(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[13]&&rd_ready[13]),
   .rd_address(rd_word_address[247+:19]),.rd_wide(rd_wide[13]),
   .wr_fire(wr_commit[13]),.wr_address(wr_word_address[247+:19]),
   .wr_data(wr_data[1664+:128]),.wr_strb(wr_strb[208+:16]),
   .rd_data(rd_data[3328+:256]),.rd_pending(read_pending_w[13]),.rd_resp_valid(rd_resp_valid[13]));
 smollm2_bank_coverage #(.WORDS(WORDS_13),.B7(1'b0)) coverage_13(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[13]),
   .epoch_ready(unit_epoch_ready_w[13]),.epoch_generation_legal(epoch_gen_ok_w[13]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[13]),.epoch_done_ready(epoch_done_ready[13]),
   .epoch_done_token(epoch_done_token[416+:32]),.epoch_done_generation(epoch_done_generation[416+:32]),
   .epoch_done_component(epoch_done_component[26+:2]),.bank_available(available_w[13]),
   .wr_commit(wr_commit[13]),.wr_address(wr_word_address[247+:19]),.wr_strb(wr_strb[208+:16]),
   .wr_transaction_id(wr_transaction_id[416+:32]),.wr_generation(wr_generation[416+:32]),
   .wr_role(wr_role[65+:5]),.wr_legal(write_legal_w[13]),.wr_pending(unit_pending_w[13]),
   .pub_valid(unit_pub_valid_w[13]),.pub_ready(unit_pub_ready_w[13]),
   .pub_component(unit_comp_w[26+:2]),.pub_generation(unit_gen_w[416+:32]),
   .pub_transaction_id(unit_txn_w[416+:32]),.pub_role(unit_role_w[65+:5]),
   .pub_data_complete(unit_data_w[13]),.pub_scale_complete(unit_scale_w[13]));

 localparam integer WORDS_14=1158;
 assign read_legal_w[14]=rd_word_address[266+:19]<19'd1158&&
   (!rd_wide[14]||(1'b1&&!rd_word_address[266]&&rd_word_address[266+:19]+19'd1<19'd1158));
 assign rd_ready[14]=resetn&&available_w[14]&&read_legal_w[14]&&!(epoch_valid&&epoch_bank==4'd14);
 assign wr_ready[14]=resetn&&available_w[14]&&write_legal_w[14]&&!(epoch_valid&&epoch_bank==4'd14);
 assign wr_commit[14]=wr_valid[14]&&wr_ready[14];
 smollm2_bank_payload #(.WORDS(WORDS_14),.WIDE(1'b1),.ULTRA(1'b0)) payload_14(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[14]&&rd_ready[14]),
   .rd_address(rd_word_address[266+:19]),.rd_wide(rd_wide[14]),
   .wr_fire(wr_commit[14]),.wr_address(wr_word_address[266+:19]),
   .wr_data(wr_data[1792+:128]),.wr_strb(wr_strb[224+:16]),
   .rd_data(rd_data[3584+:256]),.rd_pending(read_pending_w[14]),.rd_resp_valid(rd_resp_valid[14]));
 smollm2_bank_coverage #(.WORDS(WORDS_14),.B7(1'b0)) coverage_14(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[14]),
   .epoch_ready(unit_epoch_ready_w[14]),.epoch_generation_legal(epoch_gen_ok_w[14]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[14]),.epoch_done_ready(epoch_done_ready[14]),
   .epoch_done_token(epoch_done_token[448+:32]),.epoch_done_generation(epoch_done_generation[448+:32]),
   .epoch_done_component(epoch_done_component[28+:2]),.bank_available(available_w[14]),
   .wr_commit(wr_commit[14]),.wr_address(wr_word_address[266+:19]),.wr_strb(wr_strb[224+:16]),
   .wr_transaction_id(wr_transaction_id[448+:32]),.wr_generation(wr_generation[448+:32]),
   .wr_role(wr_role[70+:5]),.wr_legal(write_legal_w[14]),.wr_pending(unit_pending_w[14]),
   .pub_valid(unit_pub_valid_w[14]),.pub_ready(unit_pub_ready_w[14]),
   .pub_component(unit_comp_w[28+:2]),.pub_generation(unit_gen_w[448+:32]),
   .pub_transaction_id(unit_txn_w[448+:32]),.pub_role(unit_role_w[70+:5]),
   .pub_data_complete(unit_data_w[14]),.pub_scale_complete(unit_scale_w[14]));

 localparam integer WORDS_15=18440;
 assign read_legal_w[15]=rd_word_address[285+:19]<19'd18440&&
   (!rd_wide[15]||(1'b1&&!rd_word_address[285]&&rd_word_address[285+:19]+19'd1<19'd18440));
 assign rd_ready[15]=resetn&&available_w[15]&&read_legal_w[15]&&!(epoch_valid&&epoch_bank==4'd15);
 assign wr_ready[15]=resetn&&available_w[15]&&write_legal_w[15]&&!(epoch_valid&&epoch_bank==4'd15);
 assign wr_commit[15]=wr_valid[15]&&wr_ready[15];
 smollm2_bank_payload #(.WORDS(WORDS_15),.WIDE(1'b1),.ULTRA(1'b1)) payload_15(
   .clk(clk),.resetn(resetn),.rd_fire(rd_valid[15]&&rd_ready[15]),
   .rd_address(rd_word_address[285+:19]),.rd_wide(rd_wide[15]),
   .wr_fire(wr_commit[15]),.wr_address(wr_word_address[285+:19]),
   .wr_data(wr_data[1920+:128]),.wr_strb(wr_strb[240+:16]),
   .rd_data(rd_data[3840+:256]),.rd_pending(read_pending_w[15]),.rd_resp_valid(rd_resp_valid[15]));
 smollm2_bank_coverage #(.WORDS(WORDS_15),.B7(1'b0)) coverage_15(
   .clk(clk),.resetn(resetn),.epoch_valid(epoch_fire_w[15]),
   .epoch_ready(unit_epoch_ready_w[15]),.epoch_generation_legal(epoch_gen_ok_w[15]),
   .epoch_component(epoch_component),.epoch_token(epoch_token),.epoch_generation(epoch_generation),
   .epoch_data_offset(epoch_data_offset),.epoch_data_bytes(epoch_data_bytes),
   .epoch_scale_offset(epoch_scale_offset),.epoch_scale_bytes(epoch_scale_bytes),
   .epoch_done_valid(epoch_done_valid[15]),.epoch_done_ready(epoch_done_ready[15]),
   .epoch_done_token(epoch_done_token[480+:32]),.epoch_done_generation(epoch_done_generation[480+:32]),
   .epoch_done_component(epoch_done_component[30+:2]),.bank_available(available_w[15]),
   .wr_commit(wr_commit[15]),.wr_address(wr_word_address[285+:19]),.wr_strb(wr_strb[240+:16]),
   .wr_transaction_id(wr_transaction_id[480+:32]),.wr_generation(wr_generation[480+:32]),
   .wr_role(wr_role[75+:5]),.wr_legal(write_legal_w[15]),.wr_pending(unit_pending_w[15]),
   .pub_valid(unit_pub_valid_w[15]),.pub_ready(unit_pub_ready_w[15]),
   .pub_component(unit_comp_w[30+:2]),.pub_generation(unit_gen_w[480+:32]),
   .pub_transaction_id(unit_txn_w[480+:32]),.pub_role(unit_role_w[75+:5]),
   .pub_data_complete(unit_data_w[15]),.pub_scale_complete(unit_scale_w[15]));
endmodule
