`timescale 1ns/1ps

module smollm2_bank_subsystem (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:12] bank_acquire_valid,
    input  logic [0:12][4:0] bank_acquire_port,
    input  logic [0:12] bank_release_valid,
    input  logic [0:12][4:0] bank_release_port,
    output logic [0:12] bank_busy,
    output logic [0:12][4:0] bank_owner_port,

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

    output logic subsystem_error,
    output logic [1:0] subsystem_error_code,
    output logic ownership_error,
    output logic [2:0] ownership_error_code,
    output logic router_error,
    output logic [2:0] router_error_code,
    output logic [4:0] router_error_role,
    output logic [3:0] router_error_bank
);
    logic [0:12] bank_ena, bank_enb;
    logic [0:12][15:0] bank_wea, bank_addra, bank_addrb;
    logic [0:12][127:0] bank_dina, bank_doutb;

    bank_ownership_table #(.BANK_NUM(13), .PORT_ROLE_WIDTH(5)) ownership (
        .aclk(aclk), .aresetn(aresetn),
        .acquire_valid(bank_acquire_valid),
        .acquire_port(bank_acquire_port),
        .release_valid(bank_release_valid),
        .release_port(bank_release_port),
        .bank_busy(bank_busy), .bank_owner_port(bank_owner_port),
        .ownership_error(ownership_error),
        .ownership_error_code(ownership_error_code)
    );

    smollm2_bank_port_router #(.READ_LATENCY(3)) router (
        .aclk(aclk), .aresetn(aresetn), .bank_busy(bank_busy),
        .bank_owner_port(bank_owner_port),
        .role_read_valid(role_read_valid), .role_read_ready(role_read_ready),
        .role_read_bank(role_read_bank), .role_read_addr(role_read_addr),
        .role_rsp_valid(role_rsp_valid), .role_rsp_bank(role_rsp_bank),
        .role_rsp_data(role_rsp_data),
        .role_write_valid(role_write_valid), .role_write_ready(role_write_ready),
        .role_write_bank(role_write_bank), .role_write_addr(role_write_addr),
        .role_write_strb(role_write_strb), .role_write_data(role_write_data),
        .bank_ena(bank_ena), .bank_wea(bank_wea), .bank_addra(bank_addra),
        .bank_dina(bank_dina), .bank_enb(bank_enb), .bank_addrb(bank_addrb),
        .bank_doutb(bank_doutb), .router_error(router_error),
        .router_error_code(router_error_code),
        .router_error_role(router_error_role),
        .router_error_bank(router_error_bank)
    );

    smollm2_bank_memories memories (
        .aclk(aclk), .aresetn(aresetn),
        .bank_ena(bank_ena), .bank_wea(bank_wea),
        .bank_addra(bank_addra), .bank_dina(bank_dina),
        .bank_enb(bank_enb), .bank_addrb(bank_addrb),
        .bank_doutb(bank_doutb)
    );

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            subsystem_error <= 1'b0;
            subsystem_error_code <= 2'd0;
        end else if (!subsystem_error) begin
            if (ownership_error) begin
                subsystem_error <= 1'b1;
                subsystem_error_code <= 2'd1;
            end else if (router_error) begin
                subsystem_error <= 1'b1;
                subsystem_error_code <= 2'd2;
            end
        end
    end
endmodule
