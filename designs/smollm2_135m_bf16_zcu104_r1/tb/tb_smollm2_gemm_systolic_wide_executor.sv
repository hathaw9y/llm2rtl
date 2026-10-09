`timescale 1ns/1ps

module tb_smollm2_gemm_systolic_wide_executor;
    logic aclk = 0;
    always #5 aclk = ~aclk;
    logic aresetn = 0;
    logic cmd_valid = 0, cmd_ready;
    logic [3:0] cmd_opcode = 3;
    logic [2:0][3:0] cmd_bank = '{4'd4, 4'd3, 4'd2};
    logic [111:0] cmd_payload = 0;
    logic done_valid, done_ready = 0;
    logic [3:0] done_tag;
    logic [1:0] done_bank_count;
    logic [2:0][3:0] done_bank;
    logic done_error;
    logic act_read_valid, act_read_ready = 1;
    logic [3:0] act_read_bank;
    logic [15:0] act_read_addr;
    logic act_rsp_valid;
    logic [3:0] act_rsp_bank;
    logic [255:0] act_rsp_data;
    logic weight_read_valid, weight_read_ready = 1;
    logic [3:0] weight_read_bank;
    logic [15:0] weight_read_addr;
    logic weight_rsp_valid;
    logic [3:0] weight_rsp_bank;
    logic [255:0] weight_rsp_data;
    logic dst_write_valid, dst_write_ready = 1;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    logic [127:0] act_mem[0:2303], weight_mem[0:13823], dst_mem[0:6143];
    logic [15:0] random_act[0:26], random_weight[0:44], random_expected[0:9];
    logic [15:0] model_prefill_act[0:18431], model_decode_act[0:575];
    logic [15:0] model_weight[0:2303];
    logic [15:0] model_prefill_expected[0:7], model_decode_expected[0:3];
    logic [15:0] model_prefill_torch[0:7], model_decode_torch[0:3];
    logic [15:0] model16_weight[0:9215];
    logic [15:0] model16_prefill_exact[0:31], model16_decode_exact[0:15];
    logic [15:0] model16_prefill_torch[0:31], model16_decode_torch[0:15];
    logic [15:0] model16_prefill32_exact[0:511], model16_prefill32_torch[0:511];
    logic [2:0] av, wv;
    logic [2:0][255:0] ad, wd;
    int write_count = 0;
    longint unsigned cycle_count = 0, accept_cycle = 0, last_command_cycles = 0;
    logic done_seen = 0;

    smollm2_gemm_systolic_wide_executor dut (.*);
    assign act_rsp_valid = av[2];
    assign weight_rsp_valid = wv[2];
    assign act_rsp_bank = 2;
    assign weight_rsp_bank = 3;
    assign act_rsp_data = ad[2];
    assign weight_rsp_data = wd[2];

    always @(posedge aclk) begin
        cycle_count <= cycle_count + 1;
        if (cmd_valid && cmd_ready) accept_cycle <= cycle_count;
        if (done_valid && !done_seen)
            last_command_cycles <= cycle_count - accept_cycle;
        done_seen <= done_valid;
        if (!aresetn) begin
            av <= 0; wv <= 0; ad <= '0; wd <= '0;
        end else begin
            av <= {av[1:0], act_read_valid && act_read_ready};
            wv <= {wv[1:0], weight_read_valid && weight_read_ready};
            ad[2] <= ad[1]; ad[1] <= ad[0];
            wd[2] <= wd[1]; wd[1] <= wd[0];
            if (act_read_valid && act_read_ready) begin
                if (act_read_bank != 2 || act_read_addr[0] || act_read_addr + 17'd1 >= 2304)
                    $fatal(1, "bad activation address or bank");
                ad[0] <= {act_mem[act_read_addr+1], act_mem[act_read_addr]};
            end
            if (weight_read_valid && weight_read_ready) begin
                if (weight_read_bank != 3 || weight_read_addr[0] || weight_read_addr + 17'd1 >= 13824)
                    $fatal(1, "bad weight address or bank");
                wd[0] <= {weight_mem[weight_read_addr+1], weight_mem[weight_read_addr]};
            end
            if (dst_write_valid && dst_write_ready) begin
                if (dst_write_bank != cmd_bank[2] || dst_write_addr >= 6144 ||
                    $countones(dst_write_strb) != 2)
                    $fatal(1, "bad destination write");
                for (int byte_index = 0; byte_index < 16; byte_index++)
                    if (dst_write_strb[byte_index])
                        dst_mem[dst_write_addr][byte_index*8 +: 8] <=
                            dst_write_data[byte_index*8 +: 8];
                write_count <= write_count + 1;
            end
        end
    end

    task automatic set_act(input int index, input logic [15:0] value);
        act_mem[index/8][16*(index%8) +: 16] = value;
    endtask
    task automatic set_weight(input int index, input logic [15:0] value);
        weight_mem[index/8][16*(index%8) +: 16] = value;
    endtask
    function automatic logic [15:0] get_dst(input int index);
        get_dst = dst_mem[index/8][16*(index%8) +: 16];
    endfunction
    function automatic logic [15:0] bf16_int(input int value);
        case (value)
            1: bf16_int = 16'h3f80; 2: bf16_int = 16'h4000;
            3: bf16_int = 16'h4040; 4: bf16_int = 16'h4080;
            5: bf16_int = 16'h40a0; 6: bf16_int = 16'h40c0;
            7: bf16_int = 16'h40e0; 8: bf16_int = 16'h4100;
            10: bf16_int = 16'h4120; 12: bf16_int = 16'h4140;
            14: bf16_int = 16'h4160; 16: bf16_int = 16'h4180;
            default: bf16_int = 16'h0000;
        endcase
    endfunction
    function automatic logic [15:0] exact_bf16_positive_int(input int value);
        int high_bit;
        int significand;
        high_bit = 0;
        for (int bit_index = 0; bit_index < 16; bit_index++)
            if (value >= (1 << bit_index)) high_bit = bit_index;
        if (high_bit >= 7) significand = value >> (high_bit-7);
        else significand = value << (7-high_bit);
        exact_bf16_positive_int = {1'b0, 8'(high_bit+127), 7'(significand)};
    endfunction
    function automatic logic [111:0] payload(
        input int n_start, input int n_total, input int m_start,
        input int m_count, input int k, input int n_tile);
        payload = {49'd0, 16'(n_start), 16'(n_total), 6'(m_start),
                   6'(m_count), 11'(k), 8'(n_tile)};
    endfunction
    task automatic issue(input logic [111:0] p);
        @(negedge aclk);
        cmd_payload = p;
        cmd_valid = 1;
        if (!cmd_ready) $fatal(1, "executor not ready");
        @(negedge aclk); cmd_valid = 0;
    endtask
    task automatic finish_response(input logic expected_error,
                                   input int expected_writes);
        wait (done_valid);
        #1;
        if (done_error != expected_error || done_tag != 2 ||
            done_bank_count != 3 || done_bank[0] != 2 ||
            done_bank[1] != 3 || done_bank[2] != cmd_bank[2] ||
            write_count != expected_writes)
            $fatal(1, "completion mismatch err=%b writes=%0d",
                   done_error, write_count);
        repeat (2) @(negedge aclk);
        if (!done_valid || cmd_ready) $fatal(1, "response did not hold");
        done_ready = 1;
        @(negedge aclk); done_ready = 0;
        if (!cmd_ready) $fatal(1, "executor did not become ready");
    endtask

    initial begin
        for (int i = 0; i < 64; i++) begin
            act_mem[i] = 0; weight_mem[i] = 0;
        end
        for (int i = 0; i < 6144; i++)
            dst_mem[i] = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
        // A = [[1..8], [2,4,..16]]. W rows are 1, 0.5, alternating
        // +/-1, and 2. Expected BF16 outputs come from exact dot products.
        for (int k = 0; k < 8; k++) begin
            set_act(k, bf16_int(k+1));
            set_act(8+k, bf16_int(2*(k+1)));
            set_weight(k, 16'h3f80);
            set_weight(8+k, 16'h3f00);
            set_weight(16+k, (k & 1) ? 16'hbf80 : 16'h3f80);
            set_weight(24+k, 16'h4000);
        end
        repeat (3) @(negedge aclk);
        aresetn = 1;
        dst_write_ready = 0;
        issue(payload(2, 8, 0, 2, 8, 4));
        // Stall one destination write: DONE must wait for its handshake.
        wait (dst_write_valid);
        repeat (2) @(negedge aclk);
        if (done_valid) $fatal(1, "DONE before destination write");
        dst_write_ready = 1;
        finish_response(0, 8);
        if (get_dst(0) != 16'hbeef || get_dst(1) != 16'hdead ||
            get_dst(2) != 16'h4210 || get_dst(3) != 16'h4190 ||
            get_dst(4) != 16'hc080 || get_dst(5) != 16'h4290 ||
            get_dst(10) != 16'h4290 || get_dst(11) != 16'h4210 ||
            get_dst(12) != 16'hc100 || get_dst(13) != 16'h4310)
            $fatal(1, "BF16 GEMM output or offset mismatch: %h %h %h %h",
                   get_dst(2), get_dst(3), get_dst(4), get_dst(5));

        // Exact-rational golden values, odd K, nonzero M start, and an N
        // tile crossing a 128-bit destination word boundary.
        $readmemh("activation.hex", random_act);
        $readmemh("weight.hex", random_weight);
        $readmemh("expected.hex", random_expected);
        for (int i = 0; i < 64; i++) begin
            act_mem[i] = 0; weight_mem[i] = 0;
        end
        for (int i = 0; i < 6144; i++)
            dst_mem[i] = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
        for (int i = 0; i < 27; i++) set_act(i, random_act[i]);
        for (int i = 0; i < 45; i++) set_weight(i, random_weight[i]);
        issue(payload(3, 16, 1, 2, 9, 5));
        finish_response(0, 18);
        for (int row = 0; row < 2; row++) begin
            for (int col = 0; col < 5; col++) begin
                if (get_dst(row*16 + 3 + col) !== random_expected[row*5 + col])
                    $fatal(1, "golden mismatch row=%0d col=%0d got=%h expected=%h",
                           row, col, get_dst(row*16 + 3 + col),
                           random_expected[row*5 + col]);
            end
        end
        if (get_dst(0) != 16'hbeef || get_dst(2) != 16'hbeef ||
            get_dst(8) != 16'hbeef || get_dst(18) != 16'hbeef ||
            get_dst(24) != 16'hbeef)
            $fatal(1, "GEMM clobbered lanes outside N tile");

        // Exact halfway cases exercise BF16 ties-to-even at output.
        act_mem[0] = 0; weight_mem[0] = 0;
        set_act(0, 16'h3f80); set_act(1, 16'h3b80);
        set_weight(0, 16'h3f80); set_weight(1, 16'h3f80);
        issue(payload(0, 8, 0, 1, 2, 1));
        finish_response(0, 19);
        if (get_dst(0) != 16'h3f80)
            $fatal(1, "even BF16 tie rounded incorrectly: %h", get_dst(0));
        act_mem[0] = 0; weight_mem[0] = 0;
        set_act(0, 16'h3f80); set_act(1, 16'h3c00);
        set_act(2, 16'h3b80);
        set_weight(0, 16'h3f80); set_weight(1, 16'h3f80);
        set_weight(2, 16'h3f80);
        issue(payload(0, 8, 0, 1, 3, 1));
        finish_response(0, 20);
        if (get_dst(0) != 16'h3f82)
            $fatal(1, "odd BF16 tie rounded incorrectly: %h", get_dst(0));

        // BF16 subnormal values remain representable; nonfinite input errors.
        act_mem[0] = 0; weight_mem[0] = 0;
        set_act(0, 16'h0001); set_weight(0, 16'h3f80);
        issue(payload(0, 8, 0, 1, 1, 1));
        finish_response(0, 21);
        if (get_dst(0) != 16'h0001)
            $fatal(1, "subnormal BF16 result mismatch: %h", get_dst(0));
        set_act(0, 16'h7f80);
        issue(payload(0, 8, 0, 1, 1, 1));
        finish_response(1, 21);

        // A malformed N window returns error with the original bank IDs.
        issue(payload(7, 8, 0, 1, 8, 2));
        finish_response(1, 21);

        // Agreed processing window and N tile: 32x1 @ 1x192.
        @(negedge aclk); cmd_bank[2] = 8;
        for (int i = 0; i < 64; i++) begin act_mem[i] = 0; weight_mem[i] = 0; end
        for (int i = 0; i < 6144; i++) dst_mem[i] = '0;
        for (int row = 0; row < 32; row++) set_act(row, 16'h3f80);
        for (int col = 0; col < 192; col++) set_weight(col, 16'h4040);
        issue(payload(0, 192, 0, 32, 1, 192));
        finish_response(0, 6165);
        $display("CYCLES full_m32_n192_k1=%0d", last_command_cycles);
        for (int row = 0; row < 32; row++)
            for (int col = 0; col < 192; col++)
                if (get_dst(row*192+col) != 16'h4040)
                    $fatal(1, "full 32x192 tile mismatch row=%0d col=%0d", row, col);

        // Last-token lm_head window: activation row 31 and final 192 columns
        // of a 49,152-wide output in B12, including its last physical word.
        @(negedge aclk); cmd_bank[2] = 12;
        for (int i = 0; i < 64; i++) begin act_mem[i] = 0; weight_mem[i] = 0; end
        for (int i = 0; i < 6144; i++) dst_mem[i] = '0;
        set_act(31, 16'h4000);
        for (int col = 0; col < 192; col++) set_weight(col, 16'h3f80);
        issue(payload(48960, 49152, 31, 1, 1, 192));
        finish_response(0, 6357);
        if (get_dst(48959) != 16'h0000 || get_dst(49152-1) != 16'h4000)
            $fatal(1, "last-logit output boundary mismatch");
        for (int col = 0; col < 192; col++)
            if (get_dst(48960+col) != 16'h4000)
                $fatal(1, "last-logit tile mismatch col=%0d", col);

        // Full K for down_proj: 1x1536 @ 1536x1, no K split or partial sum.
        @(negedge aclk); cmd_bank[2] = 4;
        for (int i = 0; i < 192; i++) begin act_mem[i] = 0; weight_mem[i] = 0; end
        dst_mem[0] = '0;
        for (int k = 0; k < 1536; k++) begin
            set_act(k, 16'h3f80);
            set_weight(k, 16'h3f80);
        end
        issue(payload(0, 8, 0, 1, 1536, 1));
        finish_response(0, 6358);
        $display("CYCLES full_k1536_one_output=%0d", last_command_cycles);
        if (get_dst(0) != 16'h44c0)
            $fatal(1, "full-K accumulation mismatch: %h", get_dst(0));

        // Actual BF16 activations and weights captured from the pinned
        // SmolLM2 layer-0 Q projection in prefill32 and decode1.
        $readmemh("prefill_activation.hex", model_prefill_act);
        $readmemh("decode_activation.hex", model_decode_act);
        $readmemh("model_weight.hex", model_weight);
        $readmemh("prefill_exact.hex", model_prefill_expected);
        $readmemh("decode_exact.hex", model_decode_expected);
        $readmemh("prefill_torch.hex", model_prefill_torch);
        $readmemh("decode_torch.hex", model_decode_torch);
        for (int i = 0; i < 2304; i++) act_mem[i] = 0;
        for (int i = 0; i < 288; i++) weight_mem[i] = 0;
        for (int i = 0; i < 144; i++) dst_mem[i] = 0;
        for (int i = 0; i < 18432; i++) set_act(i, model_prefill_act[i]);
        for (int i = 0; i < 2304; i++) set_weight(i, model_weight[i]);
        issue(payload(0, 576, 30, 2, 576, 4));
        finish_response(0, 6366);
        $display("CYCLES checkpoint_prefill_2x576_576x4=%0d", last_command_cycles);
        for (int row = 0; row < 2; row++)
            for (int col = 0; col < 4; col++)
                if (get_dst(row*576+col) !== model_prefill_expected[row*4+col] ||
                    get_dst(row*576+col) !== model_prefill_torch[row*4+col])
                    $fatal(1, "checkpoint prefill BF16 mismatch row=%0d col=%0d got=%h exact=%h torch=%h",
                           row, col, get_dst(row*576+col),
                           model_prefill_expected[row*4+col], model_prefill_torch[row*4+col]);

        for (int i = 0; i < 2304; i++) act_mem[i] = 0;
        for (int i = 0; i < 72; i++) dst_mem[i] = 0;
        for (int i = 0; i < 576; i++) set_act(i, model_decode_act[i]);
        issue(payload(0, 576, 0, 1, 576, 4));
        finish_response(0, 6370);
        $display("CYCLES checkpoint_decode_1x576_576x4=%0d", last_command_cycles);
        for (int col = 0; col < 4; col++)
            if (get_dst(col) !== model_decode_expected[col] ||
                get_dst(col) !== model_decode_torch[col])
                $fatal(1, "checkpoint decode BF16 mismatch col=%0d got=%h exact=%h torch=%h",
                       col, get_dst(col), model_decode_expected[col],
                       model_decode_torch[col]);
        // Four output tiles and three K waves per tile, including M/N/K tails.
        for (int i = 0; i < 72; i++) begin
            act_mem[i] = 0; weight_mem[i] = 0; dst_mem[i] = 0;
        end
        for (int i = 0; i < 17*33; i++) begin
            set_act(i, 16'h3f80);
            set_weight(i, 16'h3f80);
        end
        issue(payload(0, 17, 0, 17, 33, 17));
        finish_response(0, 6659);
        $display("CYCLES m17_n17_k33=%0d", last_command_cycles);
        for (int row = 0; row < 17; row++)
            for (int col = 0; col < 17; col++)
                if (get_dst(row*17+col) !== 16'h4204)
                    $fatal(1, "systolic tile/tail mismatch row=%0d col=%0d got=%h",
                           row, col, get_dst(row*17+col));
        // Representative full processing window with all 256 PEs active.
        for (int i = 0; i < 2304; i++) act_mem[i] = 0;
        for (int i = 0; i < 13824; i++) weight_mem[i] = 0;
        for (int i = 0; i < 768; i++) dst_mem[i] = 0;
        for (int i = 0; i < 32*576; i++) set_act(i, 16'h3f80);
        for (int i = 0; i < 192*576; i++) set_weight(i, 16'h3f80);
        issue(payload(0, 192, 0, 32, 576, 192));
        finish_response(0, 12803);
        $display("CYCLES full_m32_n192_k576=%0d", last_command_cycles);
        for (int row = 0; row < 32; row++)
            for (int col = 0; col < 192; col++)
                if (get_dst(row*192+col) !== 16'h4410)
                    $fatal(1, "full-window systolic mismatch row=%0d col=%0d got=%h",
                           row, col, get_dst(row*192+col));
        // Distinct values at every row/column expose wavefront wiring errors.
        act_mem[0] = 0; act_mem[1] = 0;
        weight_mem[0] = 0; weight_mem[1] = 0;
        for (int i = 0; i < 32; i++) dst_mem[i] = 0;
        for (int row = 0; row < 16; row++) set_act(row, exact_bf16_positive_int(row+1));
        for (int col = 0; col < 16; col++) set_weight(col, exact_bf16_positive_int(col+1));
        issue(payload(0, 16, 0, 16, 1, 16));
        finish_response(0, 13059);
        for (int row = 0; row < 16; row++)
            for (int col = 0; col < 16; col++)
                if (get_dst(row*16+col) !== exact_bf16_positive_int((row+1)*(col+1)))
                    $fatal(1, "wavefront mismatch row=%0d col=%0d got=%h",
                           row, col, get_dst(row*16+col));
        // Broader actual checkpoint sample: all 16 columns of a PE row.
        $readmemh("weight16.hex", model16_weight);
        $readmemh("prefill_exact16.hex", model16_prefill_exact);
        $readmemh("prefill_torch16.hex", model16_prefill_torch);
        $readmemh("decode_exact16.hex", model16_decode_exact);
        $readmemh("decode_torch16.hex", model16_decode_torch);
        $readmemh("prefill32_exact16.hex", model16_prefill32_exact);
        $readmemh("prefill32_torch16.hex", model16_prefill32_torch);
        for (int i = 0; i < 2304; i++) act_mem[i] = 0;
        for (int i = 0; i < 1152; i++) weight_mem[i] = 0;
        for (int i = 0; i < 144; i++) dst_mem[i] = 0;
        for (int i = 0; i < 18432; i++) set_act(i, model_prefill_act[i]);
        for (int i = 0; i < 9216; i++) set_weight(i, model16_weight[i]);
        issue(payload(0, 576, 30, 2, 576, 16));
        finish_response(0, 13091);
        for (int row = 0; row < 2; row++)
            for (int col = 0; col < 16; col++)
                if (get_dst(row*576+col) !== model16_prefill_exact[row*16+col] ||
                    get_dst(row*576+col) !== model16_prefill_torch[row*16+col])
                    $fatal(1, "checkpoint 16-column prefill mismatch row=%0d col=%0d got=%h exact=%h torch=%h",
                           row, col, get_dst(row*576+col),
                           model16_prefill_exact[row*16+col], model16_prefill_torch[row*16+col]);
        for (int i = 0; i < 72; i++) act_mem[i] = 0;
        for (int i = 0; i < 72; i++) dst_mem[i] = 0;
        for (int i = 0; i < 576; i++) set_act(i, model_decode_act[i]);
        issue(payload(0, 576, 0, 1, 576, 16));
        finish_response(0, 13107);
        for (int col = 0; col < 16; col++)
            if (get_dst(col) !== model16_decode_exact[col] ||
                get_dst(col) !== model16_decode_torch[col])
                $fatal(1, "checkpoint 16-column decode mismatch col=%0d got=%h exact=%h torch=%h",
                       col, get_dst(col), model16_decode_exact[col], model16_decode_torch[col]);
        for (int i = 0; i < 2304; i++) begin act_mem[i] = 0; dst_mem[i] = 0; end
        for (int i = 0; i < 18432; i++) set_act(i, model_prefill_act[i]);
        issue(payload(0, 576, 0, 32, 576, 16));
        finish_response(0, 13619);
        for (int row = 0; row < 32; row++)
            for (int col = 0; col < 16; col++)
                if (get_dst(row*576+col) !== model16_prefill32_exact[row*16+col] ||
                    get_dst(row*576+col) !== model16_prefill32_torch[row*16+col])
                    $fatal(1, "checkpoint full prefill mismatch row=%0d col=%0d got=%h exact=%h torch=%h",
                           row, col, get_dst(row*576+col),
                           model16_prefill32_exact[row*16+col],
                           model16_prefill32_torch[row*16+col]);
        $display("PASS smollm2_gemm_systolic_wide_executor");
        $finish;
    end
    initial begin
        #5000000;
        $fatal(1, "GEMM timeout");
    end
endmodule
