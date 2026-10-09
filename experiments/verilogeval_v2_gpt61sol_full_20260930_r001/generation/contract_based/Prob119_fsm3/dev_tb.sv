`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic in = 0;
    wire out;
    integer expected_state = 0;
    integer transition [0:3][0:1];
    integer hits [0:3][0:1];
    integer seq, bit_index, s, b;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));
    always #5 clk = ~clk;
    initial begin
        #100000;
        $fatal(1, "FAIL watchdog");
    end
    task automatic check_output;
        if (out !== (expected_state == 3))
            $fatal(1, "FAIL state=%0d out=%b time=%0t", expected_state, out, $time);
    endtask
    task automatic reset_machine;
        @(negedge clk);
        #1 areset = 1;
        expected_state = 0;
        #1 check_output();
        @(posedge clk);
        #1 check_output();
        #1 areset = 0;
        #1 check_output();
    endtask
    task automatic step(input bit value);
        @(negedge clk);
        in = value;
        #1 check_output();
        @(posedge clk);
        hits[expected_state][value] = hits[expected_state][value] + 1;
        expected_state = transition[expected_state][value];
        #1 check_output();
        // Multiple input mutations without a state clock must not affect out.
        in = ~value;
        #1 check_output();
        in = value;
        #1 check_output();
    endtask
    initial begin
        transition[0][0]=0; transition[0][1]=1;
        transition[1][0]=2; transition[1][1]=1;
        transition[2][0]=0; transition[2][1]=3;
        transition[3][0]=2; transition[3][1]=1;
        for(s=0;s<4;s=s+1)
            for(b=0;b<2;b=b+1) hits[s][b]=0;
        for(seq=0;seq<256;seq=seq+1) begin
            reset_machine();
            for(bit_index=0;bit_index<8;bit_index=bit_index+1)
                step((seq >> bit_index) & 1);
        end
        // Exercise asynchronous reset from each reachable state.
        for(s=0;s<4;s=s+1) begin
            reset_machine();
            if(s>=1) step(1);
            if(s>=2) step(0);
            if(s>=3) step(1);
            reset_machine();
        end
        for(s=0;s<4;s=s+1)
            for(b=0;b<2;b=b+1)
                if(hits[s][b]==0) $fatal(1,"FAIL uncovered transition");
        $display("PASS: 256 eight-bit sequences, all 8 transitions, reset from all states, Moore stability");
        $finish;
    end
endmodule
