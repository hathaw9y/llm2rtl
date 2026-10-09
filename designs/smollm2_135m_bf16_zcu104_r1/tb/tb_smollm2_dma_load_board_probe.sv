`timescale 1ns/1ps
module tb_smollm2_dma_load_board_probe;
    logic aclk = 0, aresetn = 0;
    logic [31:0] host_data0 = 0, host_data1 = 0;
    logic [31:0] host_data2 = 0, host_data3 = 0;
    logic [31:0] host_control = 0, host_status;
    logic [71:0] m_axis_mm2s_cmd_tdata;
    logic m_axis_mm2s_cmd_tvalid, m_axis_mm2s_cmd_tready = 0;
    logic [63:0] s_axis_mm2s_tdata = 0;
    logic [7:0] s_axis_mm2s_tkeep = 0;
    logic s_axis_mm2s_tvalid = 0, s_axis_mm2s_tready;
    logic s_axis_mm2s_tlast = 0;
    logic [7:0] s_axis_mm2s_sts_tdata = 0;
    logic s_axis_mm2s_sts_tkeep = 0, s_axis_mm2s_sts_tvalid = 0;
    logic s_axis_mm2s_sts_tready, s_axis_mm2s_sts_tlast = 0;
    logic datamover_mm2s_err = 0;
    smollm2_dma_load_board_probe dut (.*);
    always #2.5 aclk = ~aclk;
    logic seq = 0;
    localparam logic [127:0] ACT = 128'h3f803f003e803e003e403e003dc03d80;
    localparam logic [127:0] WGT = 128'hbca0bc80bc60bc40bc20bc00bba0bb80;

    task automatic host_op(input int op, input int bank, input int addr,
                           input logic [127:0] payload,
                           output logic [31:0] status);
        @(negedge aclk);
        host_data0 = payload[31:0];
        host_data1 = payload[63:32];
        host_data2 = payload[95:64];
        host_data3 = payload[127:96];
        seq = !seq;
        host_control = {seq, 3'(op), 4'(bank), 8'd0, 16'(addr)};
        do @(posedge aclk); while (host_status[31] != seq ||
                                   host_status[30]);
        #1; status = host_status;
        if (status[28]) $fatal(1, "host op error op=%0d status=%h", op, status);
    endtask
    task automatic write_record(input int index, input logic [127:0] record);
        logic [31:0] status;
        host_op(1, 0, index, record, status);
    endtask
    task automatic send_beat(input logic [63:0] data, input logic last);
        @(negedge aclk);
        s_axis_mm2s_tdata = data;
        s_axis_mm2s_tkeep = 8'hff;
        s_axis_mm2s_tlast = last;
        s_axis_mm2s_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_tready);
        #1; s_axis_mm2s_tvalid = 0;
    endtask
    task automatic service_load(input int addr, input logic [127:0] value);
        logic [3:0] tag;
        wait (m_axis_mm2s_cmd_tvalid);
        @(negedge aclk); m_axis_mm2s_cmd_tready = 1;
        @(posedge aclk);
        if (!m_axis_mm2s_cmd_tvalid ||
            m_axis_mm2s_cmd_tdata[63:32] != addr ||
            m_axis_mm2s_cmd_tdata[22:0] != 16)
            $fatal(1, "unexpected DataMover command");
        tag = m_axis_mm2s_cmd_tdata[67:64];
        #1; m_axis_mm2s_cmd_tready = 0;
        send_beat(value[63:0], 0);
        send_beat(value[127:64], 1);
        repeat (4) @(posedge aclk);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata = {4'h8, tag};
        s_axis_mm2s_sts_tkeep = 1;
        s_axis_mm2s_sts_tlast = 1;
        s_axis_mm2s_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid = 0;
    endtask
    task automatic check_bank(input int bank, input logic [127:0] expected);
        logic [31:0] status;
        for (int i = 0; i < 8; i++) begin
            host_op(3, bank, i, '0, status);
            if (status[15:0] !== expected[16*i +: 16])
                $fatal(1, "probe bank=%0d index=%0d got=%h expected=%h",
                       bank, i, status[15:0], expected[16*i +: 16]);
        end
    endtask
    initial begin
        logic [31:0] status;
        repeat (4) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        write_record(0, {4'd1, 4'd0, 8'd0, 32'd0,
                         23'd16, 32'h1000, 25'd0});
        write_record(1, {4'd1, 4'd3, 8'd0, 32'd0,
                         23'd16, 32'h2000, 25'd0});
        write_record(2, {4'd4, 4'd0, 4'd3, 4'd2, 112'd0});
        write_record(3, {4'd11, 124'd0});
        write_record(4, '0);
        fork
            begin
                host_op(2, 0, 0, '0, status);
                wait (host_status[29]);
                check_bank(0, ACT);
                check_bank(3, WGT);
                host_op(4, 0, 0, '0, status);
                wait (host_status[27]);
                if (host_status[28]) $fatal(1, "dispatcher error at END");
                $display("PASS smollm2_dma_load_board_probe");
                $finish;
            end
            begin
                service_load('h1000, ACT);
                service_load('h2000, WGT);
            end
        join
    end
    initial begin
        #200000;
        $fatal(1, "board probe simulation timeout status=%h", host_status);
    end
endmodule
