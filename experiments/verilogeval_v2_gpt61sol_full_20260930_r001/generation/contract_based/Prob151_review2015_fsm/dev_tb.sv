module dev_tb;
    logic clk = 0;
    logic reset = 0, data = 0, done_counting = 0, ack = 0;
    wire shift_ena, counting, done;
    TopModule dut(.*);
    always #5 clk = ~clk;
    integer phase = 0, remaining = 0, samples = 0, cycles = 0;
    integer shift_visits = 0, count_visits = 0, done_visits = 0;
    logic [3:0] history = 0;
    logic [2:0] expected;
    logic [31:0] rng = 32'h217acbed;

    task automatic step(input bit r, input bit d, input bit dc, input bit a);
        logic [2:0] before_outputs;
        begin
            @(negedge clk);
            before_outputs = {shift_ena,counting,done};
            reset = r; data = d; done_counting = dc; ack = a;
            #1;
            if (cycles > 0 && {shift_ena,counting,done} !== before_outputs)
                $fatal(1,"Outputs changed without positive clock edge");
            @(posedge clk);
            if (r) begin
                phase = 0; remaining = 0; history = 0; samples = 0;
            end else begin
                case (phase)
                    0: begin
                        history = {history[2:0],d};
                        if (samples < 4) samples = samples + 1;
                        if (samples >= 4 && history == 4'b1101) begin
                            phase = 1; remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (dc) phase = 3;
                    3: if (a) begin phase = 0; history = 0; samples = 0; end
                endcase
            end
            expected = 3'b000;
            case (phase)
                1: begin expected = 3'b100; shift_visits = shift_visits + 1; end
                2: begin expected = 3'b010; count_visits = count_visits + 1; end
                3: begin expected = 3'b001; done_visits = done_visits + 1; end
            endcase
            #1;
            cycles = cycles + 1;
            if ({shift_ena,counting,done} !== expected)
                $fatal(1,"cycle %0d expected %b got %b",cycles,expected,{shift_ena,counting,done});
        end
    endtask

    task automatic pattern;
        begin
            step(0,1,1,1); step(0,1,1,1);
            step(0,0,1,1); step(0,1,1,1);
        end
    endtask

    integer stream, bit_index, i, reset_offset;
    initial begin
        step(1,0,0,0);
        // Exhaustive short streams include matching and overlapping prefixes.
        for (stream = 0; stream < 256; stream = stream + 1) begin
            step(1,0,0,0);
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                step(0,(stream >> bit_index) & 1,0,0);
            repeat (5) step(0,0,0,0);
            step(0,0,1,1); // ack must not skip notification entry
            repeat (3) step(0,1,0,0);
            step(0,1,0,1);
        end
        // Reset every shift position, counting and notification.
        for (reset_offset = 0; reset_offset <= 6; reset_offset = reset_offset + 1) begin
            step(1,0,0,0);
            pattern();
            for (i = 0; i < reset_offset; i = i + 1) step(0,1,1,0);
            step(1,1,1,1);
            pattern();
            repeat (4) step(0,0,1,1);
            step(0,0,1,1);
            repeat (4) step(0,0,0,0);
            step(0,1,0,1);
        end
        // Repeated transactions without reset.
        repeat (20) begin
            pattern();
            repeat (4) step(0,1,1,1);
            repeat (3) step(0,1,0,1);
            step(0,1,1,1);
            repeat (3) step(0,0,0,0);
            step(0,1,0,1);
        end
        for (i = 0; i < 10000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step(rng[12:8] == 0,rng[0],rng[1],rng[2]);
        end
        if (shift_visits == 0 || count_visits == 0 || done_visits == 0)
            $fatal(1,"Missing active-phase coverage");
        $display("PASS cycles=%0d shift=%0d count=%0d done=%0d",cycles,shift_visits,count_visits,done_visits);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1,"Testbench timeout");
    end
endmodule
