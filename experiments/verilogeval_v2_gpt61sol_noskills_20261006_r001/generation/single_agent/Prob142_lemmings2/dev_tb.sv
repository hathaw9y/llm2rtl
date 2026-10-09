`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg areset = 0, bump_left = 0, bump_right = 0, ground = 1;
    wire walk_left, walk_right, aaah;
    TopModule dut(.*);
    // Independent behavioral oracle: remembered direction and whether airborne.
    reg direction_right = 0;
    reg falling = 0;
    integer checks = 0;
    integer s, inputs, n;
    reg [31:0] random_bits = 32'h194b763a;

    task check_outputs;
        reg [2:0] expected;
        begin
            if (falling) expected = 3'b001;
            else if (direction_right) expected = 3'b010;
            else expected = 3'b100;
            if ({walk_left, walk_right, aaah} !== expected)
                $fatal(1, "Mismatch at %0t: expected %b, got %b", $time,
                       expected, {walk_left, walk_right, aaah});
            checks = checks + 1;
        end
    endtask

    always @(posedge clk or posedge areset) begin
        if (areset) begin
            direction_right = 0;
            falling = 0;
        end else if (falling) begin
            if (ground) falling = 0;
        end else if (!ground) begin
            falling = 1;
        end else if ((!direction_right && bump_left) ||
                     (direction_right && bump_right)) begin
            direction_right = !direction_right;
        end
        #1;
        check_outputs();
    end

    task step(input reg g, input reg bl, input reg br);
        begin
            @(negedge clk);
            ground = g;
            bump_left = bl;
            bump_right = br;
            #1;
            check_outputs(); // Moore outputs must hold until the next rising edge.
            @(posedge clk);
            #2;
            check_outputs();
        end
    endtask

    task reset_machine;
        begin
            @(negedge clk);
            #2 areset = 1;
            #2 check_outputs(); // reset must act before the next clock edge.
            @(negedge clk);
            #1 areset = 0;
        end
    endtask

    initial begin
        // Establish reset before any oracle assertion; no power-up state specified.
        #1 areset = 1;
        #2 check_outputs();
        @(negedge clk);
        #1 areset = 0;
        // Reach each of the four states, then try all eight input combinations.
        for (s = 0; s < 4; s = s + 1) begin
            for (inputs = 0; inputs < 8; inputs = inputs + 1) begin
                reset_machine();
                if (s == 1 || s == 3) step(1, 1, 0);
                if (s == 2 || s == 3) step(0, 1, 1);
                step(inputs[2], inputs[1], inputs[0]);
                step(1, 0, 0);
            end
        end
        // Repeated airborne bumps and bumps on landing preserve direction.
        reset_machine();
        step(1, 1, 0);
        step(0, 1, 1);
        repeat (6) step(0, 1, 1);
        step(1, 1, 1);
        step(1, 1, 1);
        step(0, 1, 1);
        reset_machine(); // asynchronous reset while airborne and ground is absent.
        step(0, 0, 0);
        step(1, 1, 1);
        // Deterministic varied sequences exercise state retention over many cycles.
        for (n = 0; n < 300; n = n + 1) begin
            random_bits = {random_bits[30:0], random_bits[31] ^ random_bits[21] ^ random_bits[1] ^ random_bits[0]};
            step(random_bits[5], random_bits[13], random_bits[23]);
        end
        $display("PASS: %0d output checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Testbench timeout");
    end
endmodule
