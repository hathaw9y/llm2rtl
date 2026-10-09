`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg w = 0;
    wire z;
    integer model;
    integer hits [0:5][0:1];
    integer i, j, seq, bitpos, old_model;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    function integer transition(input integer s, input integer b);
        begin
            case (s)
                0: if (b == 0) transition=0; else transition=1;
                1: if (b == 0) transition=3; else transition=2;
                2: if (b == 0) transition=3; else transition=4;
                3: if (b == 0) transition=0; else transition=5;
                4: if (b == 0) transition=3; else transition=4;
                5: if (b == 0) transition=3; else transition=2;
                default: transition=-1;
            endcase
        end
    endfunction

    task check_output;
        reg expected;
        begin
            expected = (model == 4 || model == 5);
            if (z !== expected)
                $fatal(1, "Output mismatch at %0t: model=%0d z=%b expected=%b", $time, model,z,expected);
        end
    endtask

    task step(input reg r, input reg b);
        begin
            @(negedge clk);
            reset = r;
            w = b;
            #1;
            check_output(); // Input changes must not change Moore output.
            @(posedge clk);
            if (r) model=0;
            else begin
                hits[model][b]=hits[model][b]+1;
                model=transition(model,b);
            end
            #1;
            check_output();
        end
    endtask

    task reach(input integer target);
        begin
            step(1,0);
            case(target)
                0: begin end
                1: step(0,1);
                2: begin step(0,1); step(0,1); end
                3: begin step(0,1); step(0,0); end
                4: begin step(0,1); step(0,1); step(0,1); end
                5: begin step(0,1); step(0,0); step(0,1); end
            endcase
            if (model != target) $fatal(1,"Oracle reach error");
        end
    endtask

    initial begin
        for (i=0;i<6;i=i+1)
            for(j=0;j<2;j=j+1) hits[i][j]=0;
        // Original specification does not define power-up output.
        reset=1;
        @(posedge clk);
        model=0;
        #1;
        check_output();
        for(i=0;i<6;i=i+1) begin
            for(j=0;j<2;j=j+1) begin
                reach(i);
                step(0,j);
                reach(i);
                step(1,j); // Reset priority from every state, with both w values.
            end
        end
        // A reset pulse entirely between rising edges must not reset state E.
        reach(4);
        @(negedge clk);
        w=0;
        reset=1;
        #1; check_output();
        reset=0;
        #1; check_output();
        @(posedge clk);
        model=transition(model,0);
        #1; check_output();
        // Exhaustively replay every binary input string of length eight.
        for(seq=0;seq<256;seq=seq+1) begin
            step(1,0);
            for(bitpos=7;bitpos>=0;bitpos=bitpos-1)
                step(0,(seq >> bitpos) & 1);
        end
        for(i=0;i<6;i=i+1)
            for(j=0;j<2;j=j+1)
                if(hits[i][j]==0) $fatal(1,"Uncovered transition %0d/%0d",i,j);
        $display("PASS: FSM transitions, Moore timing, synchronous reset, and exhaustive 8-bit sequences");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
