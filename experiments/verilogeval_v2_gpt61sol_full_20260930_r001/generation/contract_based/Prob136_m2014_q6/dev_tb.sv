`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic w = 0;
    wire z;
    integer ref_state = 0;
    integer checks = 0;
    integer covered [0:11];
    integer reset_covered [0:11];
    function automatic integer next_state(input integer current_state, input bit inp);
        case (current_state)
            0: next_state = inp ? 0 : 1;
            1: next_state = inp ? 3 : 2;
            2: next_state = inp ? 3 : 4;
            3: next_state = inp ? 0 : 5;
            4: next_state = inp ? 3 : 4;
            5: next_state = inp ? 3 : 2;
            default: next_state = 0;
        endcase
    endfunction
    integer sequence_id, bit_id, s, b;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));

    task automatic step(input bit rst, input bit inp);
        logic previous_z;
        begin
            previous_z = z;
            reset = rst;
            w = inp;
            #2;
            if (checks > 0 && z !== previous_z)
                $fatal(1, "Output changed between clock edges");
            if (rst) begin
                if (checks > 0) reset_covered[ref_state*2+inp] = 1;
                ref_state = 0;
            end else begin
                covered[ref_state*2+inp] = 1;
                ref_state = next_state(ref_state, inp);
            end
            clk = 1;
            #1;
            if (z !== ((ref_state == 4) || (ref_state == 5)))
                $fatal(1, "Mismatch check=%0d state=%0d z=%b", checks, ref_state, z);
            checks = checks + 1;
            #1;
            clk = 0;
            #1;
        end
    endtask

    initial begin
        for (s=0; s<6; s=s+1)
            for (b=0; b<2; b=b+1) begin
                covered[s*2+b]=0;
                reset_covered[s*2+b]=0;
            end
        for (sequence_id=0; sequence_id<1024; sequence_id=sequence_id+1) begin
            step(1, 0);
            for (bit_id=0; bit_id<10; bit_id=bit_id+1)
                step(0, (sequence_id >> bit_id) & 1);
            step(1, sequence_id & 1);
        end
        for (s=0; s<6; s=s+1)
            for (b=0; b<2; b=b+1) begin
                if (!covered[s*2+b]) $fatal(1, "Missing transition %0d/%0d", s,b);
                if (!reset_covered[s*2+b]) $fatal(1, "Missing reset %0d/%0d", s,b);
            end
        $display("PASS: %0d checked cycles; all 12 transitions and all 12 state/reset-input cases", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
