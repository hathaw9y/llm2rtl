`timescale 1ns/1ps

module tb_isa_command_dispatcher;
    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic start = 1'b0;
    logic [10:0] command_count = 11'd0;
    logic busy, done, error;
    logic [7:0] error_code;
    logic [9:0] current_pc;
    logic cmd_mem_en;
    logic [10:0] cmd_mem_addr;
    logic [127:0] cmd_mem_rdata = 128'd0;
    logic dma_cmd_valid, dma_cmd_ready = 1'b0;
    logic [255:0] dma_cmd_data;
    logic dma_rsp_valid = 1'b0, dma_rsp_ready, dma_rsp_error = 1'b0;
    logic [15:0] dma_rsp_tag = 16'd0;
    logic gemm_cmd_valid, gemm_cmd_ready = 1'b0;
    logic [255:0] gemm_cmd_data;
    logic gemm_rsp_valid = 1'b0, gemm_rsp_ready, gemm_rsp_error = 1'b0;
    logic [15:0] gemm_rsp_tag = 16'd0;
    logic [11:0] bank_state;

    logic [127:0] command_mem [0:2047];
    logic command_outstanding = 1'b0;
    integer fetch_count = 0;
    integer failures = 0;

    isa_command_dispatcher dut (.*);
    always #2.5 aclk = ~aclk;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            command_outstanding <= 1'b0;
        end else begin
            if (cmd_mem_en) begin
                cmd_mem_rdata <= command_mem[cmd_mem_addr];
                fetch_count <= fetch_count + 1;
                if (command_outstanding) begin
                    $fatal(1, "fetch occurred while command outstanding");
                end
                if ((dut.state_r == 3'd1 && cmd_mem_addr != {current_pc,1'b0}) ||
                    (dut.state_r == 3'd2 && cmd_mem_addr != ({current_pc,1'b0} + 11'd1))) begin
                    $fatal(1, "wrong BRAM address pc=%0d addr=%0d", current_pc, cmd_mem_addr);
                end
            end
            if ((dma_cmd_valid && dma_cmd_ready) ||
                (gemm_cmd_valid && gemm_cmd_ready)) begin
                if (command_outstanding) $fatal(1, "second outstanding command");
                command_outstanding <= 1'b1;
            end
            if ((dma_rsp_valid && dma_rsp_ready) ||
                (gemm_rsp_valid && gemm_rsp_ready)) begin
                command_outstanding <= 1'b0;
            end
        end
    end

    function automatic logic [255:0] mk(
        input logic [7:0] opcode,
        input logic [7:0] flags,
        input logic [15:0] tag,
        input logic [7:0] src0,
        input logic [7:0] src1,
        input logic [7:0] dst,
        input logic [31:0] seed
    );
        logic [255:0] v;
        begin
            v = 256'd0;
            v[7:0] = opcode;
            v[15:8] = flags;
            v[31:16] = tag;
            v[39:32] = src0;
            v[47:40] = src1;
            v[55:48] = dst;
            v[63:56] = seed[7:0] ^ 8'h5a;
            v[95:64] = seed + 32'h00000001;
            v[127:96] = seed ^ 32'ha5a55a5a;
            v[159:128] = seed + 32'h00000003;
            v[191:160] = seed ^ 32'h01234567;
            v[223:192] = seed + 32'h89abcdef;
            v[255:224] = seed ^ 32'hfedcba98;
            mk = v;
        end
    endfunction

    task automatic put_cmd(input integer pc, input logic [255:0] v);
        begin
            command_mem[2*pc] = v[127:0];
            command_mem[2*pc+1] = v[255:128];
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
            if (busy || done || error || bank_state !== 12'd0 ||
                dma_cmd_valid || gemm_cmd_valid || cmd_mem_en) begin
                $error("reset state mismatch");
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

    task automatic wait_state(input logic [2:0] wanted);
        integer t;
        begin
            t = 0;
            while ((dut.state_r !== wanted) && (t < 200)) begin
                @(posedge aclk); t = t + 1;
            end
            if (dut.state_r !== wanted) begin
                $error("timeout waiting state %0d", wanted); failures = failures + 1;
            end
        end
    endtask

    task automatic dma_accept_exact(
        input logic [255:0] expected,
        input integer stall_cycles
    );
        integer t;
        begin
            dma_cmd_ready = 1'b0;
            t = 0;
            while (!dma_cmd_valid && t < 200) begin
                @(posedge aclk); t = t + 1;
            end
            if (!dma_cmd_valid || dma_cmd_data !== expected) begin
                $error("DMA full payload mismatch tag=%0d", expected[31:16]);
                failures = failures + 1;
            end
            repeat (stall_cycles) begin
                @(posedge aclk);
                if (!dma_cmd_valid || dma_cmd_data !== expected) begin
                    $error("DMA valid/payload unstable under backpressure");
                    failures = failures + 1;
                end
            end
            @(negedge aclk); dma_cmd_ready = 1'b1;
            @(posedge aclk);
            @(negedge aclk); dma_cmd_ready = 1'b0;
        end
    endtask

    task automatic gemm_accept_exact(
        input logic [255:0] expected,
        input integer stall_cycles
    );
        integer t;
        begin
            gemm_cmd_ready = 1'b0;
            t = 0;
            while (!gemm_cmd_valid && t < 200) begin
                @(posedge aclk); t = t + 1;
            end
            if (!gemm_cmd_valid || gemm_cmd_data !== expected) begin
                $error("GEMM full payload mismatch tag=%0d", expected[31:16]);
                failures = failures + 1;
            end
            repeat (stall_cycles) begin
                @(posedge aclk);
                if (!gemm_cmd_valid || gemm_cmd_data !== expected) begin
                    $error("GEMM valid/payload unstable under backpressure");
                    failures = failures + 1;
                end
            end
            @(negedge aclk); gemm_cmd_ready = 1'b1;
            @(posedge aclk);
            @(negedge aclk); gemm_cmd_ready = 1'b0;
        end
    endtask

    task automatic dma_respond(
        input logic [15:0] response_tag,
        input logic response_error
    );
        begin
            @(negedge aclk);
            dma_rsp_tag = response_tag;
            dma_rsp_error = response_error;
            dma_rsp_valid = 1'b1;
            do @(posedge aclk); while (!dma_rsp_ready);
            @(negedge aclk);
            dma_rsp_valid = 1'b0;
            dma_rsp_error = 1'b0;
        end
    endtask

    task automatic gemm_respond(
        input logic [15:0] response_tag,
        input logic response_error
    );
        begin
            @(negedge aclk);
            gemm_rsp_tag = response_tag;
            gemm_rsp_error = response_error;
            gemm_rsp_valid = 1'b1;
            do @(posedge aclk); while (!gemm_rsp_ready);
            @(negedge aclk);
            gemm_rsp_valid = 1'b0;
            gemm_rsp_error = 1'b0;
        end
    endtask

    task automatic run_dma(
        input logic [255:0] expected,
        input logic response_error,
        input logic [15:0] response_tag,
        input integer stalls
    );
        begin
            dma_accept_exact(expected, stalls);
            dma_respond(response_tag, response_error);
        end
    endtask

    task automatic run_gemm(
        input logic [255:0] expected,
        input logic response_error,
        input logic [15:0] response_tag,
        input integer stalls
    );
        begin
            gemm_accept_exact(expected, stalls);
            gemm_respond(response_tag, response_error);
        end
    endtask

    task automatic expect_done;
        integer t;
        begin
            t = 0;
            while (!done && t < 200) begin @(posedge aclk); t = t + 1; end
            if (!done) begin $error("done timeout"); failures = failures + 1; end
        end
    endtask

    task automatic expect_error(input logic [7:0] code);
        integer t;
        begin
            t = 0;
            while (!error && t < 200) begin @(posedge aclk); t = t + 1; end
            if (!error || error_code !== code) begin
                $error("error mismatch expected=%02x actual=%02x", code, error_code);
                failures = failures + 1;
            end
        end
    endtask

    task automatic run_releasable_program(input logic [15:0] base_tag);
        logic [255:0] c0, c1;
        begin
            c0 = mk(8'h01, 0, base_tag, 0, 0, 0, 32'h7000 + base_tag);
            c1 = mk(8'h02, 8'h04, base_tag+1, 0, 0, 0, 32'h7100 + base_tag);
            put_cmd(0, c0); put_cmd(1, c1);
            launch(2);
            run_dma(c0, 0, base_tag, 0);
            run_dma(c1, 0, base_tag+1, 0);
            expect_done();
            if (bank_state[2:0] !== 3'd0) begin
                $error("release STORE did not free source"); failures = failures + 1;
            end
        end
    endtask

    initial begin : tests
        logic [255:0] c0, c1, c2, c3;
        integer i;
        integer before_fetch;

        reset_dut();

        // Strict in-order normal path; consumers hold ready low until valid.
        c0 = mk(8'h01, 0, 1, 0, 0, 0, 32'h10000100);
        c1 = mk(8'h01, 0, 2, 0, 0, 1, 32'h20000200);
        c2 = mk(8'h10, 0, 3, 0, 1, 2, 32'h30000300);
        c3 = mk(8'h02, 8'h04, 4, 2, 0, 0, 32'h40000400);
        put_cmd(0,c0); put_cmd(1,c1); put_cmd(2,c2); put_cmd(3,c3);
        launch(4);
        run_dma(c0,0,1,3);
        run_dma(c1,0,2,1);
        run_gemm(c2,0,3,3);
        run_dma(c3,0,4,1);
        expect_done();
        if (current_pc !== 10'd3 || bank_state !== {3'd0,3'd0,3'd2,3'd2}) begin
            $error("normal path final state mismatch"); failures = failures + 1;
        end

        // Count bounds.
        reset_dut(); launch(0); expect_error(8'h01);
        reset_dut(); launch(11'd1025); expect_error(8'h01);

        // Unknown opcode and invalid bank.
        reset_dut(); c0=mk(8'h7f,0,10,0,0,0,32'h10); put_cmd(0,c0);
        launch(1); expect_error(8'h02);
        reset_dut(); c0=mk(8'h01,0,11,0,0,4,32'h11); put_cmd(0,c0);
        launch(1); expect_error(8'h03);

        // Blocked current PC cannot look ahead.
        reset_dut();
        c0=mk(8'h10,0,12,0,1,2,32'h12);
        c1=mk(8'h01,0,13,0,0,0,32'h13);
        put_cmd(0,c0); put_cmd(1,c1); before_fetch=fetch_count;
        launch(2); repeat(20) @(posedge aclk);
        if (current_pc !== 0 || dma_cmd_valid || gemm_cmd_valid ||
            fetch_count-before_fetch !== 2) begin
            $error("blocked command looked ahead"); failures = failures + 1;
        end

        // dst/source alias is an immediate operand error.
        reset_dut();
        c0=mk(8'h01,0,20,0,0,0,32'h20);
        c1=mk(8'h10,0,21,0,0,0,32'h21);
        put_cmd(0,c0); put_cmd(1,c1); launch(2);
        run_dma(c0,0,20,0); expect_error(8'h04);
        if (gemm_cmd_valid || current_pc !== 1 || bank_state[2:0] !== 3'd2) begin
            $error("GEMM dst/source alias was issued or mutated bank"); failures = failures + 1;
        end

        // Equal sources are legal with distinct dst; GEMM backpressure and releases.
        reset_dut();
        c0=mk(8'h01,0,30,0,0,0,32'h30);
        c1=mk(8'h10,8'h03,31,0,0,1,32'h31);
        put_cmd(0,c0); put_cmd(1,c1); launch(2);
        run_dma(c0,0,30,0); run_gemm(c1,0,31,5); expect_done();
        if (bank_state[2:0] !== 3'd0 || bank_state[5:3] !== 3'd2) begin
            $error("equal-source GEMM or release flags failed"); failures = failures + 1;
        end

        // STORE error rolls its source back to READY.
        reset_dut();
        c0=mk(8'h01,0,40,0,0,0,32'h40);
        c1=mk(8'h02,8'h04,41,0,0,0,32'h41);
        put_cmd(0,c0); put_cmd(1,c1); launch(2);
        run_dma(c0,0,40,0); run_dma(c1,1,41,0); expect_error(8'h05);
        if (bank_state[2:0] !== 3'd2 || current_pc !== 1) begin
            $error("STORE error did not restore source READY"); failures = failures + 1;
        end

        // GEMM error keeps sources READY and faults, never readies, destination.
        reset_dut();
        c0=mk(8'h01,0,50,0,0,0,32'h50);
        c1=mk(8'h01,0,51,0,0,1,32'h51);
        c2=mk(8'h10,8'h03,52,0,1,2,32'h52);
        c3=mk(8'h01,0,53,0,0,3,32'h53);
        put_cmd(0,c0);put_cmd(1,c1);put_cmd(2,c2);put_cmd(3,c3);launch(4);
        run_dma(c0,0,50,0);run_dma(c1,0,51,0);run_gemm(c2,1,52,2);
        expect_error(8'h05);
        if (bank_state[2:0]!==3'd2 || bank_state[5:3]!==3'd2 ||
            bank_state[8:6]!==3'd5 || current_pc!==2) begin
            $error("GEMM error rollback/fault mismatch"); failures=failures+1;
        end

        // Completion tag mismatch.
        reset_dut(); c0=mk(8'h01,0,60,0,0,0,32'h60);put_cmd(0,c0);launch(1);
        run_dma(c0,0,61,0);expect_error(8'h06);
        if(bank_state[2:0]!==3'd5)begin $error("tag mismatch did not fault dst");failures=failures+1;end

        // Reset in FETCH_LO, FETCH_HI, CHECK_READY, ISSUE, WAIT_COMPLETION.
        reset_dut(); c0=mk(8'h01,0,70,0,0,0,32'h70);put_cmd(0,c0);launch(1);
        wait_state(3'd1); reset_dut();
        c0=mk(8'h01,0,71,0,0,0,32'h71);put_cmd(0,c0);launch(1);
        wait_state(3'd2); reset_dut();
        c0=mk(8'h10,0,72,0,1,2,32'h72);put_cmd(0,c0);launch(1);
        wait_state(3'd3); reset_dut();
        c0=mk(8'h01,0,73,0,0,0,32'h73);put_cmd(0,c0);launch(1);
        wait_state(3'd4); reset_dut();
        c0=mk(8'h01,0,74,0,0,0,32'h74);put_cmd(0,c0);launch(1);
        dma_accept_exact(c0,0); wait_state(3'd5); reset_dut();
        repeat(3) @(posedge aclk);
        if (dma_cmd_valid || gemm_cmd_valid || cmd_mem_en || bank_state!==12'd0) begin
            $error("stale activity after reset"); failures=failures+1;
        end

        // Repeated successful program without reset after all bank release.
        run_releasable_program(16'd80);
        run_releasable_program(16'd90);

        // Maximum legal command_count executes through PC 1023 and BRAM word 2047.
        reset_dut();
        for (i=0;i<512;i=i+1) begin
            put_cmd(2*i, mk(8'h01,0,16'(2*i),0,0,0,32'h10000+i));
            put_cmd(2*i+1, mk(8'h02,8'h04,16'(2*i+1),0,0,0,32'h20000+i));
        end
        launch(11'd1024);
        for (i=0;i<1024;i=i+1) begin
            if ((i & 1)==0)
                c0=mk(8'h01,0,16'(i),0,0,0,32'h10000+(i/2));
            else
                c0=mk(8'h02,8'h04,16'(i),0,0,0,32'h20000+(i/2));
            run_dma(c0,0,16'(i),0);
        end
        expect_done();
        if(current_pc!==10'd1023 || bank_state[2:0]!==3'd0)begin
            $error("1024-command boundary failed pc=%0d",current_pc);failures=failures+1;
        end

        if (failures == 0) begin
            $display("PASS: isa_command_dispatcher r2 strict ready-valid verification");
            $finish;
        end else begin
            $fatal(1,"FAIL: %0d r2 checks failed",failures);
        end
    end

    initial begin
        #2000000;
        $fatal(1,"FAIL: global timeout");
    end
endmodule
