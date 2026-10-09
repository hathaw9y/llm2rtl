`timescale 1ns/1ps
module tb_smollm2_dma_gemm_board_probe;
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
    smollm2_dma_gemm_board_probe dut (.*);
    // 6.666 ns period at the testbench's 1 ps time precision (~150 MHz).
    always #3.333 aclk = ~aclk;
    logic seq = 0;
    localparam logic [127:0] ONE = 128'h00000000000000000000000000003f80;
    logic prev_act_valid, prev_weight_valid;
    logic [3:0] prev_act_bank, prev_weight_bank;
    logic [255:0] prev_act_data, prev_weight_data;

    always @(posedge aclk) begin
        if (!aresetn) begin
            prev_act_valid <= 1'b0;
            prev_weight_valid <= 1'b0;
            prev_act_bank <= '0;
            prev_weight_bank <= '0;
            prev_act_data <= '0;
            prev_weight_data <= '0;
        end else begin
            if (dut.fabric.act_rsp_valid !== prev_act_valid ||
                dut.fabric.weight_rsp_valid !== prev_weight_valid)
                $fatal(1, "registered GEMM response valid misaligned");
            if (prev_act_valid &&
                (dut.fabric.act_rsp_bank !== prev_act_bank ||
                 dut.fabric.act_rsp_data !== prev_act_data))
                $fatal(1, "registered activation response payload misaligned");
            if (prev_weight_valid &&
                (dut.fabric.weight_rsp_bank !== prev_weight_bank ||
                 dut.fabric.weight_rsp_data !== prev_weight_data))
                $fatal(1, "registered weight response payload misaligned");
            prev_act_valid <= dut.fabric.compute_role_rsp_valid[3];
            prev_weight_valid <= dut.fabric.compute_role_rsp_valid[4];
            if (dut.fabric.compute_role_rsp_valid[3]) begin
                prev_act_bank <= dut.fabric.compute_role_rsp_bank[3];
                prev_act_data <= dut.fabric.compute_role_rsp_wide_data[3];
            end
            if (dut.fabric.compute_role_rsp_valid[4]) begin
                prev_weight_bank <= dut.fabric.compute_role_rsp_bank[4];
                prev_weight_data <= dut.fabric.compute_role_rsp_wide_data[4];
            end
        end
    end

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
        do @(posedge aclk); while (host_status[31] != seq || host_status[30]);
        #1; status = host_status;
        if (status[28]) $fatal(1, "host op error op=%0d status=%h", op, status);
    endtask
    task automatic write_record(input int index, input logic [127:0] value);
        logic [31:0] status;
        host_op(1, 0, index, value, status);
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
    task automatic service_load(input int addr, input int bytes);
        logic [3:0] tag;
        wait (m_axis_mm2s_cmd_tvalid);
        @(negedge aclk); m_axis_mm2s_cmd_tready = 1;
        @(posedge aclk);
        if (!m_axis_mm2s_cmd_tvalid ||
            m_axis_mm2s_cmd_tdata[63:32] != addr ||
            m_axis_mm2s_cmd_tdata[22:0] != bytes)
            $fatal(1, "unexpected DataMover command addr=%h btt=%0d",
                   m_axis_mm2s_cmd_tdata[63:32],m_axis_mm2s_cmd_tdata[22:0]);
        tag = m_axis_mm2s_cmd_tdata[67:64];
        #1; m_axis_mm2s_cmd_tready = 0;
        send_beat(ONE[63:0], 0);
        send_beat(ONE[127:64], bytes == 16);
        if (bytes == 32) begin
            send_beat(0, 0);
            send_beat(0, 1);
        end
        repeat (4) @(posedge aclk);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata = {4'h8, tag};
        s_axis_mm2s_sts_tkeep = 1;
        s_axis_mm2s_sts_tlast = 1;
        s_axis_mm2s_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid = 0;
    endtask
    initial begin
        logic [31:0] status;
        logic [127:0] gemm_record;
        repeat (4) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        gemm_record = (128'(16'h3234) << 112) |
                      (128'(1) << 31) | (128'(1) << 19) |
                      (128'(1) << 8) | 128'(1);
        write_record(0, {4'd1, 4'd0, 8'd0, 32'd0,
                         23'd16, 32'h1000, 25'd0});
        write_record(1, {4'd1, 4'd3, 8'd0, 32'd0,
                         23'd32, 32'h2000, 25'd0});
        write_record(2, {4'd4, 4'd0, 4'd3, 4'd2, 112'd0});
        write_record(3, gemm_record);
        write_record(4, '0);
        fork
            begin
                host_op(2, 0, 0, '0, status);
                wait (host_status[29]);
                host_op(3, 2, 0, ONE, status);
                host_op(4, 0, 0, '0, status);
                wait (host_status[27]);
                if (host_status[28]) $fatal(1, "dispatcher error at END");
                host_op(6, 0, 0, '0, status);
                if (status[15:0] != 1) $fatal(1, "GEMM write count=%0d", status[15:0]);
                host_op(5, 4, 0, '0, status);
                if (status[15:0] != 16'h3f80)
                    $fatal(1, "GEMM value=%h expected=3f80",status[15:0]);
                $display("PASS smollm2_dma_gemm_board_probe");
                $finish;
            end
            begin
                service_load('h1000, 16);
                service_load('h2000, 32);
            end
        join
    end
    initial begin
        #1000000;
        $fatal(1, "board probe timeout status=%h", host_status);
    end
endmodule
