`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 1;
    logic [7:0] in = 0;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut(.*);
    always #5 clk = ~clk;

    integer count = 0;
    integer checks = 0;
    logic initialized = 0;
    logic expected_done;
    logic [23:0] message;
    logic [23:0] expected_message;
    logic [7:0] wave [0:17];
    logic [31:0] random_r = 32'h12345678;

    // Independent byte-count oracle samples the input present BEFORE each edge.
    always @(posedge clk) begin
        if (reset) begin
            count = 0;
            expected_done = 0;
            initialized = 1;
        end else if (initialized) begin
            expected_done = 0;
            if (count == 0) begin
                if (in[3]) begin
                    message[23:16] = in;
                    count = 1;
                end
            end else if (count == 1) begin
                message[15:8] = in;
                count = 2;
            end else begin
                message[7:0] = in;
                expected_message = message;
                expected_done = 1;
                count = 0;
            end
        end
        #1;
        if (initialized) begin
            if (done !== expected_done)
                $fatal(1, "done mismatch at %0t expected %b got %b", $time, expected_done, done);
            if (expected_done && out_bytes !== expected_message)
                $fatal(1, "payload mismatch at %0t expected %h got %h", $time, expected_message, out_bytes);
            checks = checks + 1;
        end
    end

    task automatic send(input logic rst_value, input logic [7:0] byte_value);
        @(negedge clk);
        reset = rst_value;
        in = byte_value;
        @(posedge clk);
        #2;
    endtask

    initial begin
        #1;
        if (done !== 1'bx) $fatal(1, "done must initially be unknown before reset edge");
        wave[0]=8'h2c; wave[1]=8'h81; wave[2]=8'h09;
        wave[3]=8'h6b; wave[4]=8'h0d; wave[5]=8'h8d;
        wave[6]=8'h6d; wave[7]=8'h12; wave[8]=8'h01;
        wave[9]=8'h0d; wave[10]=8'h76; wave[11]=8'h3d;
        wave[12]=8'hed; wave[13]=8'h8c; wave[14]=8'hf9;
        wave[15]=8'hce; wave[16]=8'hc5; wave[17]=8'haa;
        // At t=15,25,...185 ns, the waveform inputs change on the edge.
        // NBA stimulus makes the prior byte the sampled byte, without a race.
        @(posedge clk); // t=5 synchronous reset
        for (integer i=0; i<18; i=i+1) begin
            @(posedge clk);
            reset <= 0;
            in <= wave[i];
            #2;
            case (i)
                3: if (done !== 1 || out_bytes !== 24'h2c8109) $fatal(1,"wave t45");
                6: if (done !== 1 || out_bytes !== 24'h6b0d8d) $fatal(1,"wave t75");
                9: if (done !== 1 || out_bytes !== 24'h6d1201) $fatal(1,"wave t105");
                12: if (done !== 1 || out_bytes !== 24'h0d763d) $fatal(1,"wave t135");
                15: if (done !== 1 || out_bytes !== 24'hed8cf9) $fatal(1,"wave t165");
                default: if (done !== 0) $fatal(1,"wave unexpected done");
            endcase
            @(negedge clk);
            #1;
            if (done !== expected_done) $fatal(1,"falling phase done mismatch");
            if (done && out_bytes !== expected_message) $fatal(1,"falling phase payload mismatch");
        end
        send(1, 8'hff);
        // Search rejects every byte whose bit 3 is zero.
        for (integer i=0; i<256; i=i+1)
            if ((i & 8) == 0) send(0, 8'(i));
        // Every possible first byte, boundary payload values, adjacent packets.
        for (integer i=0; i<256; i=i+1) begin
            if ((i & 8) != 0) begin
                send(0, 8'(i)); send(0, 8'h00); send(0, 8'hff);
            end
        end
        // Reset cancels a partial packet after either byte, and after done.
        send(1,0); send(0,8'h08); send(1,0); send(0,0);
        send(0,8'hff); send(0,8'hff); send(1,0); send(0,0);
        send(0,8'h08); send(0,0); send(0,0);
        // A reset pulse wholly between edges must not affect state or done.
        @(negedge clk); reset=1;
        #1; if (done !== 1) $fatal(1,"reset acted asynchronously");
        #1; reset=0; in=0;
        @(posedge clk); #2;
        for (integer i=0; i<1000; i=i+1) begin
            random_r = (random_r << 1) ^ (random_r[31] ? 32'h04c11db7 : 32'h0);
            send((i % 71)==0, random_r[7:0]);
        end
        send(1,0);
        $display("PASS independent stream oracle and original waveform: %0d edge checks", checks);
        $finish;
    end
    initial begin
        #30000;
        $fatal(1,"bounded timeout");
    end
endmodule
