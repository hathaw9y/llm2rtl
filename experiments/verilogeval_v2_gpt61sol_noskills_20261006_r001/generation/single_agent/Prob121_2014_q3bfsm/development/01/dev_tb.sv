`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg x = 0;
    wire z;
    integer transitions [0:4][0:1];
    reg outputs [0:4];
    integer model;
    integer counts [0:4][0:1];
    integer word_index, bit_index, s, b;
    integer checked = 0;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));
    always #5 clk = ~clk;

    task check_output;
        begin
            if (z !== outputs[model])
                $fatal(1, "Output mismatch at %0t: state=%0d expected=%b actual=%b", $time, model, outputs[model], z);
            checked = checked + 1;
        end
    endtask

    task step(input reg reset_value, input reg x_value);
        begin
            @(negedge clk);
            reset = reset_value;
            x = x_value;
            #1;
            // Neither reset nor x may change the Moore output between edges.
            check_output();
            @(posedge clk);
            if (reset_value) model = 0;
            else begin
                counts[model][x_value] = counts[model][x_value] + 1;
                model = transitions[model][x_value];
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        transitions[0][0]=0; transitions[0][1]=1;
        transitions[1][0]=1; transitions[1][1]=4;
        transitions[2][0]=2; transitions[2][1]=1;
        transitions[3][0]=1; transitions[3][1]=2;
        transitions[4][0]=3; transitions[4][1]=4;
        outputs[0]=0; outputs[1]=0; outputs[2]=0;
        outputs[3]=1; outputs[4]=1;
        for (s=0; s<5; s=s+1)
            for (b=0; b<2; b=b+1) counts[s][b]=0;
        // No initial state is specified. Establish it through synchronous reset.
        reset=1;
        @(posedge clk);
        model=0;
        #1;
        check_output();
        // Replay every eight-bit input word, checking before and after each edge.
        for (word_index=0; word_index<256; word_index=word_index+1) begin
            step(1, word_index & 1);
            for (bit_index=0; bit_index<8; bit_index=bit_index+1)
                step(0, (word_index >> bit_index) & 1);
        end
        // Assert reset between edges while the output is high.
        step(1, 0);
        step(0, 1);
        step(0, 1);
        step(1, 1);
        step(1, 0);
        step(0, 0);
        for (s=0; s<5; s=s+1)
            for (b=0; b<2; b=b+1)
                if (counts[s][b] == 0)
                    $fatal(1, "Missing transition coverage: state %0d x=%0d", s, b);
        $display("PASS: %0d output checks; all ten transitions covered", checked);
        $finish;
    end
    initial begin
        #30000;
        $fatal(1, "Timeout");
    end
endmodule
