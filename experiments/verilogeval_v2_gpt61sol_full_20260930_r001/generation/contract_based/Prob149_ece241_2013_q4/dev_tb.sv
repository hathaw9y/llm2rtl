`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    TopModule dut (.clk(clk), .reset(reset), .s(s), .fr2(fr2), .fr1(fr1), .fr0(fr0), .dfr(dfr));
    integer model_level = 0;
    bit model_extra = 1;
    integer checks = 0;
    bit initialized = 0;
    integer seq, pos, encoded, next_level, pattern;

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
            case (model_level)
                0: expected = {3'b111,model_extra};
                1: expected = {3'b011,model_extra};
                2: expected = {3'b001,model_extra};
                3: expected = {3'b000,model_extra};
            endcase
            if ({fr2,fr1,fr0,dfr} !== expected)
                $fatal(1,"Mismatch check=%0d level=%0d actual=%b expected=%b",checks,model_level,{fr2,fr1,fr0,dfr},expected);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic [2:0] sample, input bit rst);
        integer incoming;
        begin
            clk = 0;
            s = sample;
            reset = rst;
            #2;
            if (initialized) check_outputs();
            case (sample)
                3'b000: incoming = 0;
                3'b001: incoming = 1;
                3'b011: incoming = 2;
                3'b111: incoming = 3;
                default: incoming = model_level;
            endcase
            if (rst) begin
                model_level = 0;
                model_extra = 1;
            end else begin
                if (incoming == 0) model_extra = 1;
                else if (incoming == 3) model_extra = 0;
                else if (incoming != model_level) model_extra = (incoming > model_level);
                model_level = incoming;
            end
            clk = 1;
            #2;
            initialized = 1;
            check_outputs();
            clk = 0;
            #1;
        end
    endtask

    initial begin
        cycle(3'b111,1);
        // Enumerate all legal five-sample histories, with held-level cycles.
        for (seq = 0; seq < 1024; seq = seq + 1) begin
            cycle(3'b111,1);
            encoded = seq;
            for (pos = 0; pos < 5; pos = pos + 1) begin
                next_level = encoded % 4;
                encoded = encoded / 4;
                cycle(sensors(next_level),0);
                cycle(sensors(next_level),0);
            end
        end
        // Reset priority over every pattern, including unspecified patterns.
        for (pattern = 0; pattern < 8; pattern = pattern + 1) begin
            cycle(3'b011,0);
            cycle(pattern[2:0],1);
            cycle(3'b001,0);
        end
        // Implementation-defined invalid inputs hold established history.
        cycle(3'b111,0);
        cycle(3'b011,0);
        cycle(3'b010,0);
        cycle(3'b100,0);
        cycle(3'b101,0);
        cycle(3'b110,0);
        $display("PASS: %0d output comparisons; exhaustive legal length-five histories and reset/timing checks",checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1,"Development test watchdog timeout");
    end
endmodule
