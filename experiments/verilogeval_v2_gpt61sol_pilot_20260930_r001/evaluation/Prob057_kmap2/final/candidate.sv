module TopModule (
    input logic a,
    input logic b,
    input logic c,
    input logic d,
    output logic out
);
    always_comb begin
        case ({a,b,c,d})
            4'd0, 4'd1, 4'd2, 4'd4, 4'd6,
            4'd7, 4'd8, 4'd9, 4'd11, 4'd15: out = 1'b1;
            default: out = 1'b0;
        endcase
    end
endmodule
