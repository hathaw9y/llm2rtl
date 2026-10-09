`timescale 1ns/1ps
module dev_tb;
    reg x3, x2, x1;
    wire f;
    integer source_index, target_index;
    integer checks = 0;
    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));

    // Literal oracle copied from the original binary truth table.
    function automatic expected(input [2:0] inputs);
        begin
            case (inputs)
                3'b000: expected = 1'b0;
                3'b001: expected = 1'b0;
                3'b010: expected = 1'b1;
                3'b011: expected = 1'b1;
                3'b100: expected = 1'b0;
                3'b101: expected = 1'b1;
                3'b110: expected = 1'b0;
                3'b111: expected = 1'b1;
                default: expected = 1'bx;
            endcase
        end
    endfunction

    task automatic drive_and_check(input [2:0] inputs);
        begin
            {x3, x2, x1} = inputs;
            #1;
            if (f !== expected(inputs))
                $fatal(1, "Input %b: expected %b, observed %b", inputs, expected(inputs), f);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (source_index = 0; source_index < 8; source_index = source_index + 1) begin
            for (target_index = 0; target_index < 8; target_index = target_index + 1) begin
                drive_and_check(source_index[2:0]);
                drive_and_check(target_index[2:0]);
            end
        end
        $display("PASS: all truth-table rows and all ordered binary transitions (%0d checks)", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
