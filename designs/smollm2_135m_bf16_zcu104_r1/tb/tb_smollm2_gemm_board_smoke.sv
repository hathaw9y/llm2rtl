`timescale 1ns/1ps
module tb_smollm2_gemm_board_smoke;
    logic aclk = 0;
    always #2.5 aclk = ~aclk;
    logic aresetn = 0;
    logic [31:0] host_data0 = 0, host_data1 = 0;
    logic [31:0] host_data2 = 0, host_data3 = 0;
    logic [31:0] host_control = 0, host_status;
    logic seq = 0;
    smollm2_gemm_board_smoke dut (.*);

    task automatic transact(input logic [2:0] op, input logic [3:0] bank,
                            input logic [15:0] addr, input logic [127:0] data);
        @(negedge aclk);
        {host_data3,host_data2,host_data1,host_data0} = data;
        seq = !seq;
        host_control = {seq,op,bank,8'd0,addr};
        wait (host_status[31] == seq);
        #1;
        if (host_status[28]) $fatal(1, "host transaction error op=%0d", op);
    endtask
    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        transact(1,2,0,{8{16'h3f80}});
        transact(1,2,1,{8{16'h3f80}});
        transact(1,3,0,{8{16'h3f80}});
        transact(1,3,1,{8{16'h3f80}});
        transact(2,0,0,{4'd3,4'd2,4'd3,4'd4,
                         49'd0,16'd0,16'd1,6'd0,6'd1,11'd16,8'd1});
        if (!host_status[29]) $fatal(1, "GEMM not done");
        transact(3,4,0,'0);
        if (host_status[15:0] != 16'h4180)
            $fatal(1, "BF16 result %h expected 4180",host_status[15:0]);
        if (dut.subsystem_error || dut.router_error || dut.ownership_error)
            $fatal(1, "bank subsystem error");
        $display("PASS smollm2_gemm_board_smoke");
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "timeout");
    end
endmodule
