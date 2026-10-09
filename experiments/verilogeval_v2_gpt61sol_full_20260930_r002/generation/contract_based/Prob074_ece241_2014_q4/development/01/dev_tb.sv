`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic x = 1'b0;
    wire z;
    logic [2:0] model = 3'b000;
    logic [15:0] covered = 16'b0;
    integer cycles = 0;
    integer pattern;
    integer bit_index;

    TopModule dut (.clk(clk), .x(x), .z(z));

    // Enumerated truth table independently derived from the gate diagram.
    // State order: XOR flip-flop, AND flip-flop, OR flip-flop.
    function automatic logic [2:0] transition(input logic [2:0] state,
                                               input logic value);
        case ({state, value})
            4'b0000: transition = 3'b001;
            4'b0001: transition = 3'b111;
            4'b0010: transition = 3'b000;
            4'b0011: transition = 3'b111;
            4'b0100: transition = 3'b001;
            4'b0101: transition = 3'b101;
            4'b0110: transition = 3'b000;
            4'b0111: transition = 3'b101;
            4'b1000: transition = 3'b101;
            4'b1001: transition = 3'b011;
            4'b1010: transition = 3'b100;
            4'b1011: transition = 3'b011;
            4'b1100: transition = 3'b101;
            4'b1101: transition = 3'b001;
            4'b1110: transition = 3'b100;
            4'b1111: transition = 3'b001;
            default: $fatal(1, "Unknown oracle state or input");
        endcase
    endfunction

    task automatic check_output;
        logic expected;
        begin
            expected = (model == 3'b000);
            if (z !== expected)
                $fatal(1, "cycle=%0d clk=%b x=%b model=%b expected z=%b got=%b",
                       cycles, clk, x, model, expected, z);
        end
    endtask

    task automatic step(input logic value);
        begin
            // Exercise input changes while the clock is low.
            x = ~value;
            #1; check_output();
            x = value;
            #1; check_output();
            covered[{model, value}] = 1'b1;
            model = transition(model, value);
            clk = 1'b1;
            #1; cycles = cycles + 1; check_output();
            // Input changes during the high phase must not change state.
            x = ~value;
            #1; check_output();
            clk = 1'b0;
            #1; check_output();
        end
    endtask

    initial begin
        #1;
        check_output(); // Initial zero state must produce z=1.
        repeat (16) step(1'b0);
        repeat (16) step(1'b1);
        repeat (16) begin step(1'b0); step(1'b1); end
        for (pattern = 0; pattern < 256; pattern = pattern + 1)
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step(((pattern >> bit_index) & 1) != 0);
        if ((covered & 16'hcfcf) !== 16'hcfcf)
            $fatal(1, "Missing reachable state/input coverage: %h", covered);
        $display("PASS: %0d cycles, initial state, both clock phases, all reachable transitions", cycles);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Simulation timeout");
    end
endmodule
