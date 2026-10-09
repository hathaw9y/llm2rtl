`timescale 1ns/1ps
module dev_tb;
    reg d, done_counting, ack;
    reg [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    integer checks = 0;
    integer s, inputs;
    TopModule dut (
        .d(d), .done_counting(done_counting), .ack(ack), .state(state),
        .B3_next(B3_next), .S_next(S_next), .S1_next(S1_next),
        .Count_next(Count_next), .Wait_next(Wait_next),
        .done(done), .counting(counting), .shift_ena(shift_ena)
    );

    // Oracle uses the original transition table, not DUT Boolean equations.
    task check_state(input integer current, input reg di,
                     input reg dc, input reg ai);
        integer next_state;
        reg exp_done, exp_counting, exp_shift;
        reg [7:0] expected, observed;
        begin
            state = 10'b0000000001 << current;
            d = di;
            done_counting = dc;
            ack = ai;
            exp_done = 0;
            exp_counting = 0;
            exp_shift = 0;
            case (current)
                0: begin if (di) next_state=1; else next_state=0; end
                1: begin if (di) next_state=2; else next_state=0; end
                2: begin if (di) next_state=2; else next_state=3; end
                3: begin if (di) next_state=4; else next_state=0; end
                4: begin next_state=5; exp_shift=1; end
                5: begin next_state=6; exp_shift=1; end
                6: begin next_state=7; exp_shift=1; end
                7: begin next_state=8; exp_shift=1; end
                8: begin
                    exp_counting=1;
                    if (dc) next_state=9; else next_state=8;
                end
                9: begin
                    exp_done=1;
                    if (ai) next_state=0; else next_state=9;
                end
                default: $fatal(1,"Illegal oracle state");
            endcase
            expected = {next_state==7, next_state==0, next_state==1,
                        next_state==8, next_state==9,
                        exp_done, exp_counting, exp_shift};
            #1;
            observed = {B3_next,S_next,S1_next,Count_next,Wait_next,
                        done,counting,shift_ena};
            if (observed !== expected)
                $fatal(1,"state=%0d d=%b dc=%b ack=%b expected=%b got=%b",
                       current,di,dc,ai,expected,observed);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Reset-state ownership is external: begin by supplying S.
        check_state(0,0,0,0);
        // Directed detector, shift sequence, counting and acknowledgement.
        check_state(0,1,0,0);
        check_state(1,1,0,0);
        check_state(2,1,0,0);
        check_state(2,0,0,0);
        check_state(3,1,0,0);
        check_state(4,0,1,1);
        check_state(5,1,0,0);
        check_state(6,0,1,0);
        check_state(7,1,1,1);
        check_state(8,0,0,1);
        check_state(8,1,1,0);
        check_state(9,1,1,0);
        check_state(9,0,0,1);
        check_state(0,0,1,1);
        // Exhaustive legal state/input combinations include all don't cares.
        for (s=0; s<10; s=s+1)
            for (inputs=0; inputs<8; inputs=inputs+1)
                check_state(s,inputs[2],inputs[1],inputs[0]);
        $display("PASS: %0d combinational transition/output checks",checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1,"Bounded timeout");
    end
endmodule
