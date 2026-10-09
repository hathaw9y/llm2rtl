`timescale 1ns/1ps
module tb_smollm2_full_output_tap;
    logic clk = 0;
    always #5 clk = ~clk;
    logic write_enable = 0, read_enable = 0;
    logic [11:0] write_address = 0, read_address = 0;
    logic [127:0] write_data = 0, read_data;
    smollm2_full_output_tap dut (.*);

    function automatic logic [127:0] pattern(input int address);
        logic [127:0] word;
        for (int lane = 0; lane < 8; lane++)
            word[16*lane +: 16] = 16'((address*8+lane) ^ 16'h5a3c);
        return word;
    endfunction

    initial begin
        for (int address = 0; address < 2304; address++) begin
            @(negedge clk);
            write_enable = 1;
            write_address = 12'(address);
            write_data = pattern(address);
        end
        @(negedge clk);
        write_enable = 0;
        for (int address = 0; address < 2304; address++) begin
            read_enable = 1;
            read_address = 12'(address);
            @(posedge clk);
            #1;
            if (read_data !== pattern(address))
                $fatal(1, "full output tap address=%0d got=%h expected=%h",
                       address, read_data, pattern(address));
            @(negedge clk);
        end
        $display("PASS full output tap 2304 words / 18432 BF16 values");
        $finish;
    end
endmodule
