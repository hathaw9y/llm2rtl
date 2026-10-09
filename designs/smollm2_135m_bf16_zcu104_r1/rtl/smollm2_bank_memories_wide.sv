`timescale 1ns/1ps

// Word addresses on this boundary are still 128-bit word addresses. The four
// GEMM source banks read an even/odd pair in one cycle; all writes remain
// byte-enabled 128-bit words. A wide read must use an even word address.
module smollm2_bank_memories_wide (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_ena,
    input  logic [0:12][15:0] bank_wea,
    input  logic [0:12][15:0] bank_addra,
    input  logic [0:12][127:0] bank_dina,
    input  logic [0:12] bank_enb,
    input  logic [0:12][15:0] bank_addrb,
    output logic [0:12][255:0] bank_doutb
);
    function automatic int capacity_words(input int bank);
        case (bank)
            0, 1, 2, 4, 5, 11: capacity_words = 2304;
            3, 10: capacity_words = 36864;
            6: capacity_words = 768;
            7: capacity_words = 512;
            8, 9: capacity_words = 24576;
            12: capacity_words = 6144;
            default: capacity_words = 0;
        endcase
    endfunction

    for (genvar bank = 0; bank < 13; bank++) begin : banks
        localparam int DEPTH = capacity_words(bank);
        if (bank == 2 || bank == 3 || bank == 10 || bank == 11) begin : wide
            wire [127:0] even_data, odd_data;
            wire even_write = bank_ena[bank] && !bank_addra[bank][0];
            wire odd_write = bank_ena[bank] && bank_addra[bank][0];
            if (bank == 3 || bank == 10) begin : ultra
                uram_bank #(.DATA_WIDTH(128), .DEPTH(longint'(DEPTH/2)),
                    .READ_LATENCY(3), .ADDR_WIDTH(16)) even_mem (
                    .aclk(aclk), .aresetn(aresetn), .ena(even_write),
                    .wea(bank_wea[bank]), .addra(bank_addra[bank] >> 1),
                    .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                    .addrb(bank_addrb[bank] >> 1), .doutb(even_data));
                uram_bank #(.DATA_WIDTH(128), .DEPTH(longint'(DEPTH/2)),
                    .READ_LATENCY(3), .ADDR_WIDTH(16)) odd_mem (
                    .aclk(aclk), .aresetn(aresetn), .ena(odd_write),
                    .wea(bank_wea[bank]), .addra(bank_addra[bank] >> 1),
                    .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                    .addrb(bank_addrb[bank] >> 1), .doutb(odd_data));
            end else begin : block
                bram_bank #(.WRITE_DATA_WIDTH(128),
                    .WRITE_DEPTH(longint'(DEPTH/2)), .READ_DATA_WIDTH(128),
                    .BYTE_WRITE_WIDTH(8), .READ_LATENCY(3), .ADDR_WIDTH(16)) even_mem (
                    .aclk(aclk), .aresetn(aresetn), .ena(even_write),
                    .wea(bank_wea[bank]), .addra(bank_addra[bank] >> 1),
                    .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                    .addrb(bank_addrb[bank] >> 1), .doutb(even_data));
                bram_bank #(.WRITE_DATA_WIDTH(128),
                    .WRITE_DEPTH(longint'(DEPTH/2)), .READ_DATA_WIDTH(128),
                    .BYTE_WRITE_WIDTH(8), .READ_LATENCY(3), .ADDR_WIDTH(16)) odd_mem (
                    .aclk(aclk), .aresetn(aresetn), .ena(odd_write),
                    .wea(bank_wea[bank]), .addra(bank_addra[bank] >> 1),
                    .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                    .addrb(bank_addrb[bank] >> 1), .doutb(odd_data));
            end
            assign bank_doutb[bank] = {odd_data, even_data};
        end else if (bank == 8 || bank == 9) begin : ultra
            wire [127:0] data;
            uram_bank #(.DATA_WIDTH(128), .DEPTH(longint'(DEPTH)),
                .READ_LATENCY(3), .ADDR_WIDTH(16)) memory (
                .aclk(aclk), .aresetn(aresetn), .ena(bank_ena[bank]),
                .wea(bank_wea[bank]), .addra(bank_addra[bank]),
                .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                .addrb(bank_addrb[bank]), .doutb(data));
            assign bank_doutb[bank] = {128'd0, data};
        end else begin : block
            wire [127:0] data;
            bram_bank #(.WRITE_DATA_WIDTH(128), .WRITE_DEPTH(longint'(DEPTH)),
                .READ_DATA_WIDTH(128), .BYTE_WRITE_WIDTH(8),
                .READ_LATENCY(3), .ADDR_WIDTH(16)) memory (
                .aclk(aclk), .aresetn(aresetn), .ena(bank_ena[bank]),
                .wea(bank_wea[bank]), .addra(bank_addra[bank]),
                .dina(bank_dina[bank]), .enb(bank_enb[bank]),
                .addrb(bank_addrb[bank]), .doutb(data));
            assign bank_doutb[bank] = {128'd0, data};
        end
    end
endmodule
