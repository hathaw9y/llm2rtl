`timescale 1ns/1ps

// Connects the common DataMover engine's per-bank streams to role 1 (LOAD)
// and role 2 (STORE) of the model's ownership-checked 128-bit bank router.
module smollm2_dma_bank_bridge #(
    parameter int DMA_DATA_WIDTH = 64
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_busy,
    input  logic [0:12][4:0] bank_owner_port,

    input  logic wr_req [13],
    output logic wr_grant [13],
    input  logic load_start [13],
    output logic load_done [13],
    input  logic load_abort [13],
    input  logic [22:0] load_offset [13],
    input  logic [DMA_DATA_WIDTH-1:0] load_data [13],
    input  logic [DMA_DATA_WIDTH/8-1:0] load_keep [13],
    input  logic load_valid [13],
    output logic load_ready [13],
    input  logic load_last [13],

    input  logic rd_req [13],
    output logic rd_grant [13],
    input  logic store_start [13],
    output logic store_done [13],
    input  logic store_abort [13],
    input  logic [22:0] store_offset [13],
    input  logic [22:0] store_btt [13],
    output logic [DMA_DATA_WIDTH-1:0] store_data [13],
    output logic [DMA_DATA_WIDTH/8-1:0] store_keep [13],
    output logic store_valid [13],
    input  logic store_ready [13],
    output logic store_last [13],

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
    output logic bridge_fault_load,
    output logic bridge_fault_store,
    output logic [2:0] bridge_fault_code,
    output logic [3:0] bridge_fault_bank
);
    logic [0:12] load_bank_ena, store_bank_read_issue;
    logic [0:12][15:0] load_bank_addr, load_bank_wea, store_bank_addr;
    logic [0:12][127:0] load_bank_data;
    logic [0:12] store_bank_enb;
    logic [2:0] read_expected_valid_r;
    logic [2:0][3:0] read_expected_bank_r;
    logic request_fault_w;
    logic request_fault_load_w, request_fault_store_w;
    logic [2:0] request_fault_code_w;
    logic [3:0] request_fault_bank_w;
    logic [4:0] load_count_w, store_count_w;
    logic raw_write_valid_w, write_pipe_valid_r;
    logic [3:0] raw_write_bank_w, write_pipe_bank_r;
    logic [15:0] raw_write_addr_w, raw_write_strb_w;
    logic [15:0] write_pipe_addr_r, write_pipe_strb_r;
    logic [127:0] raw_write_data_w, write_pipe_data_r;
    logic load_adapter_done [13];
    logic [0:12] load_done_delay_r;
    logic raw_read_valid_w, read_pipe_valid_r;
    logic [3:0] raw_read_bank_w, read_pipe_bank_r;
    logic [15:0] raw_read_addr_w, read_pipe_addr_r;



    for (genvar bank = 0; bank < 13; bank++) begin : adapters
        assign wr_grant[bank] = wr_req[bank] &&
                                (bank == 0 || bank == 3 || bank == 7 ||
                                 bank == 8 || bank == 9) && bank_busy[bank] &&
                                (bank_owner_port[bank] == 5'd1) && !bridge_fault;
        assign rd_grant[bank] = rd_req[bank] &&
                                (bank == 5 || bank == 6 || bank == 12) &&
                                bank_busy[bank] &&
                                (bank_owner_port[bank] == 5'd2) && !bridge_fault;

        if (bank == 0 || bank == 3 || bank == 7 || bank == 8 || bank == 9) begin : load_bank
        mm2s_adapter #(
            .MM2S_DATA_WIDTH(DMA_DATA_WIDTH), .MM2S_KEEP_WIDTH(DMA_DATA_WIDTH/8),
            .BANK_ADDRA_WIDTH(16), .BANK_DINA_WIDTH(128),
            .BANK_WEA_WIDTH(16), .BTT_WIDTH(23)
        ) load_adapter (
            .aclk(aclk), .aresetn(aresetn),
            .s_ctrl_mm2s_adapter_start(load_start[bank]),
            .s_ctrl_mm2s_adapter_done(load_adapter_done[bank]),
            .s_ctrl_mm2s_adapter_abort(load_abort[bank]),
            .s_ctrl_mm2s_adapter_offset(load_offset[bank]),
            .s_axis_mm2s_tdata(load_data[bank]),
            .s_axis_mm2s_tkeep(load_keep[bank]),
            .s_axis_mm2s_tvalid(load_valid[bank]),
            .s_axis_mm2s_tready(load_ready[bank]),
            .s_axis_mm2s_tlast(load_last[bank]),
            .bank_ena(load_bank_ena[bank]),
            .bank_addra(load_bank_addr[bank]),
            .bank_dina(load_bank_data[bank]),
            .bank_wea(load_bank_wea[bank])
        );
        end else begin : no_load_bank
            assign load_adapter_done[bank] = 1'b0;
            assign load_ready[bank] = 1'b0;
            assign load_bank_ena[bank] = 1'b0;
            assign load_bank_addr[bank] = '0;
            assign load_bank_data[bank] = '0;
            assign load_bank_wea[bank] = '0;
        end

        if (bank == 5 || bank == 6 || bank == 12) begin : store_bank
        s2mm_adapter #(
            .S2MM_DATA_WIDTH(DMA_DATA_WIDTH), .S2MM_KEEP_WIDTH(DMA_DATA_WIDTH/8),
            .BANK_ADDRB_WIDTH(16), .BANK_DOUTB_WIDTH(128),
            .BANK_WEB_WIDTH(16), .BANK_READ_LAT(4), .BTT_WIDTH(23)
        ) store_adapter (
            .aclk(aclk), .aresetn(aresetn),
            .s_ctrl_s2mm_adapter_start(store_start[bank]),
            .s_ctrl_s2mm_adapter_done(store_done[bank]),
            .s_ctrl_s2mm_adapter_abort(store_abort[bank]),
            .s_ctrl_s2mm_adapter_offset(store_offset[bank]),
            .s_ctrl_s2mm_adapter_btt(store_btt[bank]),
            .m_axis_s2mm_tdata(store_data[bank]),
            .m_axis_s2mm_tkeep(store_keep[bank]),
            .m_axis_s2mm_tvalid(store_valid[bank]),
            .m_axis_s2mm_tready(store_ready[bank]),
            .m_axis_s2mm_tlast(store_last[bank]),
            .bank_enb(store_bank_enb[bank]),
            .bank_read_issue(store_bank_read_issue[bank]),
            .bank_addrb(store_bank_addr[bank]),
            .bank_doutb(role2_rsp_data)
        );
        end else begin : no_store_bank
            assign store_done[bank] = 1'b0;
            assign store_data[bank] = '0;
            assign store_keep[bank] = '0;
            assign store_valid[bank] = 1'b0;
            assign store_last[bank] = 1'b0;
            assign store_bank_enb[bank] = 1'b0;
            assign store_bank_read_issue[bank] = 1'b0;
            assign store_bank_addr[bank] = '0;
        end
    end

    // The role-1 port accepts one word per cycle. Register the complete
    // request together so DataMover command selection cannot reach the XPM
    // write port in the same cycle. A DONE may only escape after this final
    // registered write has reached the bank port.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            write_pipe_valid_r <= 1'b0;
            write_pipe_bank_r <= '0;
            write_pipe_addr_r <= '0;
            write_pipe_strb_r <= '0;
            write_pipe_data_r <= '0;
            load_done_delay_r <= '0;
            read_pipe_valid_r <= 1'b0;
            read_pipe_bank_r <= '0;
            read_pipe_addr_r <= '0;
        end else begin
            for (int bank = 0; bank < 13; bank++)
                load_done_delay_r[bank] <= load_adapter_done[bank];
            write_pipe_valid_r <= raw_write_valid_w && !bridge_fault &&
                !(role1_write_valid && !role1_write_ready);
            if (raw_write_valid_w) begin
                write_pipe_bank_r <= raw_write_bank_w;
                write_pipe_addr_r <= raw_write_addr_w;
                write_pipe_strb_r <= raw_write_strb_w;
                write_pipe_data_r <= raw_write_data_w;
            end
            read_pipe_valid_r <= raw_read_valid_w && !bridge_fault &&
                !(role2_read_valid && !role2_read_ready);
            if (raw_read_valid_w) begin
                read_pipe_bank_r <= raw_read_bank_w;
                read_pipe_addr_r <= raw_read_addr_w;
            end
        end
    end
    assign role1_write_valid = write_pipe_valid_r && !bridge_fault;
    assign role1_write_bank = write_pipe_bank_r;
    assign role1_write_addr = write_pipe_addr_r;
    assign role1_write_strb = write_pipe_strb_r;
    assign role1_write_data = write_pipe_data_r;
    assign role2_read_valid = read_pipe_valid_r && !bridge_fault;
    assign role2_read_bank = read_pipe_bank_r;
    assign role2_read_addr = read_pipe_addr_r;
    for (genvar bank = 0; bank < 13; bank++) begin : load_done_drain
        assign load_done[bank] = load_done_delay_r[bank] &&
            !write_pipe_valid_r;
    end

    always_comb begin
        raw_write_valid_w = 1'b0;
        raw_write_bank_w = '0;
        raw_write_addr_w = '0;
        raw_write_strb_w = '0;
        raw_write_data_w = '0;
        raw_read_valid_w = 1'b0;
        raw_read_bank_w = '0;
        raw_read_addr_w = '0;
        load_count_w = '0;
        store_count_w = '0;
        for (int bank = 0; bank < 13; bank++) begin
            if (load_bank_ena[bank]) begin
                load_count_w = load_count_w + 1'b1;
                raw_write_valid_w = 1'b1;
                raw_write_bank_w = 4'(bank);
                raw_write_addr_w = load_bank_addr[bank];
                raw_write_strb_w = load_bank_wea[bank];
                raw_write_data_w = load_bank_data[bank];
            end
            if (store_bank_read_issue[bank]) begin
                store_count_w = store_count_w + 1'b1;
                raw_read_valid_w = 1'b1;
                raw_read_bank_w = 4'(bank);
                raw_read_addr_w = store_bank_addr[bank];
            end
        end
        if (load_count_w > 1 || bridge_fault) raw_write_valid_w = 1'b0;
        if (store_count_w > 1 || bridge_fault) raw_read_valid_w = 1'b0;
    end

    always_comb begin
        request_fault_w = 1'b0;
        request_fault_load_w = 1'b0;
        request_fault_store_w = 1'b0;
        request_fault_code_w = '0;
        request_fault_bank_w = '0;
        if (role1_write_valid && !role1_write_ready) begin
            request_fault_w = 1'b1;
            request_fault_load_w = 1'b1;
            request_fault_code_w = 3'd1;
            request_fault_bank_w = role1_write_bank;
        end
        if (!request_fault_w && role2_read_valid && !role2_read_ready) begin
            request_fault_w = 1'b1;
            request_fault_store_w = 1'b1;
            request_fault_code_w = 3'd2;
            request_fault_bank_w = role2_read_bank;
        end
        for (int bank = 0; bank < 13; bank++) begin
            if (!request_fault_w && ((wr_req[bank] && !wr_grant[bank]) ||
                                      (rd_req[bank] && !rd_grant[bank]))) begin
                request_fault_w = 1'b1;
                request_fault_load_w = wr_req[bank] && !wr_grant[bank];
                request_fault_store_w = rd_req[bank] && !rd_grant[bank];
                request_fault_code_w = 3'd3;
                request_fault_bank_w = 4'(bank);
            end
        end
        if (load_count_w > 1 || store_count_w > 1) begin
            request_fault_w = 1'b1;
            request_fault_load_w = load_count_w > 1;
            request_fault_store_w = store_count_w > 1;
            request_fault_code_w = 3'd4;
            request_fault_bank_w = '0;
        end
        if ((role2_rsp_valid != read_expected_valid_r[2]) ||
            (role2_rsp_valid && (role2_rsp_bank != read_expected_bank_r[2] ||
             role2_rsp_bank >= 4'd13 ||
             !bank_busy[role2_rsp_bank] ||
             bank_owner_port[role2_rsp_bank] != 5'd2))) begin
            request_fault_w = 1'b1;
            request_fault_store_w = 1'b1;
            request_fault_code_w = 3'd5;
            request_fault_bank_w = role2_rsp_bank;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            read_expected_valid_r <= '0;
            read_expected_bank_r <= '0;
            bridge_fault <= 1'b0;
            bridge_fault_load <= 1'b0;
            bridge_fault_store <= 1'b0;
            bridge_fault_code <= '0;
            bridge_fault_bank <= '0;
        end else begin
            read_expected_valid_r[0] <= role2_read_valid && role2_read_ready;
            read_expected_bank_r[0] <= role2_read_bank;
            for (int stage = 1; stage < 3; stage++) begin
                read_expected_valid_r[stage] <= read_expected_valid_r[stage-1];
                read_expected_bank_r[stage] <= read_expected_bank_r[stage-1];
            end
            if (!bridge_fault && request_fault_w) begin
                bridge_fault <= 1'b1;
                bridge_fault_load <= request_fault_load_w;
                bridge_fault_store <= request_fault_store_w;
                bridge_fault_code <= request_fault_code_w;
                bridge_fault_bank <= request_fault_bank_w;
            end
        end
    end
endmodule
