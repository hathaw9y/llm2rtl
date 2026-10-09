`timescale 1ns/1ps
module dev_tb;
    reg clk=0, reset=0, w=0;
    wire z;
    TopModule dut(.clk(clk), .reset(reset), .w(w), .z(z));
    integer model;
    integer visits[0:5][0:1];
    integer seq, bit_index, s, b;
    reg known=0;

    function integer transition(input integer current, input integer value);
        begin
            case (current)
                0: begin if (value == 0) transition=1; else transition=0; end
                1: begin if (value == 0) transition=2; else transition=3; end
                2: begin if (value == 0) transition=4; else transition=3; end
                3: begin if (value == 0) transition=5; else transition=0; end
                4: begin if (value == 0) transition=4; else transition=3; end
                5: begin if (value == 0) transition=2; else transition=3; end
                default: $fatal(1,"Invalid oracle state");
            endcase
        end
    endfunction

    task check_output;
        reg expected;
        begin
            expected=(model == 4 || model == 5);
            if (z !== expected)
                $fatal(1,"Output mismatch: state=%0d expected=%b actual=%b time=%0t", model, expected, z, $time);
        end
    endtask

    task cycle(input reg rst, input reg value);
        begin
            reset=rst; w=value;
            #2;
            if (known) check_output(); // Reset assertion alone must not change the state.
            if (rst) model=0;
            else begin
                visits[model][value]=visits[model][value]+1;
                model=transition(model,value);
            end
            clk=1;
            #1;
            known=1;
            check_output();
            #2; clk=0;
            #1; check_output();
        end
    endtask

    task reach(input integer target);
        begin
            cycle(1,0);
            case (target)
                0: begin end
                1: cycle(0,0);
                2: begin cycle(0,0); cycle(0,0); end
                3: begin cycle(0,0); cycle(0,1); end
                4: begin cycle(0,0); cycle(0,0); cycle(0,0); end
                5: begin cycle(0,0); cycle(0,1); cycle(0,0); end
            endcase
            if (model != target) $fatal(1,"Oracle reach failure");
        end
    endtask

    initial begin
        for(s=0;s<6;s=s+1)
            for(b=0;b<2;b=b+1) visits[s][b]=0;
        // No pre-reset value is required by the original problem.
        cycle(1,1);
        for(seq=0;seq<256;seq=seq+1) begin
            cycle(1,0);
            for(bit_index=0;bit_index<8;bit_index=bit_index+1)
                cycle(0,(seq >> bit_index) & 1);
        end
        // Reset from each state, with both possible inputs, also tests priority.
        for(s=0;s<6;s=s+1)
            for(b=0;b<2;b=b+1) begin
                reach(s);
                cycle(1,b);
                cycle(1,!b);
                cycle(0,0);
            end
        for(s=0;s<6;s=s+1)
            for(b=0;b<2;b=b+1)
                if(visits[s][b]==0) $fatal(1,"Missing transition coverage %0d %0d",s,b);
        $display("PASS: exhaustive sequences, all transitions, synchronous reset and priority");
        $finish;
    end
    initial begin #20000; $fatal(1,"Timeout"); end
endmodule
