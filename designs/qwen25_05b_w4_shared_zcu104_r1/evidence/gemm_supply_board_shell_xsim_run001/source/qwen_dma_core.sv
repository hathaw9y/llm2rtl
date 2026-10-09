// Common DataMover engine + native128-bit adapter wrappers + model core.
// Vendor4-bit command tags remain internal to engine; completion uses5-bit bank.
module qwen_dma_core(
 input logic clk,rst_n,start,output logic busy,done,error,output logic [7:0] error_code,output logic [9:0] pc,
 output logic cmd_en,output logic [9:0] cmd_addr,input logic [255:0] cmd_data,
 output logic [71:0] m_axis_mm2s_cmd_tdata,output logic m_axis_mm2s_cmd_tvalid,input logic m_axis_mm2s_cmd_tready,
 input logic [63:0] s_axis_mm2s_tdata,input logic [7:0] s_axis_mm2s_tkeep,input logic s_axis_mm2s_tvalid,output logic s_axis_mm2s_tready,input logic s_axis_mm2s_tlast,
 input logic [7:0] s_axis_mm2s_sts_tdata,input logic s_axis_mm2s_sts_tkeep,s_axis_mm2s_sts_tvalid,output logic s_axis_mm2s_sts_tready,input logic s_axis_mm2s_sts_tlast,
 output logic [71:0] m_axis_s2mm_cmd_tdata,output logic m_axis_s2mm_cmd_tvalid,input logic m_axis_s2mm_cmd_tready,
 output logic [63:0] m_axis_s2mm_tdata,output logic [7:0] m_axis_s2mm_tkeep,output logic m_axis_s2mm_tvalid,input logic m_axis_s2mm_tready,output logic m_axis_s2mm_tlast,
 input logic [7:0] s_axis_s2mm_sts_tdata,input logic s_axis_s2mm_sts_tkeep,s_axis_s2mm_sts_tvalid,output logic s_axis_s2mm_sts_tready,input logic s_axis_s2mm_sts_tlast,
 output logic [7:0] load_error_code,store_error_code,output logic load_faulted,store_faulted
);
 localparam integer BANKS=23;
 function automatic logic [BANKS*32-1:0] capacities;
  logic [BANKS*32-1:0] value;
  for(integer b=0;b<BANKS;b=b+1)case(b)
   0,1,2,3,21:value[b*32+:32]=32768;4,5,6,19,20,22:value[b*32+:32]=4096;
   7,11,12,13,14,15,16,17:value[b*32+:32]=8192;8:value[b*32+:32]=1024;
   9,10:value[b*32+:32]=131072;18:value[b*32+:32]=65536;default:value[b*32+:32]=0;
  endcase
  return value;
 endfunction
 logic load_valid,load_ready,load_rsp_valid,load_rsp_ready,load_rsp_error;
 logic store_valid,store_ready,store_rsp_valid,store_rsp_ready,store_rsp_error;
 logic [31:0] load_address,store_address;logic [22:0] load_bytes,load_offset,store_bytes,store_offset;
 logic [4:0] load_bank,store_bank,load_rsp_bank,store_rsp_bank;
 logic [22:0] dma_write_grant,dma_read_grant;
 logic dma_write_en,dma_read_en;logic [4:0] dma_write_bank,dma_read_bank;
 logic [12:0] dma_write_addr,dma_read_addr;logic [127:0] dma_write_data,dma_read_data;logic [15:0] dma_write_mask;
 logic core_error;logic [7:0] core_error_code;
 wire wr_req[BANKS],wr_grant[BANKS],wr_start[BANKS],wr_done[BANKS],wr_abort[BANKS],wr_valid[BANKS],wr_ready[BANKS],wr_last[BANKS];
 wire rd_req[BANKS],rd_grant[BANKS],rd_start[BANKS],rd_done[BANKS],rd_abort[BANKS],rd_valid[BANKS],rd_ready[BANKS],rd_last[BANKS];
 wire [22:0] wr_offset[BANKS],rd_offset[BANKS],rd_btt[BANKS];
 wire [63:0] wr_data[BANKS],rd_data[BANKS];wire [7:0] wr_keep[BANKS],rd_keep[BANKS];
 wire bank_write_en[BANKS],bank_read_en[BANKS];wire [12:0] bank_write_addr[BANKS],bank_read_addr[BANKS];
 wire [127:0] bank_write_data[BANKS];wire [15:0] bank_write_mask[BANKS];
 assign error=core_error || load_faulted || store_faulted;
 assign error_code=load_faulted?load_error_code:store_faulted?store_error_code:core_error_code;
 qwen_core core(.clk,.rst_n,.start,.busy,.done,.error(core_error),.error_code(core_error_code),.pc,.cmd_en,.cmd_addr,.cmd_data,
  .load_valid,.load_ready,.load_address,.load_bytes,.load_offset,.load_bank,.load_rsp_valid,.load_rsp_ready,.load_rsp_bank,.load_rsp_error,
  .store_valid,.store_ready,.store_address,.store_bytes,.store_offset,.store_bank,.store_rsp_valid,.store_rsp_ready,.store_rsp_bank,.store_rsp_error,
  .dma_write_grant,.dma_read_grant,.dma_write_bank,.dma_write_en,.dma_write_addr,.dma_write_data,.dma_write_mask,.dma_read_bank,.dma_read_en,.dma_read_addr,.dma_read_data);
 datamover_engine #(.DMA_DATA_WIDTH(64),.BANK_NUM(BANKS),.BANK_WIDTH(5),.BANK_WORD_BYTES({BANKS{32'd16}}),.BANK_CAPACITY_BYTES(capacities())) engine(
  .aclk(clk),.aresetn(rst_n),.s_ctrl_mm2s_pause(error),.s_ctrl_mm2s_abort(1'b0),.m_ctrl_mm2s_sts_ready(load_rsp_ready),.m_ctrl_mm2s_faulted(load_faulted),
  .m_ctrl_mm2s_sts_tag(),.m_ctrl_mm2s_sts_received_tag(),.m_ctrl_mm2s_sts_raw_status(),
  .s_ctrl_mm2s_cmd_valid(load_valid),.s_ctrl_mm2s_cmd_ready(load_ready),.s_ctrl_mm2s_cmd_addr(load_address),.s_ctrl_mm2s_cmd_btt(load_bytes),.s_ctrl_mm2s_cmd_offset(load_offset),.s_ctrl_mm2s_cmd_bank(load_bank),
  .m_ctrl_mm2s_sts_valid(load_rsp_valid),.m_ctrl_mm2s_sts_error(load_rsp_error),.m_ctrl_mm2s_sts_error_code(load_error_code),.m_ctrl_mm2s_sts_bank(load_rsp_bank),
  .s_ctrl_s2mm_pause(error),.s_ctrl_s2mm_abort(1'b0),.m_ctrl_s2mm_sts_ready(store_rsp_ready),.m_ctrl_s2mm_faulted(store_faulted),
  .m_ctrl_s2mm_sts_tag(),.m_ctrl_s2mm_sts_received_tag(),.m_ctrl_s2mm_sts_raw_status(),
  .s_ctrl_s2mm_cmd_valid(store_valid),.s_ctrl_s2mm_cmd_ready(store_ready),.s_ctrl_s2mm_cmd_addr(store_address),.s_ctrl_s2mm_cmd_btt(store_bytes),.s_ctrl_s2mm_cmd_offset(store_offset),.s_ctrl_s2mm_cmd_bank(store_bank),
  .m_ctrl_s2mm_sts_valid(store_rsp_valid),.m_ctrl_s2mm_sts_error(store_rsp_error),.m_ctrl_s2mm_sts_error_code(store_error_code),.m_ctrl_s2mm_sts_bank(store_rsp_bank),
  .m_axis_mm2s_cmd_tdata,.m_axis_mm2s_cmd_tvalid,.m_axis_mm2s_cmd_tready,.s_axis_mm2s_tdata,.s_axis_mm2s_tkeep,.s_axis_mm2s_tvalid,.s_axis_mm2s_tready,.s_axis_mm2s_tlast,
  .s_axis_mm2s_sts_tdata,.s_axis_mm2s_sts_tkeep,.s_axis_mm2s_sts_tvalid,.s_axis_mm2s_sts_tready,.s_axis_mm2s_sts_tlast,
  .m_axis_s2mm_cmd_tdata,.m_axis_s2mm_cmd_tvalid,.m_axis_s2mm_cmd_tready,.m_axis_s2mm_tdata,.m_axis_s2mm_tkeep,.m_axis_s2mm_tvalid,.m_axis_s2mm_tready,.m_axis_s2mm_tlast,
  .s_axis_s2mm_sts_tdata,.s_axis_s2mm_sts_tkeep,.s_axis_s2mm_sts_tvalid,.s_axis_s2mm_sts_tready,.s_axis_s2mm_sts_tlast,
  .m_ctrl_bank_wr_req(wr_req),.m_ctrl_bank_wr_grant(wr_grant),.m_ctrl_mm2s_adapter_start(wr_start),.m_ctrl_mm2s_adapter_done(wr_done),.m_ctrl_mm2s_adapter_abort(wr_abort),.m_ctrl_mm2s_adapter_offset(wr_offset),
  .m_axis_mm2s_tdata(wr_data),.m_axis_mm2s_tkeep(wr_keep),.m_axis_mm2s_tvalid(wr_valid),.m_axis_mm2s_tready(wr_ready),.m_axis_mm2s_tlast(wr_last),
  .m_ctrl_bank_rd_req(rd_req),.m_ctrl_bank_rd_grant(rd_grant),.m_ctrl_s2mm_adapter_start(rd_start),.m_ctrl_s2mm_adapter_done(rd_done),.m_ctrl_s2mm_adapter_abort(rd_abort),.m_ctrl_s2mm_adapter_btt(rd_btt),.m_ctrl_s2mm_adapter_offset(rd_offset),
  .s_axis_s2mm_tdata(rd_data),.s_axis_s2mm_tkeep(rd_keep),.s_axis_s2mm_tvalid(rd_valid),.s_axis_s2mm_tready(rd_ready),.s_axis_s2mm_tlast(rd_last));
 for(genvar b=0;b<BANKS;b=b+1)begin:adapter_g
  assign wr_grant[b]=dma_write_grant[b];assign rd_grant[b]=dma_read_grant[b];
  mm2s_adapter #(.MM2S_DATA_WIDTH(64),.BANK_ADDRA_WIDTH(13),.BANK_DINA_WIDTH(128),.BANK_WEA_WIDTH(16),.BTT_WIDTH(23)) load_adapter(
   .aclk(clk),.aresetn(rst_n),.s_ctrl_mm2s_adapter_start(wr_start[b]),.s_ctrl_mm2s_adapter_done(wr_done[b]),.s_ctrl_mm2s_adapter_abort(wr_abort[b]),.s_ctrl_mm2s_adapter_offset(wr_offset[b]),
   .s_axis_mm2s_tdata(wr_data[b]),.s_axis_mm2s_tkeep(wr_keep[b]),.s_axis_mm2s_tvalid(wr_valid[b]),.s_axis_mm2s_tready(wr_ready[b]),.s_axis_mm2s_tlast(wr_last[b]),
   .bank_ena(bank_write_en[b]),.bank_addra(bank_write_addr[b]),.bank_dina(bank_write_data[b]),.bank_wea(bank_write_mask[b]));
  s2mm_adapter #(.S2MM_DATA_WIDTH(64),.BANK_ADDRB_WIDTH(13),.BANK_DOUTB_WIDTH(128),.BANK_WEB_WIDTH(16),.BANK_READ_LAT(3),.BTT_WIDTH(23)) store_adapter(
   .aclk(clk),.aresetn(rst_n),.s_ctrl_s2mm_adapter_start(rd_start[b]),.s_ctrl_s2mm_adapter_done(rd_done[b]),.s_ctrl_s2mm_adapter_abort(rd_abort[b]),.s_ctrl_s2mm_adapter_offset(rd_offset[b]),.s_ctrl_s2mm_adapter_btt(rd_btt[b]),
   .m_axis_s2mm_tdata(rd_data[b]),.m_axis_s2mm_tkeep(rd_keep[b]),.m_axis_s2mm_tvalid(rd_valid[b]),.m_axis_s2mm_tready(rd_ready[b]),.m_axis_s2mm_tlast(rd_last[b]),
   .bank_enb(),.bank_read_issue(bank_read_en[b]),.bank_addrb(bank_read_addr[b]),.bank_doutb(dma_read_data));
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin dma_write_bank<=0;dma_read_bank<=0;end
  else for(integer b=0;b<BANKS;b=b+1)begin
   if(wr_start[b])dma_write_bank<=5'(b);if(rd_start[b])dma_read_bank<=5'(b);
  end
 end
 always @*begin
  dma_write_en=0;dma_write_addr=0;dma_write_data=0;dma_write_mask=0;dma_read_en=0;dma_read_addr=0;
  for(integer b=0;b<BANKS;b=b+1)begin
   // The registered bank ID selects exactly one adapter. Payloads may be
   // speculative while enable is low; do not put valid/reset in the data mux.
   dma_write_en |= bank_write_en[b] && dma_write_bank==5'(b);
   dma_write_addr |= bank_write_addr[b] & {13{dma_write_bank==5'(b)}};
   dma_write_data |= bank_write_data[b] & {128{dma_write_bank==5'(b)}};
   dma_write_mask |= bank_write_mask[b] & {16{dma_write_bank==5'(b)}};
   dma_read_en |= bank_read_en[b] && dma_read_bank==5'(b);
   dma_read_addr |= bank_read_addr[b] & {13{dma_read_bank==5'(b)}};
  end
 end
endmodule
