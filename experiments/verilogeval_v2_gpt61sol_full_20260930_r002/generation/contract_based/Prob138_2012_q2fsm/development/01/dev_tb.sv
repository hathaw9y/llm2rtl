`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg w = 0;
    wire z;
    integer model;
    integer sequence_id, bit_index, s, v;
    integer checks = 0;
    integer coverage [0:5][0:1];
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    // Original table expressed as integer rows; indices 0..5 denote A..F.
    function automatic integer next_model(input integer current, input bit value);
        if (value) begin
            case (current)
                0: next_model=1;
                1: next_model=2;
                2: next_model=4;
                3: next_model=5;
                4: next_model=4;
                5: next_model=2;
                default: $fatal(1,"Invalid oracle state");
            endcase
        end else begin
            case (current)
                0: next_model=0;
                1: next_model=3;
                2: next_model=3;
                3: next_model=0;
                4: next_model=3;
                5: next_model=3;
                default: $fatal(1,"Invalid oracle state");
            endcase
        end
    endfunction

    task automatic check_output;
        reg expected;
        begin
            expected = (model==4 || model==5);
            if (z !== expected)
                $fatal(1,"Output mismatch at %0t model=%0d expected=%b got=%b",$time,model,expected,z);
            checks = checks+1;
        end
    endtask

    task automatic step(input bit reset_value, input bit input_value);
        begin
            @(negedge clk);
            reset=reset_value;
            w=input_value;
            #1;
            check_output(); // Input/reset changes cannot change Moore state output.
            @(posedge clk);
            if (reset_value) model=0;
            else begin
                coverage[model][input_value]=coverage[model][input_value]+1;
                model=next_model(model,input_value);
            end
            #1;
            check_output();
        end
    endtask

    task automatic reach_state(input integer target);
        begin
            step(1,0);
            case (target)
                0: begin end
                1: step(0,1);
                2: begin step(0,1); step(0,1); end
                3: begin step(0,1); step(0,0); end
                4: begin step(0,1); step(0,1); step(0,1); end
                5: begin step(0,1); step(0,0); step(0,1); end
            endcase
            if (model != target) $fatal(1,"Oracle path error");
        end
    endtask

    initial begin
        for (s=0;s<6;s=s+1)
            for (v=0;v<2;v=v+1) coverage[s][v]=0;
        // No pre-reset expectation: the original specifies no power-up state.
        reset=1;
        @(posedge clk);
        model=0;
        #1; check_output();
        for (sequence_id=0;sequence_id<256;sequence_id=sequence_id+1) begin
            step(1,sequence_id[0]);
            for (bit_index=0;bit_index<8;bit_index=bit_index+1)
                step(0,sequence_id[bit_index]);
        end
        for (s=0;s<6;s=s+1) begin
            for (v=0;v<2;v=v+1) begin
                reach_state(s);
                step(1,v[0]); // Check synchronous assertion and priority in every state.
                step(1,!v[0]); // Held reset.
                step(0,1); // Check synchronous deassertion and normal restart.
            end
        end
        for (s=0;s<6;s=s+1)
            for (v=0;v<2;v=v+1)
                if (coverage[s][v]==0) $fatal(1,"Uncovered transition %0d/%0d",s,v);
        $display("PASS: %0d output checks, all 12 transitions, exhaustive length-8 inputs and reset cases",checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
