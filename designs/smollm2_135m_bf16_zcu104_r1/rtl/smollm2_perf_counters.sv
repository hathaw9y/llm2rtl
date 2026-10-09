`timescale 1ns/1ps
// Per-fragment, read-only observations; no control or tensor datapath feedback.
module smollm2_perf_counters #(
    parameter int DMA_DATA_WIDTH = 128
) (
    input logic aclk, aresetn, clear,
    input logic [18:0] events,
    input logic load_valid, load_ready,
    input logic [DMA_DATA_WIDTH/8-1:0] load_keep,
    input logic store_valid, store_ready,
    input logic [DMA_DATA_WIDTH/8-1:0] store_keep,
    input logic [6:0] read_index,
    output logic [15:0] read_value
);
    logic [63:0] count [0:23];
    logic [7:0] load_bytes, store_bytes;
    always_comb begin
        load_bytes = 0;
        store_bytes = 0;
        for (int i=0; i<DMA_DATA_WIDTH/8; i++) begin
            load_bytes = load_bytes + {7'd0, load_keep[i]};
            store_bytes = store_bytes + {7'd0, store_keep[i]};
        end
        read_value = '0;
        if (read_index < 96)
            read_value = count[read_index[6:2]][16*read_index[1:0] +: 16];
    end
    always_ff @(posedge aclk) begin
        if (!aresetn || clear) begin
            for (int i=0; i<24; i++) count[i] <= 0;
        end else if (events[0]) begin
            for (int i=0; i<19; i++)
                count[i] <= count[i] + {63'd0, events[i]};
            if (load_valid && load_ready) count[19] <= count[19] + {56'd0, load_bytes};
            if (store_valid && store_ready) count[20] <= count[20] + {56'd0, store_bytes};
            count[21] <= count[21] + {63'd0, (load_valid && !load_ready)};
            count[22] <= count[22] + {63'd0, (store_valid && !store_ready)};
            count[23] <= count[23] + {63'd0, (events[1] && events[18])};
        end
    end
endmodule
