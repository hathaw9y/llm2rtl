module dev_tb;
    logic clk = 0, aresetn = 1, x = 0;
    wire z;
    TopModule dut(.clk(clk), .aresetn(aresetn), .x(x), .z(z));
    logic [1:0] history = 0;
    integer count = 0, checks = 0;
    task automatic check;
        logic expected;
        begin
            expected = (count >= 2 && history == 2'b10 && x);
            if (z !== expected) $fatal(1, "Mismatch history=%b count=%0d x=%b z=%b expected=%b", history,count,x,z,expected);
            checks = checks + 1;
        end
    endtask
    task automatic reset_now;
        begin
            clk = 0;
            aresetn = 0;
            history = 0; count = 0;
            #1; check();
            aresetn = 1;
            #1; check();
        end
    endtask
    task automatic bit_step(input logic value);
        begin
            clk = 0; x = value;
            #1; check();
            clk = 1;
            history = {history[0],value};
            count = count + 1;
            #1; check();
            clk = 0;
            #1;
        end
    endtask
    integer word_index, bit_index;
    initial begin
        reset_now();
        for (word_index = 0; word_index < 1024; word_index = word_index + 1) begin
            reset_now();
            for (bit_index = 9; bit_index >= 0; bit_index = bit_index - 1)
                bit_step((word_index >> bit_index) & 1);
        end
        reset_now();
        bit_step(1); bit_step(0);
        x=1; #1; check();
        x=0; #1; check();
        x=1; #1; check();
        reset_now();
        bit_step(1); reset_now(); bit_step(0); bit_step(1);
        $display("PASS checks=%0d exhaustive_sequences=1024 async_reset=covered",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
