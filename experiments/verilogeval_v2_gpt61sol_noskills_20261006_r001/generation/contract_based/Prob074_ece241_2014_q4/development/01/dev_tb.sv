`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg x = 0;
    wire z;
    reg [2:0] model = 3'b000;
    reg [15:0] covered = 0;
    integer checks = 0;
    integer word_index, bit_index, k;
    TopModule dut (.clk(clk), .x(x), .z(z));

    // Exhaustive gate-derived table. State order: XOR, AND, OR.
    function automatic [2:0] next_state(input [2:0] old_state, input value);
        case ({old_state, value})
            4'b0000: next_state = 3'b001;
            4'b0001: next_state = 3'b111;
            4'b0010: next_state = 3'b000;
            4'b0011: next_state = 3'b111;
            4'b0100: next_state = 3'b001;
            4'b0101: next_state = 3'b101;
            4'b0110: next_state = 3'b000;
            4'b0111: next_state = 3'b101;
            4'b1000: next_state = 3'b101;
            4'b1001: next_state = 3'b011;
            4'b1010: next_state = 3'b100;
            4'b1011: next_state = 3'b011;
            4'b1100: next_state = 3'b101;
            4'b1101: next_state = 3'b001;
            4'b1110: next_state = 3'b100;
            4'b1111: next_state = 3'b001;
            default: next_state = 3'bxxx;
        endcase
    endfunction

    task automatic check_output;
        reg expected;
        begin
            expected = (model == 3'b000);
            if (z !== expected)
                $fatal(1, "Output mismatch time=%0t state=%b x=%b clk=%b expected=%b actual=%b", $time, model, x, clk, expected, z);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input value);
        begin
            x = value;
            #2;
            check_output(); // Input changes alone must not update state.
            covered[{model, value}] = 1'b1;
            model = next_state(model, value);
            clk = 1;
            #1;
            check_output(); // Sample after nonblocking assignments settle.
            x = ~value;
            #1;
            check_output(); // Changing x while high must not update state.
            clk = 0;
            #1;
            check_output(); // Falling edge must not update state.
        end
    endtask

    initial begin
        #1;
        check_output();
        for (k = 0; k < 20; k = k + 1) cycle(0);
        for (k = 0; k < 20; k = k + 1) cycle(1);
        for (k = 0; k < 40; k = k + 1) cycle(k % 2);
        for (word_index = 0; word_index < 256; word_index = word_index + 1)
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                cycle((word_index >> bit_index) & 1);
        // States 010 and 110 are unreachable from the specified zero state.
        for (k = 0; k < 16; k = k + 1)
            if ((k/2 != 2) && (k/2 != 6) && !covered[k])
                $fatal(1, "Missing reachable transition %0d", k);
        $display("PASS: %0d output checks and all reachable transitions", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Bounded simulation timeout");
    end
endmodule
