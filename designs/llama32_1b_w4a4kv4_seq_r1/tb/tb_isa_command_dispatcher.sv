`timescale 1ns/1ps

module tb_isa_command_dispatcher;
    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic start = 1'b0;
    logic [10:0] command_count = 11'd0;
    logic busy;
    logic done;
    logic error;
    logic [7:0] error_code;
    logic [9:0] current_pc;
    logic cmd_mem_en;
    logic [10:0] cmd_mem_addr;
    logic [127:0] cmd_mem_rdata = 128'd0;
    logic dma_cmd_valid;
    logic dma_cmd_ready = 1'b0;
    logic [255:0] dma_cmd_data;
    logic dma_rsp_valid = 1'b0;
    logic dma_rsp_ready;
    logic dma_rsp_error = 1'b0;
    logic [15:0] dma_rsp_tag = 16'd0;
    logic gemm_cmd_valid;
    logic gemm_cmd_ready = 1'b0;
    logic [255:0] gemm_cmd_data;
    logic gemm_rsp_valid = 1'b0;
    logic gemm_rsp_ready;
    logic gemm_rsp_error = 1'b0;
    logic [15:0] gemm_rsp_tag = 16'd0;
    logic [11:0] bank_state;

    logic [127:0] command_mem [0:2047];
    integer failures = 0;
    integer fetch_count = 0;
    logic command_outstanding = 1'b0;

    isa_command_dispatcher dut (.*);

    always #2.5 aclk = ~aclk;

    always_ff @(posedge aclk) begin
        if (cmd_mem_en) begin
            cmd_mem_rdata <= command_mem[cmd_mem_addr];
            fetch_count <= fetch_count + 1;
            if (command_outstanding) begin
                $fatal(1, "next command fetched while prior command outstanding");
            end
        end
        if ((dma_cmd_valid && dma_cmd_ready) ||
            (gemm_cmd_valid && gemm_cmd_ready)) begin
            if (command_outstanding) begin
                $fatal(1, "more than one command outstanding");
            end
            command_outstanding <= 1'b1;
        end
        if ((dma_rsp_valid && dma_rsp_ready) ||
            (gemm_rsp_valid && gemm_rsp_ready)) begin
            command_outstanding <= 1'b0;
        end
        if (!aresetn) begin
            command_outstanding <= 1'b0;
        end
    end

    function automatic logic [255:0] make_command(
        input logic [7:0] opcode,
        input logic [7:0] flags,
        input logic [15:0] tag,
        input logic [7:0] src0,
        input logic [7:0] src1,
        input logic [7:0] dst,
        input logic [31:0] arg0,
        input logic [31:0] arg1,
        input logic [31:0] arg2
    );
        logic [255:0] value;
        begin
            value = 256'd0;
            value[7:0] = opcode;
            value[15:8] = flags;
            value[31:16] = tag;
            value[39:32] = src0;
            value[47:40] = src1;
            value[55:48] = dst;
            value[95:64] = arg0;
            value[127:96] = arg1;
            value[159:128] = arg2;
            make_command = value;
        end
    endfunction

    task automatic put_command(input integer pc, input logic [255:0] value);
        begin
            command_mem[2*pc] = value[127:0];
            command_mem[2*pc+1] = value[255:128];
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge aclk);
            aresetn = 1'b0;
            start = 1'b0;
            dma_cmd_ready = 1'b0;
            gemm_cmd_ready = 1'b0;
            dma_rsp_valid = 1'b0;
            gemm_rsp_valid = 1'b0;
            repeat (2) @(posedge aclk);
            @(negedge aclk);
            aresetn = 1'b1;
            @(posedge aclk);
            if (bank_state !== 12'd0 || done || error || busy) begin
                $error("reset did not restore idle/free state");
                failures = failures + 1;
            end
        end
    endtask

    task automatic launch(input logic [10:0] count);
        begin
            @(negedge aclk);
            command_count = count;
            start = 1'b1;
            @(negedge aclk);
            start = 1'b0;
        end
    endtask

    task automatic wait_dma_valid(input logic [15:0] expected_tag);
        integer timeout;
        begin
            @(negedge aclk);
            dma_cmd_ready = 1'b1;
            timeout = 0;
            while (!dma_cmd_valid && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            if (!dma_cmd_valid || dma_cmd_data[31:16] !== expected_tag) begin
                $error("DMA request missing/wrong tag expected=%0d", expected_tag);
                failures = failures + 1;
            end
        end
    endtask

    task automatic wait_gemm_valid(input logic [15:0] expected_tag);
        integer timeout;
        begin
            @(negedge aclk);
            gemm_cmd_ready = 1'b1;
            timeout = 0;
            while (!gemm_cmd_valid && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            if (!gemm_cmd_valid || gemm_cmd_data[31:16] !== expected_tag) begin
                $error("GEMM request missing/wrong tag expected=%0d", expected_tag);
                failures = failures + 1;
            end
        end
    endtask

    task automatic accept_dma;
        begin
            @(negedge aclk);
            dma_cmd_ready = 1'b1;
            @(posedge aclk);
            @(negedge aclk);
            dma_cmd_ready = 1'b0;
        end
    endtask

    task automatic accept_gemm;
        begin
            @(negedge aclk);
            gemm_cmd_ready = 1'b1;
            @(posedge aclk);
            @(negedge aclk);
            gemm_cmd_ready = 1'b0;
        end
    endtask

    task automatic respond_dma(input logic [15:0] tag, input logic rsp_error);
        begin
            repeat (2) @(posedge aclk);
            @(negedge aclk);
            dma_rsp_tag = tag;
            dma_rsp_error = rsp_error;
            dma_rsp_valid = 1'b1;
            do @(posedge aclk); while (!dma_rsp_ready);
            @(negedge aclk);
            dma_rsp_valid = 1'b0;
            dma_rsp_error = 1'b0;
        end
    endtask

    task automatic respond_gemm(input logic [15:0] tag, input logic rsp_error);
        begin
            repeat (2) @(posedge aclk);
            @(negedge aclk);
            gemm_rsp_tag = tag;
            gemm_rsp_error = rsp_error;
            gemm_rsp_valid = 1'b1;
            do @(posedge aclk); while (!gemm_rsp_ready);
            @(negedge aclk);
            gemm_rsp_valid = 1'b0;
            gemm_rsp_error = 1'b0;
        end
    endtask

    task automatic expect_error(input logic [7:0] expected_code);
        integer timeout;
        begin
            timeout = 0;
            while (!error && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            if (!error || error_code !== expected_code) begin
                $error("error mismatch expected=%02x actual=%02x", expected_code, error_code);
                failures = failures + 1;
            end
        end
    endtask

    task automatic expect_done;
        integer timeout;
        begin
            timeout = 0;
            while (!done && timeout < 100) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            if (!done) begin
                $error("timeout waiting for done");
                failures = failures + 1;
            end
        end
    endtask

    task automatic run_two_command_releasable(input logic [15:0] base_tag);
        begin
            put_command(0, make_command(8'h01, 8'h00, base_tag, 0, 0, 0,
                                        32'h1000, 0, 32'd64));
            put_command(1, make_command(8'h02, 8'h04, base_tag + 1, 0, 0, 0,
                                        32'h2000, 0, 32'd64));
            launch(2);
            wait_dma_valid(base_tag);
            accept_dma();
            respond_dma(base_tag, 1'b0);
            wait_dma_valid(base_tag + 1);
            accept_dma();
            respond_dma(base_tag + 1, 1'b0);
            expect_done();
            if (bank_state[2:0] !== 3'd0) begin
                $error("released DMA_STORE source did not become free");
                failures = failures + 1;
            end
        end
    endtask

    initial begin : test_sequence
        logic [255:0] held_payload;
        integer prior_fetches;

        reset_dut();

        // Normal LOAD, LOAD, GEMM, STORE. First request is deliberately stalled.
        put_command(0, make_command(8'h01, 0, 16'd1, 0, 0, 0, 32'h1000, 0, 64));
        put_command(1, make_command(8'h01, 0, 16'd2, 0, 0, 1, 32'h2000, 0, 64));
        put_command(2, make_command(8'h10, 0, 16'd3, 0, 1, 2, 2, 3, 4));
        put_command(3, make_command(8'h02, 8'h04, 16'd4, 2, 0, 0, 32'h3000, 0, 64));
        launch(4);
        @(negedge aclk);
        dma_cmd_ready = 1'b1;
        wait (dma_cmd_valid);
        held_payload = dma_cmd_data;
        dma_cmd_ready = 1'b0;
        repeat (3) begin
            @(posedge aclk);
            if (!dma_cmd_valid || dma_cmd_data !== held_payload) begin
                $error("DMA payload changed under backpressure");
                failures = failures + 1;
            end
        end
        accept_dma(); respond_dma(16'd1, 1'b0);
        wait_dma_valid(16'd2); accept_dma(); respond_dma(16'd2, 1'b0);
        wait_gemm_valid(16'd3); accept_gemm(); respond_gemm(16'd3, 1'b0);
        wait_dma_valid(16'd4); accept_dma(); respond_dma(16'd4, 1'b0);
        expect_done();
        if (current_pc !== 10'd3 || bank_state !== {3'd0,3'd0,3'd2,3'd2}) begin
            $error("normal final state mismatch pc=%0d banks=%03x", current_pc, bank_state);
            failures = failures + 1;
        end

        // Invalid program lengths.
        reset_dut(); launch(0); expect_error(8'h01);
        reset_dut(); launch(11'd1025); expect_error(8'h01);

        // Unknown opcode and illegal bank ID.
        reset_dut();
        put_command(0, make_command(8'h7f, 0, 16'd10, 0, 0, 0, 0, 0, 1));
        launch(1); expect_error(8'h02);
        reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd11, 0, 0, 4, 0, 0, 1));
        launch(1); expect_error(8'h03);

        // A blocked current command must not fetch the following command.
        reset_dut();
        put_command(0, make_command(8'h10, 0, 16'd12, 0, 1, 2, 1, 1, 1));
        put_command(1, make_command(8'h01, 0, 16'd13, 0, 0, 0, 0, 0, 1));
        prior_fetches = fetch_count;
        gemm_cmd_ready = 1'b1;
        launch(2);
        repeat (20) @(posedge aclk);
        if (current_pc !== 0 || gemm_cmd_valid || dma_cmd_valid ||
            (fetch_count - prior_fetches) !== 2) begin
            $error("blocked PC looked ahead or issued unexpectedly");
            failures = failures + 1;
        end

        // Executor error faults destination and prevents later fetch/issue.
        reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd20, 0, 0, 0, 0, 0, 64));
        put_command(1, make_command(8'h01, 0, 16'd21, 0, 0, 1, 0, 0, 64));
        launch(2); wait_dma_valid(16'd20); accept_dma(); respond_dma(16'd20, 1'b1);
        expect_error(8'h05);
        if (bank_state[2:0] !== 3'd5 || current_pc !== 0) begin
            $error("executor error committed destination or advanced PC");
            failures = failures + 1;
        end
        @(negedge aclk); start = 1'b1; command_count = 1;
        @(negedge aclk); start = 1'b0;
        if (error_code !== 8'h07) begin
            $error("faulted bank did not require reset"); failures = failures + 1;
        end

        // Completion tag mismatch faults destination.
        reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd30, 0, 0, 0, 0, 0, 64));
        launch(1); wait_dma_valid(16'd30); accept_dma(); respond_dma(16'd31, 1'b0);
        expect_error(8'h06);
        if (bank_state[2:0] !== 3'd5) begin
            $error("tag mismatch did not fault destination"); failures = failures + 1;
        end

        // Reset during fetch, issue/backpressure, and completion wait.
        reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd40, 0, 0, 0, 0, 0, 64));
        launch(1); repeat (1) @(posedge aclk); reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd41, 0, 0, 0, 0, 0, 64));
        launch(1); wait_dma_valid(16'd41); reset_dut();
        put_command(0, make_command(8'h01, 0, 16'd42, 0, 0, 0, 0, 0, 64));
        launch(1); wait_dma_valid(16'd42); accept_dma(); repeat (2) @(posedge aclk); reset_dut();

        // Repeated successful programs without reset when all banks are released.
        dma_cmd_ready = 1'b0;
        run_two_command_releasable(16'd50);
        run_two_command_releasable(16'd60);

        if (failures == 0) begin
            $display("PASS: isa_command_dispatcher strict single-PC verification");
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d dispatcher checks failed", failures);
        end
    end

    initial begin
        #20000;
        $fatal(1, "FAIL: global timeout");
    end

endmodule
