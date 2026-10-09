`timescale 1ns/1ps

module smollm2_bank_port_router #(
    parameter int READ_LATENCY = 3
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_busy,
    input  logic [0:12][4:0] bank_owner_port,

    input  logic [0:20] role_read_valid,
    output logic [0:20] role_read_ready,
    input  logic [0:20][3:0] role_read_bank,
    input  logic [0:20][15:0] role_read_addr,
    output logic [0:20] role_rsp_valid,
    output logic [0:20][3:0] role_rsp_bank,
    output logic [0:20][127:0] role_rsp_data,

    input  logic [0:20] role_write_valid,
    output logic [0:20] role_write_ready,
    input  logic [0:20][3:0] role_write_bank,
    input  logic [0:20][15:0] role_write_addr,
    input  logic [0:20][15:0] role_write_strb,
    input  logic [0:20][127:0] role_write_data,

    output logic [0:12] bank_ena,
    output logic [0:12][15:0] bank_wea,
    output logic [0:12][15:0] bank_addra,
    output logic [0:12][127:0] bank_dina,
    output logic [0:12] bank_enb,
    output logic [0:12][15:0] bank_addrb,
    input  logic [0:12][127:0] bank_doutb,

    output logic router_error,
    output logic [2:0] router_error_code,
    output logic [4:0] router_error_role,
    output logic [3:0] router_error_bank
);
    localparam logic [2:0] ERR_NONE = 0, ERR_BANK = 1, ERR_ROLE = 2,
        ERR_OWNER = 3, ERR_ADDRESS = 4, ERR_PAIR = 5;

    logic [0:12][READ_LATENCY-1:0] read_valid_pipe_r;
    logic [0:12][READ_LATENCY-1:0][4:0] read_role_pipe_r;
    logic fault_w;
    logic [2:0] fault_code_w;
    logic [4:0] fault_role_w;
    logic [3:0] fault_bank_w;
    logic [0:20] role_fault_w, role_fault_r;
    logic [0:20][2:0] role_fault_code_w, role_fault_code_r;
    logic [0:20][3:0] role_fault_bank_w, role_fault_bank_r;

    function automatic logic [15:0] capacity_words(input logic [3:0] bank);
        case (bank)
            4'd0, 4'd1, 4'd2, 4'd4, 4'd5, 4'd11: capacity_words = 16'd2304;
            4'd3, 4'd10: capacity_words = 16'd36864;
            4'd6: capacity_words = 16'd768;
            4'd7: capacity_words = 16'd512;
            4'd8, 4'd9: capacity_words = 16'd24576;
            4'd12: capacity_words = 16'd6144;
            default: capacity_words = 16'd0;
        endcase
    endfunction

    function automatic logic may_read(input int role);
        case (role)
            2, 3, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 18, 19:
                may_read = 1'b1;
            default: may_read = 1'b0;
        endcase
    endfunction

    function automatic logic may_write(input int role);
        case (role)
            1, 5, 8, 9, 13, 14, 17, 20: may_write = 1'b1;
            default: may_write = 1'b0;
        endcase
    endfunction

    function automatic logic bank_allowed(input int role, input logic [3:0] bank);
        case (role)
            1: bank_allowed = (bank == 0 || bank == 3 || bank == 7 ||
                               bank == 8 || bank == 9);
            2: bank_allowed = (bank == 5 || bank == 6 || bank == 12);
            3: bank_allowed = (bank == 2 || bank == 10 || bank == 11);
            4: bank_allowed = (bank == 3);
            5: bank_allowed = (bank == 1 || bank == 4 || bank == 5 ||
                               bank == 6 || bank == 8 || bank == 9 || bank == 12);
            6: bank_allowed = (bank == 0 || bank == 5);
            7: bank_allowed = (bank == 3);
            8: bank_allowed = (bank == 2);
            9: bank_allowed = (bank == 4 || bank == 5);
            10: bank_allowed = (bank == 7);
            11: bank_allowed = (bank == 4);
            12: bank_allowed = (bank == 8);
            13: bank_allowed = (bank == 10);
            14: bank_allowed = (bank == 10);
            15: bank_allowed = (bank == 10);
            16: bank_allowed = (bank == 9);
            17: bank_allowed = (bank == 11);
            18: bank_allowed = (bank == 0 || bank == 5 || bank == 8);
            19: bank_allowed = (bank == 1 || bank == 9);
            20: bank_allowed = (bank == 0 || bank == 5 || bank == 10);
            default: bank_allowed = 1'b0;
        endcase
    endfunction

    always_comb begin
        role_read_ready = '0;
        role_write_ready = '0;
        bank_ena = '0;
        bank_wea = '0;
        bank_addra = '0;
        bank_dina = '0;
        bank_enb = '0;
        bank_addrb = '0;
        role_fault_w = '0;
        role_fault_code_w = '0;
        role_fault_bank_w = '0;

        for (int role = 1; role <= 20; role++) begin
            if (role_read_bank[role] < 4'd13 && may_read(role) &&
                bank_allowed(role, role_read_bank[role])) begin
                role_read_ready[role] = bank_busy[role_read_bank[role]] &&
                    (bank_owner_port[role_read_bank[role]] == 5'(role)) &&
                    (role_read_addr[role] < capacity_words(role_read_bank[role]));
            end
            if (role_write_bank[role] < 4'd13 && may_write(role) &&
                bank_allowed(role, role_write_bank[role])) begin
                role_write_ready[role] = bank_busy[role_write_bank[role]] &&
                    (bank_owner_port[role_write_bank[role]] == 5'(role)) &&
                    (role_write_addr[role] < capacity_words(role_write_bank[role]));
            end
            if (role_read_valid[role] && !role_read_ready[role]) begin
                role_fault_w[role] = 1'b1;
                role_fault_bank_w[role] = role_read_bank[role];
                if (role_read_bank[role] >= 4'd13) role_fault_code_w[role] = ERR_BANK;
                else if (!may_read(role)) role_fault_code_w[role] = ERR_ROLE;
                else if (!bank_allowed(role, role_read_bank[role]))
                    role_fault_code_w[role] = ERR_PAIR;
                else if (!bank_busy[role_read_bank[role]] ||
                         bank_owner_port[role_read_bank[role]] != 5'(role))
                    role_fault_code_w[role] = ERR_OWNER;
                else role_fault_code_w[role] = ERR_ADDRESS;
            end
            if (!role_fault_w[role] && role_write_valid[role] &&
                !role_write_ready[role]) begin
                role_fault_w[role] = 1'b1;
                role_fault_bank_w[role] = role_write_bank[role];
                if (role_write_bank[role] >= 4'd13) role_fault_code_w[role] = ERR_BANK;
                else if (!may_write(role)) role_fault_code_w[role] = ERR_ROLE;
                else if (!bank_allowed(role, role_write_bank[role]))
                    role_fault_code_w[role] = ERR_PAIR;
                else if (!bank_busy[role_write_bank[role]] ||
                         bank_owner_port[role_write_bank[role]] != 5'(role))
                    role_fault_code_w[role] = ERR_OWNER;
                else role_fault_code_w[role] = ERR_ADDRESS;
            end
        end
        if (role_read_valid[0] || role_write_valid[0]) begin
            role_fault_w[0] = 1'b1;
            role_fault_code_w[0] = ERR_ROLE;
            role_fault_bank_w[0] = role_read_valid[0] ?
                role_read_bank[0] : role_write_bank[0];
        end

        // The outer bank index is a synthesis-time constant after loop unrolling.
        for (int bank = 0; bank < 13; bank++) begin
            for (int role = 1; role <= 20; role++) begin
                if (bank_allowed(role, 4'(bank)) && may_read(role) &&
                    role_read_valid[role] && role_read_ready[role] &&
                    role_read_bank[role] == 4'(bank)) begin
                    bank_enb[bank] = 1'b1;
                    bank_addrb[bank] = role_read_addr[role];
                end
                if (bank_allowed(role, 4'(bank)) && may_write(role) &&
                    role_write_valid[role] && role_write_ready[role] &&
                    role_write_bank[role] == 4'(bank)) begin
                    bank_ena[bank] = 1'b1;
                    bank_wea[bank] = role_write_strb[role];
                    bank_addra[bank] = role_write_addr[role];
                    bank_dina[bank] = role_write_data[role];
                end
            end
        end
    end

    always_comb begin
        fault_w = 1'b0;
        fault_code_w = ERR_NONE;
        fault_role_w = '0;
        fault_bank_w = '0;
        for (int role = 0; role <= 20; role++) begin
            if (!fault_w && role_fault_r[role]) begin
                fault_w = 1'b1;
                fault_code_w = role_fault_code_r[role];
                fault_role_w = 5'(role);
                fault_bank_w = role_fault_bank_r[role];
            end
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            role_fault_r <= '0;
            role_fault_code_r <= '0;
            role_fault_bank_r <= '0;
            read_valid_pipe_r <= '0;
            read_role_pipe_r <= '0;
            router_error <= 1'b0;
            router_error_code <= ERR_NONE;
            router_error_role <= '0;
            router_error_bank <= '0;
        end else begin
            role_fault_r <= role_fault_w;
            role_fault_code_r <= role_fault_code_w;
            role_fault_bank_r <= role_fault_bank_w;
            for (int bank = 0; bank < 13; bank++) begin
                read_valid_pipe_r[bank][0] <= bank_enb[bank];
                read_role_pipe_r[bank][0] <= bank_owner_port[bank];
                for (int stage = 1; stage < READ_LATENCY; stage++) begin
                    read_valid_pipe_r[bank][stage] <= read_valid_pipe_r[bank][stage-1];
                    read_role_pipe_r[bank][stage] <= read_role_pipe_r[bank][stage-1];
                end
            end
            if (!router_error && fault_w) begin
                router_error <= 1'b1;
                router_error_code <= fault_code_w;
                router_error_role <= fault_role_w;
                router_error_bank <= fault_bank_w;
            end
        end
    end

    always_comb begin
        role_rsp_valid = '0;
        role_rsp_bank = '0;
        role_rsp_data = '0;
        // A role can issue one read per cycle; fixed latency keeps its response unique.
        for (int role = 1; role <= 20; role++) begin
            for (int bank = 0; bank < 13; bank++) begin
                if (bank_allowed(role, 4'(bank)) && may_read(role) &&
                    read_valid_pipe_r[bank][READ_LATENCY-1] &&
                    read_role_pipe_r[bank][READ_LATENCY-1] == 5'(role)) begin
                    role_rsp_valid[role] = 1'b1;
                    role_rsp_bank[role] = 4'(bank);
                    role_rsp_data[role] = bank_doutb[bank];
                end
            end
        end
    end
endmodule
