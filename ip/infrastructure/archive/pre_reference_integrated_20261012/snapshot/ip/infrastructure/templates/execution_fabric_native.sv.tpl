`timescale 1ns/1ps
// Design-authoring reference only. Every __USER_*__ insertion is mandatory;
// unrendered fabric is intentionally not compilable. Numerical cores are not
// supplied. No second bank_ownership_table may be added: native bank owns it.
module __FABRIC_MODULE__ #(
    parameter int ENGINE_NUM = __CONFIG_PKG__::ENGINE_NUM,
    parameter int CMD_ADDR_WIDTH = 10,
    parameter int CMD_READ_LATENCY = 2,
    parameter int MAX_COMMANDS = 1024
) (
    input logic aclk, aresetn,
    input logic start_i,
    output logic idle_o, done_o, error_o,
    output logic [7:0] error_code_o,
    // USER_TOP_PORTS_BEGIN
    __USER_TOP_PORTS__
    // USER_TOP_PORTS_END
);
    import __CONFIG_PKG__::*;
    // USER_SHARED_SIGNALS_BEGIN
    __USER_SHARED_SIGNALS__
    // Declare all typed engine command/context/completion and native ownership
    // links here. BANK_NUM and engine count are selected in the model package.
    // USER_SHARED_SIGNALS_END
    __CONTROLLER_MODULE__ #(.ENGINE_NUM(ENGINE_NUM), .CMD_ADDR_WIDTH(CMD_ADDR_WIDTH),
        .CMD_READ_LATENCY(CMD_READ_LATENCY), .MAX_COMMANDS(MAX_COMMANDS)) u_controller (
        .aclk(aclk), .aresetn(aresetn), .start_i(start_i), .idle_o(idle_o),
        .done_o(done_o), .error_o(error_o), .error_code_o(error_code_o),
        // USER_CONTROLLER_PORTS_BEGIN
        __USER_CONTROLLER_PORTS__
        // Connect command memory, per-op engine arrays and accepted ownership.
        // USER_CONTROLLER_PORTS_END
    );
    __BANK_MODULE__ u_bank (
        .aclk(aclk), .aresetn(aresetn),
        // USER_BANK_PORTS_BEGIN
        __USER_BANK_PORTS__
        // Render bank_subsystem.sv.tpl separately. Its embedded native ownership
        // provides acquire/release acceptance; do not instantiate a second owner.
        // USER_BANK_PORTS_END
    );
    // USER_ENGINE_INSTANCES_BEGIN
    __USER_ENGINE_INSTANCES__
    // Every enabled opcode gets an operation-specific *_engine and real core.
    // Connect the full opaque context and held clean/unclean response boundary.
    // USER_ENGINE_INSTANCES_END
    // USER_ASSERTIONS_BEGIN
    __USER_ASSERTIONS__
    // Verify acquire-before-issue, request stability, core rearm, final drain,
    // matching response-before-release, END drain and coordinated reset.
    // USER_ASSERTIONS_END
endmodule
