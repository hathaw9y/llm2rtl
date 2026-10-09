`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic aresetn = 1;
    logic x = 0;
    wire z;
    logic [1:0] history = 0;
    integer count = 0;
    integer checks = 0;
    integer pattern, bit_index;
    TopModule dut (.clk(clk), .aresetn(aresetn), .x(x), .z(z));

    // Oracle records actual sampled bits, rather than duplicating FSM transitions.
    task automatic check_output;
        logic expected;
        begin
            expected = (count >= 2) && (history == 2'b10) && x;
            checks = checks + 1;
            if (z !== expected)
                $fatal(1, "Mismatch t=%0t history=%b count=%0d x=%b z=%b expected=%b",
                       $time, history, count, x, z, expected);
        end
    endtask

    task automatic reset_history;
        begin
            clk = 0;
            #2;
            aresetn = 0;
            history = 0;
            count = 0;
            #1;
            check_output();
            // Input changes cannot create a match while reset holds.
            x = 1;
            #1;
            check_output();
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
            aresetn = 1;
            #1;
            check_output();
        end
    endtask

    task automatic consume(input logic value);
        begin
            clk = 0;
            x = value;
            #2;
            check_output(); // Mealy match before the consuming edge.
            clk = 1;
            history = {history[0], value};
            if (count < 2) count = count + 1;
            #1;
            check_output(); // New state with the same current input.
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        reset_history();
        consume(1); consume(0);
        // Combinational detection and removal with no intervening clock edge.
        x = 1; #1; check_output();
        x = 0; #1; check_output();
        x = 1; #1; check_output();
        reset_history(); // Reset while output was high, away from posedge.
        consume(1); reset_history(); // Reset a partial match.
        consume(0); consume(1); consume(0); consume(1);
        consume(0); consume(1); consume(0); consume(1); // Overlap 1010101.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_history();
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                consume((pattern >> bit_index) & 1);
        end
        $display("PASS sequence detector: %0d checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
