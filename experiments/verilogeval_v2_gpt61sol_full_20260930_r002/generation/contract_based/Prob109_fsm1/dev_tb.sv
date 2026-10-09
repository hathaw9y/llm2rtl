`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic areset = 1'b0;
    logic in = 1'b0;
    wire out;
    localparam integer A = 0, B = 1;
    integer expected_state;
    integer checks = 0;
    integer pattern;
    integer index;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task automatic check_output;
        begin
            if (out !== (expected_state == B))
                $fatal(1, "Mismatch t=%0t state=%0d out=%b", $time, expected_state, out);
            checks = checks + 1;
        end
    endtask

    task automatic clock_step(input logic value);
        begin
            in = value;
            #1;
            check_output(); // Input mutation must not change Moore output.
            clk = 1'b1;
            if (areset) expected_state = B;
            else begin
                case (expected_state)
                    A: if (value == 1'b0) expected_state = B;
                       else expected_state = A;
                    B: if (value == 1'b0) expected_state = A;
                       else expected_state = B;
                    default: $fatal(1, "Invalid oracle state");
                endcase
            end
            #1;
            check_output();
            clk = 1'b0;
            #1;
            check_output();
        end
    endtask

    task automatic reset_between_edges;
        begin
            clk = 1'b0;
            #2;
            areset = 1'b1;
            expected_state = B;
            #1;
            check_output(); // No clock occurred since reset assertion.
            clock_step(1'b0);
            clock_step(1'b1);
            areset = 1'b0;
            #1;
            check_output(); // Reset release alone must retain B.
        end
    endtask

    initial begin
        // Original gives no initial state, so do not demand a power-up value.
        reset_between_edges();
        clock_step(1'b1); // B -> B
        clock_step(1'b0); // B -> A
        clock_step(1'b1); // A -> A
        clock_step(1'b0); // A -> B
        clock_step(1'b0); // B -> A
        reset_between_edges(); // Reset while in A.
        // Exhaust all eight-cycle binary sequences, each starting in B.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_between_edges();
            for (index = 0; index < 8; index = index + 1)
                clock_step((pattern >> index) & 1);
        end
        $display("PASS: Moore transitions, asynchronous reset, and stability; %0d checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
