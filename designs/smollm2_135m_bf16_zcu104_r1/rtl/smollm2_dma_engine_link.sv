`timescale 1ns/1ps

// Dispatcher <-> common DataMover engine <-> model bank bridge.
// The external AXI streams connect to vendor DataMover IP in the board wrapper.
module smollm2_dma_engine_link #(
    parameter int DMA_DATA_WIDTH = 64
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_busy,
    input  logic [0:12][4:0] bank_owner_port,

    input  logic mm2s_cmd_valid,
    output logic mm2s_cmd_ready,
    input  logic [31:0] mm2s_cmd_addr,
    input  logic [22:0] mm2s_cmd_btt,
    input  logic [31:0] mm2s_cmd_offset,
    input  logic [3:0] mm2s_cmd_bank,
    output logic mm2s_sts_valid,
    input  logic mm2s_sts_ready,
    output logic [3:0] mm2s_sts_tag,
    output logic mm2s_sts_error,
    output logic [7:0] mm2s_sts_error_code,
    input  logic s2mm_cmd_valid,
    output logic s2mm_cmd_ready,
    input  logic [31:0] s2mm_cmd_addr,
    input  logic [22:0] s2mm_cmd_btt,
    input  logic [31:0] s2mm_cmd_offset,
    input  logic [3:0] s2mm_cmd_bank,
    output logic s2mm_sts_valid,
    input  logic s2mm_sts_ready,
    output logic [3:0] s2mm_sts_tag,
    output logic s2mm_sts_error,
    output logic [7:0] s2mm_sts_error_code,

    output logic [71:0] m_axis_mm2s_cmd_tdata,
    output logic m_axis_mm2s_cmd_tvalid,
    input  logic m_axis_mm2s_cmd_tready,
    input  logic [DMA_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [DMA_DATA_WIDTH/8-1:0] s_axis_mm2s_tkeep,
    input  logic s_axis_mm2s_tvalid,
    output logic s_axis_mm2s_tready,
    input  logic s_axis_mm2s_tlast,
    input  logic [7:0] s_axis_mm2s_sts_tdata,
    input  logic s_axis_mm2s_sts_tkeep,
    input  logic s_axis_mm2s_sts_tvalid,
    output logic s_axis_mm2s_sts_tready,
    input  logic s_axis_mm2s_sts_tlast,
    output logic [71:0] m_axis_s2mm_cmd_tdata,
    output logic m_axis_s2mm_cmd_tvalid,
    input  logic m_axis_s2mm_cmd_tready,
    output logic [DMA_DATA_WIDTH-1:0] m_axis_s2mm_tdata,
    output logic [DMA_DATA_WIDTH/8-1:0] m_axis_s2mm_tkeep,
    output logic m_axis_s2mm_tvalid,
    input  logic m_axis_s2mm_tready,
    output logic m_axis_s2mm_tlast,
    input  logic [7:0] s_axis_s2mm_sts_tdata,
    input  logic s_axis_s2mm_sts_tkeep,
    input  logic s_axis_s2mm_sts_tvalid,
    output logic s_axis_s2mm_sts_tready,
    input  logic s_axis_s2mm_sts_tlast,

    output logic role1_write_valid,
    input  logic role1_write_ready,
    output logic [3:0] role1_write_bank,
    output logic [15:0] role1_write_addr,
    output logic [15:0] role1_write_strb,
    output logic [127:0] role1_write_data,
    output logic role2_read_valid,
    input  logic role2_read_ready,
    output logic [3:0] role2_read_bank,
    output logic [15:0] role2_read_addr,
    input  logic role2_rsp_valid,
    input  logic [3:0] role2_rsp_bank,
    input  logic [127:0] role2_rsp_data,

    output logic bridge_fault,
    output logic [2:0] bridge_fault_code,
    output logic [3:0] bridge_fault_bank,
    output logic mm2s_engine_faulted,
    output logic s2mm_engine_faulted,
    output logic recovery_required,
    output logic [3:0] mm2s_engine_status_tag,
    output logic [3:0] mm2s_engine_received_tag,
    output logic [7:0] mm2s_engine_raw_status,
    output logic [3:0] s2mm_engine_status_tag,
    output logic [3:0] s2mm_engine_received_tag,
    output logic [7:0] s2mm_engine_raw_status
);
    localparam logic [415:0] BANK_CAPACITY_BYTES = {
        32'd98304, 32'd36864, 32'd589824, 32'd393216, 32'd393216,
        32'd8192, 32'd12288, 32'd36864, 32'd36864, 32'd589824,
        32'd36864, 32'd36864, 32'd36864
    };
    logic wr_req [13], wr_grant [13], load_start [13], load_done [13];
    logic load_abort [13], load_valid [13], load_ready [13], load_last [13];
    logic [22:0] load_offset [13];
    logic [DMA_DATA_WIDTH-1:0] load_data [13];
    logic [DMA_DATA_WIDTH/8-1:0] load_keep [13];
    logic rd_req [13], rd_grant [13], store_start [13], store_done [13];
    logic store_abort [13], store_valid [13], store_ready [13], store_last [13];
    logic [22:0] store_offset [13], store_btt [13];
    logic [DMA_DATA_WIDTH-1:0] store_data [13];
    logic [DMA_DATA_WIDTH/8-1:0] store_keep [13];
    logic bridge_fault_load, bridge_fault_store;
    logic engine_mm2s_cmd_ready, engine_s2mm_cmd_ready;
    logic engine_mm2s_sts_valid, engine_s2mm_sts_valid;
    logic engine_mm2s_sts_error, engine_s2mm_sts_error;
    logic [7:0] engine_mm2s_error_code, engine_s2mm_error_code;
    logic [3:0] engine_mm2s_bank, engine_s2mm_bank;

    // A faulted queue retains its metadata head. The system controller must
    // reset this link, vendor DataMover IP and dispatcher together to recover.
    assign recovery_required = bridge_fault || mm2s_engine_faulted || s2mm_engine_faulted;
    assign mm2s_cmd_ready = engine_mm2s_cmd_ready && !recovery_required;
    assign s2mm_cmd_ready = engine_s2mm_cmd_ready && !recovery_required;
    assign mm2s_sts_valid = engine_mm2s_sts_valid;
    assign s2mm_sts_valid = engine_s2mm_sts_valid;
    assign mm2s_sts_tag = engine_mm2s_bank;
    assign s2mm_sts_tag = engine_s2mm_bank;
    // Preserve an already-offered engine response while READY is low.
    // A bridge fault aborts its direction; the engine emits code 50 and the
    // bridge's own bank/code pins identify the local cause separately.
    assign mm2s_sts_error = engine_mm2s_sts_error;
    assign s2mm_sts_error = engine_s2mm_sts_error;
    assign mm2s_sts_error_code = engine_mm2s_error_code;
    assign s2mm_sts_error_code = engine_s2mm_error_code;

    datamover_engine #(
        .DMA_DATA_WIDTH(DMA_DATA_WIDTH),
        .BANK_NUM(13), .BANK_WIDTH(4),
        .BANK_WORD_BYTES({13{32'd16}}),
        .BANK_CAPACITY_BYTES(BANK_CAPACITY_BYTES)
    ) engine (
        .aclk(aclk), .aresetn(aresetn),
        .s_ctrl_mm2s_pause(recovery_required),
        .s_ctrl_mm2s_abort(bridge_fault_load),
        .m_ctrl_mm2s_sts_ready(mm2s_sts_ready),
        .m_ctrl_mm2s_faulted(mm2s_engine_faulted),
        .m_ctrl_mm2s_sts_tag(mm2s_engine_status_tag),
        .m_ctrl_mm2s_sts_received_tag(mm2s_engine_received_tag),
        .m_ctrl_mm2s_sts_raw_status(mm2s_engine_raw_status),
        .s_ctrl_mm2s_cmd_valid(mm2s_cmd_valid && !recovery_required),
        .s_ctrl_mm2s_cmd_ready(engine_mm2s_cmd_ready),
        .s_ctrl_mm2s_cmd_addr(mm2s_cmd_addr),
        .s_ctrl_mm2s_cmd_btt(mm2s_cmd_btt),
        // Preserve invalid 32-bit ISA offsets as an engine descriptor error
        // instead of silently truncating them to a legal local address.
        .s_ctrl_mm2s_cmd_offset((|mm2s_cmd_offset[31:23]) ?
                                23'h7ffff0 : mm2s_cmd_offset[22:0]),
        .s_ctrl_mm2s_cmd_bank(mm2s_cmd_bank),
        .m_ctrl_mm2s_sts_valid(engine_mm2s_sts_valid),
        .m_ctrl_mm2s_sts_error(engine_mm2s_sts_error),
        .m_ctrl_mm2s_sts_error_code(engine_mm2s_error_code),
        .m_ctrl_mm2s_sts_bank(engine_mm2s_bank),
        .s_ctrl_s2mm_pause(recovery_required),
        .s_ctrl_s2mm_abort(bridge_fault_store),
        .m_ctrl_s2mm_sts_ready(s2mm_sts_ready),
        .m_ctrl_s2mm_faulted(s2mm_engine_faulted),
        .m_ctrl_s2mm_sts_tag(s2mm_engine_status_tag),
        .m_ctrl_s2mm_sts_received_tag(s2mm_engine_received_tag),
        .m_ctrl_s2mm_sts_raw_status(s2mm_engine_raw_status),
        .s_ctrl_s2mm_cmd_valid(s2mm_cmd_valid && !recovery_required),
        .s_ctrl_s2mm_cmd_ready(engine_s2mm_cmd_ready),
        .s_ctrl_s2mm_cmd_addr(s2mm_cmd_addr),
        .s_ctrl_s2mm_cmd_btt(s2mm_cmd_btt),
        .s_ctrl_s2mm_cmd_offset((|s2mm_cmd_offset[31:23]) ?
                                23'h7ffff0 : s2mm_cmd_offset[22:0]),
        .s_ctrl_s2mm_cmd_bank(s2mm_cmd_bank),
        .m_ctrl_s2mm_sts_valid(engine_s2mm_sts_valid),
        .m_ctrl_s2mm_sts_error(engine_s2mm_sts_error),
        .m_ctrl_s2mm_sts_error_code(engine_s2mm_error_code),
        .m_ctrl_s2mm_sts_bank(engine_s2mm_bank),
        .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
        .m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
        .s_axis_mm2s_tdata(s_axis_mm2s_tdata),
        .s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),
        .s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),
        .s_axis_mm2s_tready(s_axis_mm2s_tready),
        .s_axis_mm2s_tlast(s_axis_mm2s_tlast),
        .s_axis_mm2s_sts_tdata(s_axis_mm2s_sts_tdata),
        .s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),
        .s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid),
        .s_axis_mm2s_sts_tready(s_axis_mm2s_sts_tready),
        .s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),
        .m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
        .m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),
        .m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready),
        .m_axis_s2mm_tdata(m_axis_s2mm_tdata),
        .m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),
        .m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
        .m_axis_s2mm_tready(m_axis_s2mm_tready),
        .m_axis_s2mm_tlast(m_axis_s2mm_tlast),
        .s_axis_s2mm_sts_tdata(s_axis_s2mm_sts_tdata),
        .s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),
        .s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid),
        .s_axis_s2mm_sts_tready(s_axis_s2mm_sts_tready),
        .s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),
        .m_ctrl_bank_wr_req(wr_req),
        .m_ctrl_bank_wr_grant(wr_grant),
        .m_ctrl_mm2s_adapter_start(load_start),
        .m_ctrl_mm2s_adapter_done(load_done),
        .m_ctrl_mm2s_adapter_abort(load_abort),
        .m_ctrl_mm2s_adapter_offset(load_offset),
        .m_axis_mm2s_tdata(load_data),
        .m_axis_mm2s_tkeep(load_keep),
        .m_axis_mm2s_tvalid(load_valid),
        .m_axis_mm2s_tready(load_ready),
        .m_axis_mm2s_tlast(load_last),
        .m_ctrl_bank_rd_req(rd_req),
        .m_ctrl_bank_rd_grant(rd_grant),
        .m_ctrl_s2mm_adapter_start(store_start),
        .m_ctrl_s2mm_adapter_done(store_done),
        .m_ctrl_s2mm_adapter_abort(store_abort),
        .m_ctrl_s2mm_adapter_btt(store_btt),
        .m_ctrl_s2mm_adapter_offset(store_offset),
        .s_axis_s2mm_tdata(store_data),
        .s_axis_s2mm_tkeep(store_keep),
        .s_axis_s2mm_tvalid(store_valid),
        .s_axis_s2mm_tready(store_ready),
        .s_axis_s2mm_tlast(store_last)
    );

    smollm2_dma_bank_bridge #(.DMA_DATA_WIDTH(DMA_DATA_WIDTH)) bridge (
        .aclk(aclk), .aresetn(aresetn), .bank_busy(bank_busy),
        .bank_owner_port(bank_owner_port),
        .wr_req(wr_req), .wr_grant(wr_grant),
        .load_start(load_start), .load_done(load_done), .load_abort(load_abort),
        .load_offset(load_offset), .load_data(load_data), .load_keep(load_keep),
        .load_valid(load_valid), .load_ready(load_ready), .load_last(load_last),
        .rd_req(rd_req), .rd_grant(rd_grant),
        .store_start(store_start), .store_done(store_done),
        .store_abort(store_abort), .store_offset(store_offset),
        .store_btt(store_btt), .store_data(store_data),
        .store_keep(store_keep), .store_valid(store_valid),
        .store_ready(store_ready), .store_last(store_last),
        .role1_write_valid(role1_write_valid),
        .role1_write_ready(role1_write_ready),
        .role1_write_bank(role1_write_bank),
        .role1_write_addr(role1_write_addr),
        .role1_write_strb(role1_write_strb),
        .role1_write_data(role1_write_data),
        .role2_read_valid(role2_read_valid),
        .role2_read_ready(role2_read_ready),
        .role2_read_bank(role2_read_bank),
        .role2_read_addr(role2_read_addr),
        .role2_rsp_valid(role2_rsp_valid),
        .role2_rsp_bank(role2_rsp_bank),
        .role2_rsp_data(role2_rsp_data),
        .bridge_fault(bridge_fault),
        .bridge_fault_load(bridge_fault_load),
        .bridge_fault_store(bridge_fault_store),
        .bridge_fault_code(bridge_fault_code),
        .bridge_fault_bank(bridge_fault_bank)
    );
endmodule
