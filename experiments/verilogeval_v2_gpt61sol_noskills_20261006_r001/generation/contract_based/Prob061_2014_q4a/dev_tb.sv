`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg w = 0, R = 0, E = 0, L = 0;
    wire Q;
    reg expected;
    reg known = 0;
    integer checks = 0;
    integer prior, combination;
    TopModule dut (.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));
    always #5 clk = ~clk;

    task step(input reg load, enable, data, serial);
        begin
            @(negedge clk);
            L = load; E = enable; R = data; w = serial;
            #1;
            if (known && Q !== expected)
                $fatal(1, "Input change changed stored output: got %b expected %b", Q, expected);
            @(posedge clk);
            // Original semantics: loading sets data even when shifting is enabled.
            if (load) begin
                expected = data;
                known = 1;
            end else if (enable) begin
                expected = serial;
                known = 1;
            end
            #1;
            if (known && Q !== expected)
                $fatal(1, "Edge mismatch L=%b E=%b R=%b w=%b got=%b expected=%b", load, enable, data, serial, Q, expected);
            checks = checks + 1;
            // Perturb data between active edges to detect transparent behavior.
            #1;
            R = ~data; w = ~serial;
            #1;
            if (known && Q !== expected)
                $fatal(1, "Data change between edges changed Q");
        end
    endtask

    initial begin
        // No initial-state assertion: original specifies no power-on value.
        step(1, 0, 0, 1);
        step(0, 0, 1, 1);
        step(0, 1, 0, 1);
        step(1, 1, 0, 1);
        step(1, 1, 1, 0);
        for (prior = 0; prior < 2; prior = prior + 1) begin
            for (combination = 0; combination < 16; combination = combination + 1) begin
                step(1, 0, prior != 0, 0);
                step(combination[3], combination[2], combination[1], combination[0]);
            end
        end
        $display("PASS: %0d load/shift/hold cycles and between-edge stability checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Bounded timeout");
    end
endmodule
