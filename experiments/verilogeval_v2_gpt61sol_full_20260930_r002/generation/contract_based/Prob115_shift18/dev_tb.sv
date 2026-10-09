module dev_tb;
    logic clk = 0;
    logic load = 0, ena = 0;
    logic [1:0] amount = 0;
    logic [63:0] data = 0;
    wire [63:0] q;
    logic [63:0] expected = 'x;
    logic [63:0] next_expected;
    logic [63:0] patterns [0:7];
    logic [31:0] rng = 32'h45ace187;
    integer checks = 0;
    integer i, j, k;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;
    initial begin
        #40000;
        $fatal(1, "Timeout");
    end
    function automatic [63:0] shift_model(input [63:0] old, input [1:0] mode);
        integer b, distance;
        begin
            distance = mode[0] ? 8 : 1;
            for (b = 0; b < 64; b = b + 1) begin
                if (!mode[1]) begin
                    if (b < distance) shift_model[b] = 1'b0;
                    else shift_model[b] = old[b-distance];
                end else begin
                    if (b+distance >= 64) shift_model[b] = old[63];
                    else shift_model[b] = old[b+distance];
                end
            end
        end
    endfunction
    task automatic step(input logic ld, input logic en, input logic [1:0] mode, input logic [63:0] payload);
        begin
            @(negedge clk);
            load = ld; ena = en; amount = mode; data = payload;
            next_expected = expected;
            if (ld) next_expected = payload;
            else if (en) next_expected = shift_model(expected, mode);
            #1;
            if (q !== expected) $fatal(1, "Asynchronous change: got %h expected %h", q, expected);
            @(posedge clk);
            #1;
            expected = next_expected;
            if (q !== expected) $fatal(1, "Check %0d load=%b ena=%b amount=%b got=%h expected=%h", checks, ld, en, mode, q, expected);
            checks = checks + 1;
        end
    endtask
    initial begin
        patterns[0] = 64'h0;
        patterns[1] = 64'hffffffffffffffff;
        patterns[2] = 64'h8000000000000000;
        patterns[3] = 64'h7fffffffffffffff;
        patterns[4] = 64'h1;
        patterns[5] = 64'h0123456789abcdef;
        patterns[6] = 64'hfedcba9876543210;
        patterns[7] = 64'haa55aa55aa55aa55;
        #1;
        if (q !== 64'hxxxxxxxxxxxxxxxx) $fatal(1, "Unexpected initialization");
        step(0, 0, 0, 64'hffffffffffffffff);
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                step(1, 1, j[1:0], patterns[i]);
                step(0, 0, j[1:0], ~patterns[i]);
                for (k = 0; k < 66; k = k + 1)
                    step(0, 1, j[1:0], 64'h0);
            end
            step(1, 0, 0, patterns[i]);
        end
        for (i = 0; i < 500; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[0], rng[1], rng[3:2], {rng, ~rng});
        end
        $display("PASS %0d shift-register checks", checks);
        $finish;
    end
endmodule
