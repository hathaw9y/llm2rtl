`timescale 1ns/1ps

module smollm2_bank_memories (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_ena,
    input  logic [0:12][15:0] bank_wea,
    input  logic [0:12][15:0] bank_addra,
    input  logic [0:12][127:0] bank_dina,
    input  logic [0:12] bank_enb,
    input  logic [0:12][15:0] bank_addrb,
    output logic [0:12][127:0] bank_doutb
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
        if (bank == 3 || bank == 8 || bank == 9 || bank == 10) begin : ultra
            uram_bank #(
                .DATA_WIDTH(128), .DEPTH(longint'(DEPTH)),
                .READ_LATENCY(3), .ADDR_WIDTH(16)
            ) u_memory (
                .aclk(aclk), .aresetn(aresetn),
                .ena(bank_ena[bank]), .wea(bank_wea[bank]),
                .addra(bank_addra[bank]), .dina(bank_dina[bank]),
                .enb(bank_enb[bank]), .addrb(bank_addrb[bank]),
                .doutb(bank_doutb[bank])
            );
        end else begin : block
            bram_bank #(
                .WRITE_DATA_WIDTH(128), .WRITE_DEPTH(longint'(DEPTH)),
                .READ_DATA_WIDTH(128), .BYTE_WRITE_WIDTH(8),
                .READ_LATENCY(3), .ADDR_WIDTH(16)
            ) u_memory (
                .aclk(aclk), .aresetn(aresetn),
                .ena(bank_ena[bank]), .wea(bank_wea[bank]),
                .addra(bank_addra[bank]), .dina(bank_dina[bank]),
                .enb(bank_enb[bank]), .addrb(bank_addrb[bank]),
                .doutb(bank_doutb[bank])
            );
        end
    end
endmodule
