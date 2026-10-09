module dev_tb;
    logic clk=0, areset=0, bump_left=0, bump_right=0, ground=1;
    wire walk_left, walk_right, aaah;
    bit direction_right=0, falling=0;
    integer checks=0;
    integer s, v, i;
    TopModule dut(.*);
    always #5 clk = ~clk;
    initial begin
        #20000;
        $fatal(1,"FAIL watchdog");
    end
    task automatic check_outputs;
        logic [2:0] expected;
        begin
            expected = {(!falling && !direction_right),
                        (!falling && direction_right), falling};
            if ({walk_left,walk_right,aaah} !== expected)
                $fatal(1,"FAIL check=%0d expected=%b actual=%b",checks,expected,{walk_left,walk_right,aaah});
            checks=checks+1;
        end
    endtask
    task automatic reset_machine;
        begin
            @(negedge clk);
            #1 areset=1;
            direction_right=0;
            falling=0;
            #1 check_outputs();
            @(posedge clk);
            #1 check_outputs();
            @(negedge clk);
            areset=0;
            #1 check_outputs();
        end
    endtask
    task automatic step(input bit g, input bit bl, input bit br);
        begin
            @(negedge clk);
            ground=g; bump_left=bl; bump_right=br;
            #1 check_outputs();
            @(posedge clk);
            if (falling) begin
                if (g) falling=0;
            end else if (!g) falling=1;
            else if ((!direction_right && bl) || (direction_right && br))
                direction_right=!direction_right;
            #1 check_outputs();
        end
    endtask
    task automatic establish(input integer target);
        begin
            reset_machine();
            if (target == 1 || target == 3) step(1,1,0);
            if (target == 2 || target == 3) step(0,1,1);
        end
    endtask
    initial begin
        // Every input combination from each externally meaningful state.
        for (s=0;s<4;s=s+1) begin
            for (v=0;v<8;v=v+1) begin
                establish(s);
                step(v[2],v[1],v[0]);
            end
            establish(s);
            reset_machine();
        end
        // Exhaustive two-step sequences additionally exercise remembered direction.
        for(s=0;s<4;s=s+1)
            for(v=0;v<64;v=v+1) begin
                establish(s);
                step(v[5],v[4],v[3]);
                step(v[2],v[1],v[0]);
            end
        // Longer reproducible traces with repeated falls and landings.
        for(i=0;i<1000;i=i+1)
            step($random,$random,$random);
        $display("PASS checks=%0d: all-state inputs, two-step sequences, asynchronous reset, Moore stability, long traces",checks);
        $finish;
    end
endmodule
