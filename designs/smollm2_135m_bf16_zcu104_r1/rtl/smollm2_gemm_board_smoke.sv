`timescale 1ns/1ps

// Bounded PS-driven GEMM hardware test. The host transfers precomputed BF16
// words and one ISA GEMM record. All GEMM arithmetic runs in the PL executor.
module smollm2_gemm_board_smoke (
    input  logic aclk,
    input  logic aresetn,
    input  logic [31:0] host_data0,
    input  logic [31:0] host_data1,
    input  logic [31:0] host_data2,
    input  logic [31:0] host_data3,
    input  logic [31:0] host_control,
    output logic [31:0] host_status
);
    typedef enum logic [3:0] {
        IDLE, ACQUIRE_WRITE, WRITE_WORD, RELEASE_WRITE,
        ACQUIRE_GEMM, SEND_GEMM, WAIT_GEMM, RELEASE_GEMM,
        ACQUIRE_READ, SEND_READ, WAIT_READ, RELEASE_READ, ACK
    } state_t;
    state_t state_r;
    logic seq_seen_r, ack_seq_r, done_r, error_r;
    logic [3:0] host_bank_r;
    logic [15:0] host_addr_r, result_r;
    logic [127:0] data_r, gemm_record_r;
    logic [4:0] write_role_w;

    logic [0:12] bank_acquire_valid, bank_release_valid, bank_busy;
    logic [0:12][4:0] bank_acquire_port, bank_release_port, bank_owner_port;
    logic [0:20] role_read_valid, role_read_ready, role_read_wide;
    logic [0:20][3:0] role_read_bank, role_rsp_bank;
    logic [0:20][15:0] role_read_addr;
    logic [0:20] role_rsp_valid, role_write_valid, role_write_ready;
    logic [0:20][127:0] role_rsp_data, role_write_data;
    logic [0:20][255:0] role_rsp_wide_data;
    logic [0:20][3:0] role_write_bank;
    logic [0:20][15:0] role_write_addr, role_write_strb;
    logic subsystem_error, ownership_error, router_error;
    logic [1:0] subsystem_error_code;
    logic [2:0] ownership_error_code, router_error_code;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank;

    logic cmd_valid, cmd_ready, done_valid, done_ready, done_error;
    logic [3:0] done_tag;
    logic [1:0] done_bank_count;
    logic [2:0][3:0] done_bank;
    logic act_read_valid, act_read_ready, act_rsp_valid;
    logic [3:0] act_read_bank, act_rsp_bank;
    logic [15:0] act_read_addr;
    logic [255:0] act_rsp_data;
    logic weight_read_valid, weight_read_ready, weight_rsp_valid;
    logic [3:0] weight_read_bank, weight_rsp_bank;
    logic [15:0] weight_read_addr;
    logic [255:0] weight_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;

    assign write_role_w = host_bank_r == 4'd2 ? 5'd8 : 5'd1;
    assign host_status = {ack_seq_r, (state_r != IDLE), done_r,
                          (error_r || subsystem_error),
                          12'(state_r), result_r};

    smollm2_bank_subsystem_wide banks (
        .aclk(aclk), .aresetn(aresetn),
        .bank_acquire_valid(bank_acquire_valid),
        .bank_acquire_port(bank_acquire_port),
        .bank_release_valid(bank_release_valid),
        .bank_release_port(bank_release_port),
        .bank_busy(bank_busy), .bank_owner_port(bank_owner_port),
        .role_read_valid(role_read_valid), .role_read_ready(role_read_ready),
        .role_read_bank(role_read_bank), .role_read_addr(role_read_addr),
        .role_read_wide(role_read_wide), .role_rsp_valid(role_rsp_valid),
        .role_rsp_bank(role_rsp_bank), .role_rsp_data(role_rsp_data),
        .role_rsp_wide_data(role_rsp_wide_data),
        .role_write_valid(role_write_valid),
        .role_write_ready(role_write_ready),
        .role_write_bank(role_write_bank), .role_write_addr(role_write_addr),
        .role_write_strb(role_write_strb), .role_write_data(role_write_data),
        .subsystem_error(subsystem_error),
        .subsystem_error_code(subsystem_error_code),
        .ownership_error(ownership_error),
        .ownership_error_code(ownership_error_code),
        .router_error(router_error), .router_error_code(router_error_code),
        .router_error_role(router_error_role), .router_error_bank(router_error_bank)
    );

    smollm2_gemm_systolic_wide_executor gemm (
        .aclk(aclk), .aresetn(aresetn),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .cmd_opcode(gemm_record_r[127:124]),
        .cmd_bank({gemm_record_r[115:112], gemm_record_r[119:116],
                   gemm_record_r[123:120]}),
        .cmd_payload(gemm_record_r[111:0]),
        .done_valid(done_valid), .done_ready(done_ready),
        .done_tag(done_tag), .done_bank_count(done_bank_count),
        .done_bank(done_bank), .done_error(done_error),
        .act_read_valid(act_read_valid), .act_read_ready(act_read_ready),
        .act_read_bank(act_read_bank), .act_read_addr(act_read_addr),
        .act_rsp_valid(act_rsp_valid), .act_rsp_bank(act_rsp_bank),
        .act_rsp_data(act_rsp_data),
        .weight_read_valid(weight_read_valid),
        .weight_read_ready(weight_read_ready),
        .weight_read_bank(weight_read_bank),
        .weight_read_addr(weight_read_addr),
        .weight_rsp_valid(weight_rsp_valid),
        .weight_rsp_bank(weight_rsp_bank),
        .weight_rsp_data(weight_rsp_data),
        .dst_write_valid(dst_write_valid), .dst_write_ready(dst_write_ready),
        .dst_write_bank(dst_write_bank), .dst_write_addr(dst_write_addr),
        .dst_write_strb(dst_write_strb), .dst_write_data(dst_write_data)
    );

    always_comb begin
        bank_acquire_valid = '0; bank_acquire_port = '0;
        bank_release_valid = '0; bank_release_port = '0;
        if (state_r == ACQUIRE_WRITE) begin
            bank_acquire_valid[host_bank_r] = 1'b1;
            bank_acquire_port[host_bank_r] = write_role_w;
        end
        if (state_r == RELEASE_WRITE) begin
            bank_release_valid[host_bank_r] = 1'b1;
            bank_release_port[host_bank_r] = write_role_w;
        end
        if (state_r == ACQUIRE_GEMM || state_r == RELEASE_GEMM) begin
            if (state_r == ACQUIRE_GEMM)
                bank_acquire_valid[2] = 1'b1;
            else bank_release_valid[2] = 1'b1;
            if (state_r == ACQUIRE_GEMM)
                bank_acquire_valid[3] = 1'b1;
            else bank_release_valid[3] = 1'b1;
            if (state_r == ACQUIRE_GEMM)
                bank_acquire_valid[4] = 1'b1;
            else bank_release_valid[4] = 1'b1;
            bank_acquire_port[2] = 5'd3; bank_release_port[2] = 5'd3;
            bank_acquire_port[3] = 5'd4; bank_release_port[3] = 5'd4;
            bank_acquire_port[4] = 5'd5; bank_release_port[4] = 5'd5;
        end
        if (state_r == ACQUIRE_READ) begin
            bank_acquire_valid[4] = 1'b1;
            bank_acquire_port[4] = 5'd11;
        end
        if (state_r == RELEASE_READ) begin
            bank_release_valid[4] = 1'b1;
            bank_release_port[4] = 5'd11;
        end

        role_read_valid = '0; role_read_bank = '0;
        role_read_addr = '0; role_read_wide = '0;
        role_read_valid[3] = act_read_valid;
        role_read_bank[3] = act_read_bank;
        role_read_addr[3] = act_read_addr;
        role_read_wide[3] = 1'b1;
        role_read_valid[4] = weight_read_valid;
        role_read_bank[4] = weight_read_bank;
        role_read_addr[4] = weight_read_addr;
        role_read_wide[4] = 1'b1;
        role_read_valid[11] = state_r == SEND_READ;
        role_read_bank[11] = 4'd4;
        role_read_addr[11] = host_addr_r >> 3;
        role_write_valid = '0; role_write_bank = '0;
        role_write_addr = '0; role_write_strb = '0;
        role_write_data = '0;
        role_write_valid[write_role_w] = state_r == WRITE_WORD;
        role_write_bank[write_role_w] = host_bank_r;
        role_write_addr[write_role_w] = host_addr_r;
        role_write_strb[write_role_w] = 16'hffff;
        role_write_data[write_role_w] = data_r;
        role_write_valid[5] = dst_write_valid;
        role_write_bank[5] = dst_write_bank;
        role_write_addr[5] = dst_write_addr;
        role_write_strb[5] = dst_write_strb;
        role_write_data[5] = dst_write_data;
    end
    assign act_read_ready = role_read_ready[3];
    assign act_rsp_valid = role_rsp_valid[3];
    assign act_rsp_bank = role_rsp_bank[3];
    assign act_rsp_data = role_rsp_wide_data[3];
    assign weight_read_ready = role_read_ready[4];
    assign weight_rsp_valid = role_rsp_valid[4];
    assign weight_rsp_bank = role_rsp_bank[4];
    assign weight_rsp_data = role_rsp_wide_data[4];
    assign dst_write_ready = role_write_ready[5];
    assign cmd_valid = state_r == SEND_GEMM;
    assign done_ready = state_r == WAIT_GEMM;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; seq_seen_r <= 1'b0; ack_seq_r <= 1'b0;
            done_r <= 1'b0; error_r <= 1'b0; result_r <= '0;
            host_bank_r <= '0; host_addr_r <= '0;
            data_r <= '0; gemm_record_r <= '0;
        end else begin
            case (state_r)
                IDLE: if (host_control[31] != seq_seen_r) begin
                    seq_seen_r <= host_control[31];
                    host_bank_r <= host_control[27:24];
                    host_addr_r <= host_control[15:0];
                    data_r <= {host_data3, host_data2, host_data1, host_data0};
                    error_r <= 1'b0;
                    case (host_control[30:28])
                        3'd1: if ((host_control[27:24] == 4'd2 &&
                                    host_control[15:0] < 16'd2304) ||
                                   (host_control[27:24] == 4'd3 &&
                                    host_control[15:0] < 16'd36864))
                            state_r <= ACQUIRE_WRITE;
                        else begin error_r <= 1'b1; state_r <= ACK; end
                        3'd2: if (host_data3[31:16] ==
                                   {4'd3,4'd2,4'd3,4'd4}) begin
                            gemm_record_r <= {host_data3,host_data2,host_data1,host_data0};
                            done_r <= 1'b0;
                            state_r <= ACQUIRE_GEMM;
                        end else begin error_r <= 1'b1; state_r <= ACK; end
                        3'd3: if (host_control[27:24] == 4'd4 &&
                                    host_control[15:0] < 16'd18432)
                            state_r <= ACQUIRE_READ;
                        else begin error_r <= 1'b1; state_r <= ACK; end
                        default: begin error_r <= 1'b1; state_r <= ACK; end
                    endcase
                end
                ACQUIRE_WRITE: state_r <= WRITE_WORD;
                WRITE_WORD: if (role_write_ready[write_role_w])
                    state_r <= RELEASE_WRITE;
                RELEASE_WRITE: state_r <= ACK;
                ACQUIRE_GEMM: state_r <= SEND_GEMM;
                SEND_GEMM: if (cmd_ready) state_r <= WAIT_GEMM;
                WAIT_GEMM: if (done_valid) begin
                    done_r <= 1'b1;
                    if (done_error || done_tag != 4'd2 ||
                        done_bank_count != 2'd3 ||
                        done_bank != {4'd4,4'd3,4'd2}) error_r <= 1'b1;
                    state_r <= RELEASE_GEMM;
                end
                RELEASE_GEMM: state_r <= ACK;
                ACQUIRE_READ: state_r <= SEND_READ;
                SEND_READ: if (role_read_ready[11]) state_r <= WAIT_READ;
                WAIT_READ: if (role_rsp_valid[11]) begin
                    result_r <= role_rsp_data[11][16*host_addr_r[2:0] +: 16];
                    state_r <= RELEASE_READ;
                end
                RELEASE_READ: state_r <= ACK;
                ACK: begin ack_seq_r <= seq_seen_r; state_r <= IDLE; end
                default: state_r <= IDLE;
            endcase
        end
    end
endmodule
