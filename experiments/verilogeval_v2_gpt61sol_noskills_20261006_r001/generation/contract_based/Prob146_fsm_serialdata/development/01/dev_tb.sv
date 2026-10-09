`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg in = 1;
    reg reset = 0;
    wire [7:0] out_byte;
    wire done;
    TopModule dut(.clk(clk), .in(in), .reset(reset), .out_byte(out_byte), .done(done));
    always #5 clk = ~clk;

    // Reference tracks a transaction by its number of remaining samples.
    integer remaining = 0;
    reg recovering = 0;
    reg [7:0] expected_byte = 0;
    reg expected_done;
    integer checked = 0;
    integer successes = 0;
    reg enabled = 0;
    always @(posedge clk) begin
        if (reset) enabled = 1;
        if (enabled) begin
            expected_done = 0;
            if (reset) begin
                remaining = 0;
                recovering = 0;
            end else if (recovering) begin
                if (in) recovering = 0;
            end else if (remaining == 0) begin
                if (!in) begin
                    remaining = 9;
                    expected_byte = 0;
                end
            end else if (remaining > 1) begin
                // Shift LSB-first samples toward their eventual byte position.
                expected_byte = {in, expected_byte[7:1]};
                remaining = remaining - 1;
            end else begin
                remaining = 0;
                if (in) expected_done = 1;
                else recovering = 1;
            end
            #1;
            checked = checked + 1;
            if (done !== expected_done)
                $fatal(1, "done mismatch check=%0d expected=%b actual=%b", checked, expected_done, done);
            if (expected_done) begin
                successes = successes + 1;
                if (out_byte !== expected_byte)
                    $fatal(1, "byte mismatch check=%0d expected=%h actual=%h", checked, expected_byte, out_byte);
            end
        end
    end

    task tick(input reg value, input reg rst);
        begin
            @(negedge clk);
            in = value;
            reset = rst;
            @(posedge clk);
            #2;
        end
    endtask
    task frame(input reg [7:0] value, input reg stop_value);
        integer bitno;
        begin
            tick(0, 0);
            for (bitno = 0; bitno < 8; bitno = bitno + 1)
                tick(value[bitno], 0);
            tick(stop_value, 0);
        end
    endtask

    integer n, phase, j;
    reg [31:0] random_state = 32'hca912efd;
    initial begin
        tick(1, 1);
        tick(1, 0);
        repeat (8) tick(1, 0);
        for (n = 0; n < 256; n = n + 1) frame(n[7:0], 1);
        // done must persist until the next edge despite synchronous reset changing.
        @(negedge clk);
        reset = 1;
        #1;
        if (done !== 1'b1) $fatal(1, "reset acted asynchronously");
        @(posedge clk);
        #2;
        tick(1, 0);
        frame(8'h96, 0);
        repeat (20) tick(0, 0);
        tick(1, 0);
        frame(8'h69, 1);
        frame(8'h00, 0);
        tick(1, 0);
        tick(1, 0);
        frame(8'hff, 1);
        // Reset at idle, each data position, and the expected stop edge.
        for (phase = 0; phase <= 9; phase = phase + 1) begin
            tick(1, 1);
            for (j = 0; j < phase; j = j + 1) tick(0, 0);
            tick(0, 1);
            tick(1, 0);
            frame(8'ha5, 1);
        end
        frame(8'h55, 0);
        tick(0, 1); // Reset while recovering.
        frame(8'h81, 1);
        for (n = 0; n < 3000; n = n + 1) begin
            random_state = {random_state[30:0], random_state[31] ^ random_state[21] ^ random_state[1] ^ random_state[0]};
            tick(random_state[8], random_state[18:12] == 7'd0);
        end
        tick(1, 1);
        tick(1, 0);
        if (successes < 270) $fatal(1, "insufficient valid-frame coverage");
        $display("PASS checked %0d samples and %0d valid bytes", checked, successes);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
