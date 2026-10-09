`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg in = 0;
    wire out;
    integer model;
    integer transition [0:7];
    integer seq, bit_index, checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task verify;
        begin
            if (out !== (model == 3))
                $fatal(1, "Mismatch time=%0t state=%0d in=%b reset=%b out=%b", $time, model, in, areset, out);
            checks = checks + 1;
        end
    endtask

    task reset_between_edges;
        begin
            // Clock is low: reset must act without a clock edge.
            #2 areset = 1;
            model = 0;
            #1 verify;
            #2 areset = 0;
            #1 verify;
        end
    endtask

    task step(input reg value);
        begin
            in = value;
            #2 verify; // Moore output must not respond to input alone.
            clk = 1;
            if (areset) model = 0;
            else model = transition[2*model + value];
            #1 verify; // Sample after nonblocking state update.
            #2 clk = 0;
            #1 verify; // Falling edge must not change state.
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Original table, independently represented as an indexed oracle.
        transition[0] = 0; transition[1] = 1;
        transition[2] = 2; transition[3] = 1;
        transition[4] = 0; transition[5] = 3;
        transition[6] = 2; transition[7] = 1;
        reset_between_edges;
        step(1); step(0); step(1); // A -> B -> C -> D
        reset_between_edges; // Clear asserted output asynchronously.
        step(1); step(0); step(1);
        #2 areset = 1; model = 0;
        #1 verify;
        step(1); step(0); step(1); // Reset held across positive clock edges.
        #2 areset = 0;
        #1 verify;
        step(1); step(0); step(1);
        // Also assert and release reset while the clock is high.
        #2 clk = 1; model = transition[2*model + in];
        #1 verify;
        #1 areset = 1; model = 0;
        #1 verify;
        #1 areset = 0;
        #1 verify;
        clk = 0;
        #1 verify;
        for (seq = 0; seq < 256; seq = seq + 1) begin
            reset_between_edges;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step((seq >> bit_index) & 1);
        end
        $display("PASS: FSM table, exhaustive eight-cycle sequences, Moore timing and asynchronous reset (%0d checks)", checks);
        $finish;
    end
endmodule
