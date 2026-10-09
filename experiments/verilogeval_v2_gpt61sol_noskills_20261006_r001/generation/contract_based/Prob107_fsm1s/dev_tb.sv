`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire out;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    // Named reference states follow the original transition arrows.
    integer expected_state;
    localparam REF_A = 10, REF_B = 20;
    integer checks = 0;
    integer i;
    reg [15:0] stimulus = 16'hb731;

    task check_output;
        reg expected_output;
        begin
            expected_output = (expected_state == REF_B);
            if (out !== expected_output)
                $fatal(1, "Mismatch at %0t: state=%0d expected=%b actual=%b", $time, expected_state, expected_output, out);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg r, input reg x);
        begin
            @(negedge clk);
            reset = r;
            in = x;
            #1;
            check_output(); // Synchronous reset and input cannot change state here.
            @(posedge clk);
            if (r) expected_state = REF_B;
            else if (expected_state == REF_B) begin
                if (x == 0) expected_state = REF_A;
                else expected_state = REF_B;
            end else begin
                if (x == 0) expected_state = REF_B;
                else expected_state = REF_A;
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        // No assertion about the unspecified initial state.
        #2; reset = 1; in = 0;
        @(posedge clk);
        expected_state = REF_B;
        #1; check_output();
        cycle(0,1); // B holds.
        cycle(0,0); // B -> A.
        cycle(0,1); // A holds.
        cycle(0,1);
        cycle(1,1); // Reset from A with in=1.
        cycle(0,0);
        cycle(1,0); // Reset from A overrides toggle with in=0.
        cycle(1,0); // Reset while already B.
        cycle(1,1);
        cycle(0,0);
        cycle(0,0); // A -> B.
        repeat (8) cycle(0,0);
        repeat (4) cycle(0,1);
        for (i = 0; i < 64; i = i + 1) begin
            stimulus = {stimulus[14:0], stimulus[15] ^ stimulus[13] ^ stimulus[12] ^ stimulus[10]};
            cycle((i % 11) == 0, stimulus[0]);
        end
        $display("PASS: FSM transitions, Moore output, synchronous reset, and priority (%0d checks)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
