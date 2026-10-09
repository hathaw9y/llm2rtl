module dev_tb;
    logic in;
    logic [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    logic [9:0] expected_next;
    logic expected_out1, expected_out2;
    integer destination_zero [0:9];
    integer destination_one [0:9];
    integer mask, input_value, source, destination, checks;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out1(out1), .out2(out2));
    initial begin
        destination_zero[0]=0; destination_zero[1]=0;
        destination_zero[2]=0; destination_zero[3]=0;
        destination_zero[4]=0; destination_zero[5]=8;
        destination_zero[6]=9; destination_zero[7]=0;
        destination_zero[8]=0; destination_zero[9]=0;
        destination_one[0]=1; destination_one[1]=2;
        destination_one[2]=3; destination_one[3]=4;
        destination_one[4]=5; destination_one[5]=6;
        destination_one[6]=7; destination_one[7]=7;
        destination_one[8]=1; destination_one[9]=1;
        checks=0;
        for (mask=0; mask<1024; mask=mask+1) begin
            for (input_value=0; input_value<2; input_value=input_value+1) begin
                state=10'(mask);
                in=1'(input_value);
                expected_next='0;
                expected_out1=1'b0;
                expected_out2=1'b0;
                for (source=0; source<10; source=source+1) begin
                    if ((mask & (1 << source)) != 0) begin
                        if (input_value==0) destination=destination_zero[source];
                        else destination=destination_one[source];
                        expected_next[destination]=1'b1;
                        if (source==8 || source==9) expected_out1=1'b1;
                        if (source==7 || source==9) expected_out2=1'b1;
                    end
                end
                #1;
                if ({next_state,out1,out2} !== {expected_next,expected_out1,expected_out2})
                    $fatal(1,"FAIL state=%b in=%b actual=%b expected=%b",state,in,{next_state,out1,out2},{expected_next,expected_out1,expected_out2});
                checks=checks+1;
            end
        end
        $display("PASS: %0d exhaustive binary cases",checks);
        $finish;
    end
    initial begin
        #3000;
        $fatal(1,"FAIL: testbench timeout");
    end
endmodule
