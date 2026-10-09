`timescale 1ns/1ps
module tb_dma128_mm2s_adapter;
    logic clk = 0, rstn = 0, start = 0, abort_req = 0;
    logic [22:0] offset = 0;
    logic [127:0] data = 0;
    logic [15:0] keep = 0;
    logic valid = 0, last = 0, ready, done;
    logic en;
    logic [5:0] addr;
    logic [127:0] wrdata;
    logic [15:0] we;
    logic [7:0] memory [0:127];

    always #5 clk = ~clk;
    always @(posedge clk) if (rstn && en) begin
        for (integer i = 0; i < 16; i++) if (we[i]) begin
            memory[integer'(addr)*16+i] <= wrdata[i*8+:8];
        end
    end

    mm2s_adapter #(.MM2S_DATA_WIDTH(128), .BANK_DINA_WIDTH(128),
                   .BANK_ADDRA_WIDTH(6)) dut (
        .aclk(clk), .aresetn(rstn),
        .s_ctrl_mm2s_adapter_start(start),
        .s_ctrl_mm2s_adapter_done(done),
        .s_ctrl_mm2s_adapter_abort(abort_req),
        .s_ctrl_mm2s_adapter_offset(offset),
        .s_axis_mm2s_tdata(data), .s_axis_mm2s_tkeep(keep),
        .s_axis_mm2s_tvalid(valid), .s_axis_mm2s_tready(ready),
        .s_axis_mm2s_tlast(last),
        .bank_ena(en), .bank_addra(addr), .bank_dina(wrdata), .bank_wea(we)
    );

    initial begin
        for (integer i=0; i<128; i++) memory[i] = 8'hee;
        repeat (3) @(negedge clk);
        rstn=1; offset=23'd32; start=1;
        @(negedge clk);
        data=128'h0f0e0d0c0b0a09080706050403020100;
        keep='1; valid=1; last=0;
        do @(posedge clk); while (!ready);
        @(negedge clk);
        data=128'h1f1e1d1c1b1a19181716151413121110;
        keep=16'h001f; last=1;
        do @(posedge clk); while (!ready);
        @(negedge clk); valid=0;
        wait (done);
        repeat (2) @(negedge clk);
        for (integer i=0; i<16; i++)
            if (memory[32+i] !== 8'(i)) $fatal(1,"first beat byte %0d",i);
        for (integer i=0; i<5; i++)
            if (memory[48+i] !== 8'(16+i)) $fatal(1,"tail byte %0d",i);
        if (memory[53] !== 8'hee) $fatal(1,"tail mask");
        $display("PASS dma128 mm2s bank=128 full/tail/offset");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
