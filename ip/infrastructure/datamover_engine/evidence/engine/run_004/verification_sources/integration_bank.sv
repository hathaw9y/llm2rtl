// Test-only integration fixture. XSIM uses the production XPM BRAM wrapper.
// DATAMOVER_ICARUS_BANK_FALLBACK selects the explicitly test-only behavioral RAM.
module integration_bank #(
  parameter integer WIDTH=32, BANK_READ_LAT=3, DMA_DATA_WIDTH=64
) (
  input logic clk,rstn,contend,
  input logic wr_req,rd_req,wr_start,rd_start,wr_abort,rd_abort,
  output wire wr_grant,rd_grant,wr_done,rd_done,
  input logic [22:0] wr_offset,rd_offset,rd_btt,
  input logic [DMA_DATA_WIDTH-1:0] wr_data,input logic [DMA_DATA_WIDTH/8-1:0] wr_keep,
  input logic wr_valid,wr_last,output wire wr_ready,
  output wire [DMA_DATA_WIDTH-1:0] rd_data,output wire [DMA_DATA_WIDTH/8-1:0] rd_keep,
  output wire rd_valid,rd_last,input logic rd_ready,
  output wire native_write
);
  wire wr_requests[2],rd_requests[2],wr_grants[2],rd_grants[2];
  wire ena[2],enb[2];wire [5:0] addra[2],addrb[2];
  wire [WIDTH-1:0] dina[2],doutb[2];wire [WIDTH/8-1:0] wea[2];
  wire menb;wire [5:0] ma,mb;wire [WIDTH-1:0] md;
  wire [WIDTH/8-1:0] mw;
  wire [WIDTH-1:0] memory_doutb;
`ifdef DATAMOVER_ICARUS_BANK_FALLBACK
  logic [WIDTH-1:0] memory[64];
  logic [BANK_READ_LAT-1:0][WIDTH-1:0] read_pipe;
`endif
  assign wr_requests[0]=wr_req;assign wr_requests[1]=contend;
  assign rd_requests[0]=rd_req;assign rd_requests[1]=contend;
  assign wr_grant=wr_grants[0];assign rd_grant=rd_grants[0];
  assign ena[1]=0;assign enb[1]=0;assign addra[1]=0;assign addrb[1]=0;
  assign dina[1]=0;assign wea[1]=0;
`ifdef DATAMOVER_ICARUS_BANK_FALLBACK
  initial for(integer i=0;i<64;i=i+1) memory[i]='0;
  always @(posedge clk) begin
    if(native_write) for(integer b=0;b<WIDTH/8;b=b+1)
      if(mw[b]) memory[ma][8*b+:8]<=md[8*b+:8];
    if(!rstn) read_pipe<='0;
    else if(menb) begin
      read_pipe[0]<=memory[mb];
      for(integer n=1;n<BANK_READ_LAT;n=n+1) read_pipe[n]<=read_pipe[n-1];
    end
    if(rstn && ((wr_grants[0] && wr_grants[1]) || (rd_grants[0] && rd_grants[1])))
      $fatal(1,"multiple bank owners");
    if(rstn && native_write && !wr_grants[0]) $fatal(1,"write without grant");
  end
  assign memory_doutb=read_pipe[BANK_READ_LAT-1];
`else
  bram_bank #(
    .WRITE_DATA_WIDTH(WIDTH),.WRITE_DEPTH(64),.READ_DATA_WIDTH(WIDTH),
    .BYTE_WRITE_WIDTH(8),.READ_LATENCY(BANK_READ_LAT),.ADDR_WIDTH(6)
  ) real_bank (
    .aclk(clk),.aresetn(rstn),.ena(native_write),.wea(mw),.addra(ma),.dina(md),
    .enb(menb),.addrb(mb),.doutb(memory_doutb));
  always @(posedge clk) begin
    if(rstn && ((wr_grants[0] && wr_grants[1]) || (rd_grants[0] && rd_grants[1])))
      $fatal(1,"multiple bank owners");
    if(rstn && native_write && !wr_grants[0]) $fatal(1,"write without grant");
  end
`endif
  mm2s_adapter #(.MM2S_DATA_WIDTH(DMA_DATA_WIDTH),.BANK_DINA_WIDTH(WIDTH),.BANK_ADDRA_WIDTH(6)) loader(
    .aclk(clk),.aresetn(rstn),.s_ctrl_mm2s_adapter_start(wr_start),
    .s_ctrl_mm2s_adapter_done(wr_done),.s_ctrl_mm2s_adapter_abort(wr_abort),
    .s_ctrl_mm2s_adapter_offset(wr_offset),.s_axis_mm2s_tdata(wr_data),
    .s_axis_mm2s_tkeep(wr_keep),.s_axis_mm2s_tvalid(wr_valid),
    .s_axis_mm2s_tready(wr_ready),.s_axis_mm2s_tlast(wr_last),
    .bank_ena(ena[0]),.bank_addra(addra[0]),.bank_dina(dina[0]),.bank_wea(wea[0]));
  s2mm_adapter #(.S2MM_DATA_WIDTH(DMA_DATA_WIDTH),.BANK_DOUTB_WIDTH(WIDTH),.BANK_ADDRB_WIDTH(6),.BANK_READ_LAT(BANK_READ_LAT)) drain(
    .aclk(clk),.aresetn(rstn),.s_ctrl_s2mm_adapter_start(rd_start),
    .s_ctrl_s2mm_adapter_done(rd_done),.s_ctrl_s2mm_adapter_abort(rd_abort),
    .s_ctrl_s2mm_adapter_offset(rd_offset),.s_ctrl_s2mm_adapter_btt(rd_btt),
    .m_axis_s2mm_tdata(rd_data),.m_axis_s2mm_tkeep(rd_keep),.m_axis_s2mm_tvalid(rd_valid),
    .m_axis_s2mm_tready(rd_ready),.m_axis_s2mm_tlast(rd_last),
    .bank_enb(enb[0]),.bank_addrb(addrb[0]),.bank_doutb(doutb[0]));
  bank_arbiter #(.WR_PORT_NUM(2),.RD_PORT_NUM(2),.BANK_ADDRA_WIDTH(6),
    .BANK_ADDRB_WIDTH(6),.BANK_DINA_WIDTH(WIDTH),.BANK_DOUTB_WIDTH(WIDTH),.BANK_READ_LAT(BANK_READ_LAT)) arbiter(
    .aclk(clk),.aresetn(rstn),.s_ctrl_bank_wr_req(wr_requests),.s_ctrl_bank_wr_grant(wr_grants),
    .s_bank_ena(ena),.s_bank_addra(addra),.s_bank_dina(dina),.s_bank_wea(wea),
    .m_bank_ena(native_write),.m_bank_addra(ma),.m_bank_dina(md),.m_bank_wea(mw),
    .s_ctrl_bank_rd_req(rd_requests),.s_ctrl_bank_rd_grant(rd_grants),
    .s_bank_enb(enb),.s_bank_addrb(addrb),.s_bank_doutb(doutb),
    .m_bank_enb(menb),.m_bank_addrb(mb),.m_bank_doutb(memory_doutb));
endmodule
