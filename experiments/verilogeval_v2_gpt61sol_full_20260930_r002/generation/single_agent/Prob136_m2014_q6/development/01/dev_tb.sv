`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic w = 0;
    wire z;
    integer model_state;
    integer checks = 0;
    integer coverage_bits = 0;
    integer sequence_number, bit_number;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    // Independent integer oracle: states A through F are 0 through 5.
    function automatic integer transition(input integer s, input bit b);
        case (s)
            0: if (b) transition = 0; else transition = 1;
            1: if (b) transition = 3; else transition = 2;
            2: if (b) transition = 3; else transition = 4;
            3: if (b) transition = 0; else transition = 5;
            4: if (b) transition = 3; else transition = 4;
            5: if (b) transition = 3; else transition = 2;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic check_output;
        bit expected_z;
        begin
            expected_z = (model_state == 4 || model_state == 5);
            if (z !== expected_z)
                $fatal(1, "Output mismatch: state=%0d z=%b expected=%b", model_state, z, expected_z);
            checks = checks + 1;
        end
    endtask

    task automatic step(input bit rst, input bit value);
        begin
            @(negedge clk);
            reset = rst;
            w = value;
            #1;
            // Neither reset assertion nor w may change Moore output off-edge.
            check_output();
            @(posedge clk);
            if (rst) model_state = 0;
            else begin
                coverage_bits = coverage_bits | (1 << (2*model_state + value));
                model_state = transition(model_state, value);
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        // No power-up state is specified: establish state with a clocked reset.
        reset = 1;
        @(posedge clk);
        model_state = 0;
        #1;
        check_output();
        // Exhaust all eight-cycle binary paths, resetting from reached states.
        for (sequence_number = 0; sequence_number < 256; sequence_number = sequence_number + 1) begin
            step(1, sequence_number[0]);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                step(0, (sequence_number >> bit_number) & 1);
        end
        step(1, 1);
        step(1, 0);
        step(0, 1);
        if (coverage_bits != 4095) $fatal(1, "Incomplete transition coverage: %h", coverage_bits);
        $display("PASS: %0d output checks; all 12 state/input transitions covered", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
