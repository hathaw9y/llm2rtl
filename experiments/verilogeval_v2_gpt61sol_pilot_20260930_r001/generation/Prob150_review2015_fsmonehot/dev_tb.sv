module dev_tb;
    logic d, done_counting, ack;
    logic [9:0] state;
    wire B3_next,S_next,S1_next,Count_next,Wait_next,done,counting,shift_ena;
    logic [9:0] expected_next;
    logic [2:0] expected_outputs;
    integer mask, inputs, source, target, checks;
    TopModule dut(.*);
    initial begin
        checks=0;
        for(mask=0; mask<1024; mask=mask+1) begin
            for(inputs=0; inputs<8; inputs=inputs+1) begin
                state=mask;
                {d,done_counting,ack}=inputs;
                expected_next=0;
                expected_outputs=0;
                for(source=0; source<10; source=source+1) begin
                    if(state[source]) begin
                        case(source)
                            0: target=d ? 1 : 0;
                            1: target=d ? 2 : 0;
                            2: target=d ? 2 : 3;
                            3: target=d ? 4 : 0;
                            4: target=5;
                            5: target=6;
                            6: target=7;
                            7: target=8;
                            8: target=done_counting ? 9 : 8;
                            9: target=ack ? 0 : 9;
                        endcase
                        expected_next[target]=1;
                        if(source>=4 && source<=7) expected_outputs[0]=1;
                        if(source==8) expected_outputs[1]=1;
                        if(source==9) expected_outputs[2]=1;
                    end
                end
                #1;
                if({B3_next,S_next,S1_next,Count_next,Wait_next} !==
                   {expected_next[7],expected_next[0],expected_next[1],expected_next[8],expected_next[9]})
                    $fatal(1,"Next-state mismatch mask=%0d inputs=%0d",mask,inputs);
                if({done,counting,shift_ena} !== expected_outputs)
                    $fatal(1,"Output mismatch mask=%0d inputs=%0d",mask,inputs);
                checks=checks+1;
            end
        end
        $display("PASS: %0d exhaustive combinational checks",checks);
        $finish;
    end
endmodule
