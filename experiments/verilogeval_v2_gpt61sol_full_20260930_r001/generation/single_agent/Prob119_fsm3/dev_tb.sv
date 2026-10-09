`timescale 1ns/1ps
module dev_tb;
    logic clk = 0, areset = 0, in = 0;
    wire out;
    integer model = 0;
    integer checks = 0;
    integer transitions [0:3][0:1];
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        begin
            if (out !== (model == 3))
                $fatal(1, "Output mismatch: state=%0d out=%b", model, out);
            checks = checks + 1;
        end
    endtask

    task automatic reset_fsm;
        begin
            @(negedge clk);
            #1 areset = 1;
            model = 0;
            #1 check_output();
            @(negedge clk);
            #1 areset = 0;
            #1 check_output();
        end
    endtask

    task automatic step(input bit value);
        integer previous;
        begin
            @(negedge clk);
            in = value;
            #1 check_output(); // Moore output cannot depend on new input.
            previous = model;
            case (model)
                0: if (value) model = 1; else model = 0;
                1: if (value) model = 1; else model = 2;
                2: if (value) model = 3; else model = 0;
                3: if (value) model = 1; else model = 2;
            endcase
            transitions[previous][value] = transitions[previous][value] + 1;
            @(posedge clk);
            #1 check_output();
        end
    endtask

    initial begin
        for (integer s = 0; s < 4; s = s + 1)
            for (integer b = 0; b < 2; b = b + 1)
                transitions[s][b] = 0;
        for (integer pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_fsm();
            for (integer k = 0; k < 8; k = k + 1)
                step((pattern >> k) & 1);
        end
        reset_fsm();
        step(1); step(0); step(1); // Reach D before asynchronous reset.
        reset_fsm();
        step(0);
        for (integer s = 0; s < 4; s = s + 1)
            for (integer b = 0; b < 2; b = b + 1)
                if (transitions[s][b] == 0) $fatal(1, "Missing transition coverage");
        $display("PASS: %0d output checks; all eight transitions covered", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Development test timeout");
    end
endmodule
