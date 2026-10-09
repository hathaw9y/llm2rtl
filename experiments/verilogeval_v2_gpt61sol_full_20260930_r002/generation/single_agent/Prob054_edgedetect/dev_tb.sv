`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic [7:0] in = 8'h00;
    wire [7:0] pedge;
    logic [7:0] prior_sample = 8'hxx;
    logic [7:0] last_expected;
    bit have_output = 0;
    integer checks = 0;
    integer previous_value, current_value;

    TopModule dut (.clk(clk), .in(in), .pedge(pedge));
    always #5 clk = ~clk;

    task automatic sample(input logic [7:0] value);
        logic [7:0] expected;
        integer bit_index;
        begin
            @(negedge clk);
            in = value;
            #1;
            if (have_output && pedge !== last_expected)
                $fatal(1, "Output changed between rising edges: got %h expected %h", pedge, last_expected);
            // Independent per-bit transition table from the specification.
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                case ({prior_sample[bit_index], value[bit_index]})
                    2'b00, 2'b10, 2'b11: expected[bit_index] = 1'b0;
                    2'b01: expected[bit_index] = 1'b1;
                    default: begin
                        if (value[bit_index] === 1'b0)
                            expected[bit_index] = 1'b0;
                        else
                            expected[bit_index] = 1'bx;
                    end
                endcase
            end
            @(posedge clk);
            #1;
            if (pedge !== expected)
                $fatal(1, "Sample %0d: previous=%h current=%h got=%h expected=%h", checks, prior_sample, value, pedge, expected);
            prior_sample = value;
            last_expected = expected;
            have_output = 1;
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or power-up value is specified. Establish history with zero.
        // The unobserved first rising edge also samples zero.
        sample(8'h00);
        sample(8'hff);
        sample(8'hff);
        sample(8'h00);
        sample(8'haa);
        sample(8'h55);
        sample(8'haa);
        for (previous_value = 0; previous_value < 256; previous_value = previous_value + 1) begin
            for (current_value = 0; current_value < 256; current_value = current_value + 1) begin
                sample(previous_value[7:0]);
                sample(current_value[7:0]);
            end
        end
        $display("PASS: %0d sampled cycles, all byte transition pairs and inter-edge stability", checks);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Timeout");
    end
endmodule
