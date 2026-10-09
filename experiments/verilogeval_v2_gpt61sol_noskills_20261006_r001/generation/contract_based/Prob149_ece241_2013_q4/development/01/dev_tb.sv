`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    TopModule dut(.clk(clk), .reset(reset), .s(s),
                  .fr2(fr2), .fr1(fr1), .fr0(fr0), .dfr(dfr));
    always #5 clk = ~clk;
    integer previous_level;
    reg supplement;
    reg [3:0] expected;
    integer checks = 0;
    integer a, b, seq, digit, n;

    function automatic [2:0] sensors(input integer rank);
        case (rank)
            0: sensors = 3'b000;
            1: sensors = 3'b001;
            2: sensors = 3'b011;
            3: sensors = 3'b111;
        endcase
    endfunction

    task automatic compare(input [3:0] value);
        begin
            if ({fr2,fr1,fr0,dfr} !== value)
                $fatal(1, "Mismatch t=%0t s=%b reset=%b got=%b expected=%b",
                       $time, s, reset, {fr2,fr1,fr0,dfr}, value);
            checks = checks + 1;
        end
    endtask

    task automatic step(input integer rank, input reg rst);
        begin
            @(negedge clk);
            s = sensors(rank);
            reset = rst;
            #1;
            // A synchronous reset or new sensor value cannot alter outputs yet.
            if (checks != 0) compare(expected);
            @(posedge clk);
            if (rst) begin
                previous_level = 0;
                supplement = 1;
            end else begin
                if (rank == 0) supplement = 1;
                else if (rank == 3) supplement = 0;
                else if (rank != previous_level)
                    supplement = (previous_level < rank);
                previous_level = rank;
            end
            // The table asserts the lowest (3-rank) nominal flow inputs.
            expected = {3'b111 >> previous_level, supplement};
            #1;
            compare(expected);
        end
    endtask

    initial begin
        // Initial outputs are unspecified; first establish the required reset state.
        step(3, 1);
        step(3, 1);
        step(0, 0);
        step(1, 0);
        step(1, 0);
        step(2, 0);
        step(2, 0);
        step(3, 0);
        step(2, 0);
        step(2, 0);
        step(1, 0);
        step(1, 0);
        step(0, 0);
        // Every directed transition, including full-range skips and repeated levels.
        for (a=0; a<4; a=a+1)
            for (b=0; b<4; b=b+1) begin
                step(3, 1);
                step(a, 0);
                step(b, 0);
                step(b, 0);
                step(b, 0);
                step(b, 1);
            end
        // All four-sample valid sequences from the specified reset condition.
        for (seq=0; seq<256; seq=seq+1) begin
            step(3, 1);
            digit = seq;
            for (n=0; n<4; n=n+1) begin
                step(digit % 4, 0);
                digit = digit / 4;
            end
        end
        $display("PASS: %0d checks of reset, timing, levels and direction history", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Bounded timeout");
    end
endmodule
