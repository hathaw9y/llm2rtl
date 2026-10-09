`timescale 1ns/1ps
module dev_tb;
    logic [9:0] stimulus;
    wire p1y, p2y;
    logic expected_p1y, expected_p2y;
    integer vector_index;

    TopModule dut (
        .p1a(stimulus[9]), .p1b(stimulus[8]), .p1c(stimulus[7]),
        .p1d(stimulus[6]), .p1e(stimulus[5]), .p1f(stimulus[4]),
        .p2a(stimulus[3]), .p2b(stimulus[2]),
        .p2c(stimulus[1]), .p2d(stimulus[0]),
        .p1y(p1y), .p2y(p2y)
    );

    initial begin
        for (vector_index = 0; vector_index < 1024; vector_index = vector_index + 1) begin
            stimulus = vector_index[9:0];
            // Original gate definition: each AND group is true only if all bits are high.
            expected_p1y = (stimulus[9:7] == 3'b111) || (stimulus[6:4] == 3'b111);
            expected_p2y = (stimulus[3:2] == 2'b11) || (stimulus[1:0] == 2'b11);
            #1;
            if (p1y !== expected_p1y || p2y !== expected_p2y)
                $fatal(1, "vector=%b expected=%b%b actual=%b%b", stimulus,
                       expected_p1y, expected_p2y, p1y, p2y);
        end
        $display("PASS exhaustive 1024 binary input combinations");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
