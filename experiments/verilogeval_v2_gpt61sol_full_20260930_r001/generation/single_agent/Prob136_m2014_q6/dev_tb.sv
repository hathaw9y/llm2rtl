`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic w = 0;
    wire z;
    integer model = 0;
    integer checks = 0;
    integer sequence_id, bit_id;
    integer coverage [0:5][0:1];
    integer state_id, input_id;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    function automatic integer advance(input integer s, input logic v);
        case (s)
            0: advance = v ? 0 : 1;
            1: advance = v ? 3 : 2;
            2: advance = v ? 3 : 4;
            3: advance = v ? 0 : 5;
            4: advance = v ? 3 : 4;
            5: advance = v ? 3 : 2;
            default: advance = 0;
        endcase
    endfunction

    task automatic step(input logic rst, input logic value);
        logic expected;
        begin
            @(negedge clk);
            reset = rst;
            w = value;
            #1;
            if (checks > 0 && z !== ((model == 4) || (model == 5)))
                $fatal(1, "Output changed before clock edge");
            @(posedge clk);
            if (rst) model = 0;
            else begin
                coverage[model][value] = coverage[model][value] + 1;
                model = advance(model, value);
            end
            #1;
            expected = (model == 4) || (model == 5);
            if (z !== expected)
                $fatal(1, "Mismatch: state=%0d z=%b expected=%b", model, z, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (state_id = 0; state_id < 6; state_id = state_id + 1)
            for (input_id = 0; input_id < 2; input_id = input_id + 1)
                coverage[state_id][input_id] = 0;
        for (sequence_id = 0; sequence_id < 1024; sequence_id = sequence_id + 1) begin
            step(1, sequence_id[0]);
            for (bit_id = 0; bit_id < 10; bit_id = bit_id + 1)
                step(0, (sequence_id >> bit_id) & 1);
        end
        step(1, 0);
        step(0, 0); step(0, 0); step(0, 0);
        step(1, 1);
        step(0, 0); step(0, 1); step(0, 0);
        step(1, 0);
        for (state_id = 0; state_id < 6; state_id = state_id + 1)
            for (input_id = 0; input_id < 2; input_id = input_id + 1)
                if (coverage[state_id][input_id] == 0)
                    $fatal(1, "Missing transition coverage");
        $display("PASS: %0d checks, all 12 transitions covered", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end
endmodule
