`timescale 1ns/1ps
module dev_tb;
    reg clk;
    reg x;
    reg [2:0] y;
    wire Y0, z;
    reg [2:0] next_zero [0:4];
    reg [2:0] next_one [0:4];
    reg expected_z [0:4];
    reg [2:0] expected_next;
    integer state_index, input_value, phase;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));

    initial begin
        #200;
        $fatal(1, "Timeout");
    end

    initial begin
        next_zero[0]=3'b000; next_one[0]=3'b001; expected_z[0]=0;
        next_zero[1]=3'b001; next_one[1]=3'b100; expected_z[1]=0;
        next_zero[2]=3'b010; next_one[2]=3'b001; expected_z[2]=0;
        next_zero[3]=3'b001; next_one[3]=3'b010; expected_z[3]=1;
        next_zero[4]=3'b011; next_one[4]=3'b100; expected_z[4]=1;
        clk=0; x=0; y=0;
        for (state_index=0; state_index<5; state_index=state_index+1) begin
            for (input_value=0; input_value<2; input_value=input_value+1) begin
                y=state_index;
                x=input_value;
                if (input_value == 0) expected_next=next_zero[state_index];
                else expected_next=next_one[state_index];
                // Check immediately after settling and across both clock edges.
                for (phase=0; phase<3; phase=phase+1) begin
                    #1;
                    if (Y0 !== expected_next[0] || z !== expected_z[state_index])
                        $fatal(1, "Mismatch state=%b x=%b clk=%b got=%b,%b expected=%b,%b",
                               y,x,clk,Y0,z,expected_next[0],expected_z[state_index]);
                    clk=~clk;
                end
            end
        end
        $display("PASS: all specified table entries checked independently of clock");
        $finish;
    end
endmodule
