// Native-bank wiring only. Ownership/descriptor control belongs to dispatcher.
// Roles1/2 are common DMA;3..17 are the selected compute operand roles.
module qwen_bank_fabric(
 input logic clk,rst_n,output logic [22:0] write_pending,
 input logic [22:0] bank_busy,input logic [22:0][4:0] bank_owner,
 input logic [17:0][4:0] role_bank,
 input logic [17:0] role_rd_en,input logic [17:0][12:0] role_rd_addr,
 output logic [17:0][127:0] role_rd_data,
 input logic [17:0] role_wr_en,input logic [17:0][12:0] role_wr_addr,
 input logic [17:0][127:0] role_wr_data,input logic [17:0][15:0] role_wr_mask
);
 wire [22:0][127:0] bank_data;
 function automatic integer words(input integer bank);
  case(bank)
   0,1,2,3,21:return 2048;
   4,5,6,19,20,22:return 256;
   7,11,12,13,14,15,16,17:return 512;
   8:return 64;
   9,10:return 8192;
   18:return 4096;
   default:return 0;
  endcase
 endfunction
 // These pairs follow the statically enforced ISA operands in descriptors.
 // Prune impossible physical routes rather than constraining false paths.
 function automatic logic allowed(input integer bank,input integer role);
  case(role)
   1,2,15,16,17:return bank>=0 && bank<23;
   3:return bank==6 || bank==21;
   4:return bank==7 || bank==9 || bank==10;
   5:return bank>=11 && bank<=18;
   6:return bank==8;
   7,9:return bank>=0 && bank<=3;
   8,11:return bank==22;
   10,12:return bank>=0 && bank<23 && bank!=22;
   13:return bank==18;
   14:return bank==21;
   default:return 0;
  endcase
 endfunction
 logic [17:0][127:0] role_read_mux;
 always_comb begin
  role_read_mux='0;
  for(integer r=1;r<18;r=r+1)
   for(integer b=0;b<23;b=b+1)if(allowed(b,r))
    role_read_mux[r] |= bank_data[b] & {128{role_bank[r]==5'(b)}};
 end
 // Retiming the final read stage across the bank-selection mux closes the
 // role-bank-to-consumer path. XPM2 + this register1 = native latency3.
 always_ff @(posedge clk)begin
  if(!rst_n)role_rd_data<=0;
  else role_rd_data<=role_read_mux;
 end
 for(genvar b=0;b<23;b=b+1)begin:banks_g
  localparam integer DEPTH=words(b);
  logic read_en,write_en;
  logic [12:0] ra,wa;
  logic [127:0] wd;
  logic [15:0] wm;
  always_comb begin
   read_en=0;write_en=0;ra=0;wa=0;wd=0;wm=0;
   for(integer r=1;r<18;r=r+1)if(allowed(b,r))begin
    read_en |= bank_busy[b] && bank_owner[b]==5'(r) && role_bank[r]==5'(b) && role_rd_en[r];
    write_en |= bank_busy[b] && bank_owner[b]==5'(r) && role_bank[r]==5'(b) && role_wr_en[r];
    ra |= role_rd_addr[r] & {13{bank_owner[b]==5'(r)}};
    wa |= role_wr_addr[r] & {13{bank_owner[b]==5'(r)}};
    wd |= role_wr_data[r] & {128{bank_owner[b]==5'(r)}};
    wm |= role_wr_mask[r] & {16{bank_owner[b]==5'(r)}};
   end
  end
  // One accepted write per cycle; response wrappers retain ownership until
  // this stage drains. Legal ISA readers acquire only after that completion.
  logic write_shadow_valid;
  logic [12:0] write_shadow_address;
  logic [127:0] write_shadow_data;
  logic [15:0] write_shadow_mask;
  assign write_pending[b]=write_shadow_valid;
  always_ff @(posedge clk)begin
   if(!rst_n)begin write_shadow_valid<=0;write_shadow_address<=0;write_shadow_data<=0;write_shadow_mask<=0;end
   else begin
    write_shadow_valid<=write_en;
    if(write_en)begin write_shadow_address<=wa;write_shadow_data<=wd;write_shadow_mask<=wm;end
   end
  end
`ifdef QWEN_BANK_SIMULATION
  // Logical port-latency model; this is not XPM or resource verification.
  logic [127:0] storage[0:DEPTH-1],pipeline[0:1];
  assign bank_data[b]=pipeline[1];
  always @(posedge clk)begin
   if(!rst_n)for(integer p=0;p<2;p=p+1)pipeline[p]<=0;
   else begin
    pipeline[0]<=read_en && ra<DEPTH?storage[ra]:128'b0;
    for(integer p=1;p<2;p=p+1)pipeline[p]<=pipeline[p-1];
    if(write_shadow_valid && write_shadow_address<DEPTH)for(integer byte_id=0;byte_id<16;byte_id=byte_id+1)if(write_shadow_mask[byte_id])storage[write_shadow_address][byte_id*8+:8]<=write_shadow_data[byte_id*8+:8];
   end
  end
`else
  if(b==9 || b==10 || b==18)begin:uram_g
   uram_bank #(.DATA_WIDTH(128),.DEPTH(DEPTH),.READ_LATENCY(2),.ADDR_WIDTH(13)) memory(
    .aclk(clk),.aresetn(rst_n),.ena(write_shadow_valid && rst_n),.wea(write_shadow_mask),.addra(write_shadow_address),.dina(write_shadow_data),.enb(read_en),.addrb(ra),.doutb(bank_data[b]));
  end else begin:bram_g
   bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(DEPTH),.READ_DATA_WIDTH(128),.BYTE_WRITE_WIDTH(8),.READ_LATENCY(2),.ADDR_WIDTH(13)) memory(
    .aclk(clk),.aresetn(rst_n),.ena(write_shadow_valid && rst_n),.wea(write_shadow_mask),.addra(write_shadow_address),.dina(write_shadow_data),.enb(read_en),.addrb(ra),.doutb(bank_data[b]));
  end
`endif
 end
endmodule
