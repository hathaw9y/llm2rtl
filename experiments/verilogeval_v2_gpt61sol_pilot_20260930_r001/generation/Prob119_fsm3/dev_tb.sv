`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg in = 0;
    wire out;
    integer ref_state = 0;
    integer coverage_bits = 0;
    integer checks = 0;
    integer seq, bitidx;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));
    task check_output;
        begin
            checks = checks + 1;
            if (out !== (ref_state == 3))
                $fatal(1, "Mismatch state=%0d out=%b time=%0t",ref_state,out,$time);
        end
    endtask
    task reset_fsm;
        begin
            clk = 0;
            #2; areset = 1; ref_state = 0;
            #1; check_output();
            in = 1;
            #1; clk = 1;
            #1; check_output();
            clk = 0;
            #1; areset = 0;
        end
    endtask
    task step(input reg value);
        begin
            clk = 0; in = value;
            #1; check_output();
            coverage_bits = coverage_bits | (1 << (2*ref_state + value));
            case (ref_state)
                0: if (value) ref_state = 1; else ref_state = 0;
                1: if (value) ref_state = 1; else ref_state = 2;
                2: if (value) ref_state = 3; else ref_state = 0;
                3: if (value) ref_state = 1; else ref_state = 2;
            endcase
            clk = 1;
            #1; check_output();
            clk = 0;
            in = ~value;
            #1; check_output();
        end
    endtask
    initial begin
        for (seq = 0; seq < 256; seq = seq + 1) begin
            reset_fsm();
            for (bitidx = 0; bitidx < 8; bitidx = bitidx + 1)
                step((seq >> bitidx) & 1);
        end
        reset_fsm(); step(1); step(0); step(1);
        if (out !== 1'b1) $fatal(1,"Did not reach D");
        reset_fsm();
        if (coverage_bits != 255) $fatal(1,"Missing transition coverage: %h",coverage_bits);
        $display("PASS checks=%0d transition_coverage=8/8 sequences=256 async_reset_in_D=passed",checks);
        $finish;
    end
    initial begin
        #100000; $fatal(1,"Timeout");
    end
endmodule
