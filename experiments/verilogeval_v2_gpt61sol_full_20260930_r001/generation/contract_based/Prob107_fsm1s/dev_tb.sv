`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    typedef enum {REF_A, REF_B} ref_state_t;
    ref_state_t expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic step(input logic r, input logic x);
        logic previous;
        begin
            @(negedge clk);
            previous = out;
            reset = r;
            in = x;
            #1;
            if (checks != 0 && out !== previous)
                $fatal(1, "Output changed between edges");
            @(posedge clk);
            if (r) expected = REF_B;
            else begin
                case (expected)
                    REF_A: if (x == 0) expected = REF_B;
                    REF_B: if (x == 0) expected = REF_A;
                endcase
            end
            #1;
            if (out !== (expected == REF_B))
                $fatal(1, "Mismatch reset=%b in=%b expected=%b out=%b", r,x,(expected==REF_B),out);
            checks = checks + 1;
        end
    endtask

    initial begin
        step(1,0);
        step(0,1);
        step(0,0);
        step(0,1);
        step(1,1);
        step(0,0);
        step(1,0);
        step(1,1);
        for (integer seq = 0; seq < 256; seq = seq + 1) begin
            step(1,seq[0]);
            for (integer bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step(0,seq[bit_index]);
        end
        $display("PASS: %0d checked cycles; all length-eight input sequences and synchronous reset checks",checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Testbench timeout");
    end
endmodule
