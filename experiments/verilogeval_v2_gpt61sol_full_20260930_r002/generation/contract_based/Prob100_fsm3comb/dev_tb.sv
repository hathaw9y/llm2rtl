`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [1:0] state;
    wire [1:0] next_state;
    wire out;
    integer checks = 0;
    integer first_pattern, second_pattern;

    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    // Literal oracle: index is {state, in}; result is {next_state, out}.
    function automatic [2:0] expected(input [2:0] pattern);
        case (pattern)
            3'b000: expected = 3'b000; // A,0 -> A,0
            3'b001: expected = 3'b010; // A,1 -> B,0
            3'b010: expected = 3'b100; // B,0 -> C,0
            3'b011: expected = 3'b010; // B,1 -> B,0
            3'b100: expected = 3'b000; // C,0 -> A,0
            3'b101: expected = 3'b110; // C,1 -> D,0
            3'b110: expected = 3'b101; // D,0 -> C,1
            3'b111: expected = 3'b011; // D,1 -> B,1
            default: expected = 3'bxxx;
        endcase
    endfunction

    task automatic apply_and_check(input [2:0] pattern);
        logic [2:0] wanted;
        begin
            {state, in} = pattern;
            wanted = expected(pattern);
            #1;
            if ({next_state, out} !== wanted)
                $fatal(1, "pattern=%b expected=%b actual=%b", pattern, wanted, {next_state, out});
            checks = checks + 1;
        end
    endtask

    initial begin
        for (first_pattern = 0; first_pattern < 8; first_pattern = first_pattern + 1)
            apply_and_check(first_pattern[2:0]);
        for (first_pattern = 0; first_pattern < 8; first_pattern = first_pattern + 1)
            for (second_pattern = 0; second_pattern < 8; second_pattern = second_pattern + 1) begin
                apply_and_check(first_pattern[2:0]);
                apply_and_check(second_pattern[2:0]);
            end
        $display("PASS: %0d checks covering all binary combinations and ordered transitions", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
