`timescale 1ns/1ps
module smollm2_bank_coverage #(
 parameter integer WORDS=2304, parameter bit B7=0
)(
 input logic clk,resetn,
 input logic epoch_valid, output logic epoch_ready,epoch_generation_legal,
 input logic[1:0] epoch_component,input logic[31:0] epoch_token,epoch_generation,
 input logic[31:0] epoch_data_offset,epoch_data_bytes,epoch_scale_offset,epoch_scale_bytes,
 output logic epoch_done_valid,input logic epoch_done_ready,
 output logic[31:0] epoch_done_token,epoch_done_generation,output logic[1:0]epoch_done_component,
 output logic bank_available,
 input logic wr_commit,input logic[18:0]wr_address,input logic[15:0]wr_strb,
 input logic[31:0]wr_transaction_id,wr_generation,input logic[4:0]wr_role,
 output logic wr_legal,wr_pending,
 output logic pub_valid,input logic pub_ready,output logic[1:0]pub_component,
 output logic[31:0]pub_generation,pub_transaction_id,output logic[4:0]pub_role,
 output logic pub_data_complete,pub_scale_complete
);
 localparam integer AW=$clog2(WORDS);
 logic initialized_r,clear_r,clear_scale_r;
 logic[18:0] clear_cursor_r,clear_end_r,clear_scale_start_r,clear_scale_end_r;
 logic[31:0] offset_r[2],bytes_r[2],generation_r[2],remaining_r[2];
 logic[1:0]active_r,complete_r;
 logic s0_valid_r;logic[18:0]s0_address_r;logic[15:0]s0_strb_r;
 logic[31:0]s0_txn_r,s0_gen_r;logic[4:0]s0_role_r;
 logic last_valid_r;logic[18:0]last_address_r;logic[15:0]last_mask_r;
 logic[15:0]mask_read_w,old_mask_w,new_mask_w,required0_w,required1_w;
 logic[4:0] delta0_w,delta1_w;logic done0_w,done1_w,push_w;
 logic[15:0]request_required_w;
 logic cov_write_w;logic[AW-1:0]cov_write_addr_w;logic[15:0]cov_write_data_w;
 logic[1:0]queue_count_r;logic queue_head_r,queue_tail_r;
 logic[1:0]queue_component_r[2];logic[31:0]queue_gen_r[2],queue_txn_r[2];
 logic[4:0]queue_role_r[2];logic queue_data_r[2],queue_scale_r[2];
 function automatic logic[15:0]required(input logic[18:0]address,input logic[31:0]off,input logic[31:0]len);
   logic[32:0]endbyte,byteaddr;logic[15:0]result;
   begin endbyte={1'b0,off}+{1'b0,len};result=0;
     for(int k=0;k<16;k++)begin byteaddr={10'b0,address,4'b0}+33'(k);
       if(byteaddr>={1'b0,off}&&byteaddr<endbyte)result[k]=1;end
     required=result;end
 endfunction
 function automatic logic[4:0]popcount16(input logic[15:0]bits);
   logic[4:0]count;begin count=0;for(int k=0;k<16;k++)count=count+{4'b0,bits[k]};popcount16=count;end
 endfunction
 always_comb begin
   bank_available=initialized_r&&!clear_r&&!epoch_done_valid;
   wr_pending=s0_valid_r||queue_count_r!=0;
   epoch_ready=bank_available&&!wr_pending;
   epoch_generation_legal=epoch_generation!=0&&
     (!B7?(epoch_component==0&&epoch_generation>generation_r[0]):
       ((epoch_component==2||epoch_generation>generation_r[0])&&
        (epoch_component==1||epoch_generation>generation_r[1])&&epoch_component<=2));
   request_required_w=required(wr_address,offset_r[0],bytes_r[0])|
                      required(wr_address,offset_r[1],bytes_r[1]);
   wr_legal=({1'b0,wr_address}<20'(WORDS))&&wr_role>=1&&wr_role<=26&&
      ((wr_strb&~request_required_w)==0)&&
      (B7&&wr_address>=19'd256?(active_r[1]&&wr_generation==generation_r[1]):
                                     (active_r[0]&&wr_generation==generation_r[0]));
   old_mask_w=last_valid_r&&last_address_r==s0_address_r?last_mask_r:mask_read_w;
   new_mask_w=old_mask_w|s0_strb_r;
   required0_w=required(s0_address_r,offset_r[0],bytes_r[0]);
   required1_w=required(s0_address_r,offset_r[1],bytes_r[1]);
   delta0_w=popcount16((new_mask_w&~old_mask_w)&required0_w);
   delta1_w=popcount16((new_mask_w&~old_mask_w)&required1_w);
   done0_w=s0_valid_r&&!complete_r[0]&&delta0_w!=0&&remaining_r[0]==32'(delta0_w);
   done1_w=s0_valid_r&&!complete_r[1]&&delta1_w!=0&&remaining_r[1]==32'(delta1_w);
   push_w=done0_w||done1_w;
   cov_write_w=!initialized_r||clear_r||s0_valid_r;
   cov_write_addr_w=AW'((!initialized_r||clear_r)?clear_cursor_r:s0_address_r);
   cov_write_data_w=(!initialized_r||clear_r)?16'd0:new_mask_w;
   pub_valid=queue_count_r!=0;
   pub_component=queue_component_r[queue_head_r];pub_generation=queue_gen_r[queue_head_r];
   pub_transaction_id=queue_txn_r[queue_head_r];pub_role=queue_role_r[queue_head_r];
   pub_data_complete=queue_data_r[queue_head_r];pub_scale_complete=queue_scale_r[queue_head_r];
 end
 xpm_memory_sdpram #(.ADDR_WIDTH_A(AW),.ADDR_WIDTH_B(AW),.AUTO_SLEEP_TIME(0),
   .BYTE_WRITE_WIDTH_A(16),.CASCADE_HEIGHT(0),.CLOCKING_MODE("common_clock"),
   .ECC_MODE("no_ecc"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM(""),
   .MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(WORDS*16),
   .MESSAGE_CONTROL(0),.READ_DATA_WIDTH_B(16),.READ_LATENCY_B(1),
   .READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),
   .SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),
   .WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(16),.WRITE_MODE_B("read_first")) masks (
   .sleep(1'b0),.clka(clk),.ena(resetn&&cov_write_w),.wea(1'b1),
   .addra(cov_write_addr_w),.dina(cov_write_data_w),.injectsbiterra(1'b0),.injectdbiterra(1'b0),
   .clkb(clk),.rstb(!resetn),.enb(wr_commit),.regceb(1'b1),.addrb(AW'(wr_address)),
   .doutb(mask_read_w),.sbiterrb(),.dbiterrb());
 always_ff @(posedge clk)begin
   if(!resetn)begin
     initialized_r<=0;clear_r<=0;clear_scale_r<=0;clear_cursor_r<=0;clear_end_r<=0;
     clear_scale_start_r<=0;clear_scale_end_r<=0;active_r<=0;complete_r<=0;
     epoch_done_valid<=0;epoch_done_token<=0;epoch_done_generation<=0;epoch_done_component<=0;
     s0_valid_r<=0;s0_address_r<=0;s0_strb_r<=0;s0_txn_r<=0;s0_gen_r<=0;s0_role_r<=0;
     last_valid_r<=0;last_address_r<=0;last_mask_r<=0;
     queue_count_r<=0;queue_head_r<=0;queue_tail_r<=0;
     for(int k=0;k<2;k++)begin offset_r[k]<=0;bytes_r[k]<=0;generation_r[k]<=0;remaining_r[k]<=0;
       queue_component_r[k]<=0;queue_gen_r[k]<=0;queue_txn_r[k]<=0;queue_role_r[k]<=0;
       queue_data_r[k]<=0;queue_scale_r[k]<=0;end
   end else begin
     if(!initialized_r)begin
       if(clear_cursor_r==19'(WORDS-1))begin initialized_r<=1;clear_cursor_r<=0;end
       else clear_cursor_r<=clear_cursor_r+19'd1;
     end else if(clear_r)begin
       if(clear_cursor_r+19'd1==clear_end_r)begin
         if(!clear_scale_r&&clear_scale_start_r<clear_scale_end_r)begin
           clear_scale_r<=1;clear_cursor_r<=clear_scale_start_r;clear_end_r<=clear_scale_end_r;
         end else begin clear_r<=0;epoch_done_valid<=1;end
       end else clear_cursor_r<=clear_cursor_r+19'd1;
     end
     if(epoch_done_valid&&epoch_done_ready)epoch_done_valid<=0;
     if(epoch_valid&&epoch_ready)begin
       epoch_done_token<=epoch_token;epoch_done_generation<=epoch_generation;epoch_done_component<=epoch_component;
       clear_r<=1;clear_scale_r<=0;clear_cursor_r<=19'(epoch_data_offset>>4);
       clear_end_r<=19'((epoch_data_offset+epoch_data_bytes)>>4);
       clear_scale_start_r<=19'(epoch_scale_offset>>4);
       clear_scale_end_r<=19'((epoch_scale_offset+epoch_scale_bytes)>>4);
       if(B7&&epoch_component==2)begin
         offset_r[1]<=epoch_data_offset;bytes_r[1]<=epoch_data_bytes;generation_r[1]<=epoch_generation;
         remaining_r[1]<=epoch_data_bytes;active_r[1]<=1;complete_r[1]<=0;
       end else begin
         offset_r[0]<=epoch_data_offset;bytes_r[0]<=epoch_data_bytes;generation_r[0]<=epoch_generation;
         remaining_r[0]<=epoch_data_bytes;active_r[0]<=1;complete_r[0]<=0;
         if(!B7||epoch_component==0)begin
           offset_r[1]<=epoch_scale_offset;bytes_r[1]<=epoch_scale_bytes;generation_r[1]<=epoch_generation;
           remaining_r[1]<=epoch_scale_bytes;active_r[1]<=1;complete_r[1]<=epoch_scale_bytes==0;
         end
       end
     end
     s0_valid_r<=wr_commit;
     if(wr_commit)begin s0_address_r<=wr_address;s0_strb_r<=wr_strb;
       s0_txn_r<=wr_transaction_id;s0_gen_r<=wr_generation;s0_role_r<=wr_role;end
     last_valid_r<=s0_valid_r;
     if(s0_valid_r)begin last_address_r<=s0_address_r;last_mask_r<=new_mask_w;
       remaining_r[0]<=remaining_r[0]-32'(delta0_w);remaining_r[1]<=remaining_r[1]-32'(delta1_w);
       if(done0_w)complete_r[0]<=1;if(done1_w)complete_r[1]<=1;
     end
     case({push_w,pub_valid&&pub_ready})
       2'b10:queue_count_r<=queue_count_r+2'd1;
       2'b01:queue_count_r<=queue_count_r-2'd1;
       default:begin end
     endcase
     if(pub_valid&&pub_ready)queue_head_r<=~queue_head_r;
     if(push_w)begin
       queue_component_r[queue_tail_r]<=B7?(done0_w?2'd1:2'd2):2'd0;
       queue_gen_r[queue_tail_r]<=s0_gen_r;queue_txn_r[queue_tail_r]<=s0_txn_r;
       queue_role_r[queue_tail_r]<=s0_role_r;
       queue_data_r[queue_tail_r]<=B7?1'b1:(complete_r[0]||done0_w);
       queue_scale_r[queue_tail_r]<=B7?1'b1:(complete_r[1]||done1_w);
       queue_tail_r<=~queue_tail_r;
     end
   end
 end
`ifndef SYNTHESIS
 always_ff @(posedge clk)if(resetn)begin
   if(push_w&&queue_count_r==2&&!(pub_valid&&pub_ready))$fatal(1,"coverage publication queue overflow");
   if(s0_valid_r&&(32'(delta0_w)>remaining_r[0]||32'(delta1_w)>remaining_r[1]))$fatal(1,"coverage underflow");
 end
`endif
endmodule
