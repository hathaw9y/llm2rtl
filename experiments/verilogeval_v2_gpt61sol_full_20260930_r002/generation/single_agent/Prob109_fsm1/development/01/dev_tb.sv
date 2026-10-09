`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic areset = 1'b0;
    logic in = 1'b0;
    wire out;
    logic expected;
    integer sequence_id;
    integer bit_id;
    integer checks = 0;

    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task automatic check_output;
        begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: reset=%b in=%b expected=%b out=%b",
                       $time, areset, in, expected, out);
        end
    endtask

    // Oracle directly enumerates the original four labeled transitions.
    task automatic cycle(input logic input_value);
        begin
            in = input_value;
            #2;
            check_output(); // Moore output cannot change when input changes.
            if (areset) expected = 1'b1;
            else begin
                case ({expected, input_value})
                    2'b00: expected = 1'b1; // A --0--> B
                    2'b01: expected = 1'b0; // A --1--> A
                    2'b10: expected = 1'b0; // B --0--> A
                    2'b11: expected = 1'b1; // B --1--> B
                    default: $fatal(1, "Invalid oracle state/input");
                endcase
            end
            clk = 1'b1;
            #1;
            check_output(); // Sample after sequential NBA updates.
            #2;
            clk = 1'b0;
            #1;
            check_output(); // Falling edges must not update state.
        end
    endtask

    task automatic async_reset;
        begin
            // Clock is low: reset must act without a clock edge.
            #1;
            areset = 1'b1;
            expected = 1'b1;
            #1;
            check_output();
            cycle(1'b0);
            cycle(1'b1);
            areset = 1'b0;
            #1;
            check_output(); // Reset release alone must hold B.
        end
    endtask

    initial begin
        #1;
        async_reset();
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'b1);
        async_reset(); // Reset while previously in A.
        cycle(1'b0);
        cycle(1'b0);
        // Every binary sequence of eight inputs, each starting at reset B.
        for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1) begin
            async_reset();
            for (bit_id = 0; bit_id < 8; bit_id = bit_id + 1)
                cycle((sequence_id >> bit_id) & 1);
        end
        // Also assert asynchronous reset while the clock is already high.
        cycle(1'b0);
        clk = 1'b1;
        #1;
        areset = 1'b1;
        expected = 1'b1;
        #1;
        check_output();
        areset = 1'b0;
        #1;
        check_output();
        clk = 1'b0;
        #1;
        check_output();
        $display("PASS: Moore FSM transitions and asynchronous reset (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
