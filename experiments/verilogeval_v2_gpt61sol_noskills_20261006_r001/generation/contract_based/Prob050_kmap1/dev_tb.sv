`timescale 1ns/1ps
module dev_tb;
    reg a, b, c;
    wire out;
    reg [7:0] map_abc;
    integer i;
    integer checks;
    TopModule dut (.a(a), .b(b), .c(c), .out(out));

    task check_input;
        input [2:0] abc;
        begin
            {a,b,c} = abc;
            #1;
            if (out !== map_abc[abc])
                $fatal(1, "abc=%b expected=%b actual=%b", abc, map_abc[abc], out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Original map: a=0,bc=00 gives 0; every other cell gives 1.
        // Bits indexed by abc (000 through 111).
        map_abc = 8'b11111110;
        checks = 0;
        for (i = 0; i < 8; i = i + 1) check_input(i[2:0]);
        for (i = 7; i >= 0; i = i - 1) check_input(i[2:0]);
        // Directed returns to zero and isolated assertion of each input.
        check_input(3'b000);
        check_input(3'b100);
        check_input(3'b000);
        check_input(3'b010);
        check_input(3'b000);
        check_input(3'b001);
        check_input(3'b000);
        $display("PASS: %0d Karnaugh-map checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
