module TopModule (
    input  logic       clk,
    input  logic       areset,
    input  logic       predict_valid,
    input  logic [6:0] predict_pc,
    output logic       predict_taken,
    output logic [6:0] predict_history,
    input  logic       train_valid,
    input  logic       train_taken,
    input  logic       train_mispredicted,
    input  logic [6:0] train_history,
    input  logic [6:0] train_pc
);
    logic [6:0] history_r;
    logic [1:0] pht_r [0:127];
    wire [6:0] predict_index_w = predict_pc ^ history_r;
    wire [6:0] train_index_w = train_pc ^ train_history;

    assign predict_history = history_r;
    assign predict_taken = pht_r[predict_index_w][1];

    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            history_r <= 7'b0;
            for (integer i = 0; i < 128; i = i + 1)
                pht_r[i] <= 2'b01;
        end else begin
            if (train_valid && train_mispredicted)
                history_r <= {train_history[5:0], train_taken};
            else if (predict_valid)
                history_r <= {history_r[5:0], predict_taken};

            if (train_valid) begin
                if (train_taken) begin
                    if (pht_r[train_index_w] != 2'b11)
                        pht_r[train_index_w] <= pht_r[train_index_w] + 2'b01;
                end else begin
                    if (pht_r[train_index_w] != 2'b00)
                        pht_r[train_index_w] <= pht_r[train_index_w] - 2'b01;
                end
            end
        end
    end
endmodule
