`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    integer from_pair, to_pair;
    TopModule dut (.x(x), .y(y), .z(z));

    task automatic sample(input logic expected_z);
        begin
            #0;
            if (z !== expected_z)
                $fatal(1, "Mismatch at %0t: x=%b y=%b z=%b expected=%b",
                       $time, x, y, z, expected_z);
            checks = checks + 1;
        end
    endtask

    // Truth table transcribed from the original waveform, not the DUT equation.
    task automatic apply_pair(input integer pair_number);
        begin
            case (pair_number)
                0: begin x = 0; y = 0; sample(1); end
                1: begin x = 0; y = 1; sample(0); end
                2: begin x = 1; y = 0; sample(0); end
                3: begin x = 1; y = 1; sample(1); end
                default: $fatal(1, "Invalid test pair");
            endcase
        end
    endtask

    initial begin
        // Exact original timestamps: each #5 advances to the next table row.
        x=0; y=0; sample(1);       // 0ns
        #5; x=0; y=0; sample(1);   // 5ns
        #5; x=0; y=0; sample(1);   // 10ns
        #5; x=0; y=0; sample(1);   // 15ns
        #5; x=0; y=0; sample(1);   // 20ns
        #5; x=1; y=0; sample(0);   // 25ns
        #5; x=1; y=0; sample(0);   // 30ns
        #5; x=0; y=1; sample(0);   // 35ns
        #5; x=0; y=1; sample(0);   // 40ns
        #5; x=1; y=1; sample(1);   // 45ns
        #5; x=1; y=1; sample(1);   // 50ns
        #5; x=0; y=0; sample(1);   // 55ns
        #5; x=0; y=1; sample(0);   // 60ns
        #5; x=0; y=1; sample(0);   // 65ns
        #5; x=1; y=1; sample(1);   // 70ns
        #5; x=0; y=1; sample(0);   // 75ns
        #5; x=0; y=1; sample(0);   // 80ns
        #5; x=0; y=1; sample(0);   // 85ns
        #5; x=1; y=0; sample(0);   // 90ns

        for (from_pair = 0; from_pair < 4; from_pair = from_pair + 1) begin
            for (to_pair = 0; to_pair < 4; to_pair = to_pair + 1) begin
                #1; apply_pair(from_pair);
                #1; apply_pair(to_pair);
            end
        end
        $display("PASS: original waveform and all binary transitions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Development test timeout");
    end
endmodule
