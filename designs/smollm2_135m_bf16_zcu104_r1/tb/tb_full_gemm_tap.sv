`timescale 1ns/1ps
module tb_full_gemm_tap;
    logic clk = 0;
    always #5 clk = ~clk;
    logic write_enable = 0, read_enable = 0;
    logic [11:0] write_address = 0, read_address = 0;
    logic [15:0] write_strb = 0;
    logic [127:0] write_data = 0, read_data;
    smollm2_full_gemm_tap dut (.*);

    initial begin
        for (int address=0; address<2304; address++) begin
            for (int lane=0; lane<8; lane++) begin
                @(negedge clk);
                write_enable = 1;
                write_address = 12'(address);
                write_strb = 16'h0003 << (2*lane);
                write_data = '0;
                write_data[16*lane +: 16] = 16'(address ^ (lane << 12));
            end
        end
        @(negedge clk);
        write_enable = 0;
        for (int address=0; address<2304; address++) begin
            @(negedge clk);
            read_enable = 1;
            read_address = 12'(address);
            @(posedge clk);
            #1;
            for (int lane=0; lane<8; lane++)
                if (read_data[16*lane +: 16] !== 16'(address ^ (lane << 12)))
                    $fatal(1,"address=%0d lane=%0d got=%h",address,lane,
                           read_data[16*lane +: 16]);
        end
        for (int lane=0; lane<8; lane++) begin
            @(negedge clk);
            write_enable = 1;
            read_enable = 0;
            write_address = 12'd1357;
            write_strb = 16'h0003 << (2*lane);
            write_data = '0;
            write_data[16*lane +: 16] = 16'hA100 + 16'(lane);
        end
        @(negedge clk);
        write_enable = 0;
        read_enable = 1;
        read_address = 12'd1357;
        @(posedge clk);
        #1;
        for (int lane=0; lane<8; lane++)
            if (read_data[16*lane +: 16] !== 16'hA100 + 16'(lane))
                $fatal(1,"overwrite lane=%0d got=%h",lane,
                       read_data[16*lane +: 16]);
        $display("FULL GEMM TAP PASS 18432 lane writes, 2304 word reads, 8 overwrites");
        $finish;
    end
endmodule
