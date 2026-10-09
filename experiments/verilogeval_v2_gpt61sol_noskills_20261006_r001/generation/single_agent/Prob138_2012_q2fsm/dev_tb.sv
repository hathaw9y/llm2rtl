`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg w = 0;
    wire z;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));

    // Independent oracle: named states represented by integer indices,
    // with the two input columns stored as transition lookup tables.
    integer zero_dest [0:5];
    integer one_dest [0:5];
    integer model;
    reg valid = 0;
    reg [11:0] edges_seen = 0;
    reg [5:0] resets_seen = 0;
    integer sequence_number, bit_number, cycles = 0;

    task check_output;
        begin
            if (z !== ((model == 4) || (model == 5)))
                $fatal(1, "Output mismatch cycle=%0d model=%0d z=%b", cycles, model, z);
        end
    endtask

    task step(input reg rst, input reg data);
        begin
            reset = rst;
            w = data;
            #2;
            // Neither input changes nor synchronous reset may change z
            // before the next rising clock edge.
            if (valid) check_output();
            if (rst) begin
                if (valid) resets_seen[model] = 1'b1;
                model = 0;
            end else begin
                if (!valid) $fatal(1, "Oracle used before reset");
                edges_seen[2*model + data] = 1'b1;
                if (data) model = one_dest[model];
                else model = zero_dest[model];
            end
            clk = 1;
            #1;
            valid = 1;
            cycles = cycles + 1;
            check_output();
            #2;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // A,B,C,D,E,F; each entry transcribes the original transition list.
        zero_dest[0]=0; one_dest[0]=1;
        zero_dest[1]=3; one_dest[1]=2;
        zero_dest[2]=3; one_dest[2]=4;
        zero_dest[3]=0; one_dest[3]=5;
        zero_dest[4]=3; one_dest[4]=4;
        zero_dest[5]=3; one_dest[5]=2;
        // The specification does not prescribe an output before first reset.
        step(1, 0);
        step(1, 1);
        // All 256 eight-bit words, each starting in A, include boundary
        // paths through E and F, loops, and all state/input combinations.
        for (sequence_number=0; sequence_number<256; sequence_number=sequence_number+1) begin
            step(1, sequence_number % 2);
            for (bit_number=7; bit_number>=0; bit_number=bit_number-1)
                step(0, (sequence_number >> bit_number) & 1);
        end
        step(1, 1);
        if (edges_seen !== 12'hfff) $fatal(1, "Incomplete transition coverage %h", edges_seen);
        if (resets_seen !== 6'h3f) $fatal(1, "Incomplete reset coverage %h", resets_seen);
        $display("PASS: %0d cycles, all 12 transitions and reset from all six states", cycles);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
