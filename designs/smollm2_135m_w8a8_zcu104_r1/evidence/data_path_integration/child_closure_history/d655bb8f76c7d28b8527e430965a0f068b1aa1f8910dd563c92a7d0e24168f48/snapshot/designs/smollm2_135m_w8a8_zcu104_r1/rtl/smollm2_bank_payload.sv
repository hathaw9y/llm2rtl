`timescale 1ns/1ps
module smollm2_bank_payload #(
 parameter integer WORDS=2304,parameter bit WIDE=0,parameter bit ULTRA=0
)(input logic clk,resetn,input logic rd_fire,input logic[18:0]rd_address,
 input logic rd_wide,input logic wr_fire,input logic[18:0]wr_address,
 input logic[127:0]wr_data,input logic[15:0]wr_strb,
 output logic[255:0]rd_data,output logic rd_pending,output logic rd_resp_valid);
 logic[2:0]valid_r,wide_r;
 logic[127:0]narrow_w;logic[255:0]pair_w;
 always_ff @(posedge clk)begin
   if(!resetn)begin valid_r<=0;wide_r<=0;end
   else begin valid_r<={valid_r[1:0],rd_fire};
     if(rd_fire)wide_r[0]<=rd_wide;
     if(valid_r[0])wide_r[1]<=wide_r[0];
     if(valid_r[1])wide_r[2]<=wide_r[1];
   end
 end
 assign rd_pending=|valid_r;assign rd_resp_valid=valid_r[2];
 generate
   if(ULTRA&&WIDE)begin:ultra_pair
     logic[127:0]even_w,odd_w;logic[2:0]half_r;
     always_ff @(posedge clk)begin
       if(!resetn)half_r<=0;
       else begin
         if(rd_fire)half_r[0]<=rd_address[0];
         if(valid_r[0])half_r[1]<=half_r[0];
         if(valid_r[1])half_r[2]<=half_r[1];
       end
     end
     uram_bank #(.DATA_WIDTH(128),.DEPTH(64'(WORDS)/64'd2),.READ_LATENCY(3),.ADDR_WIDTH(19)) even_mem(
       .aclk(clk),.aresetn(resetn),.ena(wr_fire&&!wr_address[0]),.wea(wr_strb),
       .addra({1'b0,wr_address[18:1]}),.dina(wr_data),
       .enb(rd_fire&&(rd_wide||!rd_address[0])),.addrb({1'b0,rd_address[18:1]}),.doutb(even_w));
     uram_bank #(.DATA_WIDTH(128),.DEPTH(64'(WORDS)/64'd2),.READ_LATENCY(3),.ADDR_WIDTH(19)) odd_mem(
       .aclk(clk),.aresetn(resetn),.ena(wr_fire&&wr_address[0]),.wea(wr_strb),
       .addra({1'b0,wr_address[18:1]}),.dina(wr_data),
       .enb(rd_fire&&(rd_wide||rd_address[0])),.addrb({1'b0,rd_address[18:1]}),.doutb(odd_w));
     assign pair_w={odd_w,even_w};assign narrow_w=half_r[2]?odd_w:even_w;
   end else if(ULTRA)begin:ultra_single
     uram_bank #(.DATA_WIDTH(128),.DEPTH(64'(WORDS)),.READ_LATENCY(3),.ADDR_WIDTH(19)) mem(
       .aclk(clk),.aresetn(resetn),.ena(wr_fire),.wea(wr_strb),.addra(wr_address),.dina(wr_data),
       .enb(rd_fire),.addrb(rd_address),.doutb(narrow_w));
     assign pair_w={128'd0,narrow_w};
   end else if(WIDE)begin:bram_pair
     logic[2:0]half_r;
     always_ff @(posedge clk)begin
       if(!resetn)half_r<=0;
       else begin
         if(rd_fire)half_r[0]<=rd_address[0];
         if(valid_r[0])half_r[1]<=half_r[0];
         if(valid_r[1])half_r[2]<=half_r[1];
       end
     end
     bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(64'(WORDS)),.READ_DATA_WIDTH(256),
       .READ_LATENCY(3),.ADDR_WIDTH(19)) mem(
       .aclk(clk),.aresetn(resetn),.ena(wr_fire),.wea(wr_strb),.addra(wr_address),.dina(wr_data),
       .enb(rd_fire),.addrb({1'b0,rd_address[18:1]}),.doutb(pair_w));
     assign narrow_w=half_r[2]?pair_w[255:128]:pair_w[127:0];
   end else begin:bram_single
     bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(64'(WORDS)),.READ_DATA_WIDTH(128),
       .READ_LATENCY(3),.ADDR_WIDTH(19)) mem(
       .aclk(clk),.aresetn(resetn),.ena(wr_fire),.wea(wr_strb),.addra(wr_address),.dina(wr_data),
       .enb(rd_fire),.addrb(rd_address),.doutb(narrow_w));
     assign pair_w={128'd0,narrow_w};
   end
 endgenerate
 assign rd_data=wide_r[2]?pair_w:{128'd0,narrow_w};
endmodule
