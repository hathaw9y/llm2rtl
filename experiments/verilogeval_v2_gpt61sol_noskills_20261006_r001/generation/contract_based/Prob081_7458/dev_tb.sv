`timescale 1ns/1ps
module dev_tb;
    reg [5:0] a;
    reg [3:0] b;
    wire p1y, p2y;
    integer i, j, k;
    integer checks = 0;
    TopModule dut (
        .p1a(a[0]), .p1b(a[1]), .p1c(a[2]),
        .p1d(a[3]), .p1e(a[4]), .p1f(a[5]),
        .p2a(b[0]), .p2b(b[1]), .p2c(b[2]), .p2d(b[3]),
        .p1y(p1y), .p2y(p2y)
    );
    // Independent gate truth tables: controlling zero for AND, one for OR.
    function automatic gate_and(input x, input y);
        if ((x === 1'b0) || (y === 1'b0)) gate_and = 1'b0;
        else if ((x === 1'b1) && (y === 1'b1)) gate_and = 1'b1;
        else gate_and = 1'bx;
    endfunction
    function automatic gate_or(input x, input y);
        if ((x === 1'b1) || (y === 1'b1)) gate_or = 1'b1;
        else if ((x === 1'b0) && (y === 1'b0)) gate_or = 1'b0;
        else gate_or = 1'bx;
    endfunction
    function automatic symbol(input integer n);
        case (n)
            0: symbol = 1'b0;
            1: symbol = 1'b1;
            2: symbol = 1'bx;
            3: symbol = 1'bz;
        endcase
    endfunction
    task automatic check_outputs;
        reg e1, e2;
        begin
            #1;
            e1 = gate_or(gate_and(gate_and(a[0],a[1]),a[2]),
                         gate_and(gate_and(a[3],a[4]),a[5]));
            e2 = gate_or(gate_and(b[0],b[1]),gate_and(b[2],b[3]));
            if ((p1y !== e1) || (p2y !== e2))
                $fatal(1,"Mismatch a=%b b=%b got=%b%b expected=%b%b",a,b,p1y,p2y,e1,e2);
            checks = checks + 1;
        end
    endtask
    initial begin
        // Registers start unknown; the uninitialized gate network must settle to X.
        check_outputs();
        for (i=0; i<1024; i=i+1) begin
            {b,a} = i;
            check_outputs();
        end
        b = 0;
        for (i=0; i<4096; i=i+1) begin
            k = i;
            for (j=0; j<6; j=j+1) begin
                a[j] = symbol(k % 4);
                k = k / 4;
            end
            check_outputs();
        end
        a = 0;
        for (i=0; i<256; i=i+1) begin
            k = i;
            for (j=0; j<4; j=j+1) begin
                b[j] = symbol(k % 4);
                k = k / 4;
            end
            check_outputs();
        end
        $display("PASS checked %0d combinations including initial unknowns",checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1,"Timeout");
    end
endmodule
