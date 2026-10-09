`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    integer prior_level = 0;
    bit prior_direction = 1;
    bit initialized = 0;
    integer checks = 0;
    integer a, b, c;
    TopModule dut(.*);
    always #5 clk = ~clk;

    function automatic logic [2:0] sensors(input integer level);
        case (level)
            0: sensors = 3'b000;
            1: sensors = 3'b001;
            2: sensors = 3'b011;
            3: sensors = 3'b111;
        endcase
    endfunction

    task automatic check_outputs;
        logic [3:0] expected;
        begin
            case (prior_level)
                0: expected = 4'b1111;
                1: expected = {3'b011, prior_direction};
                2: expected = {3'b001, prior_direction};
                3: expected = 4'b0000;
            endcase
            if ({fr2,fr1,fr0,dfr} !== expected)
                $fatal(1,"level=%0d direction=%0b expected=%b actual=%b time=%0t",prior_level,prior_direction,expected,{fr2,fr1,fr0,dfr},$time);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input integer new_level, input bit rst);
        begin
            @(negedge clk);
            s = sensors(new_level);
            reset = rst;
            #1;
            if (initialized) check_outputs(); // synchronous reset/input stability
            @(posedge clk);
            if (rst) begin
                prior_level = 0;
                prior_direction = 1;
                initialized = 1;
            end else begin
                if (new_level == 0) prior_direction = 1;
                else if (new_level == 3) prior_direction = 0;
                else if (new_level != prior_level)
                    prior_direction = (new_level > prior_level);
                prior_level = new_level;
            end
            #1;
            check_outputs();
        end
    endtask

    initial begin
        cycle(3,1); // reset overrides even the highest sensors
        cycle(3,1);
        cycle(0,0);
        for (a=0; a<4; a=a+1)
            for (b=0; b<4; b=b+1)
                for (c=0; c<4; c=c+1) begin
                    cycle(a,1);
                    cycle(a,0);
                    cycle(b,0);
                    cycle(b,0);
                    cycle(c,0);
                    cycle(c,0);
                end
        cycle(2,1);
        cycle(1,0);
        cycle(2,0);
        cycle(1,0);
        cycle(3,0);
        cycle(2,0);
        cycle(0,0);
        $display("PASS: %0d output checks across all legal level triples, holds, and synchronous resets",checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1,"Timeout");
    end
endmodule
