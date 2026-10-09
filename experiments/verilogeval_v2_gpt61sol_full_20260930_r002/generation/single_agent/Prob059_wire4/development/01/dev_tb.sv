`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    wire w, x, y, z;
    logic [1:0] states [0:3];
    integer ia, ib, ic;
    integer checked;
    TopModule dut (.a(a), .b(b), .c(c), .w(w), .x(x), .y(y), .z(z));

    task automatic check_connections;
        begin
            if (w !== a || x !== b || y !== b || z !== c)
                $fatal(1, "Connection mismatch: abc=%b%b%b wxyz=%b%b%b%b", a,b,c,w,x,y,z);
            checked = checked + 1;
        end
    endtask

    function automatic logic state_value(input integer index);
        case (index)
            0: state_value = 1'b0;
            1: state_value = 1'b1;
            2: state_value = 1'bx;
            3: state_value = 1'bz;
            default: state_value = 1'bx;
        endcase
    endfunction

    initial begin
        checked = 0;
        // Uninitialized inputs propagate unknowns through the wires.
        #1;
        check_connections();
        // Exhaust all binary combinations and X/Z propagation combinations.
        for (ia = 0; ia < 4; ia = ia + 1)
            for (ib = 0; ib < 4; ib = ib + 1)
                for (ic = 0; ic < 4; ic = ic + 1) begin
                    a = state_value(ia);
                    b = state_value(ib);
                    c = state_value(ic);
                    #1;
                    check_connections();
                end
        $display("PASS: %0d wire connection checks", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
