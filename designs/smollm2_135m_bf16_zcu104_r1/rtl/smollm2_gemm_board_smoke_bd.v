module smollm2_gemm_board_smoke_bd (
    input wire aclk,
    input wire aresetn,
    input wire [31:0] host_data0,
    input wire [31:0] host_data1,
    input wire [31:0] host_data2,
    input wire [31:0] host_data3,
    input wire [31:0] host_control,
    output wire [31:0] host_status
);
    smollm2_gemm_board_smoke core (
        .aclk(aclk), .aresetn(aresetn),
        .host_data0(host_data0), .host_data1(host_data1),
        .host_data2(host_data2), .host_data3(host_data3),
        .host_control(host_control), .host_status(host_status)
    );
endmodule
