module TopModule (
    input wire clk,
    input wire areset,
    input wire predict_valid,
    input wire [6:0] predict_pc,
    output wire predict_taken,
    output wire [6:0] predict_history,
    input wire train_valid,
    input wire train_taken,
    input wire train_mispredicted,
    input wire [6:0] train_history,
    input wire [6:0] train_pc
);
    reg [6:0] history;
    reg [1:0] pht [0:127];
    wire [6:0] predict_index = predict_pc ^ history;
    wire [6:0] train_index = train_pc ^ train_history;
    integer i;

    assign predict_history = history;
    assign predict_taken = pht[predict_index][1];

    always @(posedge clk or posedge areset) begin
        if (areset) begin
            history <= 7'b0;
            for (i = 0; i < 128; i = i + 1)
                pht[i] <= 2'b01;
        end else begin
            if (train_valid && train_mispredicted)
                history <= {train_history[5:0], train_taken};
            else if (predict_valid)
                history <= {history[5:0], predict_taken};

            if (train_valid) begin
                if (train_taken) begin
                    if (pht[train_index] != 2'b11)
                        pht[train_index] <= pht[train_index] + 2'b01;
                end else begin
                    if (pht[train_index] != 2'b00)
                        pht[train_index] <= pht[train_index] - 2'b01;
                end
            end
        end
    end
endmodule
